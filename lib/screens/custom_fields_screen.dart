import 'package:flutter/material.dart';
import '../models/custom_field_definition.dart';
import '../services/custom_fields_service.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../widgets/sidebar_menu.dart';
import 'app_shell_screen.dart';

class CustomFieldsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const CustomFieldsScreen({super.key, this.onBack});

  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen> {
  // Document type definitions for Ventes and Achats
  static const List<Map<String, dynamic>> _documentTypes = [
    // Ventes
    {
      'key': 'invoice',
      'label': 'Facture - Vente',
      'shortLabel': 'Facture',
      'group': 'Ventes',
      'icon': Icons.receipt_long_rounded,
    },
    {
      'key': 'quote',
      'label': 'Devis - Vente',
      'shortLabel': 'Devis',
      'group': 'Ventes',
      'icon': Icons.description_rounded,
    },
    {
      'key': 'customer_order',
      'label': 'Bon de commande - Vente',
      'shortLabel': 'Commande client',
      'group': 'Ventes',
      'icon': Icons.shopping_cart_rounded,
    },
    {
      'key': 'delivery_note',
      'label': 'Bon de livraison - Vente',
      'shortLabel': 'Bon de livraison',
      'group': 'Ventes',
      'icon': Icons.local_shipping_rounded,
    },
    {
      'key': 'exit_voucher',
      'label': 'Bon de sortie - Vente',
      'shortLabel': 'Bon de sortie',
      'group': 'Ventes',
      'icon': Icons.outbox_rounded,
    },
    {
      'key': 'credit_note',
      'label': 'Avoir - Vente',
      'shortLabel': 'Avoir client',
      'group': 'Ventes',
      'icon': Icons.assignment_return_rounded,
    },
    {
      'key': 'return_voucher',
      'label': 'Bon de retour - Vente',
      'shortLabel': 'Bon de retour client',
      'group': 'Ventes',
      'icon': Icons.keyboard_return_rounded,
    },

    // Achats
    {
      'key': 'purchase_invoice',
      'label': 'Facture - Achat',
      'shortLabel': 'Facture d\'achat',
      'group': 'Achats',
      'icon': Icons.receipt_rounded,
    },
    {
      'key': 'supplier_order',
      'label': 'Commande - Fournisseur',
      'shortLabel': 'Commande fournisseur',
      'group': 'Achats',
      'icon': Icons.shopping_bag_rounded,
    },
    {
      'key': 'receiving_voucher',
      'label': 'Bon de réception - Achat',
      'shortLabel': 'Bon de réception',
      'group': 'Achats',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'key': 'supplier_credit_note',
      'label': 'Avoir - Achat',
      'shortLabel': 'Avoir fournisseur',
      'group': 'Achats',
      'icon': Icons.assignment_returned_rounded,
    },
    {
      'key': 'supplier_return',
      'label': 'Bon de retour - Fournisseur',
      'shortLabel': 'Retour fournisseur',
      'group': 'Achats',
      'icon': Icons.assignment_return_outlined,
    },
  ];

  String _selectedDocType = 'quote'; // Default to Devis as requested
  List<CustomFieldDefinition> _fields = [];
  bool _isLoading = true;
  static const int _maxFields = 6;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() => _isLoading = true);
    final fields = await CustomFieldsService.instance.getCustomFields(
      _selectedDocType,
      forceRefresh: true,
    );
    if (mounted) {
      setState(() {
        _fields = fields;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> get _currentDocTypeInfo =>
      _documentTypes.firstWhere((d) => d['key'] == _selectedDocType, orElse: () => _documentTypes[0]);

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    final shell = context.findAncestorStateOfType<AppShellScreenState>();
    if (shell != null) {
      shell.setActiveModule(AppModule.settings);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _openAddFieldDialog() async {
    if (_fields.length >= _maxFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limite maximale de $_maxFields champs personnalisés atteinte pour ce document.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final placeholderController = TextEditingController();
    String selectedType = 'text';
    bool isRequired = false;
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ajouter un Champ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom du champ *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Ex: Diagnostic technicien, Prix estimé...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surface,
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
                      style: const TextStyle(fontSize: 13.5),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Veuillez saisir un nom pour ce champ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type de champ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'text',
                          child: Row(
                            children: [
                              Icon(Icons.text_fields_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Texte court', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'number',
                          child: Row(
                            children: [
                              Icon(Icons.pin_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Nombre / Prix', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'date',
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Date', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'textarea',
                          child: Row(
                            children: [
                              Icon(Icons.notes_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Texte long (Zone de texte)', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Texte d\'indication (Optionnel)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: placeholderController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Saisissez le résultat du diagnostic...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Champ obligatoire', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Empêche l\'enregistrement si le champ est vide',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      value: isRequired,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setDlgState(() => isRequired = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() != true) return;
                  final eid = EnterpriseService.instance.currentEnterpriseId ?? '';
                  final newField = CustomFieldDefinition(
                    id: '',
                    enterpriseId: eid,
                    documentType: _selectedDocType,
                    name: nameController.text.trim(),
                    type: selectedType,
                    isRequired: isRequired,
                    placeholder: placeholderController.text.trim().isEmpty ? null : placeholderController.text.trim(),
                    order: _fields.length,
                  );

                  try {
                    await CustomFieldsService.instance.saveCustomField(newField);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (added == true) {
      await _loadFields();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Champ personnalisé ajouté avec succès'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteField(CustomFieldDefinition field) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            const Text('Supprimer ce champ ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer le champ « ${field.name} » pour le document ${_currentDocTypeInfo['shortLabel']} ?\n\nCe champ ne sera plus demandé lors de la création de nouveaux documents.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CustomFieldsService.instance.deleteCustomField(
          field.id,
          documentType: _selectedDocType,
        );
        await _loadFields();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Champ supprimé avec succès'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 28,
          vertical: isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Header with Retour and Title ──────────────────
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Retour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    backgroundColor: AppColors.surface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              'Champs Personnalisés',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configurez les champs personnalisés pour les types de documents',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // ─── 2. Card: Type de Document (Dropdown) ──────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type de Document',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sélectionnez un type de document',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDocType,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: _documentTypes.map((dt) {
                          final isAchat = dt['group'] == 'Achats';
                          return DropdownMenuItem<String>(
                            value: dt['key'] as String,
                            child: Row(
                              children: [
                                Icon(
                                  dt['icon'] as IconData,
                                  size: 18,
                                  color: isAchat ? const Color(0xFFD97706) : AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  dt['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAchat
                                        ? const Color(0xFFFEF3C7)
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    dt['group'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isAchat ? const Color(0xFFB45309) : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newType) {
                          if (newType != null && newType != _selectedDocType) {
                            setState(() => _selectedDocType = newType);
                            _loadFields();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── 3. Card: Fields List & Add Action ─────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row of Card 2
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentDocTypeInfo['shortLabel'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_fields.length} / $_maxFields champs personnalisés',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _fields.length < _maxFields ? _openAddFieldDialog : null,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            isMobile ? 'Ajouter' : 'Ajouter un Champ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: 10,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Body: Loading, Empty, or List of Fields
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_fields.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                      child: Center(
                        child: Text(
                          'Aucun champ personnalisé configuré',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _fields.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final field = _fields[index];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 14 : 20,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(field.icon, size: 18, color: AppColors.primary),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  field.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (field.isRequired) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Text(
                                    'Obligatoire',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Type : ${field.typeLabel}${field.placeholder != null ? ' · "${field.placeholder}"' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                            tooltip: 'Supprimer ce champ',
                            onPressed: () => _deleteField(field),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
