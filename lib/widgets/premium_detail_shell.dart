import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../mobile/utils/mobile_status_colors.dart';

/// Action button item for the top action bar
class PremiumDetailAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDanger;
  final Color? customColor;
  final String? tooltip;

  const PremiumDetailAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
    this.customColor,
    this.tooltip,
  });
}

/// Field model for information cards
class PremiumInfoField {
  final String label;
  final String value;
  final IconData? icon;
  final bool isHighlight;
  final Color? valueColor;
  final Widget? customValueWidget;

  const PremiumInfoField({
    required this.label,
    required this.value,
    this.icon,
    this.isHighlight = false,
    this.valueColor,
    this.customValueWidget,
  });
}

/// Information section containing a title and a list of fields
class PremiumInfoSection {
  final String title;
  final IconData? icon;
  final List<PremiumInfoField> fields;

  const PremiumInfoSection({
    required this.title,
    this.icon,
    required this.fields,
  });
}

/// Article item representation for the articles table / card list
class PremiumArticleItem {
  final String? reference;
  final String designation;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double? tvaRate;
  final double? discountPercent;
  final double totalHT;
  final String? unit;

  const PremiumArticleItem({
    this.reference,
    required this.designation,
    this.description,
    required this.quantity,
    this.unitPrice = 0,
    this.tvaRate,
    this.discountPercent,
    this.totalHT = 0,
    this.unit,
  });
}

/// Total summary row item
class PremiumTotalRow {
  final String label;
  final double? amount;
  final String? formattedValue;
  final bool isBold;
  final bool isGrandTotal;
  final Color? color;

  const PremiumTotalRow({
    required this.label,
    this.amount,
    this.formattedValue,
    this.isBold = false,
    this.isGrandTotal = false,
    this.color,
  });
}

/// A premium, enterprise-grade detail shell widget with animations,
/// responsive layout, modern status badge, action toolbar, structured cards,
/// professional data table, and grand total calculations.
class PremiumDetailShell extends StatefulWidget {
  final String documentType; // e.g. "Devis", "Facture", "Bon de livraison"
  final String referenceNumber;
  final String? statusLabel;
  final Color? statusColor;
  final bool showStatusBadge;
  final VoidCallback? onBack;
  final List<PremiumDetailAction> actions;
  final List<PremiumInfoSection> infoSections;
  final List<PremiumArticleItem> articles;
  final List<PremiumTotalRow> totals;
  final String? notes;
  final String? termsAndConditions;
  final Widget? customHeaderExtension;
  final Widget? customBottomWidget;
  final bool isScrollable;

  const PremiumDetailShell({
    super.key,
    required this.documentType,
    required this.referenceNumber,
    this.statusLabel,
    this.statusColor,
    this.showStatusBadge = true,
    this.onBack,
    this.actions = const [],
    this.infoSections = const [],
    this.articles = const [],
    this.totals = const [],
    this.notes,
    this.termsAndConditions,
    this.customHeaderExtension,
    this.customBottomWidget,
    this.isScrollable = true,
  });

  @override
  State<PremiumDetailShell> createState() => _PremiumDetailShellState();
}

