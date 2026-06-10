import 'dart:ui';

class ConnectivityState {
  static final ConnectivityState _instance = ConnectivityState._internal();
  factory ConnectivityState() => _instance;
  ConnectivityState._internal();

  bool _isServiceAvailable = false;
  VoidCallback? onWentOffline;

  bool get isServiceAvailable => _isServiceAvailable;
  set isServiceAvailable(bool value) {
    final wentOffline = _isServiceAvailable && !value;
    _isServiceAvailable = value;
    if (wentOffline) onWentOffline?.call();
  }
}