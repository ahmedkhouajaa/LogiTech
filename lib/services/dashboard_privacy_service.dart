import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing privacy disguise mode (masking financial figures) across Dashboard
class DashboardPrivacyService {
  static final DashboardPrivacyService instance = DashboardPrivacyService._();

  DashboardPrivacyService._() {
    _loadPreference();
  }

  static const String _prefKey = 'dashboard_figures_hidden';
  final ValueNotifier<bool> isHidden = ValueNotifier<bool>(false);

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isHidden.value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {}
  }

  Future<void> toggle() async {
    isHidden.value = !isHidden.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, isHidden.value);
    } catch (_) {}
  }

  /// Replaces figures with a professional, sleek masked bullet pattern
  String maskFigure(String original, {bool isCurrency = true}) {
    if (!isHidden.value) return original;
    if (original.isEmpty) return original;

    if (isCurrency || original.toUpperCase().contains('TND') || original.toUpperCase().contains('DT')) {
      return '•••••• TND';
    }

    if (original.contains('%')) {
      return '••%';
    }

    return '••••';
  }
}
