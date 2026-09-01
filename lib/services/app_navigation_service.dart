import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/sidebar_menu.dart' show AppModule;

/// Service to coordinate navigation to specific modules in the main App Shell
class AppNavigationService {
  static final AppNavigationService instance = AppNavigationService._();
  AppNavigationService._();

  final StreamController<AppModule> _navController =
      StreamController<AppModule>.broadcast();

  Stream<AppModule> get onModuleNavigation => _navController.stream;

  /// Navigates to a specific AppModule inside the main app shell,
  /// popping all open modal dialogs and stacked screens.
  void navigateToModule(BuildContext context, AppModule module) {
    try {
      final nav = Navigator.of(context, rootNavigator: true);
      nav.popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('[AppNavigationService] Pop error: $e');
    }

    _navController.add(module);
  }
}
