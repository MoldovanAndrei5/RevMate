import 'dart:convert';
import 'dart:io';
import 'package:car_maintenance_tracker/utils/api_client.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiUploadService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  Future<Map<String, String>> getPresignedUrl({
    required String fileName,
    required String fileType,
    required int fileSize,
    required String folder,
  }) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/upload/presigned-url"),
      body: jsonEncode({
        "file_name": fileName,
        "file_type": fileType,
        "file_size": fileSize,
        "folder": folder,
      }),
    );
    try {
      final data = jsonDecode(response.body);
      return {
        "upload_url": data["upload_url"],
        "file_key": data["file_key"],
      };
    } catch (_) {
      throw ApiException("Failed to parse url", 500);
    }
  }

  Future<void> uploadToS3({
    required String uploadUrl,
    required File file,
    required String fileType,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          "Content-Type": fileType,
          "Content-Length": bytes.length.toString(),
        },
        body: bytes,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw ApiException("Failed to upload file to cloud", response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException("Failed to upload file: $e", 500);
    }
  }

  Future<String> uploadFile({
    required File file,
    required String fileName,
    required String fileType,
    required String folder,
  }) async {
    final fileSize = await file.length();
    final presigned = await getPresignedUrl(
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      folder: folder,
    );
    await uploadToS3(
      uploadUrl: presigned["upload_url"]!,
      file: file,
      fileType: fileType,
    );
    return presigned["file_key"]!;
  }
}