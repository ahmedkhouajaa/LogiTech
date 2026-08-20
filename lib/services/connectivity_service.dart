import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_utils.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = !result.contains(ConnectivityResult.none);
      _controller.add(_isOnline);

      _connectivity.onConnectivityChanged.listen((results) {
        final online = !results.contains(ConnectivityResult.none);
        if (online != _isOnline) {
          _isOnline = online;
          _controller.add(_isOnline);
        }
      });
    } catch (_) {
      _isOnline = true; // Safe fallback
      _controller.add(_isOnline);
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = !result.contains(ConnectivityResult.none);
    } catch (_) {
      _isOnline = true;
    }
    return _isOnline;
  }

  void dispose() {
    _controller.close();
  }
}
