import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing the visibility of the floating AI assistant mascot button.
/// Per user requirement, the default value is unchecked / disabled (`false`).
class AiAssistantSettingsService {
  static final AiAssistantSettingsService instance = AiAssistantSettingsService._();

  AiAssistantSettingsService._() {
    _loadPreference();
  }

  static const String prefKey = 'show_ai_floating_button';

  /// ValueNotifier exposing whether the floating AI assistant button is visible.
  /// Defaults to `false` (hidden / unchecked).
  final ValueNotifier<bool> isFloatingButtonEnabled = ValueNotifier<bool>(false);

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isFloatingButtonEnabled.value = prefs.getBool(prefKey) ?? false;
    } catch (_) {}
  }

  Future<void> setFloatingButtonEnabled(bool enabled) async {
    isFloatingButtonEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggleFloatingButton() async {
    await setFloatingButtonEnabled(!isFloatingButtonEnabled.value);
  }
}
