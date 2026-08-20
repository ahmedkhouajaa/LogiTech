import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/enterprise.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import 'create_enterprise_wizard.dart';

/// Interactive Enterprise Switcher widget for both Desktop and Mobile.
class EnterpriseSwitcherWidget extends StatelessWidget {
  final bool isCollapsed;
  final bool isMobile;

  const EnterpriseSwitcherWidget({
    super.key,
    this.isCollapsed = false,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Enterprise?>(
      valueListenable: EnterpriseService.instance.currentEnterpriseNotifier,
      builder: (context, currentNotifierEnt, _) {
        return BlocBuilder<EnterpriseBloc, EnterpriseState>(
          builder: (context, state) {
            final enterprises = (state is EnterpriseLoaded && state.enterprises.isNotEmpty)
                ? state.enterprises
                : EnterpriseService.instance.enterprises;

            final currentId = (state is EnterpriseLoaded)
                ? (state.currentEnterpriseId ?? EnterpriseService.instance.currentEnterpriseId)
                : EnterpriseService.instance.currentEnterpriseId;

            final currentEnterprise = currentNotifierEnt ??
                enterprises.firstWhere(
                  (e) => e.id == currentId,
                  orElse: () => Enterprise(
                    id: currentId ?? '',
                    name: 'Mon Entreprise',
                    ownerId: '',
                  ),
                );

            if (isMobile) {
              return _buildMobileSwitcher(context, currentEnterprise, enterprises);
            }

            return _buildDesktopSwitcher(context, currentEnterprise, enterprises);
          },
        );
      },
    );
  }

  Widget _buildDesktopSwitcher(
    BuildContext context,
    Enterprise current,
    List<Enterprise> enterprises,
  ) {
    if (isCollapsed) {
      return Tooltip(
        message: current.name,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: Text(
              current.name.isNotEmpty ? current.name[0].toUpperCase() : 'E',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Changer d\'entreprise',
      offset: const Offset(0, 45),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
      onSelected: (value) {
        if (value == '__create_new__') {
          showCreateEnterpriseDialog(context);
        } else {
          context.read<EnterpriseBloc>().add(SwitchEnterprise(value));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'MES ENTREPRISES',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...enterprises.map((e) {
          final isSelected = e.id == current.id;
          return PopupMenuItem<String>(
            value: e.id,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.business_rounded,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__create_new__',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Créer une entreprise',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  current.name.isNotEmpty ? current.name[0].toUpperCase() : 'E',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    current.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Workspace',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded, color: AppColors.sidebarText, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSwitcher(
    BuildContext context,
    Enterprise current,
    List<Enterprise> enterprises,
  ) {
    return InkWell(
      onTap: () => _showMobileBottomSheet(context, current, enterprises),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                current.name.isNotEmpty ? current.name[0].toUpperCase() : 'E',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        current.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 20),
                  ],
                ),
                Text(
                  'Gestion d\'entreprise',
                  style: TextStyle(color: AppColors.sidebarText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileBottomSheet(
    BuildContext context,
    Enterprise current,
    List<Enterprise> initialEnterprises,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return BlocBuilder<EnterpriseBloc, EnterpriseState>(
          builder: (context, state) {
            final enterprises = (state is EnterpriseLoaded) ? state.enterprises : initialEnterprises;
            final currentId = (state is EnterpriseLoaded) ? (state.currentEnterpriseId ?? current.id) : current.id;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mes Entreprises',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: enterprises.length,
                        itemBuilder: (context, index) {
                          final e = enterprises[index];
                          final isSelected = e.id == currentId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.surfaceAlt,
                              child: Text(
                                e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              e.name,
                              style: TextStyle(
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(bottomSheetContext);
                              context.read<EnterpriseBloc>().add(SwitchEnterprise(e.id));
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.add, color: AppColors.primary),
                      ),
                      title: Text(
                        'Créer une entreprise',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        showCreateEnterpriseDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showCreateEnterpriseDialog(BuildContext context, {bool isDismissible = true}) {
    showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) => PopScope(
        canPop: isDismissible,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          elevation: 0,
          child: CreateEnterpriseWizard(isDismissible: isDismissible),
        ),
      ),
    );
  }
}
