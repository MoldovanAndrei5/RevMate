import 'package:car_maintenance_tracker/database.dart';
import 'package:car_maintenance_tracker/services/api_task_service.dart';
import 'package:car_maintenance_tracker/services/sync_service.dart';
import 'package:car_maintenance_tracker/utils/api_response.dart';
import 'package:car_maintenance_tracker/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/maintenance_task.dart';
import '../utils/sort_filter_enums.dart';

class TaskProvider extends ChangeNotifier {
  List<MaintenanceTask> _tasks = [];
  TaskSortOption _sortBy = TaskSortOption.date;
  SortOrder _sortOrder = SortOrder.descending;
  TaskFilterOption _filterBy = TaskFilterOption.all;
  final ApiTaskService _apiTaskService = ApiTaskService();

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

  List<MaintenanceTask> get () => _tasks;

  void clearCache() {
    _tasks = [];
    notifyListeners();
  }

  void _abortSync() {
    AppLogger.error("Sync aborted! Server unreachable");
    SyncService().setIsServiceAvailable = false;
  }

  Future<void> syncAllData() async {
    AppLogger.info("Syncing server with local maintenanceTasks table");
    final db = await AppDatabase.instance.database;
    try {
      final unsyncedTasks = await db.query(
          'maintenanceTasks', where: 'is_synced = 0 AND is_deleted = 0');
      for (var taskMap in unsyncedTasks) {
        MaintenanceTask task = MaintenanceTask.fromMap(taskMap);
        ApiResponse<MaintenanceTask> putResponse = await _apiTaskService.putTask(task);
        if (putResponse.statusCode == 200) {
          await db.update('maintenanceTasks', {'is_synced': 1}, where: 'task_uuid = ?', whereArgs: [task.taskUuid]);
        }
        else if (putResponse.statusCode == 404) {
          ApiResponse<MaintenanceTask> postResponse = await _apiTaskService.postTask(task);
          if (postResponse.statusCode == 200 || postResponse.statusCode == 201) {
            await db.update('maintenanceTasks', {'is_synced': 1}, where: 'task_uuid = ?', whereArgs: [task.taskUuid]);
          }
          else {
            AppLogger.error("Failed to sync task ${task.taskUuid} with the server");
          }
        }
        else {
          AppLogger.error("Failed to sync task ${task.taskUuid} with the server");
        }
      }
      final deletedCTasks = await db.query('maintenanceTasks', where: 'is_deleted = 1');
      for (var taskMap in deletedCTasks) {
        MaintenanceTask task = MaintenanceTask.fromMap(taskMap);
        ApiResponse<String> response = await _apiTaskService.deleteTask(task.taskUuid!);
        if (response.statusCode == 200) {
          await db.delete('maintenanceTasks', where: 'task_uuid = ?', whereArgs: [task.taskUuid]);
        }
        else {
          AppLogger.error("Failed to sync task ${task.taskUuid} with the server");
        }
      }
    }
    catch (e) {
      _abortSync();
    }
  }

  Future<void> fetchTasks() async {
    AppLogger.info("Starting fetchTasks");
    bool loadedFromServer = false;
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<List<MaintenanceTask>> response = await _apiTaskService.getAllTasks();
        if (response.statusCode == 200) {
          _tasks = response.data!;
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
      final result = await db.query('maintenanceTasks', where: 'is_deleted = 0');
      _tasks = result.map((e) => MaintenanceTask.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _updateLocalDb() async {
    AppLogger.info("Updating local maintenanceTasks table from server");
    final db =  await AppDatabase.instance.database;
    await db.delete('maintenanceTasks', where: 'is_synced = 1 AND is_deleted = 0');
    for (var task in _tasks) {
      var taskData = task.toMap();
      taskData['is_synced'] = 1;
      await db.insert('maintenanceTasks', taskData, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> addTask(MaintenanceTask newTask) async {
    AppLogger.info("Adding task");
    final db = await AppDatabase.instance.database;
    final uuid = const Uuid().v4();
    newTask = newTask.copyWith(isSynced: 0, taskUuid: uuid);
    await db.insert('maintenanceTasks', newTask.toMap());
    AppLogger.info("Added task with id $uuid");
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<MaintenanceTask> response = await _apiTaskService.postTask(newTask);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update("maintenanceTasks", {"is_synced": 1}, where: "task_uuid = ?", whereArgs: [uuid]);
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
    await fetchTasks();
  }

  Future<void> updateTask(MaintenanceTask updatedTask) async {
    AppLogger.info("Updating task ${updatedTask.taskUuid}");
    final db = await AppDatabase.instance.database;
    updatedTask = updatedTask.copyWith(isSynced: 0);
    await db.update('maintenanceTasks', updatedTask.toMap(), where: 'task_uuid = ?', whereArgs: [updatedTask.taskUuid]);
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<MaintenanceTask> response = await _apiTaskService.putTask(updatedTask);
        if (response.statusCode == 200) {
          await db.update('maintenanceTasks', {"is_synced": 1}, where: 'task_uuid = ?', whereArgs: [updatedTask.taskUuid]);
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
    await fetchTasks();
  }

  Future<void> deleteTask(String taskUuid) async {
    AppLogger.info("Deleting task $taskUuid");
    final db = await AppDatabase.instance.database;
    await db.update('maintenanceTasks', {'is_synced' : 0, 'is_deleted': 1}, where: 'task_uuid = ?', whereArgs: [taskUuid]);
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<String> response = await _apiTaskService.deleteTask(taskUuid);
        if (response.statusCode == 200) {
          await db.delete('maintenanceTasks', where: 'task_uuid = ?', whereArgs: [taskUuid]);
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
    await fetchTasks();
  }

  Future<MaintenanceTask?> getById(String taskUuid) async {
    AppLogger.info("Attempting to get task $taskUuid");
    if (SyncService().isServiceAvailable) {
      try {
        ApiResponse<MaintenanceTask> response = await _apiTaskService.getTaskById(taskUuid);
        if (response.statusCode == 200) {
          return response.data;
        }
        else if (response.statusCode == 404) {
          AppLogger.error("Task not found on the server");
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
    final result = await db.query("maintenanceTasks", where: "task_uuid = ?", whereArgs: [taskUuid]);
    if (result.isNotEmpty) {
      return MaintenanceTask.fromMap(result.first);
    }
    AppLogger.error("Task not found");
    return null;
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

  Future<void> markTaskCompleted(String taskUuid) async {
    final taskIndex = _tasks.indexWhere((t) => t.taskUuid == taskUuid);
    if (taskIndex == -1) return;
    final task = _tasks[taskIndex];
    final updatedTask = task.copyWith(
      completedDate: DateTime.now(),
      scheduledDate: null,
      isSynced: 0,
    );
    await updateTask(updatedTask);
    notifyListeners();
  }
}
