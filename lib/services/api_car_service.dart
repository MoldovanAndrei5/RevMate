import 'dart:convert';
import 'dart:typed_data';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';

class ApiCarService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<List<Car>> getAllCars() async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/cars/"));
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => Car.fromMap(item)).toList();
    } catch (_) {
      throw ApiException("Failed to parse car list", 500);
    }
  }

  Future<Car> getCarById(String carUuid) async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/cars/$carUuid"));
    try {
      return Car.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse car", 500);
    }
  }

  Future<Car> postCar(Car car) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/cars/"),
      body: jsonEncode(car.toMap()),
    );
    try {
      return Car.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse car", 500);
    }
  }

  Future<Car> putCar(Car car) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/cars/${car.carUuid}"),
      body: jsonEncode(car.toMap()),
    );
    try {
      return Car.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse car", 500);
    }
  }

  Future<void> deleteCar(String carUuid) async {
    await ApiClient.delete(Uri.parse("$baseUrl/cars/$carUuid"));
  }

  Future<Uint8List> getCarReport(String carUuid) async {
    final response = await ApiClient.get(
      Uri.parse("$baseUrl/cars/$carUuid/report"),
      timeout: const Duration(seconds: 30),
    );
    return response.bodyBytes;
  }
}