import 'dart:convert';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiAuthService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiClient.post(
        Uri.parse("$baseUrl/auth/login"),
        body: jsonEncode({
          "email": email,
          "password": password,
        })
    );
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw ApiException("Failed to parse login output", 500);
    }
  }

  Future<void> sendRegisterOtp(String email) async {
    await ApiClient.post(
      Uri.parse("$baseUrl/auth/send-otp"),
      body: jsonEncode({"email": email}),
    );
  }

  Future<void> register(String firstName, String lastName, String email, String password, String otpCode) async {
    await ApiClient.post(
      Uri.parse("$baseUrl/auth/register"),
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
        "password": password,
        "otp_code": otpCode,
      }),
    );
  }

  Future<void> sendForgotPasswordOtp(String email) async {
    await ApiClient.post(
      Uri.parse("$baseUrl/auth/forgot-password/send-otp"),
      body: jsonEncode({"email": email}),
    );
  }

  Future<void> resetForgottenPassword(String email, String otpCode, String newPassword) async {
    await ApiClient.post(
      Uri.parse("$baseUrl/auth/forgot-password/reset"),
      body: jsonEncode({
        "email": email,
        "otp_code": otpCode,
        "new_password": newPassword,
      }),
    );
  }
}