import 'package:car_maintenance_tracker/database.dart';
import 'package:car_maintenance_tracker/services/api_task_service.dart';
import 'package:car_maintenance_tracker/providers/sync_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/app_logger.dart';
import 'package:car_maintenance_tracker/utils/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/maintenance_task.dart';
import '../utils/sort_filter_enums.dart';
import 'dart:io';
import 'package:car_maintenance_tracker/services/api_invoice_service.dart';

class TaskProvider extends ChangeNotifier {
  List<MaintenanceTask> _tasks = [];
  TaskSortOption _sortBy = TaskSortOption.date;
  SortOrder _sortOrder = SortOrder.descending;
  TaskFilterOption _filterBy = TaskFilterOption.all;
  final ApiTaskService _apiTaskService = ApiTaskService();
  final ApiInvoiceService _apiInvoiceService = ApiInvoiceService();

  TaskProvider() {
    SyncService().registerSyncTask(syncAllData);
  }

  TaskFilterOption get filterBy => _filterBy;
  TaskSortOption get sortBy => _sortBy;
  SortOrder get sortOrder => _sortOrder;

  void setSortBy(TaskSortOption newSortBy) {
    _sortBy = newSortBy;
    notifyListeners();
  }

  void setSortOrder(SortOrder newSortOrder) {
    _sortOrder = newSortOrder;
    notifyListeners();
  }

  void setFilterBy(TaskFilterOption newFilterBy) {
    _filterBy = newFilterBy;
    notifyListeners();
  }

  List<MaintenanceTask> get tasks => _tasks;

  void clearCache() {
    _tasks = [];
    notifyListeners();
  }

  Future<void> syncAllData() async {
    AppLogger.info("Syncing server with local maintenanceTasks table");
    final db = await AppDatabase.instance.database;
    bool hasErrors = false;
      final unsyncedTasks = await db.query("maintenanceTasks", where: "is_synced = 0 AND is_deleted = 0");
      for (var taskMap in unsyncedTasks) {
        MaintenanceTask task = MaintenanceTask.fromMap(taskMap);
        try {
          await _apiTaskService.putTask(task);
          await db.update("maintenanceTasks", {"is_synced": 1}, where: "task_uuid = ?", whereArgs: [task.taskUuid]);
        } on ApiException catch (e) {
          if (e.statusCode == 0) {
            AppLogger.error("Sync aborted! Server unreachable");
            ConnectivityState().isServiceAvailable = false;
            throw Exception("Server unreachable");
          }
          else if (e.statusCode == 404) {
            try {
              await _apiTaskService.postTask(task);
              await db.update("maintenanceTasks", {"is_synced": 1}, where: "task_uuid = ?", whereArgs: [task.taskUuid]);
            }
            on ApiException {
              AppLogger.error("Failed to sync task ${task.taskUuid}");
              hasErrors = true;
            }
          }
          else {
            AppLogger.error("Failed to sync task ${task.taskUuid}");
            hasErrors = true;
          }
        }
      }
      final deletedCTasks = await db.query("maintenanceTasks", where: "is_deleted = 1");
      for (var taskMap in deletedCTasks) {
        MaintenanceTask task = MaintenanceTask.fromMap(taskMap);
        try {
          await _apiTaskService.deleteTask(task.taskUuid!);
          await db.delete("maintenanceTasks", where: "task_uuid = ?", whereArgs: [task.taskUuid]);
        } on ApiException catch (e) {
          if (e.statusCode == 0) {
            AppLogger.error("Sync aborted! Server unreachable");
            ConnectivityState().isServiceAvailable = false;
            throw Exception("Server unreachable");
          }
          if (e.statusCode == 404) {
            await db.delete("maintenanceTasks", where: "task_uuid = ?", whereArgs: [task.taskUuid]);
          } else {
            hasErrors = true;
          }
        }
      }
    if (hasErrors) throw Exception("Some tasks failed to sync");
  }

