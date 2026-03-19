import 'dart:convert';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_response.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/car.dart';
import 'package:http/http.dart' as http;

class ApiCarService {
  static final String baseUrl = "${dotenv.env["HOST"]}:${dotenv.env["PORT"]}";

  Future<ApiResponse<List<Car>>> getAllCars() async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/cars/"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return ApiResponse(data.map((item) => Car.fromMap(item)).toList(), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ApiResponse<Car>> getCarById(String carUuid) async {
    http.Response response;
    try {
      response = await ApiClient.get(
        Uri.parse("$baseUrl/cars/$carUuid"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return ApiResponse(Car.fromMap(jsonDecode(response.body)), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<Car>> postCar(Car car) async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/cars/"),
        body: jsonEncode(car.toMap()),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(Car.fromMap(jsonDecode(response.body)), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<Car>> putCar(Car car) async {
    try {
      final response = await ApiClient.put(
        Uri.parse("$baseUrl/cars/${car.carUuid}"),
        body: jsonEncode(car.toMap()),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return ApiResponse(Car.fromMap(jsonDecode(response.body)), response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<String>> deleteCar(String carUuid) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse("$baseUrl/cars/$carUuid"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return ApiResponse(jsonDecode(response.body), response.statusCode);
      }
      else if (response.statusCode == 404) {

      }
      return ApiResponse(null, response.statusCode);
    }
    catch (e) {
      throw Exception("Server unreachable");
    }
  }
}