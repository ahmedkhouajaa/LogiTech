import 'package:flutter/material.dart';
import '../services/connection_quality_service.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionQuality>(
      stream: ConnectionQualityService.instance.onQualityChanged,
      initialData: ConnectionQualityService.instance.currentQuality,
      builder: (context, snapshot) {
        final quality = snapshot.data ?? ConnectionQuality.excellent;
        final isOffline = quality == ConnectionQuality.disconnected;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isOffline ? 36.0 : 0.0,
              color: Colors.red.shade700,
              width: double.infinity,
              child: isOffline
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Mode Hors Ligne — Lecture seule (Écritures désactivées)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
