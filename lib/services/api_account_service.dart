import 'dart:convert';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stats.dart';
import '../utils/api_exception.dart';

class ApiAccountService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<void> resetPassword(String password) async {
    await ApiClient.put(
      Uri.parse("$baseUrl/account/reset-password"),
      body: jsonEncode({"password": password}),
    );
  }

  Future<void> sendDeleteOtp() async {
    await ApiClient.post(Uri.parse("$baseUrl/account/send-delete-otp"));
  }

  Future<void> deleteAccount(String otpCode) async {
    await ApiClient.delete(
      Uri.parse("$baseUrl/account/delete-account"),
      body: jsonEncode({"otp_code": otpCode}),
    );
  }

  Future<AccountStats?> getStats() async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/account/stats"));
    try {
      return AccountStats.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse statistics", 500);
    }
  }
}