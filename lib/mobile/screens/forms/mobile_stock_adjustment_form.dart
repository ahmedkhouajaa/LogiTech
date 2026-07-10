import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../blocs/stock/stock_bloc.dart';
import '../../../blocs/products/products_bloc.dart';
import '../../../models/stock_movement.dart';
import '../../../models/product.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileStockAdjustmentForm extends StatefulWidget {
  const MobileStockAdjustmentForm({super.key});

  @override
  State<MobileStockAdjustmentForm> createState() => _MobileStockAdjustmentFormState();
}

class _MobileStockAdjustmentFormState extends State<MobileStockAdjustmentForm> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  Product? _selectedProduct;
  String? _selectedWarehouseId;
  String _adjustmentAction = 'add'; // add, exit, correct
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un article'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un entrepôt'), backgroundColor: AppColors.error),
      );
      return;
    }
    final qtyText = _quantityCtrl.text.trim();
    if (qtyText.isEmpty || double.tryParse(qtyText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une quantité valide'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stockState = context.read<StockBloc>().state;
      if (stockState is! StockLoaded) return;

      final qtyInput = double.parse(qtyText);
      double qtyToRegister = 0;
      MovementType type = MovementType.adjustment;

      if (_adjustmentAction == 'correct') {
        final diff = qtyInput - _selectedProduct!.stockQty;
        qtyToRegister = diff;
        type = MovementType.adjustment;
      } else if (_adjustmentAction == 'add') {
        qtyToRegister = qtyInput;
        type = MovementType.adjustment;
      } else {
        qtyToRegister = -qtyInput;
        type = MovementType.adjustment;
      }

      if (qtyToRegister == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La quantité d\'ajustement ne peut pas être nulle.'), backgroundColor: AppColors.warning),
        );
        setState(() => _isLoading = false);
        return;
      }

      final warehouse = stockState.warehouses.firstWhere((w) => w.id == _selectedWarehouseId);

      final movement = StockMovement(
        id: _uuid.v4(),
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        warehouseId: _selectedWarehouseId!,
        warehouseName: warehouse.name,
        type: type,
        quantity: qtyToRegister,
        referenceType: 'Ajustement',
        date: DateTime.now(),
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'Ajustement manuel',
      );

      context.read<StockBloc>().add(AddStockMovement(movement));
      context.read<ProductsBloc>().add(LoadProducts());

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajustement de stock enregistré avec succès'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: 'Nouvel ajustement de stock',
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      children: [
        // ── Section 1: Article ──
        MobileFormSection(
          title: 'Article',
          icon: Icons.inventory_2_outlined,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocBuilder<ProductsBloc, ProductsState>(
                  builder: (context, pState) {
                    if (pState is! ProductsLoaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Autocomplete<Product>(
                      displayStringForOption: (p) => p.name,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                        return pState.products.where((p) =>
                            p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            p.code.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (p) {
                        setState(() {
                          _selectedProduct = p;
                          if (_adjustmentAction == 'correct') {
                            _quantityCtrl.text = p.stockQty.toString();
                          }
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un article par nom ou code...',
                            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 200,
                                maxWidth: MediaQuery.of(context).size.width - 64,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, i) {
                                  final option = options.elementAt(i);
                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                                    ),
                                    title: Text(option.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    subtitle: Text(
                                      'Code: ${option.code} • Stock: ${formatQuantity(option.stockQty)} ${option.unit}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    onTap: () => onSelected(option),
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                if (_selectedProduct != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primary.withValues(alpha: 0.03)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProduct!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stock actuel: ${formatQuantity(_selectedProduct!.stockQty)} ${_selectedProduct!.unit}',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Section 2: Entrepôt & Action ──
        MobileFormSection(
          title: 'Entrepôt & Action',
          icon: Icons.warehouse_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                if (stockState is! StockLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Auto-select default warehouse
                if (_selectedWarehouseId == null && stockState.warehouses.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedWarehouseId == null) {
                      setState(() => _selectedWarehouseId = stockState.warehouses.first.id);
                    }
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartDropdown<String>(
                      label: 'Entrepôt',
                      value: _selectedWarehouseId,
                      items: stockState.warehouses.map((w) =>
                        DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 16))),
                      ).toList(),
                      onChanged: (v) => setState(() => _selectedWarehouseId = v),
                      hint: 'Sélectionner un entrepôt',
                    ),
                    const SizedBox(height: 20),
                    const Text("Type d'action", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    _buildActionSelector(),
                    const SizedBox(height: 20),
                    Text(
                      _adjustmentAction == 'correct' ? 'Nouveau stock réel' : 'Quantité',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _quantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        suffixText: _selectedProduct?.unit ?? '',
                        suffixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Section 3: Notes ──
        MobileFormSection(
          title: 'Notes / Motif',
          icon: Icons.notes_rounded,
          isInitiallyExpanded: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SmartTextInput(
              label: 'Notes internes, motif d\'ajustement...',
              controller: _notesCtrl,
              hint: 'Ex: Inventaire du mois, produit cassé...',
              maxLines: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _buildActionChip('add', 'Ajouter', Icons.add_rounded, AppColors.success),
          const SizedBox(width: 4),
          _buildActionChip('exit', 'Retirer', Icons.remove_rounded, AppColors.error),
          const SizedBox(width: 4),
          _buildActionChip('correct', 'Corriger', Icons.edit_rounded, AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildActionChip(String action, String label, IconData icon, Color color) {
    final isSelected = _adjustmentAction == action;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _adjustmentAction = action;
            if (action == 'correct' && _selectedProduct != null) {
              _quantityCtrl.text = _selectedProduct!.stockQty.toString();
            } else {
              _quantityCtrl.clear();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
