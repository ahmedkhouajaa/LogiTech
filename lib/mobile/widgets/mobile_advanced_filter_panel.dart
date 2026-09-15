import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../models/customer.dart';
import '../../models/supplier.dart';
import '../utils/mobile_status_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/custom_status_service.dart';

class MobileAdvancedFilterPanel extends StatefulWidget {
  final String? entityLabel; // 'Client', 'Fournisseur', or null
  final String? selectedEntityId;
  final List<Customer>? customers;
  final List<Supplier>? suppliers;
  final ValueChanged<String?>? onEntityChanged;

  final DateTime? dateFrom;
  final ValueChanged<DateTime?> onDateFromChanged;
  final DateTime? dateTo;
  final ValueChanged<DateTime?> onDateToChanged;
  final String? selectedStatus;
  final List<String> statusOptions;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onResetFilters;
  final int itemCount;
  final String? documentType;

  const MobileAdvancedFilterPanel({
    super.key,
    this.entityLabel = 'Client',
    String? selectedCustomerId,
    this.customers,
    ValueChanged<String?>? onCustomerChanged,
    this.suppliers,
    String? selectedEntityId,
    ValueChanged<String?>? onEntityChanged,
    required this.dateFrom,
    required this.onDateFromChanged,
    required this.dateTo,
    required this.onDateToChanged,
    required this.selectedStatus,
    this.statusOptions = const [],
    required this.onStatusChanged,
    required this.onResetFilters,
    required this.itemCount,
    this.documentType,
  })  : selectedEntityId = selectedEntityId ?? selectedCustomerId,
        onEntityChanged = onEntityChanged ?? onCustomerChanged;

  @override
  State<MobileAdvancedFilterPanel> createState() => _MobileAdvancedFilterPanelState();
}

class _MobileStatusOptionItem {
  final String value;
  final String label;
  final Color? color;
  final bool isCustom;

  const _MobileStatusOptionItem({
    required this.value,
    required this.label,
    this.color,
    this.isCustom = false,
  });
}

