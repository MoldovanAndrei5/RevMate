import 'dart:convert';

import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_response.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiTaskService {
  static final String baseUrl = "${dotenv.env["HOST"]}:${dotenv.env["PORT"]}";

  Future<ApiResponse<List<MaintenanceTask>>> getAllTasks() async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/tasks/"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return ApiResponse(data.map((item) => MaintenanceTask.fromMap(item)).toList(), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<MaintenanceTask>> getTaskById(String taskUuid) async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/tasks/$taskUuid"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return ApiResponse(MaintenanceTask.fromMap(jsonDecode(response.body)), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<List<MaintenanceTask>>> getTasksForCar(String carUuid) async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/tasks/car/$carUuid"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return ApiResponse(data.map((item) => MaintenanceTask.fromMap(item)).toList(), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<MaintenanceTask>> postTask(MaintenanceTask task) async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/tasks/"),
        body: jsonEncode(task.toMap()),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(MaintenanceTask.fromMap(jsonDecode(response.body)), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<MaintenanceTask>> putTask(MaintenanceTask task) async {
    try {
      final response = await ApiClient.put(
        Uri.parse("$baseUrl/tasks/${task.taskUuid}"),
        body: jsonEncode(task.toMap()),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return ApiResponse(MaintenanceTask.fromMap(jsonDecode(response.body)), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<String>> deleteTask(String taskUuid) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse("$baseUrl/tasks/$taskUuid"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return ApiResponse(jsonDecode(response.body), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }
}