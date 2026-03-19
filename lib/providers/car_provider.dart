import 'package:car_maintenance_tracker/database.dart';
import 'package:car_maintenance_tracker/services/api_car_service.dart';
import 'package:car_maintenance_tracker/services/sync_service.dart';
import 'package:car_maintenance_tracker/utils/api_response.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/car.dart';
import '../utils/app_logger.dart';

class CarProvider extends ChangeNotifier {
  List<Car> _cars = [];
  String _searchQuery = '';
  final ApiCarService _apiCarService = ApiCarService();

  CarProvider() {
    SyncService().registerSyncTask(syncAllData);
  }

  List<Car> getCars () => _cars;

  String getSearchQuery () => _searchQuery;

  void updateSearchQuery(String newSearchQuery) {
    _searchQuery = newSearchQuery;
    notifyListeners();
  }

  void clearCache() {
    _cars = [];
    _searchQuery = '';
    notifyListeners();
  }

  void _abortSync() {
    AppLogger.error("Sync aborted! Server unreachable");
    SyncService().setIsServiceAvailable = false;
  }

  Future<void> syncAllData() async {
    AppLogger.info("Syncing server with local cars table");
    final db = await AppDatabase.instance.database;
    try {
      final unsyncedCars = await db.query('cars', where: 'is_synced = 0 AND is_deleted = 0');
      for (var carMap in unsyncedCars) {
        Car car = Car.fromMap(carMap);
        ApiResponse<Car> putResponse = await _apiCarService.putCar(car);
        if (putResponse.statusCode == 200) {
          await db.update('cars', {'is_synced': 1}, where: 'car_uuid = ?', whereArgs: [car.carUuid]);
        }
        else if (putResponse.statusCode == 404) {
          ApiResponse<Car> postResponse = await _apiCarService.postCar(car);
          if (postResponse.statusCode == 200 || postResponse.statusCode == 201) {
            await db.update('cars', {'is_synced': 1}, where: 'car_uuid = ?',
                whereArgs: [car.carUuid]);
          }
          else {
            AppLogger.error("Failed to sync car ${car.carUuid} with the server");
          }
        }
        else {
          AppLogger.error("Failed to sync car ${car.carUuid} with the server");
        }
      }
      final deletedCars = await db.query('cars', where: 'is_deleted = 1');
      for (var mapCar in deletedCars) {
        Car car = Car.fromMap(mapCar);
        ApiResponse<String> deleteResponse = await _apiCarService.deleteCar(
            car.carUuid!);
        if (deleteResponse.statusCode == 200) {
          await db.delete(
              'cars', where: 'car_uuid = ?', whereArgs: [car.carUuid]);
        }
        else {
          AppLogger.error("Failed to sync car ${car.carUuid} with the server");
        }
      }
    }
    catch (e) {
      _abortSync();
    }
  }

  Future<void> fetchCars() async {
    AppLogger.info("Starting fetchCars");
    bool loadedFromServer = false;
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<List<Car>> response = await _apiCarService.getAllCars();
        if (response.statusCode == 200) {
          _cars = response.data!;
          loadedFromServer = true;
          await _updateLocalDb();
        }
        else {
          AppLogger.error("Server error");
        }
      }
      catch (e) {
        AppLogger.error("Fetching from server failed, switching to offline mode", e);
        SyncService().setIsServiceAvailable = false;
      }
    }
    if (!loadedFromServer) {
      final db = await AppDatabase.instance.database;
      final result = await db.query('cars', where: 'is_deleted = 0');
      _cars = result.map((e) => Car.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _updateLocalDb() async {
    AppLogger.info("Updating local cars table from server");
    final db = await AppDatabase.instance.database;
    await db.delete('cars', where: 'is_synced = 1 AND is_deleted = 0');
    for (var car in _cars) {
      var carData = car.toMap();
      carData['is_synced'] = 1;
      await db.insert('cars', carData, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> addCar(Car newCar) async {
    AppLogger.info("Adding car");
    final db = await AppDatabase.instance.database;
    final uuid = const Uuid().v4();
    newCar = newCar.copyWith(isSynced: 0, carUuid: uuid);
    await db.insert('cars', newCar.toMap());
    AppLogger.info("Added car with uuid $uuid");

    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<Car> response = await _apiCarService.postCar(newCar);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update('cars', {'is_synced': 1}, where: 'car_uuid = ?', whereArgs: [uuid]);
        }
        else {
          AppLogger.error('Server rejected the data');
        }
      }
      catch (e) {
        AppLogger.error("Server request failed", e);
        SyncService().setIsServiceAvailable = false;
      }
    }
    await fetchCars();
  }

  Future<void> updateCar(Car updatedCar) async {
    AppLogger.info("Updating car ${updatedCar.carUuid}");
    final db = await AppDatabase.instance.database;
    updatedCar = updatedCar.copyWith(isSynced: 0);
    await db.update('cars', updatedCar.toMap(), where: 'car_uuid = ?', whereArgs: [updatedCar.carUuid]);

    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<Car> response = await _apiCarService.putCar(updatedCar);
        if (response.statusCode == 200) {
          await db.update('cars', {'is_synced': 1}, where: 'car_uuid = ?',
              whereArgs: [updatedCar.carUuid]);
        }
        else {
          AppLogger.error('Server rejected the data');
        }
      }
      catch (e) {
        AppLogger.error("Server request failed", e);
        SyncService().setIsServiceAvailable = false;
      }
    }
    await fetchCars();
  }

  Future<void> deleteCar(String carUuid) async {
    AppLogger.info("Deleting car $carUuid");
    final db = await AppDatabase.instance.database;
    await db.update('cars', {'is_deleted': 1, 'is_synced': 0}, where: 'car_uuid = ?', whereArgs: [carUuid]);

    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<String> response = await _apiCarService.deleteCar(carUuid);
        if (response.statusCode == 200) {
          await db.delete('cars', where: 'car_uuid = ?', whereArgs: [carUuid]);
        }
        else {
          AppLogger.error("Server rejected the data");
        }
      }
      catch (e) {
        AppLogger.error("Server request failed", e);
        SyncService().setIsServiceAvailable = false;
      }
    }
    await fetchCars();
  }

  Future<Car?> getById(String carUuid) async {
    AppLogger.info("Attempting to get car $carUuid");
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<Car> response = await _apiCarService.getCarById(carUuid);
        if (response.statusCode == 200) {
          return response.data;
        }
        else if (response.statusCode == 404) {
          AppLogger.error("Car not found on the server");
          return null;
        }
        else {
          AppLogger.error("Server error");
        }
      } catch (e) {
        AppLogger.error("Fetching from server failed, switching to offline mode", e);
        SyncService().setIsServiceAvailable = false;
      }
    }
    final db = await AppDatabase.instance.database;
    final result = await db.query('cars', where: 'car_uuid = ?', whereArgs: [carUuid]);
    if (result.isNotEmpty) {
      return Car.fromMap(result.first);
    }
    AppLogger.error("Car not found");
    return null;
  }

  List<Car> getFilteredCars() {
    AppLogger.info("Attempting to get filtered cars");
    if (_searchQuery.isEmpty) {
      return _cars;
    }
    return _cars.where((car) {
      final query = _searchQuery.toLowerCase();
      return car.model.toLowerCase().contains(query) || car.make.toLowerCase().contains(query) || car.name.toLowerCase().contains(query);
    }).toList();
  }
}
