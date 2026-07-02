import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/supplier_order.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';

class CreateReceivingVoucherScreen extends StatefulWidget {
  final ReceivingVoucher? existing;
  final bool isReadOnly;
  final String? overrideTitle;
  const CreateReceivingVoucherScreen({super.key, this.existing, this.isReadOnly = false, this.overrideTitle});

  @override
  State<CreateReceivingVoucherScreen> createState() =>
      _CreateReceivingVoucherScreenState();
}

class _CreateReceivingVoucherScreenState extends State<CreateReceivingVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedSupplierId;
  String? _selectedProjectId;
  List<ReceivingVoucherItem> _items = [];
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  ReceivingVoucherStatus _status = ReceivingVoucherStatus.draft;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      map[rate] = (map[rate] ?? 0) + item.tvaAmount;
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + i.tvaAmount);

  double get _globalDiscountAmount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return 0;
    return _totalHT * _globalDiscountPercent / 100;
  }

  double get _totalHTAfterDiscount => _totalHT - _globalDiscountAmount;
  double get _totalTvaAfterDiscount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return _totalTva;
    return _items.fold(0, (s, i) {
      final itemHT = i.totalHT;
      final discountedHT = itemHT - (itemHT * _globalDiscountPercent / 100);
      return s + discountedHT * (i.tvaRate / 100);
    });
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.000 : 0;
  double get _totalTTC =>
      _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedSupplierId = n.supplierId;
      _selectedProjectId = n.projectId;
      _pricingModeHT = n.pricingMode == 'ht';
      _withGlobalDiscount = n.globalDiscountPercent > 0;
      _globalDiscountPercent = n.globalDiscountPercent;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _status = ReceivingVoucherStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => ReceivingVoucherStatus.draft,
      );
      _notesCtrl.text = n.notes ?? '';
      _conditionsCtrl.text = n.conditionsGenerales ?? '';
      _items = n.items.map((i) => ReceivingVoucherItem(
        id: i.id,
        orderId: i.orderId,
        productId: i.productId,
        description: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        showDescription: i.showDescription,
        showDiscount: i.showDiscount,
      )).toList();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez selectionner un fournisseur'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<ReceivingVouchersBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextReceivingVoucherSequence();
      number = generateDocNumber(DocPrefix.supplierOrder, seq);
    }

    final orderId = widget.existing?.id ?? _uuid.v4();
    final order = ReceivingVoucher(
      id: orderId,
      number: number,
      supplierId: _selectedSupplierId!,
      projectId: _selectedProjectId,
      date: _date,
      status: _status.name,
      pricingMode: _pricingModeHT ? 'ht' : 'ttc',
      globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
      globalDiscountAmount: _globalDiscountAmount,
      timbreFiscal: _timbreFiscal,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      conditionsGenerales:
          _conditionsCtrl.text.isNotEmpty ? _conditionsCtrl.text : null,
      items: _items.map((item) => ReceivingVoucherItem(
        id: item.id,
        orderId: orderId,
        productId: item.productId,
        description: item.description,
        quantity: item.quantityReceived,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
        showDescription: item.showDescription,
        showDiscount: item.showDiscount,
      )).toList(),
    );

    if (_isEditing) {
      bloc.add(UpdateReceivingVoucher(order));
    } else {
      bloc.add(AddReceivingVoucher(order));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Commande ${order.number} mise a jour'
          : 'Commande ${order.number} creee avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildArticlesSection(),
                      if (!widget.isReadOnly) ...[
                        const SizedBox(height: AppSpacing.md),
                        _buildArticleActions(),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _buildGlobalDiscountSection(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildTotalsSection(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildNotesSection(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            widget.overrideTitle ?? (widget.isReadOnly 
                ? 'Détails de la bon de réception' 
                : (_isEditing ? 'Modifier la bon de réception' : 'Ajouter une bon de réception')),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          _buildHeaderButton(
              Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          if (!widget.isReadOnly) ...[
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
              setState(() => _status = ReceivingVoucherStatus.draft);
            }),
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.send_rounded, 'Envoyer', () {
              setState(() => _status = ReceivingVoucherStatus.sent);
            }, color: AppColors.info),
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.check_circle_rounded, 'Valider', () {
              setState(() => _status = ReceivingVoucherStatus.validated);
            }, color: AppColors.success),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
      label: Text(label,
          style: TextStyle(color: color ?? AppColors.textSecondary)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  // ── Form Details ────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fournisseur
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fournisseur *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    BlocBuilder<SuppliersBloc, SuppliersState>(
                      builder: (context, state) {
                        List<Supplier> suppliers = [];
                        if (state is SuppliersLoaded) {
                          suppliers = state.suppliers;
                        }
                        return DropdownButtonFormField<String>(
                          value: _selectedSupplierId,
                          decoration: const InputDecoration(
                              hintText: 'Selectionner un fournisseur...'),
                          items: suppliers
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedSupplierId = val);
                          },
                          validator: (v) => v == null
                              ? 'Veuillez selectionner un fournisseur'
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              // Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: AppColors.surfaceAlt,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formatDateLong(_date),
                                style: const TextStyle(
                                    color: AppColors.textPrimary)),
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Projet (Optionnel)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        List<Project> projects = [];
                        if (state is ProjectsLoaded) {
                          projects = state.projects;
                        }
                        return DropdownButtonFormField<String>(
                          value: _selectedProjectId,
                          decoration: const InputDecoration(
                              hintText: 'Selectionner un projet...'),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('Aucun projet')),
                            ...projects.map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.name))),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedProjectId = val);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              // Options
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Options',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              color: AppColors.surfaceAlt,
                            ),
                            child: CheckboxListTile(
                              title: const Text('Timbre fiscal',
                                  style: TextStyle(fontSize: 13)),
                              value: _withTimbreFiscal,
                              onChanged: (v) => setState(
                                  () => _withTimbreFiscal = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              color: AppColors.surfaceAlt,
                            ),
                            child: CheckboxListTile(
                              title: const Text('Remise globale',
                                  style: TextStyle(fontSize: 13)),
                              value: _withGlobalDiscount,
                              onChanged: (v) => setState(
                                  () => _withGlobalDiscount = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Articles ────────────────────────────────────────────────────────
  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
              color: AppColors.background,
            ),
            child: const Row(
              children: [
                SizedBox(width: 32),
                Expanded(
                    flex: 3,
                    child: Text('Article',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Quantite',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Prix U. HT',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('TVA %',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Remise %',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Total HT',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                SizedBox(width: 80), // Actions
              ],
            ),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Aucun article ajoute. Cliquez sur "Ajouter un article".',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildArticleRow(item, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArticleRow(ReceivingVoucherItem item, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          const SizedBox(
            width: 32,
            height: 40,
            child: Icon(Icons.drag_indicator,
                color: AppColors.textTertiary, size: 20),
          ),
          // Product selection
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: BlocBuilder<ProductsBloc, ProductsState>(
                    builder: (context, state) {
                      List<Product> products = [];
                      if (state is ProductsLoaded) {
                        products = state.products;
                      }
                      return DropdownButtonFormField<String>(
                        value: item.productId.isEmpty ? null : item.productId,
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          hintText: 'Selectionner un article...',
                        ),
                        items: products
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final p = products.firstWhere((e) => e.id == val);
                            setState(() {
                              _items[index] = item.copyWith(
                                productId: val,
                                unitPrice: p.purchasePrice, // Using purchase price for supplier order
                                tvaRate: p.tvaRate,
                              );
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                if (item.showDescription) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: item.description,
                    decoration: const InputDecoration(
                      hintText: 'Description additionnelle...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 2,
                    onChanged: (val) {
                      _items[index] = item.copyWith(description: val);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Quantity
          Expanded(
            child: TextFormField(
              initialValue: item.quantityReceived.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(quantityReceived: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          // Unit Price
          Expanded(
            child: TextFormField(
              initialValue: item.unitPrice.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(unitPrice: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          // TVA Rate
          Expanded(
            child: DropdownButtonFormField<double>(
              value: item.tvaRate,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              items: TvaRates.all
                  .map((t) => DropdownMenuItem(value: t, child: Text('$t%')))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _items[index] = item.copyWith(tvaRate: val));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Discount
          Expanded(
            child: TextFormField(
              initialValue: item.discountPercent.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(discountPercent: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          // Total HT
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(formatCurrencyDT(item.totalHT),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          if (!widget.isReadOnly)
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      item.showDescription ? Icons.description : Icons.description_outlined,
                      color: item.showDescription ? AppColors.primary : AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _items[index] = item.copyWith(showDescription: !item.showDescription);
                      });
                    },
                    tooltip: 'Description',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleActions() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _items.add(ReceivingVoucherItem(
                  orderId: widget.existing?.id ?? '', productId: ''));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ajouter un article'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            elevation: 0,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ── Totals & Global Discount ────────────────────────────────────────
  Widget _buildGlobalDiscountSection() {
    if (!_withGlobalDiscount) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.percent_rounded, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          const Text('Remise globale sur la commande :',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: _globalDiscountPercent.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: '%',
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _globalDiscountPercent = double.tryParse(val) ?? 0;
                });
              },
            ),
          ),
          const Spacer(),
          Text(
            '- ${formatCurrencyDT(_globalDiscountAmount)}',
            style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTotalRow('Total HT', _totalHT),
          if (_withGlobalDiscount) ...[
            const SizedBox(height: 8),
            _buildTotalRow('Remise globale', -_globalDiscountAmount,
                color: AppColors.error),
            const SizedBox(height: 8),
            _buildTotalRow('Total HT (Apres remise)', _totalHTAfterDiscount,
                isBold: true),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border),
          ),
          ..._tvaBreakdown.entries.map((e) {
            // Apply proportionate discount to TVA if global discount is enabled
            double tvaAmount = e.value;
            if (_withGlobalDiscount && _totalHT > 0) {
              tvaAmount = tvaAmount * (1 - (_globalDiscountPercent / 100));
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTotalRow('TVA ${e.key}%', tvaAmount),
            );
          }),
          if (_withTimbreFiscal) ...[
            const SizedBox(height: 8),
            _buildTotalRow('Timbre fiscal', _timbreFiscal),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border),
          ),
          _buildTotalRow('NET A PAYER', _totalTTC,
              isBold: true, fontSize: 20, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool isBold = false, double fontSize = 14, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 200,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 150,
          child: Text(
            formatCurrencyDT(amount),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Notes ───────────────────────────────────────────────────────────
  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes (Visibles par le fournisseur)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ajouter une note...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Conditions d\'achat',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ajouter des conditions...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
