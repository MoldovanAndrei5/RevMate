import 'dart:convert';
import 'package:car_maintenance_tracker/models/car_transfer.dart';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiTransferService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<CarTransferOutgoing> initiateTransfer({
    required String carUuid,
    required String receiverEmail,
  }) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/transfers/initiate"),
      body: jsonEncode({
        "car_uuid": carUuid,
        "receiver_email": receiverEmail,
      }),
    );
    try {
      return CarTransferOutgoing.fromMap(jsonDecode(response.body));
    } catch (_) {
      throw ApiException("Failed to parse car transfer", 500);
    }
  }

  Future<List<CarTransferIncoming>> getIncomingTransfers() async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/transfers/incoming"));
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => CarTransferIncoming.fromMap(item)).toList();
    } catch (_) {
      throw ApiException("Failed to parse incoming car transfer list", 500);
    }
  }

  Future<List<CarTransferOutgoing>> getOutgoingTransfers() async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/transfers/outgoing"));
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => CarTransferOutgoing.fromMap(item)).toList();
    } catch (_) {
      throw ApiException("Failed to parse outgoing car transfer list", 500);
    }
  }

  Future<void> acceptTransfer(String transferUuid) async {
    await ApiClient.post(Uri.parse("$baseUrl/transfers/accept/$transferUuid"));
  }

  Future<void> rejectTransfer(String transferUuid) async {
    await ApiClient.post(Uri.parse("$baseUrl/transfers/reject/$transferUuid"));
  }

  Future<void> cancelTransfer(String transferUuid) async {
    await ApiClient.delete(Uri.parse("$baseUrl/transfers/cancel/$transferUuid"));
  }
}