import 'dart:convert';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/stats.dart';

class ApiAccountService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<bool> resetPassword(String password) async {
    final response = await ApiClient.put(
        Uri.parse("$baseUrl/account/reset-password"),
        body: jsonEncode({
          "password": password,
        })
    ).timeout(const Duration(seconds: 15));
    return response.statusCode == 200;
  }

  Future<bool> sendDeleteOtp() async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/account/send-delete-otp"),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount(String otpCode) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse("$baseUrl/account/delete-account?otp_code=$otpCode"),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AccountStats?> getStats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/account/stats"),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return AccountStats.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}