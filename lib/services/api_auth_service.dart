import 'dart:convert';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiAuthService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        })
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      else {
        throw Exception("Login failed");
      }
    }
    catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> register(String firstName, String lastName, String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
        "password": password,
      })
    ).timeout(const Duration(seconds: 3));
    return response.statusCode == 200;
  }

  Future<bool> resetPassword(int userId, String password) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/auth/reset-password"),
      body: jsonEncode({
        "password": password,
      })
    ).timeout(const Duration(seconds: 3));
    return response.statusCode == 200;
  }
}