import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;
  Timer? _periodicCheckTimer;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasAdapter = !result.contains(ConnectivityResult.none);
      _isOnline = hasAdapter;
      _controller.add(_isOnline);
      
      unawaited(_verifyActualInternet());

      _connectivity.onConnectivityChanged.listen((results) {
        final hasConnection = !results.contains(ConnectivityResult.none);
        if (!hasConnection) {
          _updateStatus(false);
        } else {
          unawaited(_verifyActualInternet());
        }
      });

      // Periodically check actual internet reachability (e.g. after sleep wake up)
      _periodicCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_verifyActualInternet());
      });
    } catch (_) {
      _isOnline = true; // Safe fallback
      _controller.add(_isOnline);
    }
  }

  void _updateStatus(bool online) {
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(_isOnline);
      debugPrint('[ConnectivityService] Connectivity state changed: online=$online');
    }
  }

  Future<bool> _verifyActualInternet() async {
    if (kIsWeb) return _isOnline;
    try {
      final lookup = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(milliseconds: 1500));
      final hasNet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      _updateStatus(hasNet);
      return hasNet;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasAdapter = !result.contains(ConnectivityResult.none);
      if (!hasAdapter) {
        _updateStatus(false);
        return false;
      }
      return await _verifyActualInternet();
    } catch (_) {
      return _isOnline;
    }
  }

  void dispose() {
    _periodicCheckTimer?.cancel();
    _controller.close();
  }
}
