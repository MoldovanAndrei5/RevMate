import 'dart:async';
import 'package:car_maintenance_tracker/services/api_helper_service.dart';
import 'package:car_maintenance_tracker/utils/app_logger.dart';
import 'package:car_maintenance_tracker/utils/connectivity_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  final List<Future<void> Function()> _registry = [];
  final ApiHelperService _apiHelperService = ApiHelperService();
  bool _isRunning = false;
  Timer? _timer;
  StreamSubscription? _connectivitySub;
  String? _lastSyncError;

  String? get lastSyncError => _lastSyncError;
  bool get isSyncing => _isSyncing;

  void registerSyncTask(Future<void> Function() task) {
    _registry.add(task);
  }

  Future<void> startSync() async {
    if (_isRunning) return;
    _isRunning = true;
    ConnectivityState().onWentOffline = () => notifyListeners();
    await _checkServerStatus();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        await _checkServerStatus();
      }
    });
    _timer = Timer.periodic(
      const Duration(seconds: 120),
          (timer) => _checkServerStatus(),
    );
  }

  Future<void> stopSync() async {
    _isRunning = false;
    ConnectivityState().onWentOffline = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkServerStatus() async {
    ConnectivityState().isServiceAvailable = await _apiHelperService.isServerOnline();
    if (ConnectivityState().isServiceAvailable) {
      await syncAll();
    }
    notifyListeners();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    final tasks = List<Future<void> Function()>.from(_registry);
    for (var task in tasks) {
      try {
        await task();
      } catch (e) {
        _lastSyncError = e.toString().replaceAll("Exception: ", "");
        AppLogger.error("Sync task failed: $e");
      }
    }
    _isSyncing = false;
    notifyListeners();
  }
}