import 'dart:convert';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/maintenance_task.dart';
import '../utils/api_exception.dart';

class ApiAiService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<List<MaintenanceTask>> getSuggestions({
    required String carUuid,
    required String make,
    required String model,
    required int year,
    required int mileage,
    required String fuelType,
    required String transmissionType,
    int? lastOilChangeKm,
    String? knownIssues,
  }) async {
    final body = {
      "car_uuid": carUuid,
      "make": make,
      "model": model,
      "year": year,
      "mileage": mileage,
      "fuel_type": fuelType,
      "transmission_type": transmissionType,
      if (lastOilChangeKm != null) "last_oil_change_km": lastOilChangeKm,
      if (knownIssues != null && knownIssues.isNotEmpty) "known_issues": knownIssues,
    };
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/ai/suggestions"),
      body: jsonEncode(body),
      timeout: const Duration(seconds: 30),
    );
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => MaintenanceTask(
        carUuid: carUuid,
        title: item["title"] as String,
        category: item["category"] as String,
        mileage: item["mileage"] as int?,
        scheduledDate: item["scheduled_date"] != null ? DateTime.fromMillisecondsSinceEpoch(item["scheduled_date"] as int) : null,
        notes: item["notes"] as String?,
      )).toList();
    } catch (_) {
      throw ApiException("Failed to parse AI suggestions", 500);
    }
  }
}