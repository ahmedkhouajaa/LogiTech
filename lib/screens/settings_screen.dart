import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sidebar_menu.dart';
import 'app_shell_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Parametres', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            'General',
            [
              _buildSettingItem(Icons.business_rounded, 'Informations de l\'entreprise', 'Gerer les details de la societe, logo, NIF, RC'),
              _buildSettingItem(Icons.palette_rounded, 'Apparence', 'Theme clair/sombre, couleurs de l\'interface'),
              _buildSettingItem(Icons.language_rounded, 'Langue et region', 'Francais (Algerie), devise par defaut'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            'Documents',
            [
              _buildSettingItem(
                Icons.description_rounded,
                'Modèles de documents',
                'Personnaliser les modèles de factures et documents',
                onTap: () {
                  final shell = context.findAncestorStateOfType<AppShellScreenState>();
                  shell?.setActiveModule(AppModule.documentTemplates);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            'Synchronisation',
            [
              _buildSettingItem(Icons.cloud_sync_rounded, 'Etat de la synchronisation', 'Derniere synchro reussie il y a 5 min', isAction: true),
              _buildSettingItem(Icons.wifi_rounded, 'Mode hors ligne', 'Fonctionnement complet sans internet'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            'Comptabilite',
            [
              _buildSettingItem(Icons.receipt_long_rounded, 'Numerotation des documents', 'Prefixes et sequences (FAC-24-001)'),
              _buildSettingItem(Icons.percent_rounded, 'Taux de TVA par defaut', '19%, 9% ou exonere'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, {bool isAction = false, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: isAction
          ? AppButton(label: 'Forcer la synchro', isSmall: true, onPressed: () {})
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
      onTap: onTap ?? () {},
    );
  }
}
