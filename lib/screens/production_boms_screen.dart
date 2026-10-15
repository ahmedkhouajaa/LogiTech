import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../models/production_bom.dart';
import '../models/production_workcenter.dart';
import '../models/product.dart';
import '../blocs/products/products_bloc.dart';
import '../services/production_service.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../l10n/app_localizations.dart';

class ProductionBomsScreen extends StatefulWidget {
  const ProductionBomsScreen({super.key});

  @override
  State<ProductionBomsScreen> createState() => _ProductionBomsScreenState();
}

class _ProductionBomsScreenState extends State<ProductionBomsScreen> {
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
                          context.tr('Nomenclatures de Fabrication (BOM)'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filtered.length} nomenclatures configurées',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openBomEditor(context, null),
                      icon: const Icon(Icons.add_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Nouvelle Nomenclature',
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

                // Search box (Styled to match Image 2)
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par article fini ou version...',
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
                ),
                const SizedBox(height: 18),

                // BOM List / Grid
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune nomenclature trouvée.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final b = filtered[i];
                            return _buildBomCard(b, isDark);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBomCard(ProductionBom b, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_tree_rounded,
                        color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(b.productName,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(b.version,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (b.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Par défaut',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lot référence : ${b.quantityProduced.toInt()} ${b.unit}'
                        ' • ${b.components.length} matières • ${b.operations.length} opérations',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Coût standard unitaire',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                      Text(currencyFmt.format(b.standardUnitCost),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        _openBomEditor(context, b);
                      } else if (action == 'duplicate') {
                        if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
                        await ProductionService.instance
                            .duplicateBom(b, '${b.version}.1');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Nomenclature dupliquée avec succès'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } else if (action == 'delete') {
                        OfflineActionHelper.executeAction(
                          context: context,
                          action: 'delete',
                          customActionLabel:
                              'Êtes-vous sûr de vouloir supprimer cette nomenclature ?',
                          onConfirmed: () async {
                            await ProductionService.instance.deleteBom(b.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Nomenclature supprimée avec succès'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Modifier la BOM')),
                      const PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Dupliquer / Nouvelle version')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer',
                              style: TextStyle(color: Color(0xFFEF4444)))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOM EDITOR DIALOG
  // ---------------------------------------------------------------------------
  void _openBomEditor(BuildContext context, ProductionBom? initialBom) {
    final productsState = context.read<ProductsBloc>().state;
    final List<Product> products =
        productsState is ProductsLoaded ? productsState.products : [];
    final workcenters = ProductionService.instance.workcentersNotifier.value;

    Product? selectedProduct = initialBom != null
        ? products
            .where((p) => p.id == initialBom.productId)
            .firstOrNull
        : null;
    final versionCtrl =
        TextEditingController(text: initialBom?.version ?? 'v1.0');
    final batchQtyCtrl = TextEditingController(
        text: initialBom?.quantityProduced.toString() ?? '1');
    final scrapCtrl =
        TextEditingController(text: initialBom?.scrapRate.toString() ?? '0');
    bool isDefault = initialBom?.isDefault ?? true;

    List<BomComponent> components = initialBom != null
        ? List.from(initialBom.components)
        : [];
    List<BomOperation> operations = initialBom != null
        ? List.from(initialBom.operations)
        : [];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;

            // Compute standard unit cost preview
            final totalMat =
                components.fold(0.0, (acc, c) => acc + c.totalCost);
            final batchQty = double.tryParse(batchQtyCtrl.text.trim()) ?? 1.0;
            final totalOps = operations.fold(
                0.0, (acc, op) => acc + op.costForQty(batchQty));
            final scrap = double.tryParse(scrapCtrl.text.trim()) ?? 0.0;
            final unitCost = batchQty > 0
                ? ((totalMat + totalOps) * (1 + (scrap / 100))) / batchQty
                : 0.0;

            return Dialog(
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
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
                          Text(
                            initialBom == null
                                ? 'Nouvelle Nomenclature (BOM)'
                                : 'Modifier la Nomenclature',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // General Info: Product, Version, Batch, Scrap
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<Product>(
                              initialValue: selectedProduct,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              decoration: _inputDeco('Article à fabriquer *', isDark),
                              items: products.map((p) {
                                return DropdownMenuItem(
                                    value: p,
                                    child: Text('${p.code} - ${p.name}', style: const TextStyle(fontSize: 12.5)));
                              }).toList(),
                              onChanged: (p) =>
                                  setDState(() => selectedProduct = p),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: versionCtrl,
                              decoration: _inputDeco('Version (ex: v1.0)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: batchQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('Qté de référence'),
                              onChanged: (_) => setDState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: isDefault,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (v) =>
                                setDState(() => isDefault = v ?? true),
                          ),
                          const Text('Définir comme nomenclature par défaut',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 24),

                      // Section 1: Components (Matières)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1. Composants & Matières premières (${components.length})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _addComponentDialog(
                                  dCtx, products, (c) => setDState(() => components.add(c)));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ajouter un composant'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (components.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucun composant. Ajoutez les matières requises pour cette recette.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        )
                      else
                        ...components.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final c = entry.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.circle,
                                size: 8, color: Color(0xFF2563EB)),
                            title: Text(c.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${c.quantity} ${c.unit} × ${currencyFmt.format(c.unitCost)} / u'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currencyFmt.format(c.totalCost),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Color(0xFFEF4444)),
                                  onPressed: () => setDState(
                                      () => components.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                      const Divider(height: 24),

                      // Section 2: Operations (Gamme de fabrication)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '2. Gamme Opératoire & Postes (${operations.length})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _addOperationDialog(dCtx, workcenters,
                                  (op) => setDState(() => operations.add(op)));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ajouter une opération'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (operations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucune opération. Ajoutez les étapes opératoires (découpe, soudure, assemblage...).',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        )
                      else
                        ...operations.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final op = entry.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.15),
                              child: Text('${op.seq}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(
                                '${op.name} (${op.workcenterName})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                'Réglage: ${op.setupMinutes}m • Exécution: ${op.runMinutesPerUnit}m/u • Taux: ${currencyFmt.format(op.hourlyCost)}/h'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Color(0xFFEF4444)),
                              onPressed: () => setDState(
                                  () => operations.removeAt(idx)),
                            ),
                          );
                        }),
                      const Divider(height: 24),

                      // Cost Summary Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Coût de revient standard calculé :',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A))),
                            Text(
                              '${currencyFmt.format(unitCost)} / unité',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

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
                            onPressed: (selectedProduct == null || isSaving)
                                ? null
                                : () async {
                                    if (initialBom != null) {
                                      if (!await OfflineActionHelper.checkOnlineOrShowError(dCtx)) return;
                                    }
                                    setDState(() => isSaving = true);
                                    try {
                                      final isOnline = ConnectivityService.instance.isOnline;
                                      final bom = ProductionBom(
                                        id: initialBom?.id ?? const Uuid().v4(),
                                        productId: selectedProduct!.id,
                                        productName: selectedProduct!.name,
                                        version: versionCtrl.text.trim().isEmpty
                                            ? 'v1.0'
                                            : versionCtrl.text.trim(),
                                        quantityProduced: batchQty,
                                        components: components,
                                        operations: operations,
                                        isDefault: isDefault,
                                      );
                                      await ProductionService.instance
                                          .saveBom(bom);
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
                                                        ? 'Nomenclature enregistrée avec succès'
                                                        : 'Nomenclature enregistrée hors ligne. Elle sera synchronisée dès la reconnexion.',
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
                                : const Text('Enregistrer la Nomenclature',
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

  void _addComponentDialog(BuildContext context, List<Product> products,
      Function(BomComponent) onAdd) {
    Product? selected;
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Ajouter un composant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                decoration: _inputDeco('Article composant', isDark),
                items: products
                    .map((p) => DropdownMenuItem(
                        value: p, child: Text('${p.code} - ${p.name}', style: const TextStyle(fontSize: 12.5))))
                    .toList(),
                onChanged: (p) => selected = p,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('Quantité requise par lot', isDark),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () {
                if (selected != null) {
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                  onAdd(BomComponent(
                    productId: selected!.id,
                    productName: selected!.name,
                    quantity: qty,
                    unit: selected!.unit,
                    unitCost: selected!.purchasePrice > 0
                        ? selected!.purchasePrice
                        : selected!.sellingPrice,
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _addOperationDialog(BuildContext context,
      List<ProductionWorkcenter> workcenters, Function(BomOperation) onAdd) {
    ProductionWorkcenter? selectedWc =
        workcenters.isNotEmpty ? workcenters.first : null;
    final nameCtrl = TextEditingController(text: 'Opération');
    final setupCtrl = TextEditingController(text: '15');
    final runCtrl = TextEditingController(text: '5');
    int seq = 10;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Ajouter une opération'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: _inputDeco('Intitulé de l\'opération', isDark),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductionWorkcenter>(
                initialValue: selectedWc,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                decoration: _inputDeco('Poste de travail', isDark),
                items: workcenters
                    .map((w) => DropdownMenuItem(
                        value: w, child: Text('${w.name} (${currencyFmt.format(w.hourlyCost)}/h)', style: const TextStyle(fontSize: 12.5))))
                    .toList(),
                onChanged: (w) => selectedWc = w,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: setupCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('Réglage (min)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: runCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('Exécution (min/u)'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              if (selectedWc != null) {
                final setup = double.tryParse(setupCtrl.text.trim()) ?? 0.0;
                final run = double.tryParse(runCtrl.text.trim()) ?? 0.0;
                onAdd(BomOperation(
                  seq: seq,
                  name: nameCtrl.text.trim(),
                  workcenterId: selectedWc!.id,
                  workcenterName: selectedWc!.name,
                  setupMinutes: setup,
                  runMinutesPerUnit: run,
                  hourlyCost: selectedWc!.hourlyCost,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
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
