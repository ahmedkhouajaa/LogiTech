import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sidebar_menu.dart';
import 'app_shell_screen.dart';
import 'app_modules_settings_screen.dart';
import 'company_info_screen.dart';
import 'document_numbering_screen.dart';
import 'personal_info_screen.dart';
import 'import_export_screen.dart';
import 'support_tickets_screen.dart';

import '../services/permission_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/theme/theme_cubit.dart';
import '../blocs/locale/locale_cubit.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selection_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Parametres'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            context.tr('General'),
            [
                            _buildSettingItem(
                Icons.badge_outlined,
                context.tr('Informations personnelles'),
                context.tr('Modifiez vos informations d\'identification et de contact'),
                onTap: () {
                  final shell = context.findAncestorStateOfType<AppShellScreenState>();
                  if (shell != null) {
                    shell.setActiveModule(AppModule.personalInfo);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalInfoScreen()));
                  }
                },
              ),
              if (PermissionService.instance.canAccessModule(AppModule.companyInfo))
                _buildSettingItem(
                  Icons.business_rounded,
                  context.tr('Informations de l\'entreprise'),
                  context.tr('Gerer les details de la societe, logo, NIF, RC'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    if (shell != null) {
                      shell.setActiveModule(AppModule.companyInfo);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanyInfoScreen(),
                        ),
                      );
                    }
                  },
                ),
              if (PermissionService.instance.canAccessModule(AppModule.appModulesSettings))
                _buildSettingItem(
                  Icons.widgets_rounded,
                  context.tr('Modules de l\'application'),
                  context.tr('Activer ou désactiver les modules et sous-documents'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    if (shell != null) {
                      shell.setActiveModule(AppModule.appModulesSettings);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppModulesSettingsScreen(isMobile: true),
                        ),
                      );
                    }
                  },
                ),
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, themeMode) {
                  return _buildSettingItem(
                    Icons.palette_rounded,
                    context.tr('Mode sombre'),
                    context.tr('Basculer entre le theme clair et sombre'),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        context.read<ThemeCubit>().toggleTheme();
                      },
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
              if (PermissionService.instance.isAdmin)
                _buildSettingItem(
                  Icons.manage_accounts_rounded,
                  context.tr('Gestion des utilisateurs'),
                  context.tr('Gérer les collaborateurs, rôles et permissions d\'accès'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    shell?.setActiveModule(AppModule.userManagement);
                  },
                ),
              BlocBuilder<LocaleCubit, Locale>(
                builder: (context, locale) {
                  final localeCubit = context.read<LocaleCubit>();
                  return _buildSettingItem(
                    Icons.language_rounded,
                    context.tr('Langue et region'),
                    localeCubit.currentRegionSubtitle,
                    onTap: () {
                      LanguageSelectionDialog.show(context);
                    },
                  );
                },
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            context.tr('Documents'),
            [
              if (PermissionService.instance.canAccessModule(AppModule.documentTemplates))
                _buildSettingItem(
                  Icons.design_services_rounded,
                  context.tr('Modèles de documents'),
                  context.tr('Personnaliser les modèles de factures et documents'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    shell?.setActiveModule(AppModule.documentTemplates);
                  },
                ),
              if (PermissionService.instance.canAccessModule(AppModule.customFields))
                _buildSettingItem(
                  Icons.tune_rounded,
                  context.tr('Champs personnalisés'),
                  context.tr('Configurer des champs personnalisés pour vos devis, factures et documents'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    shell?.setActiveModule(AppModule.customFields);
                  },
                ),
              if (PermissionService.instance.canAccessModule(AppModule.customStatuses))
                _buildSettingItem(
                  Icons.bookmarks_outlined,
                  context.tr('Statuts personnalisés'),
                  context.tr('Configurer des statuts personnalisés pour vos devis, factures et documents'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    shell?.setActiveModule(AppModule.customStatuses);
                  },
                ),
            ],
          ),
                    SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            context.tr('Import / Export des Données'),
            [
              if (PermissionService.instance.canAccessModule(AppModule.importExport))
                _buildSettingItem(
                  Icons.sync_alt_rounded,
                  context.tr('Import / Export des Données'),
                  context.tr('Sauvegardez ou restaurez l\'intégralité de vos données d\'entreprise en toute sécurité.'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    if (shell != null) {
                      shell.setActiveModule(AppModule.importExport);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportExportScreen()));
                    }
                  },
                ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            context.tr('Support client'),
            [
              _buildSettingItem(
                Icons.support_agent_rounded,
                context.tr('Centre de Support & Assistance'),
                context.tr('Besoin d\'aide ? Ouvrez un ticket pour échanger avec notre équipe technique.'),
                onTap: () {
                  final shell = context.findAncestorStateOfType<AppShellScreenState>();
                  if (shell != null) {
                    shell.setActiveModule(AppModule.support);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));
                  }
                },
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            context.tr('Synchronisation'),
            [
              _buildSettingItem(
                Icons.cloud_sync_rounded,
                context.tr('Etat de la synchronisation'),
                context.tr('Derniere synchro reussie il y a 5 min'),
                isAction: true,
                actionLabel: context.tr('Forcer la synchro'),
              ),
              _buildSettingItem(
                Icons.wifi_rounded,
                context.tr('Mode hors ligne'),
                context.tr('Fonctionnement complet sans internet'),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _buildSettingsGroup(
            context.tr('Comptabilite'),
            [
              if (PermissionService.instance.canAccessModule(AppModule.documentNumbering))
                _buildSettingItem(
                  Icons.receipt_long_rounded,
                  context.tr('Numerotation des documents'),
                  context.tr('Prefixes et sequences (FAC-24-001)'),
                  onTap: () {
                    final shell = context.findAncestorStateOfType<AppShellScreenState>();
                    if (shell != null) {
                      shell.setActiveModule(AppModule.documentNumbering);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DocumentNumberingScreen(),
                        ),
                      );
                    }
                  },
                ),
              _buildSettingItem(
                Icons.percent_rounded,
                context.tr('Taux de TVA par defaut'),
                context.tr('19%, 9% ou exonere'),
              ),
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
          child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
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

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle, {
    bool isAction = false,
    String? actionLabel,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: trailing ?? (isAction
          ? AppButton(label: actionLabel ?? 'Forcer la synchro', isSmall: true, onPressed: () {})
          : Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary)),
      onTap: onTap ?? () {},
    );
  }
}
