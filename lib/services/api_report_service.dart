import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';

class ApiReportService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<List<int>?> getCarReport(String carUuid) async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/cars/$carUuid/report"),
      ).timeout(const Duration(seconds: 30)); // PDF generation can take a moment

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      AppLogger.error("Failed to get report: ${response.statusCode}");
      return null;
    } catch (e) {
      AppLogger.error("Failed to get car report", e);
      return null;
    }
  }
}