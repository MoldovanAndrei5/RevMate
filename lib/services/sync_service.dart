import 'dart:async';
import 'package:car_maintenance_tracker/services/api_helper_service.dart';
import 'package:car_maintenance_tracker/utils/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  final List<Future<void> Function()> _registry = [];
  final ApiHelperService _apiHelperService = ApiHelperService();
  bool _isServiceAvailable = false;
  bool _isRunning = false;
  Timer? _timer;
  StreamSubscription? _connectivitySub;

  bool get isServiceAvailable => _isServiceAvailable;
  set setIsServiceAvailable(bool value) => _isServiceAvailable = value;

  void registerSyncTask(Future<void> Function() task) {
    _registry.add(task);
  }

  Future<void> startSync() async {
    if (_isRunning) return;
    _isRunning = true;
    await _checkServerStatus();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        await _checkServerStatus();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) => _checkServerStatus());
  }

  Future<void> stopSync() async {
    _isRunning = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkServerStatus() async {
    _isServiceAvailable = await _apiHelperService.isServerOnline();
    if (_isServiceAvailable) {
      await syncAll();
    }
    notifyListeners();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    AppLogger.info("Sync started");
    for (var task in _registry) {
      try {
        await task();
      }
      catch (e) {
        AppLogger.error("Sync failed");
      }
    }
    _isSyncing = false;
    notifyListeners();
  }
}