import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/product_settings/product_settings_bloc.dart';
import '../blocs/product_settings/product_settings_state.dart';
import '../blocs/product_settings/product_settings_event.dart';
import '../models/product.dart';
import '../models/product_family.dart';
import '../models/product_category.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import 'package:business_manager_pro/services/error_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/trial_service.dart';

class CreateArticleScreen extends StatefulWidget {
  final Product? existing;
  const CreateArticleScreen({super.key, this.existing});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  
  // Controllers
  late final TextEditingController _nameCtrl, _refCtrl, _descCtrl;
  late final TextEditingController _purchCtrl, _sellCtrl, _discountCtrl;
  late final TextEditingController _barcodeCtrl, _privateNotesCtrl;
  
  // State variables
  String _destination = 'Vente et Achat';
  String _productType = 'produit';
  double _tvaRate = 19;
  static const List<double> _defaultTvaRates = [0.0, 7.0, 13.0, 19.0];
  final List<double> _tvaRates = [0.0, 7.0, 13.0, 19.0];
  String _unit = 'Piece';
  String? _family; 
  String? _subFamily;
  String? _category;
  String? _brand;
  String? _priceList;
  
  bool _allowNegativeStock = false;
  bool _lowStockAlert = false;
  bool _highStockAlert = false;
  
  late TabController _tabController;

  static const List<Map<String, String>> _unitOptions = [
    {'value': 'Piece', 'label': 'Pièce', 'code': 'pcs'},
    {'value': 'Kilogramme', 'label': 'Kilogramme', 'code': 'kg'},
    {'value': 'Litre', 'label': 'Litre', 'code': 'L'},
    {'value': 'Metre', 'label': 'Mètre', 'code': 'm'},
    {'value': 'Gramme', 'label': 'Gramme', 'code': 'g'},
    {'value': 'Millilitre', 'label': 'Millilitre', 'code': 'ml'},
    {'value': 'Boite', 'label': 'Boîte', 'code': 'bte'},
    {'value': 'Carton', 'label': 'Carton', 'code': 'ctn'},
    {'value': 'Paquet', 'label': 'Paquet', 'code': 'pqt'},
    {'value': 'Lot', 'label': 'Lot', 'code': 'lot'},
    {'value': 'Heure', 'label': 'Heure', 'code': 'h'},
    {'value': 'Jour', 'label': 'Jour', 'code': 'j'},
    {'value': 'Forfait', 'label': 'Forfait', 'code': 'forf'},
  ];

