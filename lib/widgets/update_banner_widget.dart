import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';
import 'update_dialog.dart';

class UpdateBannerWidget extends StatelessWidget {
  const UpdateBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = UpdateService.instance;

    return ValueListenableBuilder<AppUpdateInfo?>(
      valueListenable: updateService.updateInfoNotifier,
      builder: (context, info, _) {
        if (info == null) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: updateService.isDismissedNotifier,
          builder: (context, isDismissed, _) {
            if (isDismissed && !info.forceUpdate) {
              return const SizedBox.shrink();
            }

            final isMobile = AppBreakpoints.isMobile(context);

            return Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3A8A),
                    AppColors.primary,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.rocket_launch_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nouvelle version v${info.version} disponible !',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (!info.forceUpdate)
                              InkWell(
                                onTap: () => updateService.dismissBanner(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => UpdateDialog.show(context, info),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text(
                              'Mettre à jour maintenant',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'Nouvelle mise à jour disponible !',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'v${info.version}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (info.changelog.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    info.changelog.replaceAll('\n', ' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => UpdateDialog.show(context, info),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text(
                            'Mettre à jour',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (!info.forceUpdate) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                            tooltip: 'Ignorer pour l\'instant',
                            onPressed: () => updateService.dismissBanner(),
                          ),
                        ],
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}
