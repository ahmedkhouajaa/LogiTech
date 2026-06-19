import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../models/receiving_voucher.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import 'create_receiving_voucher_screen.dart';
import 'create_supplier_order_screen.dart';
import '../models/supplier_order.dart';
import '../blocs/supplier_orders/supplier_orders_bloc.dart';

enum ReceivingVoucherStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Validé', AppColors.success),
  partial('Réception partielle', AppColors.warning),
  canceled('Annulé', AppColors.error);

  final String label;
  final Color color;
  const ReceivingVoucherStatus(this.label, this.color);
}

class ReceivingVouchersScreen extends StatefulWidget {
  const ReceivingVouchersScreen({super.key});

  @override
  State<ReceivingVouchersScreen> createState() => _ReceivingVouchersScreenState();
}

class _ReceivingVouchersScreenState extends State<ReceivingVouchersScreen> {
  String? _selectedSupplierId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  ReceivingVoucherStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<ReceivingVouchersBloc>().add(LoadReceivingVouchers());
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  void _applyFilters() {
    _currentPage = 0;
    // We don't have a backend filter event, so we just trigger a rebuild to filter locally
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Bons de réception',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              AppButton(
                label: 'Nouveau bon',
                icon: Icons.add,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateReceivingVoucherScreen()),
                  );
                },
                isPrimary: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _buildFilterBar(),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTable(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Supplier
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: BlocBuilder<SuppliersBloc, SuppliersState>(
                    builder: (context, state) {
                      List<Supplier> suppliers = [];
                      if (state is SuppliersLoaded) {
                        suppliers = state.suppliers;
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedSupplierId,
                        decoration: InputDecoration(
                          hintText: 'Sélectionner un fournisseur...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary)),
                        ),
                        icon: const Icon(Icons.unfold_more, size: 16),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('Tous les fournisseurs', style: TextStyle(color: AppColors.textSecondary))),
                          ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSupplierId = val == 'all' ? null : val);
                          _applyFilters();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date From
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Date de début', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (date != null) {
                      setState(() => _dateFrom = date);
                      _applyFilters();
                    }
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateFrom != null ? formatDateLong(_dateFrom!) : 'Sélectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateFrom != null ? AppColors.textPrimary : AppColors.textTertiary),
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
          const SizedBox(width: AppSpacing.md),
          // Date To
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Date de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (date != null) {
                      setState(() => _dateTo = date);
                      _applyFilters();
                    }
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateTo != null ? formatDateLong(_dateTo!) : 'Sélectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateTo != null ? AppColors.textPrimary : AppColors.textTertiary),
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
          const SizedBox(width: AppSpacing.md),
          // Status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: DropdownButtonFormField<ReceivingVoucherStatus?>(
                    value: _statusFilter,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                    icon: const Icon(Icons.expand_more, size: 16),
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: AppColors.textPrimary))),
                      ...ReceivingVoucherStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                    ],
                    onChanged: (val) {
                      setState(() => _statusFilter = val);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Reset Button
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _selectedSupplierId = null;
                  _dateFrom = null;
                  _dateTo = null;
                  _statusFilter = null;
                });
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return BlocBuilder<ReceivingVouchersBloc, ReceivingVouchersState>(
      builder: (context, state) {
        if (state is ReceivingVouchersLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ReceivingVouchersError) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        if (state is ReceivingVouchersLoaded) {
          // Local filtering
          var filteredVouchers = state.vouchers.where((v) {
            if (_selectedSupplierId != null && _selectedSupplierId != 'all' && v.supplierId != _selectedSupplierId) return false;
            if (_dateFrom != null && v.date.isBefore(DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day))) return false;
            if (_dateTo != null && v.date.isAfter(DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59))) return false;
            if (_statusFilter != null && v.status != _statusFilter!.name) return false;
            return true;
          }).toList();

          // Pagination
          final totalItems = filteredVouchers.length;
          final totalPages = (totalItems / _rowsPerPage).ceil() == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
          if (_currentPage >= totalPages) _currentPage = totalPages - 1;
          if (_currentPage < 0) _currentPage = 0;

          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage > totalItems) ? totalItems : startIndex + _rowsPerPage;
          final paginatedVouchers = filteredVouchers.sublist(startIndex, endIndex);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 32), // Checkbox space
                              Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 3, child: Text('Fournisseur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        // Table Body
                        Expanded(
                          child: paginatedVouchers.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.border),
                                      SizedBox(height: 16),
                                      Text("Aucun bon de réception trouvé", style: TextStyle(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: paginatedVouchers.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final voucher = paginatedVouchers[index];
                                    final statusEnum = ReceivingVoucherStatus.values.firstWhere(
                                      (e) => e.name == voucher.status,
                                      orElse: () => ReceivingVoucherStatus.draft,
                                    );

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            child: Checkbox(
                                              value: false,
                                              onChanged: (_) {},
                                              side: const BorderSide(color: AppColors.border),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(voucher.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                                const SizedBox(height: 4),
                                                Text(formatDateTimeLong(voucher.date), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.business_outlined, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    voucher.supplierName ?? 'Fournisseur Inconnu',
                                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(formatDateLong(voucher.date), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusEnum.color.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  statusEnum.label,
                                                  style: TextStyle(color: statusEnum.color, fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                                                tooltip: 'Actions',
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                color: AppColors.surface,
                                                onSelected: (val) {
                                                  if (val == 'view') {
                                                    if (voucher.orderId != null) {
                                                      final state = context.read<SupplierOrdersBloc>().state;
                                                      SupplierOrder? originalOrder;
                                                      if (state is SupplierOrdersLoaded) {
                                                        try {
                                                          originalOrder = state.orders.firstWhere((o) => o.id == voucher.orderId);
                                                        } catch (_) {}
                                                      }
                                                      if (originalOrder != null) {
                                                        final receiptOrder = originalOrder.copyWith(
                                                          number: voucher.number,
                                                          date: voucher.date,
                                                          status: voucher.status,
                                                        );
                                                        Navigator.push(context, MaterialPageRoute(
                                                          builder: (_) => CreateSupplierOrderScreen(
                                                            existing: receiptOrder,
                                                            isReadOnly: true,
                                                            overrideTitle: 'Détails du bon de réception',
                                                          ),
                                                        ));
                                                        return;
                                                      }
                                                    }
                                                    // Fallback
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => CreateReceivingVoucherScreen(existing: voucher),
                                                      ),
                                                    );
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  PopupMenuItem(
                                                    value: 'view',
                                                    child: Row(
                                                      children: const [
                                                        Icon(Icons.visibility_outlined, size: 18, color: AppColors.info),
                                                        SizedBox(width: 8),
                                                        Text('Voir les détails', style: TextStyle(fontSize: 13)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Pagination Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                  color: AppColors.background,
                ),
                child: Row(
                  children: [
                    const Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.surface,
                      ),
                      child: DropdownButton<int>(
                        value: _rowsPerPage,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _rowsPerPage = v;
                              _currentPage = 0;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(
                      totalItems == 0 ? 'Affichage de 0 à 0 sur 0 résultats' : 'Affichage de ${startIndex + 1} à $endIndex sur $totalItems résultats',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        InkWell(
                          onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(4),
                              color: AppColors.surface,
                            ),
                            child: Icon(Icons.chevron_left, size: 20, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(4),
                              color: AppColors.surface,
                            ),
                            child: Icon(Icons.chevron_right, size: 20, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }
}
