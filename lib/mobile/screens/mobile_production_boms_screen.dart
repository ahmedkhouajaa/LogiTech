import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../models/production_bom.dart';
import '../../models/product.dart';
import '../../blocs/products/products_bloc.dart';
import '../../services/production_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';

class MobileProductionBomsScreen extends StatefulWidget {
  const MobileProductionBomsScreen({super.key});

  @override
  State<MobileProductionBomsScreen> createState() =>
      _MobileProductionBomsScreenState();
}

class _MobileProductionBomsScreenState
    extends State<MobileProductionBomsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ProductionService.instance.bomsNotifier,
      builder: (context, _) {
        final boms = ProductionService.instance.bomsNotifier.value;
        final filtered = boms.where((b) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return b.productName.toLowerCase().contains(q) ||
                b.version.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF2563EB),
            onPressed: () => _openBomEditor(context, null),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: Column(
            children: [
              // Search Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une nomenclature...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
              ),

              // Summary bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} nomenclatures configurées',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // BOM List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_tree_outlined,
                                size: 52,
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune nomenclature trouvée',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bom = filtered[index];
                          return _buildBomCard(context, bom, isDark);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBomCard(
      BuildContext context, ProductionBom bom, bool isDark) {
    return InkWell(
      onTap: () => _showBomDetailsModal(context, bom),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bom.productName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bom.isDefault
                        ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                        : const Color(0xFF64748B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bom.version,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: bom.isDefault
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${bom.components.length} composants',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.precision_manufacturing_outlined,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${bom.operations.length} opérations',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coût standard unitaire',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFmt.format(bom.standardUnitCost),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF2563EB)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openBomEditor(context, bom),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _duplicateBom(bom),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBomDetailsModal(BuildContext context, ProductionBom bom) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bom.productName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Version: ${bom.version} ${bom.isDefault ? "(Par défaut)" : ""}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFmt.format(bom.standardUnitCost),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Composants & Matières premières (${bom.components.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...bom.components.map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.quantity} ${c.unit}  •  Rebut: ${c.scrapPercent.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFmt.format(c.totalCost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                      Text(
                        'Opérations & Postes de charge (${bom.operations.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...bom.operations.map((op) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        op.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Poste: ${op.workcenterName}  •  Setup: ${op.setupMinutes.toStringAsFixed(0)} min  •  Cadence: ${op.runMinutesPerUnit.toStringAsFixed(1)} min/u',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFmt.format(op.costForQty(1)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _duplicateBom(ProductionBom bom) async {
    if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
    final copy = bom.copyWith(
      id: const Uuid().v4(),
      version: '${bom.version}-Copie',
      isDefault: false,
    );
    await ProductionService.instance.saveBom(copy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nomenclature dupliquée : ${copy.version}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _openBomEditor(BuildContext context, ProductionBom? initial) {
    showDialog(
      context: context,
      builder: (_) => _MobileBomEditorDialog(initial: initial),
    );
  }
}

class _MobileBomEditorDialog extends StatefulWidget {
  final ProductionBom? initial;
  const _MobileBomEditorDialog({this.initial});

  @override
  State<_MobileBomEditorDialog> createState() => _MobileBomEditorDialogState();
}

class _MobileBomEditorDialogState extends State<_MobileBomEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _id;
  String? _productId;
  String _productName = '';
  late String _version;
  late double _quantityProduced;
  late bool _isDefault;
  late List<BomComponent> _components;
  late List<BomOperation> _operations;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _id = init?.id ?? const Uuid().v4();
    _productId = init?.productId;
    _productName = init?.productName ?? '';
    _version = init?.version ?? 'v1.0';
    _quantityProduced = init?.quantityProduced ?? 1.0;
    _isDefault = init?.isDefault ?? true;
    _components = init != null ? List.from(init.components) : [];
    _operations = init != null ? List.from(init.operations) : [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsState = context.watch<ProductsBloc>().state;
    final List<Product> products =
        productsState is ProductsLoaded ? productsState.products : [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initial == null
                        ? 'Nouvelle Nomenclature'
                        : 'Modifier Nomenclature',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    // Product Selection
                    DropdownButtonFormField<String>(
                      initialValue: _productId,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _dropdownDeco('Article à fabriquer *', isDark),
                      items: products
                          .map((p) => DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _productId = v;
                          final match =
                              products.where((p) => p.id == v).firstOrNull;
                          _productName = match?.name ?? '';
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Veuillez sélectionner un article' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _version,
                            decoration: const InputDecoration(
                              labelText: 'Version *',
                              isDense: true,
                            ),
                            onSaved: (v) => _version = v ?? 'v1.0',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Par défaut',
                                style: TextStyle(fontSize: 12)),
                            value: _isDefault,
                            onChanged: (v) => setState(() => _isDefault = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Composants (${_components.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextButton.icon(
                          onPressed: () => _addComponentDialog(products),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter'),
                        ),
                      ],
                    ),
                    ..._components.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.productName,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            'Qté: ${c.quantity} ${c.unit} | Coût: ${c.unitCost.toStringAsFixed(2)} TND'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () =>
                              setState(() => _components.removeAt(i)),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Opérations (${_operations.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextButton.icon(
                          onPressed: _addOperationDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter'),
                        ),
                      ],
                    ),
                    ..._operations.asMap().entries.map((entry) {
                      final i = entry.key;
                      final op = entry.value;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text(op.name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            'Poste: ${op.workcenterName} | Cadence: ${op.runMinutesPerUnit} min'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () =>
                              setState(() => _operations.removeAt(i)),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Enregistrer',
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addComponentDialog(List<Product> products) {
    String? prodId;
    String prodName = '';
    double qty = 1.0;
    String unit = 'U';
    double cost = 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('Ajouter un composant',
                style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  decoration: _dropdownDeco('Matière / Article', isDark),
                  items: products
                      .map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setDState(() {
                      prodId = v;
                      final m = products.where((p) => p.id == v).firstOrNull;
                      prodName = m?.name ?? '';
                      unit = m?.unit ?? 'U';
                      cost = (m != null && m.purchasePrice > 0)
                          ? m.purchasePrice
                          : (m?.sellingPrice ?? 0.0);
                    });
                  },
                ),
              TextField(
                decoration: const InputDecoration(labelText: 'Quantité'),
                keyboardType: TextInputType.number,
                onChanged: (v) => qty = double.tryParse(v) ?? 1.0,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Coût unitaire (TND)'),
                keyboardType: TextInputType.number,
                controller:
                    TextEditingController(text: cost.toStringAsFixed(2)),
                onChanged: (v) => cost = double.tryParse(v) ?? 0.0,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (prodId != null) {
                  setState(() {
                    _components.add(BomComponent(
                      productId: prodId!,
                      productName: prodName,
                      quantity: qty,
                      unit: unit,
                      unitCost: cost,
                    ));
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    ),
  );
}

  void _addOperationDialog() {
    final workcenters = ProductionService.instance.workcentersNotifier.value;
    String opName = '';
    String? wcId;
    String wcName = '';
    double setupMin = 0.0;
    double runMin = 5.0;
    double hourlyRate = 25.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('Ajouter une opération',
                style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Nom de l\'opération'),
                  onChanged: (v) => opName = v,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  decoration: _dropdownDeco('Poste de charge', isDark),
                  items: workcenters
                      .map((w) => DropdownMenuItem<String>(
                            value: w.id,
                            child: Text(w.name, style: const TextStyle(fontSize: 12.5)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setDState(() {
                      wcId = v;
                      final match =
                          workcenters.where((w) => w.id == v).firstOrNull;
                      wcName = match?.name ?? '';
                      hourlyRate = match?.hourlyCost ?? 25.0;
                    });
                  },
                ),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Temps unitaire (minutes/u)'),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: '5.0'),
                onChanged: (v) => runMin = double.tryParse(v) ?? 5.0,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (opName.isNotEmpty && wcId != null) {
                  setState(() {
                    _operations.add(BomOperation(
                      seq: (_operations.length + 1) * 10,
                      name: opName,
                      workcenterId: wcId!,
                      workcenterName: wcName,
                      setupMinutes: setupMin,
                      runMinutesPerUnit: runMin,
                      hourlyCost: hourlyRate,
                    ));
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    ),
  );
}

  void _save() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() ?? false) {
      if (widget.initial != null) {
        if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
      }
      setState(() => _isSaving = true);
      try {
        _formKey.currentState?.save();
        final isOnline = ConnectivityService.instance.isOnline;
        final bom = ProductionBom(
          id: _id,
          productId: _productId!,
          productName: _productName,
          version: _version,
          quantityProduced: _quantityProduced,
          isDefault: _isDefault,
          components: _components,
          operations: _operations,
        );
        await ProductionService.instance.saveBom(bom);
        if (mounted) {
          Navigator.of(context).pop();
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
                          ? 'Nomenclature enregistrée avec succès'
                          : 'Nomenclature enregistrée hors ligne. Elle sera synchronisée dès la reconnexion.',
                    ),
                  ),
                ],
              ),
              backgroundColor:
                  isOnline ? AppColors.success : AppColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  InputDecoration _dropdownDeco(String? label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
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
