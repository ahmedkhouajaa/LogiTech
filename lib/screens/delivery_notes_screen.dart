import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class DeliveryNotesScreen extends StatelessWidget {
  const DeliveryNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.local_shipping_rounded,
      title: 'Bons de livraison',
      subtitle: 'La gestion des bons de livraison sera bientôt disponible',
    );
  }
}
