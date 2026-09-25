import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;

  const UpdateDialog({
    super.key,
    required this.info,
  });

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => PopScope(
        canPop: !info.forceUpdate,
        child: UpdateDialog(info: info),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateService = UpdateService.instance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ValueListenableBuilder<UpdateState>(
            valueListenable: updateService.stateNotifier,
            builder: (context, state, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header ─────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mise à jour disponible !',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'v${info.version}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Actuelle : v${AppConfig.appVersion}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!info.forceUpdate && state != UpdateState.downloading)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          color: AppColors.textTertiary,
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ─── Changelog / Notes ──────────────────────────────
                  if (info.changelog.isNotEmpty) ...[
                    Text(
                      'Nouveautés & Améliorations :',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          info.changelog,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Downloading Progress Section ───────────────────
                  if (state == UpdateState.downloading || state == UpdateState.installing) ...[
                    ValueListenableBuilder<double>(
                      valueListenable: updateService.progressNotifier,
                      builder: (context, progress, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress > 0 ? progress : null,
                                minHeight: 10,
                                backgroundColor: AppColors.borderLight,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<String>(
                              valueListenable: updateService.statusTextNotifier,
                              builder: (context, statusText, _) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Error State ────────────────────────────────────
                  if (state == UpdateState.error) ...[
                    ValueListenableBuilder<String?>(
                      valueListenable: updateService.errorMessageNotifier,
                      builder: (context, errorMsg, _) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMsg ?? 'Une erreur est survenue lors du téléchargement.',
                                  style: TextStyle(fontSize: 12, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Completed State ────────────────────────────────
                  if (state == UpdateState.completed) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Téléchargement terminé ! L\'installateur va démarrer.',
                              style: TextStyle(fontSize: 12, color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Action Buttons ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!info.forceUpdate && state != UpdateState.downloading)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Plus tard',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      if (state == UpdateState.downloading)
                        TextButton(
                          onPressed: () => updateService.cancelDownload(),
                          child: Text(
                            'Annuler',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      const SizedBox(width: 10),
                      if (state == UpdateState.completed)
                        ElevatedButton.icon(
                          onPressed: () => updateService.retryInstall(),
                          icon: const Icon(Icons.install_mobile, size: 18),
                          label: const Text('Relancer l\'installation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else if (state != UpdateState.downloading)
                        ElevatedButton.icon(
                          onPressed: () => updateService.startDownloadAndInstall(info: info),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(state == UpdateState.error ? 'Réessayer' : 'Mettre à jour maintenant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