class _MobileAdvancedFilterPanelState extends State<MobileAdvancedFilterPanel> {
  bool _isExpanded = false;
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToCustomStatuses();
  }

  @override
  void didUpdateWidget(MobileAdvancedFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentType != widget.documentType) {
      _subscribeToCustomStatuses();
    }
  }

  void _subscribeToCustomStatuses() {
    _statusSubscription?.cancel();
    if (widget.documentType != null && widget.documentType!.isNotEmpty) {
      _statusSubscription = CustomStatusService.instance.changeStream.listen((docType) {
        if (docType == widget.documentType && mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  List<_MobileStatusOptionItem> get _effectiveStatusOptions {
    if (widget.documentType != null && widget.documentType!.isNotEmpty) {
      final statuses = CustomStatusService.instance.getAllStatusesSync(widget.documentType!);
      final list = <_MobileStatusOptionItem>[
        const _MobileStatusOptionItem(value: 'Tous', label: 'Tous', color: null, isCustom: false),
      ];
      for (final s in statuses) {
        list.add(_MobileStatusOptionItem(
          value: s.name,
          label: s.name,
          color: s.color,
          isCustom: !s.isDefault,
        ));
      }
      return list;
    }

    return widget.statusOptions.map((opt) {
      if (opt == 'Tous') {
        return const _MobileStatusOptionItem(value: 'Tous', label: 'Tous', color: null, isCustom: false);
      }
      return _MobileStatusOptionItem(
        value: opt,
        label: opt,
        color: MobileStatusColors.getColorForStatus(opt),
        isCustom: false,
      );
    }).toList();
  }

  int get _activeFilterCount {
    int count = 0;
    if (widget.selectedEntityId != null && widget.selectedEntityId!.isNotEmpty) {
      count++;
    }
    if (widget.dateFrom != null) {
      count++;
    }
    if (widget.dateTo != null) {
      count++;
    }
    if (widget.selectedStatus != null &&
        widget.selectedStatus != 'Tous' &&
        widget.selectedStatus!.isNotEmpty) {
      count++;
    }
    return count;
  }

  String get _selectedEntityName {
    final label = widget.entityLabel ?? 'Client';
    if (widget.selectedEntityId == null || widget.selectedEntityId!.isEmpty) {
      return 'Tous les ${label == 'Fournisseur' ? 'fournisseurs' : 'clients'}';
    }

    if (label == 'Fournisseur' && widget.suppliers != null) {
      final match = widget.suppliers!.cast<Supplier?>().firstWhere(
            (s) => s?.id == widget.selectedEntityId,
            orElse: () => null,
          );
      if (match != null) {
        return match.name.isNotEmpty ? match.name : (match.companyName ?? 'Fournisseur');
      }
      return 'Tous les fournisseurs';
    } else if (widget.customers != null) {
      final match = widget.customers!.cast<Customer?>().firstWhere(
            (c) => c?.id == widget.selectedEntityId,
            orElse: () => null,
          );
      if (match != null) {
        return match.name.isNotEmpty ? match.name : (match.companyName ?? 'Client');
      }
      return 'Tous les clients';
    }

    return 'Tous les ${label == 'Fournisseur' ? 'fournisseurs' : 'clients'}';
  }

  void _showEntitySearchModal(BuildContext context) {
    final isSupplier = widget.entityLabel == 'Fournisseur';
    final titleText = 'Sélectionner un ${isSupplier ? 'fournisseur' : 'client'}';
    final searchHint = 'Rechercher un ${isSupplier ? 'fournisseur' : 'client'}...';
    final allText = 'Tous les ${isSupplier ? 'fournisseurs' : 'clients'}';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dynamicRawList = isSupplier ? (widget.suppliers ?? []) : (widget.customers ?? []);

            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520, maxWidth: 400),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    TextField(
                      onChanged: (val) => setModalState(() => query = val),
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // "Tous les ..." Option Tile
                    InkWell(
                      onTap: () {
                        widget.onEntityChanged?.call(null);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.selectedEntityId == null
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              allText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: widget.selectedEntityId == null
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: widget.selectedEntityId == null
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (widget.selectedEntityId == null)
                              Icon(Icons.check, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),

                    // List
                    Expanded(
                      child: ListView.builder(
                        itemCount: dynamicRawList.length,
                        itemBuilder: (_, index) {
                          final dynamic item = dynamicRawList[index];
                          final id = (item.id ?? '').toString();
                          final name = (item.name ?? '').toString().isNotEmpty
                              ? item.name.toString()
                              : ((item.companyName ?? '').toString().isNotEmpty
                                  ? item.companyName.toString()
                                  : (isSupplier ? 'Fournisseur' : 'Client'));
                          final code = (item.code ?? '').toString().isNotEmpty
                              ? item.code.toString()
                              : '${isSupplier ? 'FOR' : 'CLI'}-${id.length >= 4 ? id.substring(0, 4) : id}';
                          final phone = item.phone as String?;

                          if (query.isNotEmpty) {
                            final q = query.toLowerCase();
                            final nameMatch = name.toLowerCase().contains(q);
                            final codeMatch = code.toLowerCase().contains(q);
                            final phoneMatch = (phone ?? '').toLowerCase().contains(q);
                            if (!nameMatch && !codeMatch && !phoneMatch) {
                              return const SizedBox.shrink();
                            }
                          }

                          final isSelected = id == widget.selectedEntityId;
                          final phoneStr = (phone != null && phone.isNotEmpty) ? ' • $phone' : '';
                          final subtitleText = '$code$phoneStr';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: InkWell(
                              onTap: () {
                                widget.onEntityChanged?.call(id);
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitleText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSelected
                                                  ? AppColors.primary.withValues(alpha: 0.8)
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check, color: AppColors.primary, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeFilterCount;
    final showEntityField = widget.entityLabel != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toggle Row & Result Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expand/Collapse Filter Button
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isExpanded || activeCount > 0
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    border: Border.all(
                      color: _isExpanded || activeCount > 0 ? AppColors.primary : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: _isExpanded || activeCount > 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('Filtres'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isExpanded || activeCount > 0 ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$activeCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: _isExpanded || activeCount > 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // Result Count Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.itemCount} ${context.tr(widget.itemCount > 1 ? 'résultats' : 'résultat')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          // Expandable Filter Controls Card
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Entity Field (Client / Fournisseur)
                  if (showEntityField) ...[
                    Text(
                      widget.entityLabel!,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _showEntitySearchModal(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedEntityName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.selectedEntityId != null ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 2. Dates Row (Date de début & Date de fin)
                  Row(
                    children: [
                      // Date de début
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Date de début'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: widget.dateFrom ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  locale: Localizations.localeOf(context),
                                );
                                if (picked != null) widget.onDateFromChanged(picked);
                              },
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.dateFrom != null ? formatDate(widget.dateFrom!) : context.tr('Sélectionner une date'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: widget.dateFrom != null ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Date de fin
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Date de fin'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: widget.dateTo ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  locale: Localizations.localeOf(context),
                                );
                                if (picked != null) widget.onDateToChanged(picked);
                              },
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.dateTo != null ? formatDate(widget.dateTo!) : context.tr('Sélectionner une date'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: widget.dateTo != null ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. Statut Popup Menu
                  Text(context.tr('Statut'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  PopupMenuButton<String>(
                    tooltip: context.tr('Filtrer par statut'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                    ),
                    color: AppColors.surface,
                    elevation: 6,
                    offset: const Offset(0, 44),
                    initialValue: widget.selectedStatus ?? 'Tous',
                    onSelected: (val) {
                      if (val == 'Tous') {
                        widget.onStatusChanged(null);
                      } else {
                        widget.onStatusChanged(val);
                      }
                    },
                    itemBuilder: (context) => _effectiveStatusOptions.map((opt) {
                      final isSelected = (widget.selectedStatus ?? 'Tous').toLowerCase() == opt.value.toLowerCase();

                      return PopupMenuItem<String>(
                        value: opt.value,
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (opt.value == 'Tous')
                              Text(
                                context.tr('Tous'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            else
                              Builder(
                                builder: (_) {
                                  final statusColor = opt.color ?? MobileStatusColors.getColorForStatus(opt.label);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (opt.isCustom) ...[
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                        Text(
                                          context.tr(opt.label),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            if (isSelected)
                              Icon(Icons.check, size: 18, color: AppColors.primary),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.selectedStatus == null || widget.selectedStatus == 'Tous')
                            Text(
                              context.tr('Tous'),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            )
                          else
                            Builder(
                              builder: (_) {
                                final sInfo = widget.documentType != null
                                    ? CustomStatusService.instance.getStatusInfo(widget.documentType!, widget.selectedStatus!)
                                    : null;
                                final statusColor = sInfo?.color ?? MobileStatusColors.getColorForStatus(widget.selectedStatus!);
                                final statusLabel = sInfo?.label ?? widget.selectedStatus!;
                                final isCustom = sInfo?.isCustom ?? false;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCustom) ...[
                                        Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                      Text(
                                        context.tr(statusLabel),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Reset Filters Button ("Réinitialiser les filtres")
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        widget.onResetFilters();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        context.tr('Réinitialiser les filtres'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Active Filter Chips Bar
          if (activeCount > 0) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (widget.selectedEntityId != null && showEntityField)
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Chip(
                        label: Text('${widget.entityLabel}: $_selectedEntityName', style: const TextStyle(fontSize: 11)),
                        onDeleted: () => widget.onEntityChanged?.call(null),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  if (widget.dateFrom != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Chip(
                        label: Text('Du: ${formatDate(widget.dateFrom!)}', style: const TextStyle(fontSize: 11)),
                        onDeleted: () => widget.onDateFromChanged(null),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  if (widget.dateTo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Chip(
                        label: Text('Au: ${formatDate(widget.dateTo!)}', style: const TextStyle(fontSize: 11)),
                        onDeleted: () => widget.onDateToChanged(null),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  if (widget.selectedStatus != null && widget.selectedStatus != 'Tous')
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Builder(
                        builder: (_) {
                          final sInfo = widget.documentType != null
                              ? CustomStatusService.instance.getStatusInfo(widget.documentType!, widget.selectedStatus!)
                              : null;
                          final statusLabel = sInfo?.label ?? widget.selectedStatus!;
                          final statusColor = sInfo?.color ?? AppColors.primary;
                          return Chip(
                            label: Text('Statut: $statusLabel', style: const TextStyle(fontSize: 11)),
                            onDeleted: () => widget.onStatusChanged(null),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            backgroundColor: statusColor.withValues(alpha: 0.12),
                            side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.all(4),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
