import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = false;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _isOnline = await _checkInternetAccess();
      _controller.add(_isOnline);
      Timer.periodic(const Duration(seconds: 10), (_) async {
        final online = await _checkInternetAccess();
        if (online != _isOnline) {
          _isOnline = online;
          _controller.add(_isOnline);
        }
      });
    } else {
      try {
        final result = await _connectivity.checkConnectivity();
        _isOnline = !result.contains(ConnectivityResult.none);
        _controller.add(_isOnline);

        _connectivity.onConnectivityChanged.listen((results) {
          _isOnline = !results.contains(ConnectivityResult.none);
          _controller.add(_isOnline);
        });
      } catch (_) {
        _isOnline = true; // Fallback
      }
    }
  }

  Future<bool> checkConnectivity() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _isOnline = await _checkInternetAccess();
    } else {
      try {
        final result = await _connectivity.checkConnectivity();
        _isOnline = !result.contains(ConnectivityResult.none);
      } catch (_) {
        _isOnline = true;
      }
    }
    return _isOnline;
  }

  Future<bool> _checkInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void dispose() {
    _controller.close();
  }
}

