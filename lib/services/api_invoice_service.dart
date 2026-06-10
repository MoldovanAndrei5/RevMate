import 'dart:convert';
import 'dart:io';
import 'package:car_maintenance_tracker/models/invoice.dart';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:car_maintenance_tracker/services/api_upload_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiInvoiceService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";
  final ApiUploadService _uploadService = ApiUploadService();

  Future<List<Invoice>> getTaskInvoices(String taskUuid) async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/invoices/task/$taskUuid"));
    try {
      final List data = jsonDecode(response.body);
      return data.map((item) => Invoice.fromMap(item)).toList();
    } catch (_) {
      throw ApiException("Failed to parse invoice list", 500);
    }
  }

  Future<String> getInvoiceDownloadLink(String invoiceUuid) async {
    final response = await ApiClient.get(Uri.parse("$baseUrl/invoices/$invoiceUuid/download"));
    try {
      final data = jsonDecode(response.body);
      return data["download_url"];
    } catch (_) {
      throw ApiException("Failed to parse download link", 500);
    }
  }

  Future<Invoice> uploadInvoice({
    required String taskUuid,
    required File file,
    required String fileName,
    required String fileType,
  }) async {
      final fileSize = await file.length();
      final fileKey = await _uploadService.uploadFile(
        file: file,
        fileName: fileName,
        fileType: fileType,
        folder: "invoices",
      );
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/invoices/"),
        body: jsonEncode({
          "task_uuid": taskUuid,
          "file_key": fileKey,
          "file_name": fileName,
          "file_type": fileType,
          "file_size": fileSize,
        }),
      );
      try {
        return Invoice.fromMap(jsonDecode(response.body));
      } catch (_) {
        throw ApiException("Failed to parse invoice", 500);
      }
  }

  Future<void> deleteInvoice(String invoiceUuid) async {
    await ApiClient.delete(Uri.parse("$baseUrl/invoices/$invoiceUuid"));
  }
}