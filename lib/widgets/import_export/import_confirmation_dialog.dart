import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/import_export_service.dart';

/// Category definition for grouping collections in confirmation dialog
class _CollectionCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> collectionKeys;

  const _CollectionCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.collectionKeys,
  });
}

/// A professional, polished, trustworthy Import Confirmation Dialog.
/// Replaces clunky vertical bullet lists with an organized, categorized card layout.
class ImportConfirmationDialog extends StatefulWidget {
  final bool isFullImport;
  final List<String> selectedCollectionKeys;
  final String enterpriseName;

  const ImportConfirmationDialog({
    super.key,
    required this.isFullImport,
    required this.selectedCollectionKeys,
    required this.enterpriseName,
  });

  /// Displays the confirmation dialog and returns true if confirmed
  static Future<bool> show({
    required BuildContext context,
    required bool isFullImport,
    required List<String> selectedCollectionKeys,
    required String enterpriseName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImportConfirmationDialog(
        isFullImport: isFullImport,
        selectedCollectionKeys: selectedCollectionKeys,
        enterpriseName: enterpriseName,
      ),
    );
    return result ?? false;
  }

  @override
  State<ImportConfirmationDialog> createState() => _ImportConfirmationDialogState();
}

class _ImportConfirmationDialogState extends State<ImportConfirmationDialog> {
  bool _isAgreed = false;

  // ─── Categories definition ─────────────────────────────────────────
  static const List<_CollectionCategory> _categories = [
    _CollectionCategory(
      title: 'Ventes & Facturation',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF2563EB),
      collectionKeys: [
        'invoices',
        'quotes',
        'customer_orders',
        'delivery_notes',
        'credit_notes',
        'return_notes',
      ],
    ),
    _CollectionCategory(
      title: 'Achats & Fournisseurs',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF0D9488),
      collectionKeys: [
        'purchase_invoices',
        'supplier_orders',
        'receiving_vouchers',
        'supplier_credit_notes',
        'supplier_returns',
      ],
    ),
    _CollectionCategory(
      title: 'Contacts & Tiers',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF7C3AED),
      collectionKeys: [
        'clients',
        'fournisseurs',
      ],
    ),
    _CollectionCategory(
      title: 'Articles & Gestion des Stocks',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFFD97706),
      collectionKeys: [
        'articles',
        'stock_entries',
        'stock_withdrawals',
        'stock_movements',
        'stock_transfers',
        'inventory_sheets',
      ],
    ),
    _CollectionCategory(
      title: 'Trésorerie & Règlements',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF059669),
      collectionKeys: [
        'treasury_accounts',
        'treasury_transactions',
        'paiements',
      ],
    ),
    _CollectionCategory(
      title: 'Organisation & Paramètres',
      icon: Icons.business_center_outlined,
      color: Color(0xFF4B5563),
      collectionKeys: [
        'projects',
        'warehouses',
        'document_templates',
        'company_settings',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final selectedSet = widget.selectedCollectionKeys.toSet();

    // Filter categories that have at least one selected collection
    final activeCategories = _categories.where((cat) {
      return cat.collectionKeys.any((k) => selectedSet.contains(k));
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: 580,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(context),

            const Divider(height: 1),

            // ── Scrollable Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enterprise Banner
                    _buildEnterpriseBanner(),
                    const SizedBox(height: 16),

                    // Section Title
                    Row(
                      children: [
                        Text(
                          'DONNÉES QUI SERONT REMPLACÉES',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${widget.selectedCollectionKeys.length} collections',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Categorized Cards
                    ...activeCategories.map((category) {
                      final categoryItems = category.collectionKeys
                          .where((k) => selectedSet.contains(k))
                          .map((k) => ImportExportService.backupCollections[k] ?? k)
                          .toList();

                      return _buildCategoryCard(
                        category: category,
                        items: categoryItems,
                      );
                    }),

                    const SizedBox(height: 16),

                    // Warning Notice Box
                    _buildWarningCallout(),

                    const SizedBox(height: 16),

                    // Irreversible Confirmation Checkbox Card
                    _buildAgreementCard(),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Footer Actions ──
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Warm amber background
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isFullImport
                      ? 'Attention : Importation complète'
                      : 'Attention : Importation des données',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.isFullImport
                      ? 'Cette action va remplacer toutes les données actuelles par le fichier importé.'
                      : 'Cette action va remplacer les données pour les collections sélectionnées.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 20),
            tooltip: 'Fermer',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.business_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                children: [
                  const TextSpan(text: 'Entreprise cible : '),
                  TextSpan(
                    text: widget.enterpriseName,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required _CollectionCategory category,
    required List<String> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(category.icon, color: category.color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCallout() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Soft red/rose background
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFDC2626),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cette opération est irréversible. Les anciennes données existantes dans les collections ciblées seront définitivement remplacées par celles du fichier importé.',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementCard() {
    return InkWell(
      onTap: () => setState(() => _isAgreed = !_isAgreed),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isAgreed
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _isAgreed
                ? AppColors.primary
                : AppColors.border,
            width: _isAgreed ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _isAgreed,
                onChanged: (val) => setState(() => _isAgreed = val ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Je comprends que cette action est irréversible',
                style: TextStyle(
                  color: _isAgreed ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: _isAgreed ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.textPrimary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isAgreed ? () => Navigator.of(context).pop(true) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.surfaceAlt,
              disabledForegroundColor: AppColors.textTertiary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text(
              'Confirmer et importer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
