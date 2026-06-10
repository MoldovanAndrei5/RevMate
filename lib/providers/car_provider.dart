import 'dart:io';
import 'package:car_maintenance_tracker/database.dart';
import 'package:car_maintenance_tracker/services/api_car_service.dart';
import 'package:car_maintenance_tracker/services/api_upload_service.dart';
import 'package:car_maintenance_tracker/providers/sync_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/car.dart';
import '../services/api_transfer_service.dart';
import '../utils/app_logger.dart';

class CarProvider extends ChangeNotifier {
  List<Car> _cars = [];
  String _searchQuery = "";
  final ApiCarService _apiCarService = ApiCarService();
  final ApiUploadService _uploadService = ApiUploadService();
  final ApiTransferService _apiTransferService = ApiTransferService();

  CarProvider() {
    SyncService().registerSyncTask(syncAllData);
  }

  List<Car> getCars() => _cars;
  String getSearchQuery() => _searchQuery;

  void updateSearchQuery(String newSearchQuery) {
    _searchQuery = newSearchQuery;
    notifyListeners();
  }

  void clearCache() {
    _cars = [];
    _searchQuery = "";
    notifyListeners();
  }

  Future<String> _uploadCarImage(File imageFile) async {
    final fileName = imageFile.path.split("/").last;
    final ext = fileName.split(".").last.toLowerCase();
    final fileType = ext == "png" ? "image/png" : "image/jpeg";
    return await _uploadService.uploadFile(
      file: imageFile,
      fileName: fileName,
      fileType: fileType,
      folder: "cars",
    );
  }

  Future<void> syncAllData() async {
    AppLogger.info("Syncing server with local cars table");
    final db = await AppDatabase.instance.database;
    bool hasErrors = false;
      final unsyncedCars = await db.query("cars", where: "is_synced = 0 AND is_deleted = 0");
      for (var carMap in unsyncedCars) {
        Car car = Car.fromMap(carMap);
        try {
          await _apiCarService.putCar(car);
          await db.update("cars", {"is_synced": 1}, where: "car_uuid = ?", whereArgs: [car.carUuid]);
        } on ApiException catch (e) {
          if (e.statusCode == 0) {
            AppLogger.error("Sync aborted! Server unreachable");
            ConnectivityState().isServiceAvailable = false;
            throw Exception("Server unreachable");
          }
          else if (e.statusCode == 404) {
            try {
              await _apiCarService.postCar(car);
              await db.update("cars", {"is_synced": 1}, where: "car_uuid = ?",
                  whereArgs: [car.carUuid]);
            } on ApiException {
              AppLogger.error("Failed to sync car ${car.carUuid}");
              hasErrors = true;
            }
          }
          else {
            AppLogger.error("Failed to sync car ${car.carUuid}: ${e.message}");
            hasErrors = true;
          }
        }
      }
      final deletedCars = await db.query("cars", where: "is_deleted = 1");
      for (var mapCar in deletedCars) {
        Car car = Car.fromMap(mapCar);
        try {
          await _apiCarService.deleteCar(car.carUuid!);
          await db.delete("cars", where: "car_uuid = ?", whereArgs: [car.carUuid]);
        } on ApiException catch (e) {
          if (e.statusCode == 0) {
            AppLogger.error("Sync aborted! Server unreachable");
            ConnectivityState().isServiceAvailable = false;
            throw Exception("Server unreachable");
          }
          if (e.statusCode == 404) {
            await db.delete("cars", where: "car_uuid = ?", whereArgs: [car.carUuid]);
          } else {
            hasErrors = true;
          }
        }
      }
      if (hasErrors) throw Exception("Some cars failed to sync");
  }

