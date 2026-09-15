import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LocaleCubit extends Cubit<Locale> {
  static const String prefKey = 'app_language';

  LocaleCubit([String initialCode = 'fr']) : super(Locale(initialCode)) {
    Intl.defaultLocale = initialCode == 'ar' ? 'ar' : (initialCode == 'en' ? 'en' : 'fr_FR');
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefKey);
      if (code != null && ['fr', 'en', 'ar'].contains(code) && code != state.languageCode) {
        Intl.defaultLocale = code == 'ar' ? 'ar' : (code == 'en' ? 'en' : 'fr_FR');
        emit(Locale(code));
      }
    } catch (e) {
      debugPrint('[LocaleCubit] Error loading saved locale: $e');
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (!['fr', 'en', 'ar'].contains(languageCode)) return;
    if (state.languageCode == languageCode) return;
    Intl.defaultLocale = languageCode == 'ar' ? 'ar' : (languageCode == 'en' ? 'en' : 'fr_FR');
    emit(Locale(languageCode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, languageCode);
    } catch (e) {
      debugPrint('[LocaleCubit] Error saving locale: $e');
    }
  }

  String get currentLanguageName {
    switch (state.languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'fr':
      default:
        return 'Français';
    }
  }

  String get currentRegionSubtitle {
    switch (state.languageCode) {
      case 'en':
        return 'English , default currency';
      case 'ar':
        return 'العربية ، العملة الافتراضية';
      case 'fr':
      default:
        return 'Français , devise par défaut';
    }
  }
}
