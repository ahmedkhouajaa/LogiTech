import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionQuality {
  excellent,
  slow,
  disconnected,
}

class ConnectionQualityService {
  static final ConnectionQualityService instance = ConnectionQualityService._();
  ConnectionQualityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionQuality> _qualityController = StreamController<ConnectionQuality>.broadcast();
  ConnectionQuality _currentQuality = ConnectionQuality.excellent;

  ConnectionQuality get currentQuality => _currentQuality;
  bool get isOnline => _currentQuality != ConnectionQuality.disconnected;
  Stream<ConnectionQuality> get onQualityChanged => _qualityController.stream;

  Timer? _pingTimer;

  Future<void> initialize() async {
    await checkQuality();

    _connectivity.onConnectivityChanged.listen((results) {
      checkQuality();
    });

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      checkQuality();
    });
  }

  Future<ConnectionQuality> checkQuality() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        _updateQuality(ConnectionQuality.disconnected);
        return ConnectionQuality.disconnected;
      }

      final stopwatch = Stopwatch()..start();
      final addresses = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (addresses.isEmpty || addresses[0].rawAddress.isEmpty) {
        _updateQuality(ConnectionQuality.disconnected);
        return ConnectionQuality.disconnected;
      }

      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs > 1200) {
        _updateQuality(ConnectionQuality.slow);
        return ConnectionQuality.slow;
      } else {
        _updateQuality(ConnectionQuality.excellent);
        return ConnectionQuality.excellent;
      }
    } catch (_) {
      _updateQuality(ConnectionQuality.disconnected);
      return ConnectionQuality.disconnected;
    }
  }

  void _updateQuality(ConnectionQuality quality) {
    if (_currentQuality != quality) {
      _currentQuality = quality;
      _qualityController.add(quality);
    }
  }

  void dispose() {
    _pingTimer?.cancel();
    _qualityController.close();
  }
}
