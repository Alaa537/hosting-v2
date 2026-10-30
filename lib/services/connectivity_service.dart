import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Global connectivity monitor.
/// Exposes `isOnline` notifier. Initialize once in main().
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService I = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription? _sub;

  Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      isOnline.value = _isOnline(results);
      _sub?.cancel();
      _sub = _connectivity.onConnectivityChanged.listen((results) {
        final online = _isOnline(results);
        if (isOnline.value != online) {
          isOnline.value = online;
        }
      });
    } catch (_) {
      // keep default
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      return false;
    }
    return true;
  }

  void dispose() {
    _sub?.cancel();
  }
}
