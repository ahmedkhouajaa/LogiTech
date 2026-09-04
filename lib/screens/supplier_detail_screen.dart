import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/supplier.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/details/detail_components.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'suppliers_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late Supplier currentSupplier;

  @override
  void initState() {
    super.initState();
    currentSupplier = widget.supplier;
  }

  bool get _isDefault =>
      currentSupplier.isDefault ||
      currentSupplier.name.trim().toLowerCase() == 'fournisseur passager' ||
      currentSupplier.id.trim().isEmpty;

  bool get _showFinancialKpis => false;

  void _navigateToEdit() {
    if (_isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cet élément est un élément par défaut et ne peut pas être modifié.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<SuppliersBloc>(),
        child: SupplierDialog(existing: currentSupplier),
      ),
    );
  }

  void _confirmDelete() {
    if (_isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cet élément est un élément par défaut et ne peut pas être supprimé.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Supprimer le fournisseur'),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer le fournisseur "${currentSupplier.name}" (${currentSupplier.code}) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<SuppliersBloc>().add(DeleteSupplier(currentSupplier.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fournisseur "${currentSupplier.name}" supprimé'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.suppliers);
    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.suppliers);

    final isEntreprise = currentSupplier.supplierType.toLowerCase() == 'entreprise';

    // Balance indicator
    final hasDebt = currentSupplier.balance > 0.01;
    final balanceColor = hasDebt ? AppColors.error : AppColors.success;
    final balanceLabel = hasDebt
        ? 'Solde dû : ${formatCurrency(currentSupplier.balance)}'
        : 'Solde soldé (${formatCurrency(currentSupplier.balance)})';

    // Address formatting
    final billingAddress = [
      currentSupplier.address,
      currentSupplier.city,
      currentSupplier.postalCode,
      currentSupplier.country,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

    final deliveryAddress = currentSupplier.deliverySameAsBilling
        ? 'Identique à l\'adresse de facturation'
        : [
            currentSupplier.deliveryStreet,
            currentSupplier.deliveryCity,
            currentSupplier.deliveryPostalCode,
            currentSupplier.deliveryCountry,
          ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

    return BlocListener<SuppliersBloc, SuppliersState>(
      listener: (context, state) {
        if (state is SuppliersLoaded) {
          final updated = state.suppliers.where((s) => s.id == currentSupplier.id).firstOrNull;
          if (updated != null) {
            setState(() => currentSupplier = updated);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: currentSupplier.name,
          subtitle: 'Fournisseur ${currentSupplier.code}',
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            tooltip: 'Retour',
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (canUpdate && !_isDefault)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: _navigateToEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            if (canDelete && !_isDefault)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'Supprimer',
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Header ─────────────────────────────────────
                  DetailHeroHeader(
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBackgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.12),
                    title: currentSupplier.name,
                    subtitle: (currentSupplier.companyName != null && currentSupplier.companyName!.isNotEmpty)
                        ? currentSupplier.companyName
                        : 'Fournisseur ${currentSupplier.code}',
                    badges: [
                      buildDetailBadge(
                        label: currentSupplier.code,
                        color: AppColors.primary,
                        icon: Icons.tag_rounded,
                        onTap: () => copyToClipboard(context, label: 'Code fournisseur', text: currentSupplier.code),
                      ),
                      buildDetailBadge(
                        label: isEntreprise ? 'ENTREPRISE' : 'PARTICULIER',
                        color: isEntreprise ? AppColors.primary : const Color(0xFF0D9488),
                        icon: isEntreprise ? Icons.business_rounded : Icons.person_outline_rounded,
                      ),
                      if (_showFinancialKpis)
                        buildDetailBadge(
                          label: balanceLabel,
                          color: balanceColor,
                          icon: hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        ),
                      if (_isDefault)
                        buildDetailBadge(
                          label: 'FOURNISSEUR PAR DÉFAUT',
                          color: AppColors.info,
                          icon: Icons.star_rounded,
                        ),
                    ],
                  ),
                  // ── KPI Summary Row (Hidden per user request, kept in code) ──────
                  if (_showFinancialKpis) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int crossAxisCount = width > 850 ? 4 : 2;
                        double itemWidth = (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Solde Dû (Encours)',
                                value: formatCurrency(currentSupplier.balance),
                                icon: Icons.account_balance_wallet_outlined,
                                color: balanceColor,
                                isHighlight: hasDebt,
                                subtitle: hasDebt ? 'Montant à payer au fournisseur' : 'Compte fournisseur soldé',
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Type Fournisseur',
                                value: currentSupplier.supplierType.toUpperCase(),
                                icon: Icons.category_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Matricule Fiscal',
                                value: currentSupplier.taxId ?? 'Non renseigné',
                                icon: Icons.receipt_long_outlined,
                                color: AppColors.info,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Coordonnées Bancaires',
                                value: currentSupplier.bankAccount != null && currentSupplier.bankAccount!.isNotEmpty
                                    ? 'RIB Configuré'
                                    : 'Non renseigné',
                                icon: Icons.account_balance_rounded,
                                color: currentSupplier.bankAccount != null && currentSupplier.bankAccount!.isNotEmpty
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Detail Sections ─────────────────────────────────
                  // Section 1: Coordonnées Bancaires / RIB (kept visible, financial balance tiles hidden)
                  DetailSectionCard(
                    title: _showFinancialKpis ? 'Situation Financière & Bancaire' : 'Coordonnées Bancaires (RIB)',
                    icon: Icons.account_balance_outlined,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = _showFinancialKpis ? (isWide ? 2 : 1) : 1;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (_showFinancialKpis)
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'Solde dû (Encours à payer)',
                                  value: formatCurrency(currentSupplier.balance),
                                  icon: Icons.account_balance_wallet_outlined,
                                  valueColor: balanceColor,
                                  valueFontWeight: FontWeight.bold,
                                ),
                              ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Compte bancaire / RIB',
                                value: currentSupplier.bankAccount,
                                icon: Icons.account_balance_rounded,
                                copyable: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Identité & Interlocuteurs
                  DetailSectionCard(
                    title: 'Identité & Interlocuteurs',
                    icon: Icons.badge_outlined,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 3 : 2;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Société / Enseigne',
                                value: currentSupplier.companyName,
                                icon: Icons.business_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Responsable / Interlocuteur',
                                value: currentSupplier.responsibleName,
                                icon: Icons.person_pin_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Numéro CIN / Identité',
                                value: currentSupplier.cinNumber,
                                icon: Icons.credit_card_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Date de naissance',
                                value: currentSupplier.birthDate,
                                icon: Icons.cake_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Référence interne',
                                value: currentSupplier.referenceCode,
                                icon: Icons.bookmark_border_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Type de fournisseur',
                                value: currentSupplier.supplierType.toUpperCase(),
                                icon: Icons.group_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Coordonnées & Adresses
                  DetailSectionCard(
                    title: 'Coordonnées & Adresses',
                    icon: Icons.location_on_outlined,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 2 : 1;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Numéro de téléphone',
                                value: currentSupplier.phone,
                                icon: Icons.phone_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Adresse Email',
                                value: currentSupplier.email,
                                icon: Icons.email_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Adresse du Siège',
                                value: billingAddress.isNotEmpty ? billingAddress : null,
                                icon: Icons.business_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Adresse de Livraison / Expédition',
                                value: deliveryAddress.isNotEmpty ? deliveryAddress : null,
                                copyValue: currentSupplier.deliverySameAsBilling
                                    ? (billingAddress.isNotEmpty ? billingAddress : deliveryAddress)
                                    : deliveryAddress,
                                icon: Icons.local_shipping_outlined,
                                copyable: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 4: Fiscalité & Légal
                  DetailSectionCard(
                    title: 'Fiscalité & Enregistrement Légal',
                    icon: Icons.gavel_rounded,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 2 : 1;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Matricule Fiscal (NIF)',
                                value: currentSupplier.taxId,
                                icon: Icons.numbers_rounded,
                                copyable: true,
                                valueFontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Registre de Commerce (RC)',
                                value: currentSupplier.rc,
                                icon: Icons.assignment_outlined,
                                copyable: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 5: Notes & Traçabilité
                  DetailSectionCard(
                    title: 'Notes & Traçabilité',
                    icon: Icons.history_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DetailInfoTile(
                          label: 'Notes d\'information',
                          value: currentSupplier.notes,
                          icon: Icons.notes_rounded,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 650;
                            final colCount = isWide ? 2 : 1;
                            final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: tileWidth,
                                  child: DetailInfoTile(
                                    label: 'Date de création',
                                    value: formatDateTime(currentSupplier.createdAt),
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: DetailInfoTile(
                                    label: 'Dernière mise à jour',
                                    value: formatDateTime(currentSupplier.updatedAt),
                                    icon: Icons.update_rounded,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