class _PremiumDetailShellState extends State<PremiumDetailShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _resolveStatusColor() {
    if (widget.statusColor != null) return widget.statusColor!;
    if (widget.statusLabel != null && widget.statusLabel!.isNotEmpty) {
      return MobileStatusColors.getColorForStatus(widget.statusLabel!);
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final statusColor = _resolveStatusColor();

    final content = FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header Section (Hero Card) ──────────────────────────
            _buildHeroHeader(context, statusColor, isDesktop),
            const SizedBox(height: 16),

            // ─── Information Cards ────────────────────────────────────
            if (widget.infoSections.isNotEmpty) ...[
              _buildInfoSections(context, isDesktop),
              const SizedBox(height: 16),
            ],

            // ─── Articles Section ─────────────────────────────────────
            if (widget.articles.isNotEmpty) ...[
              _buildArticlesSection(context, isDesktop),
              const SizedBox(height: 16),
            ],

            // ─── Totaux & Notes (Side-by-side on desktop, stacked on mobile)
            _buildTotalsAndNotesSection(context, isDesktop),

            // ─── Optional Custom Bottom Widget ────────────────────────
            if (widget.customBottomWidget != null) ...[
              const SizedBox(height: 16),
              widget.customBottomWidget!,
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    if (!widget.isScrollable) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32.0 : 16.0,
          vertical: 16.0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: content,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32.0 : 16.0,
        vertical: 16.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: content,
        ),
      ),
    );
  }

  // ─── HERO HEADER ───────────────────────────────────────────────────
  Widget _buildHeroHeader(
      BuildContext context, Color statusColor, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Document Icon & Type
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: isDesktop ? 24 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.documentType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.referenceNumber,
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.showStatusBadge &&
                  widget.statusLabel != null &&
                  widget.statusLabel!.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildStatusBadge(widget.statusLabel!, statusColor, isDesktop),
              ],
            ],
          ),
          if (widget.customHeaderExtension != null) ...[
            const SizedBox(height: 12),
            widget.customHeaderExtension!,
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 10 : 8,
        vertical: isDesktop ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: isDesktop ? 12 : 11.5,
        ),
      ),
    );
  }


  // ─── INFO SECTIONS ─────────────────────────────────────────────────
  Widget _buildInfoSections(BuildContext context, bool isDesktop) {
    if (isDesktop && widget.infoSections.length >= 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.infoSections.map((section) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: section == widget.infoSections.last ? 0 : 16,
              ),
              child: _buildSingleInfoCard(section, isDesktop),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: widget.infoSections.map((section) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: section == widget.infoSections.last ? 0 : 12,
          ),
          child: _buildSingleInfoCard(section, isDesktop),
        );
      }).toList(),
    );
  }

  Widget _buildSingleInfoCard(PremiumInfoSection section, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (section.icon != null) ...[
                Icon(section.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...section.fields.asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final isLast = idx == section.fields.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (f.icon != null) ...[
                          Icon(f.icon,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            f.label,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: f.customValueWidget ??
                        Text(
                          f.value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: f.isHighlight
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: f.isHighlight ? 14 : 13,
                            color: f.valueColor ??
                                (f.isHighlight
                                    ? AppColors.primary
                                    : AppColors.textPrimary),
                          ),
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── ARTICLES SECTION ──────────────────────────────────────────────
  Widget _buildArticlesSection(BuildContext context, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Articles (${widget.articles.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isDesktop)
            _buildArticlesTableDesktop()
          else
            _buildArticlesListMobile(),
        ],
      ),
    );
  }

  Widget _buildArticlesTableDesktop() {
    return Column(
      children: [
        // Table Header (Full Width)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Référence',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Désignation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Qté',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Prix Unit. (HT)',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TVA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Remise',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total HT',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        // Table Rows (Full Width)
        ...widget.articles.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isEven = idx % 2 == 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isEven ? AppColors.surface : AppColors.surfaceAlt.withValues(alpha: 0.3),
              border: Border(
                bottom: idx == widget.articles.length - 1
                    ? BorderSide.none
                    : BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    (item.reference != null && item.reference!.trim().isNotEmpty)
                        ? item.reference!
                        : '—',
                    style: TextStyle(
                      color: (item.reference != null && item.reference!.trim().isNotEmpty)
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.designation,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      if (item.description != null &&
                          item.description!.trim().isNotEmpty &&
                          item.description!.trim() != item.designation.trim() &&
                          item.description!.trim() != item.reference?.trim())
                        Text(
                          item.description!,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatCurrencyDT(item.unitPrice),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.center,
                    child: item.tvaRate != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.tvaRate}%',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          )
                        : const Text('—', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.center,
                    child: (item.discountPercent != null && item.discountPercent! > 0)
                        ? Text(
                            '${item.discountPercent}%',
                            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 12),
                          )
                        : const Text('—', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatCurrencyDT(item.totalHT),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildArticlesListMobile() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final item = widget.articles[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          color: idx % 2 == 0 ? AppColors.surface : AppColors.surfaceAlt.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.designation,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        if (item.reference != null && item.reference!.isNotEmpty)
                          Text('Réf: ${item.reference}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrencyDT(item.totalHT),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} x ${formatCurrencyDT(item.unitPrice)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ),
                  Row(
                    children: [
                      if (item.tvaRate != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('TVA ${item.tvaRate}%', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (item.discountPercent != null && item.discountPercent! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Remise -${item.discountPercent}%', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TOTALS & NOTES SECTION ────────────────────────────────────────
  Widget _buildTotalsAndNotesSection(BuildContext context, bool isDesktop) {
    final hasNotes = (widget.notes != null && widget.notes!.trim().isNotEmpty) ||
        (widget.termsAndConditions != null && widget.termsAndConditions!.trim().isNotEmpty);

    final totalsCard = _buildTotalsCard();

    if (isDesktop && hasNotes) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: _buildNotesCard()),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: totalsCard),
        ],
      );
    }

    return Column(
      children: [
        totalsCard,
        if (hasNotes) ...[
          const SizedBox(height: 16),
          _buildNotesCard(),
        ],
      ],
    );
  }

  Widget _buildTotalsCard() {
    if (widget.totals.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Récapitulatif des Totaux',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...widget.totals.map((row) {
            final isGrandTotal = row.isGrandTotal;
            final valStr = row.formattedValue ??
                (row.amount != null ? formatCurrencyDT(row.amount!) : '—');

            if (isGrandTotal) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      valStr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.label,
                    style: TextStyle(
                      color: row.isBold ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: row.isBold ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    valStr,
                    style: TextStyle(
                      color: row.color ?? AppColors.textPrimary,
                      fontWeight: row.isBold ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.notes != null && widget.notes!.trim().isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.notes_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Notes / Observations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.notes!,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          if (widget.termsAndConditions != null &&
              widget.termsAndConditions!.trim().isNotEmpty) ...[
            if (widget.notes != null && widget.notes!.trim().isNotEmpty)
              const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.gavel_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Conditions Générales',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.termsAndConditions!,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
