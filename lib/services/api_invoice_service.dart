import 'dart:convert';
import 'dart:io';
import 'package:car_maintenance_tracker/models/invoice.dart';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:car_maintenance_tracker/services/api_upload_service.dart';
import 'package:car_maintenance_tracker/utils/api_response.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';

class ApiInvoiceService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";
  final ApiUploadService _uploadService = ApiUploadService();

  Future<ApiResponse<List<Invoice>>> getTaskInvoices(String taskUuid) async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/invoices/task/$taskUuid"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return ApiResponse(
          data.map((item) => Invoice.fromMap(item)).toList(),
          response.statusCode,
        );
      }
      return ApiResponse(null, response.statusCode);
    } catch (e) {
      throw Exception("Server unreachable");
    }
  }

  Future<ApiResponse<String>> getInvoiceDownloadLink(String invoiceUuid) async {
    try {
      final response = await ApiClient.get(
        Uri.parse("$baseUrl/invoices/$invoiceUuid/download")
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse(data["download_url"], response.statusCode);
      }
      return ApiResponse(null, response.statusCode);
    } catch (e) {
      throw Exception ("Server unreachable");
    }
  }

  Future<Invoice?> uploadInvoice({
    required String taskUuid,
    required File file,
    required String fileName,
    required String fileType,
  }) async {
    try {
      final fileSize = await file.length();

      // upload to S3
      final fileKey = await _uploadService.uploadFile(
        file: file,
        fileName: fileName,
        fileType: fileType,
        folder: "invoices",
      );

      if (fileKey == null) {
        AppLogger.error("Failed to upload invoice to S3");
        return null;
      }

      // save record to backend DB
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/invoices/"),
        body: jsonEncode({
          "task_uuid": taskUuid,
          "file_key": fileKey,
          "file_name": fileName,
          "file_type": fileType,
          "file_size": fileSize,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Invoice.fromMap(jsonDecode(response.body));
      }
      AppLogger.error("Failed to save invoice record: ${response.statusCode}");
      return null;
    } catch (e) {
      AppLogger.error("Failed to upload invoice", e);
      return null;
    }
  }

  Future<bool> deleteInvoice(String invoiceUuid) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse("$baseUrl/invoices/$invoiceUuid"),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Failed to delete invoice", e);
      return false;
    }
  }
}