  Future<void> fetchCars() async {
    AppLogger.info("Starting fetchCars");
    bool loadedFromServer = false;
    if (ConnectivityState().isServiceAvailable) {
      _cars = await _apiCarService.getAllCars();
      loadedFromServer = true;
      // Filter out cars with pending outgoing transfers
      final transfers = await _apiTransferService.getOutgoingTransfers();
      final pendingUuids = transfers.map((t) => t.carUuid).toSet();
      _cars = _cars.where((c) => !pendingUuids.contains(c.carUuid)).toList();
      await _updateLocalDb();
    }
    if (!loadedFromServer) {
      final db = await AppDatabase.instance.database;
      final result = await db.query("cars", where: "is_deleted = 0");
      _cars = result.map((e) => Car.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _updateLocalDb() async {
    AppLogger.info("Updating local cars table from server");
    final db = await AppDatabase.instance.database;
    await db.delete("cars", where: "is_synced = 1 AND is_deleted = 0");
    for (var car in _cars) {
      var carData = car.toMap();
      carData["is_synced"] = 1;
      await db.insert("cars", carData,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Car> addCar(Car newCar, {File? imageFile}) async {
    AppLogger.info("Adding car");
    final db = await AppDatabase.instance.database;
    final uuid = const Uuid().v4();
    if (imageFile != null && ConnectivityState().isServiceAvailable) {
      final imageKey = await _uploadCarImage(imageFile);
      newCar = newCar.copyWith(imageKey: imageKey);
    }
    newCar = newCar.copyWith(isSynced: 0, carUuid: uuid);
    await db.insert("cars", newCar.toMap());
    AppLogger.info("Added car with uuid $uuid");
    if (ConnectivityState().isServiceAvailable) {
      await _apiCarService.postCar(newCar);
      await db.update("cars", {"is_synced": 1}, where: "car_uuid = ?", whereArgs: [uuid]);
    }
    await fetchCars();
    return _cars.firstWhere((c) => c.carUuid == uuid, orElse: () => newCar);
  }

  Future<void> updateCar(Car updatedCar, {File? imageFile}) async {
    AppLogger.info("Updating car ${updatedCar.carUuid}");
    final db = await AppDatabase.instance.database;
    updatedCar = updatedCar.copyWith(isSynced: 0);
    if (ConnectivityState().isServiceAvailable && imageFile != null) {
      final imageKey = await _uploadCarImage(imageFile);
      updatedCar = updatedCar.copyWith(imageKey: imageKey);
    }
    await db.update("cars", updatedCar.toMap(), where: "car_uuid = ?", whereArgs: [updatedCar.carUuid]);
    if (ConnectivityState().isServiceAvailable) {
      await _apiCarService.putCar(updatedCar);
      await db.update("cars", {"is_synced": 1}, where: "car_uuid = ?", whereArgs: [updatedCar.carUuid]);
    }
    await fetchCars();
  }

  Future<void> deleteCar(String carUuid) async {
    AppLogger.info("Deleting car $carUuid");
    final db = await AppDatabase.instance.database;
    await db.update("cars", {"is_deleted": 1, "is_synced": 0}, where: "car_uuid = ?", whereArgs: [carUuid]);
    if (ConnectivityState().isServiceAvailable) {
      await _apiCarService.deleteCar(carUuid);
      await db.delete("cars", where: "car_uuid = ?", whereArgs: [carUuid]);
    }
    await fetchCars();
  }

  Future<Car> getById(String carUuid) async {
    AppLogger.info("Attempting to get car $carUuid");
    if (ConnectivityState().isServiceAvailable) {
      final car = await _apiCarService.getCarById(carUuid);
      return car;
    }
    final db = await AppDatabase.instance.database;
    final result = await db.query("cars", where: "car_uuid = ?", whereArgs: [carUuid]);
    if (result.isEmpty) {
      throw ApiException("Car not found", 404);
    }
    return Car.fromMap(result.first);
  }

  List<Car> getFilteredCars() {
    if (_searchQuery.isEmpty) return _cars;
    return _cars.where((car) {
      final query = _searchQuery.toLowerCase();
      return car.model.toLowerCase().contains(query) ||
          car.make.toLowerCase().contains(query) ||
          car.name.toLowerCase().contains(query);
    }).toList();
  }
}