  Future<void> fetchTasks() async {
    AppLogger.info("Starting fetchTasks");
    bool loadedFromServer = false;
    if (ConnectivityState().isServiceAvailable) {
        _tasks = await _apiTaskService.getAllTasks();
        loadedFromServer = true;
        await _updateLocalDb();
    }
    if (!loadedFromServer) {
      final db = await AppDatabase.instance.database;
      final result = await db.query("maintenanceTasks", where: "is_deleted = 0");
      _tasks = result.map((e) => MaintenanceTask.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _updateLocalDb() async {
    AppLogger.info("Updating local maintenanceTasks table from server");
    final db =  await AppDatabase.instance.database;
    await db.delete("maintenanceTasks", where: "is_synced = 1 AND is_deleted = 0");
    for (var task in _tasks) {
      var taskData = task.toMap();
      taskData["is_synced"] = 1;
      await db.insert("maintenanceTasks", taskData, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> addTask(MaintenanceTask newTask, {List<File> invoices = const []}) async {
    AppLogger.info("Adding task");
    final db = await AppDatabase.instance.database;
    final uuid = const Uuid().v4();
    newTask = newTask.copyWith(isSynced: 0, taskUuid: uuid);
    await db.insert("maintenanceTasks", newTask.toMap());
    AppLogger.info("Added task with id $uuid");
    if (ConnectivityState().isServiceAvailable) {
      await _apiTaskService.postTask(newTask);
      await db.update("maintenanceTasks", {"is_synced": 1}, where: "task_uuid = ?", whereArgs: [uuid]);
      for (final file in invoices) {
        final fileName = file.path.split("/").last;
        final fileType = _getFileType(fileName);
        try {
          await _apiInvoiceService.uploadInvoice(
            taskUuid: uuid,
            file: file,
            fileName: fileName,
            fileType: fileType,
          );
        } on ApiException catch (e) {
          AppLogger.error("Failed to upload invoice: ${e.message}");
        }
      }
    }
    await fetchTasks();
  }

  Future<void> updateTask(MaintenanceTask updatedTask) async {
    AppLogger.info("Updating task ${updatedTask.taskUuid}");
    final db = await AppDatabase.instance.database;
    updatedTask = updatedTask.copyWith(isSynced: 0);
    await db.update("maintenanceTasks", updatedTask.toMap(), where: "task_uuid = ?", whereArgs: [updatedTask.taskUuid]);
    if (ConnectivityState().isServiceAvailable) {
      await _apiTaskService.putTask(updatedTask);
      await db.update("maintenanceTasks", {"is_synced": 1}, where: "task_uuid = ?", whereArgs: [updatedTask.taskUuid]);
    }
    await fetchTasks();
  }

  Future<void> deleteTask(String taskUuid) async {
    AppLogger.info("Deleting task $taskUuid");
    final db = await AppDatabase.instance.database;
    await db.update("maintenanceTasks", {"is_synced" : 0, "is_deleted": 1}, where: "task_uuid = ?", whereArgs: [taskUuid]);
    if (ConnectivityState().isServiceAvailable) {
      await _apiTaskService.deleteTask(taskUuid);
      await db.delete("maintenanceTasks", where: "task_uuid = ?", whereArgs: [taskUuid]);
    }
    await fetchTasks();
  }

  Future<MaintenanceTask> getById(String taskUuid) async {
    AppLogger.info("Attempting to get task $taskUuid");
    if (ConnectivityState().isServiceAvailable) {
        MaintenanceTask task = await _apiTaskService.getTaskById(taskUuid);
        return task;
    }
    final db = await AppDatabase.instance.database;
    final result = await db.query("maintenanceTasks", where: "task_uuid = ?", whereArgs: [taskUuid]);
    if (result.isEmpty) {
      throw ApiException("Task not found", 404);
    }
    return MaintenanceTask.fromMap(result.first);
  }

  Future<List<MaintenanceTask>> getTasksForCar(String carUuid) async {
    List<MaintenanceTask> carTasks = _tasks.where((t) => t.carUuid == carUuid).toList();
    switch (_filterBy) {
      case TaskFilterOption.completed:
        carTasks = carTasks.where((t) => t.completedDate != null).toList();
        break;
      case TaskFilterOption.scheduled:
        carTasks = carTasks.where((t) => t.completedDate == null && t.scheduledDate!.compareTo(DateTime.now()) >= 0).toList();
        break;
      case TaskFilterOption.overdue:
        carTasks = carTasks.where((t) => t.completedDate == null && t.scheduledDate!.compareTo(DateTime.now()) < 0).toList();
      case TaskFilterOption.all:
        break;
    }

    int sortMultiplier = _sortOrder == SortOrder.ascending ? 1 : -1;

    switch (_sortBy) {
      case TaskSortOption.date:
        carTasks.sort((a, b) {
          final aDate = a.completedDate ?? a.scheduledDate ?? DateTime(2100);
          final bDate = b.completedDate ?? b.scheduledDate ?? DateTime(2100);
          return aDate.compareTo(bDate) * sortMultiplier;
        });
        break;
      case TaskSortOption.cost:
        carTasks.sort((a, b) => ((a.cost ?? 0).compareTo(b.cost ?? 0)) * sortMultiplier);
        break;
      case TaskSortOption.mileage:
        carTasks.sort((a, b) => ((a.mileage ?? 0).compareTo(b.mileage ?? 0)) * sortMultiplier);
        break;
    }
    return carTasks;
  }

  Future<void> markTaskCompleted(String taskUuid, {List<File> invoices = const []}) async {
    final taskIndex = _tasks.indexWhere((t) => t.taskUuid == taskUuid);
    if (taskIndex == -1) return;
    final task = _tasks[taskIndex];
    final updatedTask = task.copyWith(
      completedDate: DateTime.now(),
      scheduledDate: null,
      isSynced: 0,
    );
    await updateTask(updatedTask);
    if (ConnectivityState().isServiceAvailable && invoices.isNotEmpty) {
      for (final file in invoices) {
        final fileName = file.path.split("/").last;
        final fileType = _getFileType(fileName);
        await _apiInvoiceService.uploadInvoice(
          taskUuid: taskUuid,
          file: file,
          fileName: fileName,
          fileType: fileType,
        );
      }
    }
  }

  String _getFileType(String fileName) {
    final ext = fileName.split(".").last.toLowerCase();
    switch (ext) {
      case "pdf": return "application/pdf";
      case "png": return "image/png";
      case "jpg":
      case "jpeg": return "image/jpeg";
      default: return "application/octet-stream";
    }
  }
}
