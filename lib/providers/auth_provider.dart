import 'package:car_maintenance_tracker/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_auth_service.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final _apiAuthService = ApiAuthService();
  final _storage = const FlutterSecureStorage();

  String? _token;
  bool _isLoading = true;

  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  int? _userId;
  int? get userId => _userId;
  String? get token => _token;

  Future<void> loadToken() async {
    await SyncService().startSync();
    _isLoading = true; // start loading
    notifyListeners();

    _token = await _storage.read(key: "token");
    ApiClient.setToken(_token);

    final userIdStr = await _storage.read(key: "user_id");
    if (userIdStr != null) {
      _userId = int.tryParse(userIdStr);
    }

    _isLoading = false; // finished loading
    notifyListeners(); // triggers AuthGate rebuild
  }

  Future<bool> login(String email, String password) async {
    try {
      final result = await _apiAuthService.login(email, password);
      _token = result["access_token"];
      _userId = result["user_id"];
      ApiClient.setToken(_token);

      await _storage.write(key: "token", value: _token);
      await _storage.write(key: "user_id", value: _userId.toString());

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> register(String firstName, String lastName, String email, String password) async {
    try {
      await _apiAuthService.register(firstName, lastName, email, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    ApiClient.setToken(null);
    await SyncService().stopSync();
    await _storage.delete(key: "token");
    await _storage.delete(key: "user_id");
    await AppDatabase.instance.clearUserData();
    notifyListeners();
  }

  Future<void> resetPassword(String password) async {
    await _apiAuthService.resetPassword(userId!, password);
  }
}