  static const List<String> _priceListOptions = [
    'Prix de Gros',
    'Prix Détaillant',
    'Client VIP',
    'Tarif Spécial',
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    context.read<ProductSettingsBloc>().add(LoadFamilies());

    final p = widget.existing;
    
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _refCtrl = TextEditingController(text: p?.reference ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    
    _purchCtrl = TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _sellCtrl = TextEditingController(text: p?.sellingPrice.toString() ?? '0');
    _discountCtrl = TextEditingController(text: p?.usualDiscount.toString() ?? '0');
    
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _privateNotesCtrl = TextEditingController(text: p?.privateNotes ?? '');
    
    _destination = p?.destination ?? 'Vente et Achat';
    _productType = ['produit', 'service', 'consommable', 'immobilisation'].contains(p?.productType) ? p!.productType : 'produit';
    if (_productType == 'immobilisation') {
      _destination = 'Achat';
    } else if (p != null && (p.destination.isEmpty || p.destination == 'Vente et Achat')) {
      if (p.purchasePrice > 0 && p.sellingPrice == 0) {
        _destination = 'Achat';
      } else if (p.sellingPrice > 0 && p.purchasePrice == 0) {
        _destination = 'Vente';
      }
    }
    _tvaRate = p?.tvaRate ?? 19;
    if (!_tvaRates.contains(_tvaRate)) {
      _tvaRates.add(_tvaRate);
      _tvaRates.sort();
    }
    
    // Safely load unit
    String rawUnit = p?.unit ?? 'Piece';
    if (rawUnit == 'Pièce' || rawUnit == 'Unite') rawUnit = 'Piece';
    _unit = _unitOptions.any((u) => u['value'] == rawUnit) ? rawUnit : 'Piece';
    
    _family = p?.familyId;
    _subFamily = p?.subFamilyId;
    _category = p?.category;
    _brand = p?.brandId;
    
    _allowNegativeStock = p?.allowNegativeStock ?? false;
    _lowStockAlert = p?.lowStockAlert ?? false;
    _highStockAlert = p?.highStockAlert ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose(); _refCtrl.dispose(); _descCtrl.dispose();
    _purchCtrl.dispose(); _sellCtrl.dispose(); _discountCtrl.dispose();
    _barcodeCtrl.dispose(); _privateNotesCtrl.dispose();
    super.dispose();
  }

  // ─── SEARCHABLE SELECTION DIALOG (Warehouse Picker Style) ─────────────────
  Future<T?> _showSearchableSelectDialog<T>({
    required String title,
    required String searchHint,
    required List<T> items,
    required String Function(T) itemTitle,
    String Function(T)? itemSubtitle,
    required bool Function(T, String query) filter,
    required bool Function(T) isSelected,
    IconData? itemIcon,
    bool allowCustom = false,
    T Function(String)? onAddCustom,
    VoidCallback? onAddNew,
    String? addNewLabel,
  }) async {
    return showDialog<T?>(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = search.trim().toLowerCase();
            final filtered = items.where((item) {
              if (query.isEmpty) return true;
              return filter(item, query);
            }).toList();

            final bool canAddNew = allowCustom &&
                query.isNotEmpty &&
                !items.any((item) => itemTitle(item).toLowerCase() == query);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxHeight: 540),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title, Optional Add & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (onAddNew != null) ...[
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onAddNew();
                            },
                            icon: Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                            label: Text(
                              addNewLabel ?? 'Ajouter',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    SizedBox(
                      height: 40,
                      child: TextField(
                        autofocus: false,
                        onChanged: (val) => setDialogState(() => search = val),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 8),

                    // Quick add inside dropdown dialog
                    if (onAddNew != null) ...[
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onAddNew();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  addNewLabel ?? 'Ajouter',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Items List
                    Flexible(
                      child: filtered.isEmpty && !canAddNew
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              alignment: Alignment.center,
                              child: Text(
                                'Aucun résultat trouvé',
                                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length + (canAddNew ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                if (canAddNew && index == filtered.length) {
                                  return InkWell(
                                    onTap: () {
                                      if (onAddCustom != null) {
                                        Navigator.of(context).pop(onAddCustom(search.trim()));
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Utiliser "${search.trim()}"',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final item = filtered[index];
                                final selected = isSelected(item);
                                final subtitle = itemSubtitle != null ? itemSubtitle(item) : null;

                                return InkWell(
                                  onTap: () => Navigator.of(context).pop(item),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: selected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (itemIcon != null) ...[
                                          Icon(
                                            itemIcon,
                                            size: 18,
                                            color: selected ? AppColors.primary : AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemTitle(item),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                                  color: selected ? AppColors.primary : AppColors.textPrimary,
                                                ),
                                              ),
                                              if (subtitle != null && subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                                      ],
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

  // ─── DIALOG SELECTOR TRIGGER FIELD ───────────────────────────────────────
  Widget _buildDialogSelectorField({
    required String? text,
    required String hint,
    required VoidCallback? onTap,
    IconData? prefixIcon,
  }) {
    final hasValue = text != null && text.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
        ),
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              Icon(
                prefixIcon,
                size: 16,
                color: hasValue ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                hasValue ? text : hint,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                  color: hasValue ? AppColors.textPrimary : AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD FAMILY / SUBFAMILY DIALOGS ─────────────────────────────────────────
  Future<void> _showAddFamilyDialog(BuildContext context) async {
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dialogCtx.tr('Nouvelle Famille'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    dialogCtx.tr('Nom de la famille'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: textCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: dialogCtx.tr('Nom de la famille (ex: Informatique, Mobilier...)'),
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return dialogCtx.tr('Veuillez entrer un nom');
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submitFamily(dialogCtx, textCtrl, formKey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(dialogCtx.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _submitFamily(dialogCtx, textCtrl, formKey),
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: Text(dialogCtx.tr('Créer la famille'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
  }

  void _submitFamily(BuildContext dialogCtx, TextEditingController textCtrl, GlobalKey<FormState> formKey) {
    if (formKey.currentState?.validate() != true) return;
    final name = textCtrl.text.trim();
    final newFam = ProductFamily(
      id: const Uuid().v4(),
      name: name,
    );
    context.read<ProductSettingsBloc>().add(AddFamily(newFam));
    setState(() {
      _family = newFam.id;
      _subFamily = null;
    });
    Navigator.of(dialogCtx).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Famille "$name" créée et sélectionnée'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _showAddSubFamilyDialog(BuildContext context, List<ProductFamily> rootFamilies, String? selectedParentId) async {
    if (rootFamilies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Veuillez d\'abord créer au moins une famille principale')),
          duration: const Duration(seconds: 3),
        ),
      );
      _showAddFamilyDialog(context);
      return;
    }

    String parentId = selectedParentId ?? rootFamilies.first.id;
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final parentFamily = rootFamilies.where((f) => f.id == parentId).firstOrNull;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.subdirectory_arrow_right_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                dialogCtx.tr('Nouvelle Sous-famille'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        dialogCtx.tr('Famille parente'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: parentId,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            items: rootFamilies.map((f) {
                              return DropdownMenuItem<String>(
                                value: f.id,
                                child: Text(f.name, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => parentId = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        dialogCtx.tr('Nom de la sous-famille'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: textCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: dialogCtx.tr('Nom de la nouvelle sous-famille'),
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return dialogCtx.tr('Veuillez entrer un nom');
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submitSubFamily(dialogCtx, textCtrl, formKey, parentId, parentFamily?.name),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(dialogCtx.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _submitSubFamily(dialogCtx, textCtrl, formKey, parentId, parentFamily?.name),
                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            label: Text(dialogCtx.tr('Créer la sous-famille'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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

  void _submitSubFamily(BuildContext dialogCtx, TextEditingController textCtrl, GlobalKey<FormState> formKey, String parentId, String? parentName) {
    if (formKey.currentState?.validate() != true) return;
    final name = textCtrl.text.trim();
    final newSub = ProductFamily(
      id: const Uuid().v4(),
      name: name,
      parentId: parentId,
    );
    context.read<ProductSettingsBloc>().add(AddSubFamily(newSub));
    setState(() {
      _family = parentId;
      _subFamily = newSub.id;
    });
    Navigator.of(dialogCtx).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sous-famille "$name" liée à "${parentName ?? ''}" et sélectionnée'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dialogCtx.tr('Nouvelle Catégorie'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    dialogCtx.tr('Nom de la catégorie'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: textCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: dialogCtx.tr('ex: Téléphonie, Accessoires...'),
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return dialogCtx.tr('Veuillez entrer un nom');
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submitCategory(dialogCtx, textCtrl, formKey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(dialogCtx.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _submitCategory(dialogCtx, textCtrl, formKey),
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: Text(dialogCtx.tr('Créer la catégorie'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
  }

  void _submitCategory(BuildContext dialogCtx, TextEditingController textCtrl, GlobalKey<FormState> formKey) {
    if (formKey.currentState?.validate() != true) return;
    final name = textCtrl.text.trim();
    final newCat = ProductCategory(
      id: const Uuid().v4(),
      name: name,
    );
    context.read<ProductSettingsBloc>().add(AddCategory(newCat));
    setState(() {
      _category = newCat.name;
    });
    Navigator.of(dialogCtx).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Catégorie "$name" créée et sélectionnée'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _showAddBrandDialog(BuildContext context, List<ProductCategory> categories, String? selectedCategoryName) async {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Veuillez d\'abord créer au moins une catégorie')),
          duration: const Duration(seconds: 3),
        ),
      );
      _showAddCategoryDialog(context);
      return;
    }

    String parentCatName = selectedCategoryName ?? categories.first.name;
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.branding_watermark_outlined, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                dialogCtx.tr('Nouvelle Marque'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        dialogCtx.tr('Catégorie parente'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: categories.any((c) => c.name == parentCatName) ? parentCatName : categories.first.name,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            items: categories.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.name,
                                child: Text(c.name, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => parentCatName = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        dialogCtx.tr('Nom de la marque'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: textCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: dialogCtx.tr('Nom de la nouvelle marque'),
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return dialogCtx.tr('Veuillez entrer un nom');
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submitBrand(dialogCtx, textCtrl, formKey, parentCatName),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(dialogCtx.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _submitBrand(dialogCtx, textCtrl, formKey, parentCatName),
                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            label: Text(dialogCtx.tr('Créer la marque'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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

  void _submitBrand(BuildContext dialogCtx, TextEditingController textCtrl, GlobalKey<FormState> formKey, String parentCategoryName) {
    if (formKey.currentState?.validate() != true) return;
    final name = textCtrl.text.trim();
    final newBrand = ProductBrand(
      id: const Uuid().v4(),
      name: name,
      categoryId: parentCategoryName,
    );
    context.read<ProductSettingsBloc>().add(AddBrand(newBrand));
    setState(() {
      _category = parentCategoryName;
      _brand = newBrand.name;
    });
    Navigator.of(dialogCtx).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marque "$name" liée à "$parentCategoryName" et sélectionnée'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  context.tr(widget.existing == null ? 'Creer un Nouvel Article' : 'Modifier l\'Article'),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Spacer(),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                  label: Text(context.tr('Retour'), style: TextStyle(color: AppColors.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.tr(widget.existing == null ? 'Creer' : 'Enregistrer'),
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // TabBar Header
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(text: context.tr('General'), icon: Icon(Icons.info_outline_rounded, size: 20)),
                Tab(text: context.tr('Prix & TVA'), icon: Icon(Icons.attach_money_rounded, size: 20)),
                Tab(text: context.tr('Classification'), icon: Icon(Icons.category_outlined, size: 20)),
                Tab(text: context.tr('Stock & Alertes'), icon: Icon(Icons.inventory_2_outlined, size: 20)),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildMainSection()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildPricingSection()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildClassificationSection()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStockSection()),
                ],
              ),
            ),
          ),

          // Bottom Step Navigation Footer
          _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final currentIndex = _tabController.index;
    final isFirstTab = currentIndex == 0;
    final isLastTab = currentIndex == 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Précédent / Annuler Button
          if (!isFirstTab)
            OutlinedButton.icon(
              onPressed: () {
                _tabController.animateTo(currentIndex - 1);
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(context.tr('Précédent'), style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
              label: Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),

          // Step Progress Dots & Text
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Étape ${currentIndex + 1}/4',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (index) {
                  final isActive = currentIndex == index;
                  final isPassed = currentIndex > index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : (isPassed
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),

          // Suivant / Terminer Button
          if (!isLastTab)
            ElevatedButton.icon(
              onPressed: () {
                if (currentIndex == 0 && _nameCtrl.text.trim().isEmpty) {
                  _formKey.currentState?.validate();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Veuillez saisir le nom de l\'article pour continuer'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                _tabController.animateTo(currentIndex + 1);
              },
              icon: Text(context.tr('Suivant'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              label: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              label: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      context.tr(widget.existing == null ? 'Terminer & Créer' : 'Terminer & Enregistrer'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Destination'), style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSelectableButton(
                  'Vente',
                  Icons.attach_money,
                  _destination == 'Vente',
                  () => setState(() {
                    _destination = 'Vente';
                    if (_productType == 'immobilisation') {
                      _productType = 'produit';
                    }
                  }),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSelectableButton(
                  'Achat',
                  Icons.shopping_cart_outlined,
                  _destination == 'Achat',
                  () => setState(() => _destination = 'Achat'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSelectableButton(
                  'Vente et Achat',
                  null,
                  _destination == 'Vente et Achat',
                  () => setState(() {
                    _destination = 'Vente et Achat';
                    if (_productType == 'immobilisation') {
                      _productType = 'produit';
                    }
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text('Type d\'Article', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSelectableButton(
                  'Produit',
                  Icons.inventory_2_outlined,
                  _productType == 'produit',
                  () => setState(() => _productType = 'produit'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSelectableButton(
                  'Service',
                  Icons.settings_outlined,
                  _productType == 'service',
                  () => setState(() => _productType = 'service'),
                ),
              ),
              if (_destination == 'Achat') ...[
                SizedBox(width: 12),
                Expanded(
                  child: _buildSelectableButton(
                    'Immobilisation',
                    Icons.account_balance_outlined,
                    _productType == 'immobilisation',
                    () => setState(() => _productType = 'immobilisation'),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    AppTextField(label: 'Nom de l\'Article', controller: _nameCtrl, hint: 'Saisissez le nom de l\'article', validator: (v) => v!.isEmpty ? 'Requis' : null),
                    SizedBox(height: 16),
                    AppTextField(label: 'Reference', controller: _refCtrl, hint: 'Saisissez la reference de l\'article'),
                    SizedBox(height: 16),
                    AppTextField(label: 'Description', controller: _descCtrl, hint: 'Saisissez la description de l\'article', maxLines: 4),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text('TVA', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._tvaRates.map((rate) => _buildTvaButton(rate)),
              OutlinedButton.icon(
                onPressed: _showAddTvaDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter TVA'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Taxes Supplementaires', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.add, size: 16),
                label: Text('Ajouter Taxe', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              if (_destination == 'Vente' || _destination == 'Vente et Achat')
                Expanded(
                  child: AppTextField(
                    label: 'Prix de Vente',
                    controller: _sellCtrl,
                    suffix: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('DT')]),
                    keyboardType: TextInputType.number,
                  ),
                ),
              if (_destination == 'Vente et Achat')
                const SizedBox(width: 24),
              if (_destination == 'Achat' || _destination == 'Vente et Achat')
                Expanded(
                  child: AppTextField(
                    label: 'Prix d\'Achat',
                    controller: _purchCtrl,
                    suffix: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('DT')]),
                    keyboardType: TextInputType.number,
                  ),
                ),
              if (_destination != 'Vente et Achat') ...[
                const SizedBox(width: 24),
                Expanded(child: Container()),
              ],
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Listes de Prix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          SizedBox(height: 4),
          Text('Configurez des tarifs speciaux pour differents groupes de clients ou quantites d\'achat', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          SizedBox(height: 16),
          _buildDialogSelectorField(
            text: _priceList,
            hint: 'Sélectionnez une liste de prix',
            prefixIcon: Icons.sell_outlined,
            onTap: () async {
              final res = await _showSearchableSelectDialog<String>(
                title: 'Sélectionner une liste de prix',
                searchHint: 'Rechercher une liste...',
                items: _priceListOptions,
                itemTitle: (p) => p,
                filter: (p, q) => p.toLowerCase().contains(q),
                isSelected: (p) => p == _priceList,
                itemIcon: Icons.sell_outlined,
                allowCustom: true,
                onAddCustom: (q) => q,
              );
              if (res != null) {
                setState(() => _priceList = res);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Famille et Marque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: 16),
          BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
            builder: (context, state) {
              List<ProductFamily> rootFamilies = [];
              List<ProductFamily> subFamilies = [];
              List<ProductCategory> categories = [];
              List<ProductBrand> brands = [];

              if (state is ProductSettingsLoaded) {
                rootFamilies = state.rootFamilies;
                if (_family != null && !rootFamilies.any((f) => f.id == _family)) {
                  _family = null;
                  _subFamily = null;
                }
                if (_family != null) {
                  subFamilies = state.getSubFamilies(_family!);
                  if (_subFamily != null && !subFamilies.any((sf) => sf.id == _subFamily)) {
                    _subFamily = null;
                  }
                }

                categories = state.categories;
                if (_category != null) {
                  brands = state.getBrandsForCategory(_category!);
                } else {
                  brands = state.brands;
                }
              }

              final selectedFamily = rootFamilies.where((f) => f.id == _family).firstOrNull;
              final selectedSubFamily = subFamilies.where((sf) => sf.id == _subFamily).firstOrNull;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Famille'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            SizedBox(height: 6),
                            _buildDialogSelectorField(
                              text: selectedFamily?.name,
                              hint: context.tr('Sélectionner'),
                              prefixIcon: Icons.account_tree_outlined,
                              onTap: () async {
                                final res = await _showSearchableSelectDialog<ProductFamily>(
                                  title: context.tr('Sélectionner une famille'),
                                  searchHint: context.tr('Rechercher une famille...'),
                                  items: rootFamilies,
                                  itemTitle: (f) => f.name,
                                  filter: (f, q) => f.name.toLowerCase().contains(q),
                                  isSelected: (f) => f.id == _family,
                                  itemIcon: Icons.folder_open_rounded,
                                  onAddNew: () => _showAddFamilyDialog(context),
                                  addNewLabel: context.tr('Ajouter une famille'),
                                );
                                if (res != null) {
                                  setState(() {
                                    _family = res.id;
                                    _subFamily = null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Sous-famille'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            SizedBox(height: 6),
                            _buildDialogSelectorField(
                              text: selectedSubFamily?.name,
                              hint: _family == null ? context.tr('Choisir famille') : context.tr('Sélectionner'),
                              prefixIcon: Icons.subdirectory_arrow_right_rounded,
                              onTap: _family == null
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(context.tr('Veuillez d\'abord sélectionner une famille')),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  : () async {
                                      final res = await _showSearchableSelectDialog<ProductFamily>(
                                        title: context.tr('Sélectionner une sous-famille'),
                                        searchHint: context.tr('Rechercher une sous-famille...'),
                                        items: subFamilies,
                                        itemTitle: (sf) => sf.name,
                                        filter: (sf, q) => sf.name.toLowerCase().contains(q),
                                        isSelected: (sf) => sf.id == _subFamily,
                                        itemIcon: Icons.account_tree_outlined,
                                        onAddNew: () => _showAddSubFamilyDialog(context, rootFamilies, _family),
                                        addNewLabel: context.tr('Ajouter une sous-famille'),
                                      );
                                      if (res != null) {
                                        setState(() => _subFamily = res.id);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Catégorie'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            SizedBox(height: 6),
                            _buildDialogSelectorField(
                              text: _category,
                              hint: context.tr('Sélectionner'),
                              prefixIcon: Icons.folder_outlined,
                              onTap: () async {
                                final res = await _showSearchableSelectDialog<ProductCategory>(
                                  title: context.tr('Sélectionner une catégorie'),
                                  searchHint: context.tr('Rechercher une catégorie...'),
                                  items: categories,
                                  itemTitle: (c) => c.name,
                                  filter: (c, q) => c.name.toLowerCase().contains(q),
                                  isSelected: (c) => c.name == _category,
                                  itemIcon: Icons.category_outlined,
                                  onAddNew: () => _showAddCategoryDialog(context),
                                  addNewLabel: context.tr('Ajouter une catégorie'),
                                );
                                if (res != null) {
                                  setState(() {
                                    _category = res.name;
                                    final validBrands = state is ProductSettingsLoaded ? state.getBrandsForCategory(res.name) : [];
                                    if (_brand != null && !validBrands.any((b) => b.name.toLowerCase() == _brand!.toLowerCase())) {
                                      _brand = null;
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Marque'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            SizedBox(height: 6),
                            _buildDialogSelectorField(
                              text: _brand,
                              hint: context.tr('Sélectionner'),
                              prefixIcon: Icons.branding_watermark_outlined,
                              onTap: () async {
                                final res = await _showSearchableSelectDialog<ProductBrand>(
                                  title: context.tr('Sélectionner une marque'),
                                  searchHint: context.tr('Rechercher une marque...'),
                                  items: brands,
                                  itemTitle: (b) => b.name,
                                  itemSubtitle: (b) => (b.categoryId != null && b.categoryId!.isNotEmpty) ? '${context.tr('Catégorie')}: ${b.categoryId}' : '',
                                  filter: (b, q) => b.name.toLowerCase().contains(q),
                                  isSelected: (b) => b.name == _brand,
                                  itemIcon: Icons.branding_watermark_outlined,
                                  onAddNew: () => _showAddBrandDialog(context, categories, _category),
                                  addNewLabel: context.tr('Ajouter une marque'),
                                );
                                if (res != null) {
                                  setState(() {
                                    _brand = res.name;
                                    if (res.categoryId != null && _category == null) {
                                      _category = res.categoryId;
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    _buildDialogSelectorField(
                      text: _unitOptions.firstWhere((u) => u['value'] == _unit, orElse: () => _unitOptions.first)['label'],
                      hint: 'Sélectionner une unité',
                      prefixIcon: Icons.straighten_rounded,
                      onTap: () async {
                        final res = await _showSearchableSelectDialog<Map<String, String>>(
                          title: 'Sélectionner une unité',
                          searchHint: 'Rechercher une unité...',
                          items: _unitOptions,
                          itemTitle: (u) => '${u['label']} (${u['code']})',
                          itemSubtitle: (u) => 'Unité standard: ${u['value']}',
                          filter: (u, q) =>
                              u['label']!.toLowerCase().contains(q) ||
                              u['code']!.toLowerCase().contains(q) ||
                              u['value']!.toLowerCase().contains(q),
                          isSelected: (u) => u['value'] == _unit,
                          itemIcon: Icons.straighten_rounded,
                        );
                        if (res != null) {
                          setState(() => _unit = res['value']!);
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(child: Container()), // Empty space to align
            ],
          ),
          SizedBox(height: 24),
          AppTextField(label: 'Code-barres', controller: _barcodeCtrl, hint: 'Entrez le code-barres'),
          SizedBox(height: 16),
          AppTextField(label: 'Notes Privees', controller: _privateNotesCtrl, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    if (_productType == 'service') {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              context.tr('Article de type Service'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Les services sont des prestations intangibles : ils ne possèdent pas de stock physique, n\'entrent pas dans les mouvements de stock et ne déclenchent aucune alerte de rupture.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Parametres de Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondary),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _allowNegativeStock,
                onChanged: (v) => setState(() => _allowNegativeStock = v ?? false),
                activeColor: AppColors.primary,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Autoriser Stock Vide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('Autoriser la vente de cet article quand il est en rupture de stock', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Text('Alerte rupture de stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Definissez des seuils d\'alerte pour etre notifie quand le stock est faible dans chaque entrepot', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Entrepot par defaut', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Spacer(),
                Switch(
                  value: _lowStockAlert,
                  onChanged: (v) => setState(() => _lowStockAlert = v),
                  activeThumbColor: AppColors.primary,
                ),
                Text('Alerte activee', style: TextStyle(fontSize: 13, color: _lowStockAlert ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text('Alertes de Stock Maximum (surstockage)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Definissez des seuils max pour etre alerte quand le stock depasse le maximum dans chaque entrepot', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Entrepot par defaut', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Spacer(),
                Switch(
                  value: _highStockAlert,
                  onChanged: (v) => setState(() => _highStockAlert = v),
                  activeThumbColor: AppColors.primary,
                ),
                Text('Alerte max activee', style: TextStyle(fontSize: 13, color: _highStockAlert ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Text('% Remise Habituelle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                Switch(value: false, onChanged: (v) {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableButton(String title, IconData? icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 8),
                ],
                Text(
                  context.tr(title),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                right: 0,
                child: Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTvaDialog() async {
    final tvaCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.percent_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ajouter un taux de TVA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saisissez la valeur du taux de TVA en pourcentage (ex: 9 pour 9%).',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: tvaCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Taux de TVA (%)',
                          hintText: 'Ex: 9',
                          suffixText: '%',
                          suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Veuillez saisir un taux de TVA';
                          }
                          final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                          if (parsed == null) {
                            return 'Veuillez entrer un nombre valide';
                          }
                          if (parsed < 0 || parsed > 100) {
                            return 'Le taux doit être entre 0% et 100%';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (formKey.currentState!.validate()) {
                            final val = double.parse(tvaCtrl.text.trim().replaceAll(',', '.'));
                            Navigator.of(dialogCtx).pop(val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Suggestions rapides :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [9.0, 10.0, 14.0, 20.0]
                            .where((r) => !_tvaRates.contains(r))
                            .map((r) {
                          return ActionChip(
                            label: Text('${r.toInt()}%'),
                            labelStyle: TextStyle(fontSize: 12, color: AppColors.primary),
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                            onPressed: () {
                              tvaCtrl.text = r.toInt().toString();
                              if (formKey.currentState!.validate()) {
                                Navigator.of(dialogCtx).pop(r);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final val = double.parse(tvaCtrl.text.trim().replaceAll(',', '.'));
                      Navigator.of(dialogCtx).pop(val);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (!_tvaRates.contains(result)) {
          _tvaRates.add(result);
          _tvaRates.sort();
        }
        _tvaRate = result;
      });
    }
  }

  void _removeTvaRate(double rate) {
    final rateLabel = rate == rate.roundToDouble() ? '${rate.toInt()}%' : '${rate.toStringAsFixed(1)}%';
    final wasSelected = _tvaRate == rate;
    setState(() {
      _tvaRates.remove(rate);
      if (wasSelected) {
        _tvaRate = _tvaRates.contains(19.0) ? 19.0 : (_tvaRates.isNotEmpty ? _tvaRates.first : 0.0);
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Taux de TVA $rateLabel supprimé'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Annuler',
          textColor: AppColors.primaryLight,
          onPressed: () {
            setState(() {
              if (!_tvaRates.contains(rate)) {
                _tvaRates.add(rate);
                _tvaRates.sort();
              }
              if (wasSelected) {
                _tvaRate = rate;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildTvaButton(double rate) {
    final isSelected = _tvaRate == rate;
    final isCustom = !_defaultTvaRates.contains(rate);
    final rateLabel = rate == rate.roundToDouble() ? '${rate.toInt()}%' : '${rate.toStringAsFixed(1)}%';

    return InkWell(
      onTap: () => setState(() => _tvaRate = rate),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCustom ? 16 : 24,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rateLabel,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            if (isCustom) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _removeTvaRate(rate),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.border.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (widget.existing == null && !TrialService.instance.checkCanCreate(context)) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final product = Product(
        id: widget.existing?.id ?? const Uuid().v4(),
        code: widget.existing?.code ?? 'ART-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: _nameCtrl.text.trim(),
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        productType: _productType,
        destination: _destination,
        familyId: _family,
        subFamilyId: _subFamily,
        category: _category,
        brandId: _brand,
        unit: _unit,
        purchasePrice: (_destination == 'Vente') ? 0 : (double.tryParse(_purchCtrl.text) ?? 0),
        sellingPrice: (_destination == 'Achat') ? 0 : (double.tryParse(_sellCtrl.text) ?? 0),
        tvaRate: _tvaRate,
        allowNegativeStock: _productType == 'service' ? false : _allowNegativeStock,
        lowStockAlert: _productType == 'service' ? false : _lowStockAlert,
        highStockAlert: _productType == 'service' ? false : _highStockAlert,
        stockQty: _productType == 'service' ? 0.0 : (widget.existing?.stockQty ?? 0.0),
        minStockQty: _productType == 'service' ? 0.0 : (widget.existing?.minStockQty ?? 0.0),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        privateNotes: _privateNotesCtrl.text.trim().isEmpty ? null : _privateNotesCtrl.text.trim(),
        isActive: widget.existing?.isActive ?? true,
      );

      if (widget.existing == null) {
        context.read<ProductsBloc>().add(AddProduct(product));
      } else {
        context.read<ProductsBloc>().add(UpdateProduct(product));
      }

      nav.pop(product);
      messenger.showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Article cree avec succes' : 'Article mis a jour'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }
}
