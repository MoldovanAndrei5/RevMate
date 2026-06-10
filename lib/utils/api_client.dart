import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/connectivity_state.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> get _headers {
    final headers = {"Content-Type": "application/json"};
    if (_token != null) {
      headers["Authorization"] = "Bearer $_token";
    }
    return headers;
  }

  static void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail;
    try {
      detail = jsonDecode(response.body)["detail"] ?? "Something went wrong";
    }
    catch (_) {
      detail = "Something went wrong";
    }
    throw ApiException(detail, response.statusCode);
  }

  static Future<http.Response> _execute(Future<http.Response> Function() request, Duration timeout) async {
    try {
      final response = await request().timeout(timeout);
      _handleResponse(response);
      return response;
    }
    on ApiException {
      rethrow;
    }
    on SocketException {
      ConnectivityState().isServiceAvailable = false;
      throw ApiException("No internet connection", 0);
    }
    on TimeoutException {
      ConnectivityState().isServiceAvailable = false;
      throw ApiException("Request timed out", 0);
    }
    catch (e) {
      throw ApiException("Unexpected error: $e", 500);
    }
  }

  static Future<http.Response> get(Uri url, {Duration timeout = const Duration(seconds: 15)}) =>
      _execute(() => http.get(url, headers: _headers), timeout);

  static Future<http.Response> post(Uri url, {Object? body, Duration timeout = const Duration(seconds: 15)}) =>
      _execute(() => http.post(url, headers: _headers, body: body), timeout);

  static Future<http.Response> put(Uri url, {Object? body, Duration timeout = const Duration(seconds: 15)}) =>
      _execute(() => http.put(url, headers: _headers, body: body), timeout);

  static Future<http.Response> delete(Uri url, {Object? body, Duration timeout = const Duration(seconds: 15)}) =>
      _execute(() => http.delete(url, headers: _headers, body: body), timeout);
}