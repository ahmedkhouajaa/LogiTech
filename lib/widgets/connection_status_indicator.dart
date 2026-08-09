import 'package:flutter/material.dart';
import '../services/connection_quality_service.dart';

class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionQuality>(
      stream: ConnectionQualityService.instance.onQualityChanged,
      initialData: ConnectionQualityService.instance.currentQuality,
      builder: (context, snapshot) {
        final quality = snapshot.data ?? ConnectionQuality.excellent;
        
        IconData icon;
        Color color;
        String tooltip;

        switch (quality) {
          case ConnectionQuality.excellent:
            icon = Icons.wifi_rounded;
            color = Colors.green;
            tooltip = 'Connexion excellente';
            break;
          case ConnectionQuality.slow:
            icon = Icons.network_check_rounded;
            color = Colors.orange;
            tooltip = 'Connexion lente / instable';
            break;
          case ConnectionQuality.disconnected:
            icon = Icons.wifi_off_rounded;
            color = Colors.red;
            tooltip = 'Hors ligne (Lecture seule)';
            break;
        }

        return Tooltip(
          message: tooltip,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        );
      },
    );
  }
}
