import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';
import '../l10n/app_localizations.dart';

/// Wraps the application to intercept window close requests on desktop (Windows, macOS, Linux)
/// and display a confirmation dialog before allowing the app to close.
class DesktopExitListener extends StatefulWidget {
  final Widget child;

  const DesktopExitListener({
    super.key,
    required this.child,
  });

  /// Shows the desktop exit confirmation dialog directly.
  /// Returns `true` if the user confirmed exit, `false` otherwise.
  static Future<bool> showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) => const _DesktopExitConfirmationDialog(),
    );
    return result ?? false;
  }

  @override
  State<DesktopExitListener> createState() => _DesktopExitListenerState();
}

class _DesktopExitListenerState extends State<DesktopExitListener> {
  AppLifecycleListener? _lifecycleListener;
  bool _isExitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      _lifecycleListener = AppLifecycleListener(
        onExitRequested: _handleExitRequested,
      );
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequested() async {
    if (!mounted || _isExitDialogOpen) {
      return AppExitResponse.cancel;
    }

    _isExitDialogOpen = true;
    try {
      final shouldExit = await DesktopExitListener.showExitConfirmationDialog(context);
      return shouldExit ? AppExitResponse.exit : AppExitResponse.cancel;
    } catch (e) {
      return AppExitResponse.cancel;
    } finally {
      _isExitDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _DesktopExitConfirmationDialog extends StatelessWidget {
  const _DesktopExitConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title + Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Quitter l\'application'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'LogiTech Pro',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    tooltip: context.tr('Annuler'),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Description Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('Êtes-vous sûr de vouloir quitter LogiTech Pro ? Toutes les modifications non enregistrées pourraient être perdues.'),
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      context.tr('Annuler'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                    label: Text(
                      context.tr('Quitter'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
