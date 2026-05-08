import 'dart:convert';
import 'package:car_maintenance_tracker/models/car_transfer.dart';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_response.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';

class ApiTransferService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<ApiResponse<CarTransferOutgoing>> initiateTransfer({
    required String carUuid,
    required String receiverEmail,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/transfers/initiate"),
        body: jsonEncode({
          "car_uuid": carUuid,
          "receiver_email": receiverEmail,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          CarTransferOutgoing.fromMap(jsonDecode(response.body)),
          response.statusCode,
        );
      }
      AppLogger.error("Failed to initiate transfer: ${response.statusCode} ${response.body}");
      return ApiResponse(null, response.statusCode);
    } catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<List<CarTransferIncoming>>> getIncomingTransfers() async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/transfers/incoming"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return ApiResponse(
          data.map((item) => CarTransferIncoming.fromMap(item)).toList(),
          response.statusCode,
        );
      }
      return ApiResponse(null, response.statusCode);
    } catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<List<CarTransferOutgoing>>> getOutgoingTransfers() async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/transfers/outgoing"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return ApiResponse(
          data.map((item) => CarTransferOutgoing.fromMap(item)).toList(),
          response.statusCode,
        );
      }
      return ApiResponse(null, response.statusCode);
    } catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<bool> acceptTransfer(String transferUuid) async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/transfers/accept/$transferUuid"),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Failed to accept transfer", e);
      return false;
    }
  }

  Future<bool> rejectTransfer(String transferUuid) async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/transfers/reject/$transferUuid"),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Failed to reject transfer", e);
      return false;
    }
  }

  Future<bool> cancelTransfer(String transferUuid) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse("$baseUrl/transfers/cancel/$transferUuid"),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Failed to cancel transfer", e);
      return false;
    }
  }
}