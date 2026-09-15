import 'package:flutter/material.dart';
import '../services/app_modules_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class AppModulesSettingsScreen extends StatefulWidget {
  final bool isMobile;

  const AppModulesSettingsScreen({
    super.key,
    this.isMobile = false,
  });

  @override
  State<AppModulesSettingsScreen> createState() => _AppModulesSettingsScreenState();
}

class _AppModulesSettingsScreenState extends State<AppModulesSettingsScreen> {
  final Set<String> _expandedGroups = {};
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isMobile
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: AppColors.border),
              ),
              title: Text(
                context.tr('Modules de l\'application'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              actions: [
                if (_isSaving)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _saveChanges,
                    child: Text(
                      context.tr('Enregistrer'),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: ValueListenableBuilder<int>(
        valueListenable: AppModulesService.instance.notifier,
        builder: (context, _, __) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = !widget.isMobile && constraints.maxWidth > 840;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 32,
                  vertical: widget.isMobile ? 16 : 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isMobile) _buildDesktopHeader(),
                    if (widget.isMobile) _buildMobileHeaderNotice(),
                    SizedBox(height: widget.isMobile ? 16 : 24),
                    _buildModuleCardsGrid(isWide),
                    const SizedBox(height: 40),
                    if (widget.isMobile)
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  context.tr('Enregistrer les modifications'),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Modules de l\'application'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Contrôlez la visibilité de chaque module et sous-document dans la navigation.'),
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          height: 38,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    context.tr('Enregistrer'),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeaderNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('Activez ou désactivez les modules et sous-documents pour personnaliser votre menu.'),
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCardsGrid(bool isWide) {
    final defs = AppModulesService.groupDefinitions;

    if (isWide) {
      final leftColumn = <Widget>[];
      final rightColumn = <Widget>[];
      for (int i = 0; i < defs.length; i++) {
        final card = _buildGroupCard(defs[i]);
        if (i % 2 == 0) {
          leftColumn.add(card);
          leftColumn.add(const SizedBox(height: 12));
        } else {
          rightColumn.add(card);
          rightColumn.add(const SizedBox(height: 12));
        }
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: leftColumn)),
          const SizedBox(width: 14),
          Expanded(child: Column(children: rightColumn)),
        ],
      );
    } else {
      return Column(
        children: defs.map((def) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildGroupCard(def),
          );
        }).toList(),
      );
    }
  }

  Widget _buildGroupCard(ModuleGroupDefinition group) {
    final isGroupEnabled = AppModulesService.instance.isGroupEnabled(group.key);
    final hasSubModules = group.subModules.length > 1;
    final isExpanded = _expandedGroups.contains(group.key);
    final enabledCount = AppModulesService.instance.getEnabledCountInGroup(group.key);
    final allEnabled = enabledCount == group.subModules.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Main Row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isGroupEnabled
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    group.icon,
                    size: 20,
                    color: isGroupEnabled ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 14),

                // Label + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.tr(group.title),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isGroupEnabled ? AppColors.textPrimary : AppColors.textTertiary,
                            ),
                          ),
                          // Sub-module count badge — only shown when expanded or not all enabled
                          if (hasSubModules && isGroupEnabled && !allEnabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$enabledCount/${group.subModules.length}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(group.description),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Toggle
                Switch(
                  value: isGroupEnabled,
                  onChanged: (val) {
                    setState(() {
                      AppModulesService.instance.setGroupEnabled(group.key, val);
                    });
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppColors.border,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),

          // ── Sub-modules Accordion ─────────────────────────────
          if (hasSubModules) ...[
            Divider(height: 1, color: AppColors.border),
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(group.key);
                  } else {
                    _expandedGroups.add(group.key);
                  }
                });
              },
              borderRadius: BorderRadius.vertical(
                bottom: isExpanded ? Radius.zero : const Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        isGroupEnabled
                            ? '${context.tr('Sous-documents')} ($enabledCount/${group.subModules.length} ${context.tr('actifs')})'
                            : context.tr('Sous-documents'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) _buildSubModulesList(group, isGroupEnabled),
          ],
        ],
      ),
    );
  }

  Widget _buildSubModulesList(ModuleGroupDefinition group, bool isGroupEnabled) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),

          // Sub-module rows
          ...group.subModules.asMap().entries.map((entry) {
            final isLast = entry.key == group.subModules.length - 1;
            final sub = entry.value;
            final isSubEnabled =
                isGroupEnabled && AppModulesService.instance.isModuleEnabled(sub.module);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        sub.icon,
                        size: 16,
                        color: isSubEnabled ? AppColors.primary : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr(sub.title),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isSubEnabled ? AppColors.textPrimary : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.82,
                        child: Switch(
                          value: isSubEnabled,
                          onChanged: !isGroupEnabled
                              ? null
                              : (val) {
                                  setState(() {
                                    AppModulesService.instance
                                        .setModuleEnabled(sub.module, val);
                                  });
                                },
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.primary,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.border,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 42,
                    endIndent: 16,
                    color: AppColors.border.withValues(alpha: 0.7),
                  ),
              ],
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await AppModulesService.instance.saveConfig();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Configuration enregistrée',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('Erreur')} : $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
