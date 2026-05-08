import 'dart:convert';
import 'dart:io';
import 'package:car_maintenance_tracker/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class ApiUploadService {
  static final String baseUrl = "${dotenv.env["BASE_URL"]}";

  // Step 1 — get presigned URL from your backend
  Future<Map<String, String>?> getPresignedUrl({
    required String fileName,
    required String fileType,
    required int fileSize,
    required String folder,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse("$baseUrl/upload/presigned-url"),
        body: jsonEncode({
          "file_name": fileName,
          "file_type": fileType,
          "file_size": fileSize,
          "folder": folder,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "upload_url": data["upload_url"],
          "file_key": data["file_key"],
        };
      }
      AppLogger.error("Failed to get presigned URL: ${response.statusCode}");
      return null;
    } catch (e) {
      AppLogger.error("Failed to get presigned URL", e);
      return null;
    }
  }

  // Step 2 — upload file directly to S3 using presigned URL
  Future<bool> uploadToS3({
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

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Failed to upload file to S3", e);
      return false;
    }
  }

  // Combined helper — get URL then upload
  Future<String?> uploadFile({
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
    if (presigned == null) return null;

    final success = await uploadToS3(
      uploadUrl: presigned["upload_url"]!,
      file: file,
      fileType: fileType,
    );

    return success ? presigned["file_key"] : null;
  }
}