import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/production_order.dart';
import '../models/production_bom.dart';
import '../models/product.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../services/connectivity_service.dart';
import '../services/production_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../l10n/app_localizations.dart';

class ProductionOrdersScreen extends StatefulWidget {
  const ProductionOrdersScreen({super.key});

  @override
  State<ProductionOrdersScreen> createState() => _ProductionOrdersScreenState();
}

class _ProductionOrdersScreenState extends State<ProductionOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  ProductionOrderStatus? _selectedStatus;
  int? _selectedPriority;

  final currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ProductionService.instance.ordersNotifier,
      builder: (context, _) {
        final allOrders = ProductionService.instance.ordersNotifier.value;

        // Apply filters
        final filtered = allOrders.where((o) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchNum = o.number.toLowerCase().contains(q);
            final matchProd = o.productName.toLowerCase().contains(q);
            if (!matchNum && !matchProd) return false;
          }
          if (_selectedStatus != null && o.status != _selectedStatus) {
            return false;
          }
          if (_selectedPriority != null && o.priority != _selectedPriority) {
            return false;
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Ordres de Fabrication (OF)'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filtered.length} ordres de fabrication affichés',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateOrderDialog(context),
                      icon: const Icon(Icons.add_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Nouvel Ordre de Fabrication',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Filters Toolbar (Styled to match Image 2)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 750;

                    final searchWidget = SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Rechercher par N° OF, article...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    );

                    final statusDropdown = Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProductionOrderStatus?>(
                          value: _selectedStatus,
                          hint: Text(
                            'Tous les statuts',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tous les statuts', style: TextStyle(fontSize: 12.5)),
                            ),
                            ...ProductionOrderStatus.values.map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(s.icon, size: 14, color: s.color),
                                    const SizedBox(width: 6),
                                    Text(s.label, style: const TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedStatus = v),
                        ),
                      ),
                    );

                    final priorityDropdown = Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedPriority,
                          hint: Text(
                            'Toutes priorités',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Toutes priorités', style: TextStyle(fontSize: 12.5)),
                            ),
                            DropdownMenuItem(value: 0, child: Text('Basse', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 1, child: Text('Normale', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 2, child: Text('Haute', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 3, child: Text('Urgente 🔥', style: TextStyle(fontSize: 12.5))),
                          ],
                          onChanged: (v) => setState(() => _selectedPriority = v),
                        ),
                      ),
                    );

                    final resetButton = (_selectedStatus != null ||
                            _selectedPriority != null ||
                            _searchQuery.isNotEmpty)
                        ? SizedBox(
                            height: 40,
                            child: TextButton.icon(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedStatus = null;
                                  _selectedPriority = null;
                                });
                              },
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              label: const Text('Réinitialiser', style: TextStyle(fontSize: 12.5)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                              ),
                            ),
                          )
                        : null;

                    if (isNarrow) {
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(width: constraints.maxWidth, child: searchWidget),
                          statusDropdown,
                          priorityDropdown,
                          if (resetButton != null) resetButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchWidget),
                        const SizedBox(width: 10),
                        statusDropdown,
                        const SizedBox(width: 10),
                        priorityDropdown,
                        if (resetButton != null) ...[
                          const SizedBox(width: 8),
                          resetButton,
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Orders Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun ordre de fabrication trouvé.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final o = filtered[i];
                              return _buildOrderRow(o, isDark);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderRow(ProductionOrder o, bool isDark) {
    final priorityLabels = ['Basse', 'Normale', 'Haute', 'Urgente'];
    final priorityColors = [
      const Color(0xFF64748B),
      const Color(0xFF2563EB),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    return InkWell(
      onTap: () => _openOrderDetailModal(context, o),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status Icon Container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: o.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(o.status.icon, color: o.status.color, size: 20),
            ),
            const SizedBox(width: 14),

            // Number & Product
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.number,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(o.productName,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF64748B))),
                ],
              ),
            ),

            // Quantity & Progression
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${o.qtyProduced.toInt()} / ${o.qtyPlanned.toInt()} ${o.unit}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: o.progressPercentage / 100.0,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(o.status.color),
                    ),
                  ),
                ],
              ),
            ),

            // Priority Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (priorityColors[o.priority.clamp(0, 3)])
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                priorityLabels[o.priority.clamp(0, 3)],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: priorityColors[o.priority.clamp(0, 3)],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Dates
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.plannedEnd != null
                        ? 'Fin: ${dateFmt.format(o.plannedEnd!)}'
                        : 'Non planifié',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (o.hasShortage)
                    const Text('Rupture matière !',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444))),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: o.status.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: o.status.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                o.status.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: o.status.color,
                ),
              ),
            ),
            const SizedBox(width: 8),

            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE ORDER DIALOG
  // ---------------------------------------------------------------------------
  void _openCreateOrderDialog(BuildContext context) {
    final productsState = context.read<ProductsBloc>().state;
    final List<Product> products =
        productsState is ProductsLoaded ? productsState.products : [];

    final boms = ProductionService.instance.bomsNotifier.value;
    final warehousesState = context.read<WarehousesBloc>().state;
    final warehouses =
        warehousesState is WarehousesLoaded ? warehousesState.warehouses : [];

    Product? selectedProduct;
    ProductionBom? selectedBom;
    final qtyCtrl = TextEditingController(text: '10');
    int priority = 1;
    String? sourceWarehouseId =
        warehouses.isNotEmpty ? warehouses.first.id : null;
    String? sourceWarehouseName =
        warehouses.isNotEmpty ? warehouses.first.name : null;
    String? destWarehouseId =
        warehouses.isNotEmpty ? warehouses.first.id : null;
    String? destWarehouseName =
        warehouses.isNotEmpty ? warehouses.first.name : null;
    DateTime plannedStart = DateTime.now();
    DateTime plannedEnd = DateTime.now().add(const Duration(days: 3));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Créer un Ordre de Fabrication',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Finished Product dropdown
                      const Text('Article à fabriquer *',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<Product>(
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        decoration: _inputDeco('Sélectionner un produit', isDark),
                        items: products.map((p) {
                          return DropdownMenuItem(
                              value: p, child: Text('${p.code} - ${p.name}', style: const TextStyle(fontSize: 12.5)));
                        }).toList(),
                        onChanged: (p) {
                          setDState(() {
                            selectedProduct = p;
                            if (p != null) {
                              selectedBom = ProductionService.instance
                                  .getBomForProduct(p.id);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Associated BOM
                      if (selectedProduct != null) ...[
                        const Text('Nomenclature (BOM) associée *',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<ProductionBom>(
                          initialValue: selectedBom,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          decoration: _inputDeco(null, isDark),
                          items: boms
                              .where((b) => b.productId == selectedProduct!.id)
                              .map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(
                                      '${b.version} (${b.components.length} composants, ${currencyFmt.format(b.standardUnitCost)} / unité)',
                                      style: const TextStyle(fontSize: 12.5))))
                              .toList(),
                          onChanged: (b) => setDState(() => selectedBom = b),
                        ),
                        if (selectedBom == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ Aucune nomenclature configurée pour ce produit. Créez-en une d\'abord dans le menu Nomenclatures.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFFEF4444)),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],

                      // Quantity to produce
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Quantité à produire *',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDeco('Ex: 50', isDark),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Priorité',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  initialValue: priority,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  decoration: _inputDeco(null, isDark),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 0, child: Text('Basse', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(
                                        value: 1, child: Text('Normale', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(
                                        value: 2, child: Text('Haute', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(
                                        value: 3,
                                        child: Text('Urgente 🔥', style: TextStyle(fontSize: 12.5))),
                                  ],
                                  onChanged: (v) =>
                                      setDState(() => priority = v ?? 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Warehouses
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Entrepôt Matières (Sortie)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: sourceWarehouseId,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  decoration: _inputDeco(null, isDark),
                                  items: warehouses
                                      .map((w) => DropdownMenuItem<String>(
                                          value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12.5))))
                                      .toList(),
                                  onChanged: (v) {
                                    final w = warehouses
                                        .firstWhere((item) => item.id == v);
                                    setDState(() {
                                      sourceWarehouseId = v;
                                      sourceWarehouseName = w.name;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Entrepôt Produit Fini (Entrée)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: destWarehouseId,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  decoration: _inputDeco(null, isDark),
                                  items: warehouses
                                      .map((w) => DropdownMenuItem<String>(
                                          value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12.5))))
                                      .toList(),
                                  onChanged: (v) {
                                    final w = warehouses
                                        .firstWhere((item) => item.id == v);
                                    setDState(() {
                                      destWarehouseId = v;
                                      destWarehouseName = w.name;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Planned Dates
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Début planifié',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dCtx,
                                      initialDate: plannedStart,
                                      firstDate: DateTime.now()
                                          .subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDState(() => plannedStart = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 16,
                                            color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Text(dateFmt.format(plannedStart)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fin planifiée',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dCtx,
                                      initialDate: plannedEnd,
                                      firstDate: plannedStart,
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDState(() => plannedEnd = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 16,
                                            color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Text(dateFmt.format(plannedEnd)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler')),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: (selectedBom == null || isSaving)
                                ? null
                                : () async {
                                    setDState(() => isSaving = true);
                                    try {
                                      final qty = double.tryParse(
                                              qtyCtrl.text.trim()) ??
                                          1.0;
                                      final isOnline = ConnectivityService.instance.isOnline;
                                      await ProductionService.instance
                                          .createOrderFromBom(
                                        bom: selectedBom!,
                                        qtyToProduce: qty,
                                        priority: priority,
                                        plannedStart: plannedStart,
                                        plannedEnd: plannedEnd,
                                        sourceWarehouseId: sourceWarehouseId,
                                        sourceWarehouseName:
                                            sourceWarehouseName,
                                        destWarehouseId: destWarehouseId,
                                        destWarehouseName: destWarehouseName,
                                      );
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  isOnline
                                                      ? Icons.check_circle_rounded
                                                      : Icons.cloud_off_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    isOnline
                                                        ? 'Ordre de fabrication créé avec succès'
                                                        : 'OF enregistré hors ligne. Il sera synchronisé dès la reconnexion.',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: isOnline
                                                ? AppColors.success
                                                : AppColors.warning,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setDState(() => isSaving = false);
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Erreur: $e'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Créer l\'OF',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ORDER DETAIL MODAL
  // ---------------------------------------------------------------------------
  void _openOrderDetailModal(BuildContext context, ProductionOrder o) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setModalState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;
            final currentOrder = ProductionService.instance.ordersNotifier.value
                .where((item) => item.id == o.id)
                .firstOrNull ?? o;

            return Dialog(
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: DefaultTabController(
                  length: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(currentOrder.number,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: currentOrder.status.color
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: currentOrder.status.color
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        currentOrder.status.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: currentOrder.status.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${currentOrder.productName} • Qté : ${currentOrder.qtyProduced.toInt()} / ${currentOrder.qtyPlanned.toInt()} ${currentOrder.unit}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.print_rounded),
                                  tooltip: 'Imprimer la fiche suiveuse d\'OF',
                                  onPressed: () => _printOrderPdf(currentOrder),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Lifecycle Action Stepper Toolbar
                        _buildLifecycleToolbar(dCtx, currentOrder, setModalState),
                        const Divider(height: 24),

                        // Tab Bar
                        const TabBar(
                          tabs: [
                            Tab(text: 'Composants & Matières'),
                            Tab(text: 'Opérations & Pointages'),
                            Tab(text: 'Suivi des Coûts'),
                            Tab(text: 'Contrôle Qualité'),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Tab content
                        SizedBox(
                          height: 380,
                          child: TabBarView(
                            children: [
                              _buildComponentsTab(currentOrder, isDark),
                              _buildOperationsTab(currentOrder, isDark, setModalState),
                              _buildCostsTab(currentOrder, isDark),
                              _buildQualityTab(dCtx, currentOrder, setModalState),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLifecycleToolbar(
      BuildContext context, ProductionOrder o, StateSetter setModalState) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (o.status == ProductionOrderStatus.draft)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
              await ProductionService.instance.confirmOrder(o.id);
              setModalState(() {});
            },
            icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
            label: const Text('Confirmer l\'OF', style: TextStyle(color: Colors.white)),
          ),
        if (o.status == ProductionOrderStatus.confirmed)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () async {
              if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
              await ProductionService.instance.planOrder(o.id);
              setModalState(() {});
            },
            icon: const Icon(Icons.calendar_month, size: 16, color: Colors.white),
            label: const Text('Planifier l\'OF', style: TextStyle(color: Colors.white)),
          ),
        if (o.status == ProductionOrderStatus.planned ||
            o.status == ProductionOrderStatus.confirmed)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
              await ProductionService.instance.startOrder(o.id);
              setModalState(() {});
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
            label: const Text('Démarrer la fabrication',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        if (o.status == ProductionOrderStatus.inProgress) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => _openDeclareProductionDialog(context, o, setModalState),
            icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
            label: const Text('Déclarer production',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
              await ProductionService.instance.completeOrder(o.id);
              setModalState(() {});
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Marquer terminé'),
          ),
        ],
        if (o.status == ProductionOrderStatus.qualityCheck)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
              await ProductionService.instance.completeOrder(o.id);
              setModalState(() {});
            },
            icon: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
            label: const Text('Valider QC & Clôturer l\'OF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        if (o.status != ProductionOrderStatus.completed &&
            o.status != ProductionOrderStatus.cancelled)
          TextButton.icon(
            onPressed: () {
              OfflineActionHelper.executeAction(
                context: context,
                action: 'cancel',
                customActionLabel:
                    'Êtes-vous sûr de vouloir annuler cet ordre de fabrication ?',
                onConfirmed: () async {
                  await ProductionService.instance.cancelOrder(o.id);
                  setModalState(() {});
                },
              );
            },
            icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
            label: const Text('Annuler l\'OF', style: TextStyle(color: Color(0xFFEF4444))),
          ),
      ],
    );
  }

  void _openDeclareProductionDialog(
      BuildContext context, ProductionOrder o, StateSetter setModalState) {
    final remaining = (o.qtyPlanned - o.qtyProduced).clamp(0.0, o.qtyPlanned);
    final produceCtrl = TextEditingController(text: remaining.toStringAsFixed(0));
    final scrapCtrl = TextEditingController(text: '0');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Déclarer une production'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OF : ${o.number} - ${o.productName}'),
                  const SizedBox(height: 12),
                  const Text('Quantité bonne produite *', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: produceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(null),
                  ),
                  const SizedBox(height: 12),
                  const Text('Quantité rebutée / déchet', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: scrapCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(null),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!await OfflineActionHelper.checkOnlineOrShowError(dialogCtx)) return;
                          setDialogState(() => isSaving = true);
                          try {
                            final qty = double.tryParse(produceCtrl.text.trim()) ?? 0.0;
                            final scrap = double.tryParse(scrapCtrl.text.trim()) ?? 0.0;
                            await ProductionService.instance.declareProduction(
                              orderId: o.id,
                              qtyProduced: qty,
                              qtyScrapped: scrap,
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            setModalState(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Production déclarée et entrée en stock enregistrée'),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Valider l\'entrée en stock',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildComponentsTab(ProductionOrder o, bool isDark) {
    if (o.materialLines.isEmpty) {
      return const Center(child: Text('Aucun composant associé.'));
    }
    return ListView.separated(
      itemCount: o.materialLines.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final line = o.materialLines[i];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            line.isShortage ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: line.isShortage ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
          title: Text(line.productName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Requis : ${line.qtyRequired.toStringAsFixed(2)} ${line.unit}'
            ' • Consommé : ${line.qtyConsumed.toStringAsFixed(2)} ${line.unit}',
          ),
          trailing: Text(
            currencyFmt.format(line.totalPlannedCost),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildOperationsTab(
      ProductionOrder o, bool isDark, StateSetter setModalState) {
    if (o.operationLines.isEmpty) {
      return const Center(child: Text('Aucune opération configurée.'));
    }
    return ListView.separated(
      itemCount: o.operationLines.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final op = o.operationLines[i];
        final isDone = op.status == 'done';
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isDone
                ? const Color(0xFF10B981)
                : const Color(0xFF2563EB).withValues(alpha: 0.15),
            child: Text('${op.seq}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDone ? Colors.white : const Color(0xFF2563EB),
                    fontWeight: FontWeight.bold)),
          ),
          title: Text('${op.name} (${op.workcenterName})',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null)),
          subtitle: Text(
            'Prévu: ${op.plannedMinutes.toStringAsFixed(0)} min'
            ' • Réalisé: ${op.actualMinutes.toStringAsFixed(0)} min'
            ' • Coût: ${currencyFmt.format(op.plannedCost)}',
          ),
          trailing: Checkbox(
            value: isDone,
            activeColor: const Color(0xFF10B981),
            onChanged: (v) async {
              if (v != null) {
                if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
                await ProductionService.instance.updateOperation(
                  orderId: o.id,
                  seq: op.seq,
                  status: v ? 'done' : 'pending',
                  actualMinutes: v ? op.plannedMinutes : 0.0,
                );
                setModalState(() {});
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCostsTab(ProductionOrder o, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCostBox('Coût Prévu', currencyFmt.format(o.plannedTotalCost),
                  const Color(0xFF2563EB)),
              _buildCostBox('Coût Réel', currencyFmt.format(o.actualTotalCost),
                  const Color(0xFF8B5CF6)),
              _buildCostBox(
                'Écart',
                currencyFmt.format(o.costVariance),
                o.costVariance > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
              _buildCostBox('Coût Unitaire Réel',
                  currencyFmt.format(o.actualUnitCost), const Color(0xFF0F172A)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          dense: true,
          title: const Text('Coût matières premières consommées'),
          trailing: Text(currencyFmt.format(o.actualMaterialCost),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          dense: true,
          title: const Text('Coût main d\'œuvre et machines'),
          trailing: Text(currencyFmt.format(o.actualOperationCost),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCostBox(String title, String val, Color color) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Text(val,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildQualityTab(BuildContext context, ProductionOrder o, StateSetter setModalState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            o.qcStatus == 'passed'
                ? Icons.verified_rounded
                : Icons.pending_actions_rounded,
            size: 48,
            color: o.qcStatus == 'passed'
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          Text(
            'Statut Qualité : ${o.qcStatus.toUpperCase()}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            onPressed: () {
              Navigator.pop(context);
              // Navigate to Quality screen
            },
            icon: const Icon(Icons.checklist_rounded, size: 16, color: Colors.white),
            label: const Text('Ouvrir les contrôles qualité',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRINT PDF OF SHEET
  // ---------------------------------------------------------------------------
  Future<void> _printOrderPdf(ProductionOrder o) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FICHE SUIVEUSE DE FABRICATION',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(o.number,
                        style: pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.blue,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Article : ${o.productName}'),
              pw.Text('Quantité à produire : ${o.qtyPlanned} ${o.unit}'),
              pw.Text(
                  'Date début : ${o.plannedStart != null ? dateFmt.format(o.plannedStart!) : "-"}'),
              pw.Text(
                  'Date fin cible : ${o.plannedEnd != null ? dateFmt.format(o.plannedEnd!) : "-"}'),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('NOMENCLATURE / MATIÈRES PREMIÈRES :',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Composant', 'Qté Requise', 'Unité'],
                data: o.materialLines
                    .map((l) => [
                          l.productName,
                          l.qtyRequired.toStringAsFixed(2),
                          l.unit
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Text('GAMME OPÉRATOIRE / ATELIERS :',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Séquence', 'Opération', 'Poste / Machine', 'Temps Prévu'],
                data: o.operationLines
                    .map((op) => [
                          '${op.seq}',
                          op.name,
                          op.workcenterName,
                          '${op.plannedMinutes.toStringAsFixed(0)} min'
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  InputDecoration _inputDeco(String? hint, [bool isDark = false]) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
