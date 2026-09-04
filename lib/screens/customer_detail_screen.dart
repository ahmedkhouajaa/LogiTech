import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/customer.dart';
import '../blocs/customers/customers_bloc.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/details/detail_components.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'customers_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer currentCustomer;

  @override
  void initState() {
    super.initState();
    currentCustomer = widget.customer;
  }

  bool get _isDefault =>
      currentCustomer.isDefault ||
      currentCustomer.name.trim().toLowerCase() == 'client passager' ||
      currentCustomer.id.trim().isEmpty;

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
        value: context.read<CustomersBloc>(),
        child: CustomerDialog(existing: currentCustomer),
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
            const Text('Supprimer le client'),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer le client "${currentCustomer.name}" (${currentCustomer.code}) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<CustomersBloc>().add(DeleteCustomer(currentCustomer.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Client "${currentCustomer.name}" supprimé'),
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
    final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.customers);
    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.customers);

    final isEntreprise = currentCustomer.customerType.toLowerCase() == 'entreprise';

    // Balance indicator
    final hasDebt = currentCustomer.balance > 0.01;
    final balanceColor = hasDebt ? AppColors.error : AppColors.success;
    final balanceLabel = hasDebt
        ? 'Solde débiteur : ${formatCurrency(currentCustomer.balance)}'
        : 'Solde régularisé (${formatCurrency(currentCustomer.balance)})';

    // Address formatting
    final billingAddress = [
      currentCustomer.streetAddress ?? currentCustomer.address,
      currentCustomer.city,
      currentCustomer.postalCode,
      currentCustomer.country,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

    final deliveryAddress = currentCustomer.deliverySameAsBilling
        ? 'Identique à l\'adresse de facturation'
        : [
            currentCustomer.deliveryStreet,
            currentCustomer.deliveryCity,
            currentCustomer.deliveryPostalCode,
            currentCustomer.deliveryCountry,
          ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

    return BlocListener<CustomersBloc, CustomersState>(
      listener: (context, state) {
        if (state is CustomersLoaded) {
          final updated = state.customers.where((c) => c.id == currentCustomer.id).firstOrNull;
          if (updated != null) {
            setState(() => currentCustomer = updated);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: currentCustomer.name,
          subtitle: 'Client ${currentCustomer.code}',
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
                    icon: isEntreprise ? Icons.domain_rounded : Icons.person_rounded,
                    iconColor: isEntreprise ? AppColors.primary : const Color(0xFF0D9488),
                    iconBackgroundColor: (isEntreprise ? AppColors.primary : const Color(0xFF0D9488)).withValues(alpha: 0.12),
                    title: currentCustomer.name,
                    subtitle: (currentCustomer.companyName != null && currentCustomer.companyName!.isNotEmpty)
                        ? currentCustomer.companyName
                        : 'Client ${currentCustomer.code}',
                    badges: [
                      buildDetailBadge(
                        label: currentCustomer.code,
                        color: AppColors.primary,
                        icon: Icons.tag_rounded,
                        onTap: () => copyToClipboard(context, label: 'Code client', text: currentCustomer.code),
                      ),
                      buildDetailBadge(
                        label: isEntreprise ? 'ENTREPRISE' : 'PARTICULIER',
                        color: isEntreprise ? AppColors.primary : const Color(0xFF0D9488),
                        icon: isEntreprise ? Icons.domain_rounded : Icons.person_outline_rounded,
                      ),
                      if (_showFinancialKpis)
                        buildDetailBadge(
                          label: balanceLabel,
                          color: balanceColor,
                          icon: hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        ),
                      if (currentCustomer.tvaSuspension)
                        buildDetailBadge(
                          label: 'SUSPENSION TVA',
                          color: AppColors.warning,
                          icon: Icons.shield_outlined,
                        ),
                      if (_isDefault)
                        buildDetailBadge(
                          label: 'CLIENT PAR DÉFAUT',
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
                                label: 'Solde en cours',
                                value: formatCurrency(currentCustomer.balance),
                                icon: Icons.account_balance_wallet_outlined,
                                color: balanceColor,
                                isHighlight: hasDebt,
                                subtitle: hasDebt ? 'Montant à recouvrer' : 'Compte en règle',
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Plafond de Crédit',
                                value: formatCurrency(currentCustomer.creditLimit),
                                icon: Icons.speed_rounded,
                                color: AppColors.info,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Grille Tarifaire',
                                value: currentCustomer.priceList.toUpperCase(),
                                icon: Icons.price_change_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DetailKpiCard(
                                label: 'Régime Fiscal',
                                value: currentCustomer.tvaSuspension ? 'En suspension' : 'Standard',
                                icon: Icons.receipt_long_outlined,
                                color: currentCustomer.tvaSuspension ? AppColors.warning : AppColors.success,
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
                    title: _showFinancialKpis ? 'Situation Financière & Facturation' : 'Coordonnées Bancaires (RIB)',
                    icon: Icons.account_balance_outlined,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = _showFinancialKpis ? (isWide ? 4 : 2) : 1;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (_showFinancialKpis) ...[
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'Solde actuel',
                                  value: formatCurrency(currentCustomer.balance),
                                  icon: Icons.account_balance_wallet_outlined,
                                  valueColor: balanceColor,
                                  valueFontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'Plafond de crédit autorisé',
                                  value: formatCurrency(currentCustomer.creditLimit),
                                  icon: Icons.credit_score_rounded,
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'Grille tarifaire assignée',
                                  value: currentCustomer.priceList,
                                  icon: Icons.local_offer_outlined,
                                ),
                              ),
                            ],
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Compte bancaire / RIB',
                                value: currentCustomer.bankAccount,
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
                    title: 'Identité & Contact Commercial',
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
                                label: 'Raison sociale / Enseigne',
                                value: currentCustomer.companyName,
                                icon: Icons.business_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Interlocuteur / Responsable',
                                value: currentCustomer.responsibleName,
                                icon: Icons.person_pin_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Numéro CIN / Identité',
                                value: currentCustomer.cinNumber,
                                icon: Icons.credit_card_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Date de naissance',
                                value: currentCustomer.birthDate,
                                icon: Icons.cake_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Référence interne',
                                value: currentCustomer.referenceCode,
                                icon: Icons.bookmark_border_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Type de client',
                                value: currentCustomer.customerType.toUpperCase(),
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
                                value: currentCustomer.phone,
                                icon: Icons.phone_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Adresse Email',
                                value: currentCustomer.email,
                                icon: Icons.email_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Adresse de Facturation (Siège)',
                                value: billingAddress.isNotEmpty ? billingAddress : null,
                                icon: Icons.receipt_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Adresse de Livraison',
                                value: deliveryAddress.isNotEmpty ? deliveryAddress : null,
                                copyValue: currentCustomer.deliverySameAsBilling
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

                  // Section 4: Fiscalité & Exonération TVA
                  DetailSectionCard(
                    title: 'Fiscalité & Exonération de TVA',
                    icon: Icons.gavel_rounded,
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
                                label: 'Matricule Fiscal (NIF)',
                                value: currentCustomer.taxId,
                                icon: Icons.numbers_rounded,
                                copyable: true,
                                valueFontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Registre de Commerce (RC)',
                                value: currentCustomer.rc,
                                icon: Icons.assignment_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Régime TVA',
                                value: currentCustomer.tvaSuspension ? 'En suspension de TVA' : 'Régime standard',
                                icon: Icons.shield_outlined,
                                valueColor: currentCustomer.tvaSuspension ? AppColors.warning : AppColors.success,
                                valueFontWeight: FontWeight.bold,
                              ),
                            ),
                            if (currentCustomer.tvaSuspension) ...[
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'N° Attestation d\'exonération',
                                  value: currentCustomer.tvaAttestation,
                                  icon: Icons.verified_user_outlined,
                                  copyable: true,
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'Date de début d\'exonération',
                                  value: currentCustomer.tvaStartDate,
                                  icon: Icons.calendar_month_outlined,
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: DetailInfoTile(
                                  label: 'Date d\'expiration d\'exonération',
                                  value: currentCustomer.tvaEndDate,
                                  icon: Icons.event_busy_outlined,
                                  valueColor: AppColors.error,
                                ),
                              ),
                            ],
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
                          value: currentCustomer.notes,
                          icon: Icons.notes_rounded,
                        ),
                        const SizedBox(height: 12),
                        DetailInfoTile(
                          label: 'Notes privées / confidentielles',
                          value: currentCustomer.privateNote,
                          icon: Icons.lock_outline_rounded,
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
                                    value: formatDateTime(currentCustomer.createdAt),
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: DetailInfoTile(
                                    label: 'Dernière mise à jour',
                                    value: formatDateTime(currentCustomer.updatedAt),
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
