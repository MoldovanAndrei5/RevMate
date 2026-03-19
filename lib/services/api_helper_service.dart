import 'package:car_maintenance_tracker/utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiHelperService {
  static final String baseUrl = "${dotenv.env["HOST"]}:${dotenv.env["PORT"]}";

  Future<bool> isServerOnline() async {
    AppLogger.info("Checking if server is online...");
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/health"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 3));
      AppLogger.info("Server is online");
      return response.statusCode == 200;
    }
    catch (e) {
      AppLogger.error("Server is offline");
      return false;
    }
  }
}