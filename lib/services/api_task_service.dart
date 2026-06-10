import 'dart:convert';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiTaskService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<List<MaintenanceTask>> getAllTasks() async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/tasks/"));
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => MaintenanceTask.fromMap(item)).toList();
    } catch (_) {
      throw ApiException("Failed to parse task list", 500);
    }
  }

  Future<MaintenanceTask> getTaskById(String taskUuid) async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/tasks/$taskUuid"));
    try {
      return MaintenanceTask.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse task", 500);
    }
  }

  Future<List<MaintenanceTask>> getTasksForCar(String carUuid) async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/tasks/car/$carUuid"));
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => MaintenanceTask.fromMap(item)).toList();
    } catch (_) {
      throw ApiException("Failed to parse task list", 500);
    }
  }

  Future<MaintenanceTask> postTask(MaintenanceTask task) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/tasks/"),
      body: jsonEncode(task.toMap()),
    );
    try {
      return MaintenanceTask.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse task", 500);
    }
  }

  Future<MaintenanceTask> putTask(MaintenanceTask task) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/tasks/${task.taskUuid}"),
      body: jsonEncode(task.toMap()),
    );
    try {
      return MaintenanceTask.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse task", 500);
    }
  }

  Future<void> deleteTask(String taskUuid) async {
    await ApiClient.delete(Uri.parse("$baseUrl/tasks/$taskUuid"));
  }
}