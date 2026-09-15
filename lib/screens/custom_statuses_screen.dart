import 'package:flutter/material.dart';
import '../models/custom_status_definition.dart';
import '../services/custom_status_service.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../widgets/sidebar_menu.dart';
import 'app_shell_screen.dart';

class CustomStatusesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const CustomStatusesScreen({super.key, this.onBack});

  @override
  State<CustomStatusesScreen> createState() => _CustomStatusesScreenState();
}

class _CustomStatusesScreenState extends State<CustomStatusesScreen> {
  // Document type definitions for Ventes and Achats
  static const List<Map<String, dynamic>> _documentTypes = [
    // Ventes
    {
      'key': 'quote',
      'label': 'Devis - Vente',
      'shortLabel': 'Devis',
      'group': 'Ventes',
      'icon': Icons.description_rounded,
    },
    {
      'key': 'invoice',
      'label': 'Facture - Vente',
      'shortLabel': 'Facture',
      'group': 'Ventes',
      'icon': Icons.receipt_long_rounded,
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

  static const List<Color> _paletteColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFA855F7), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFF64748B), // Slate
    Color(0xFF8B5CF6), // Violet
  ];

  String _selectedDocType = 'quote';
  List<CustomStatusDefinition> _defaultStatuses = [];
  List<CustomStatusDefinition> _customStatuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);
    final defaults = CustomStatusService.instance.getDefaultStatuses(_selectedDocType);
    final customs = await CustomStatusService.instance.getCustomStatuses(
      _selectedDocType,
      forceRefresh: true,
    );
    if (mounted) {
      setState(() {
        _defaultStatuses = defaults;
        _customStatuses = customs;
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

  Future<void> _openAddStatusDialog() async {
    final nameController = TextEditingController();
    Color selectedColor = _paletteColors[0];
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
                  child: Icon(Icons.bookmarks_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ajouter un Statut',
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
                      'Nom du statut *',
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
                        hintText: 'Ex: En cours de contrôle, Prêt pour livraison...',
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
                          return 'Veuillez saisir un nom pour ce statut';
                        }
                        return null;
                      },
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Couleur du badge *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _paletteColors.map((color) {
                        final isSelected = color.toARGB32() == selectedColor.toARGB32();
                        return InkWell(
                          onTap: () => setDlgState(() => selectedColor = color),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Live preview of badge
                    Text(
                      'Aperçu du badge :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: selectedColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'Nom du statut',
                        style: TextStyle(
                          color: selectedColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                  final newStatus = CustomStatusDefinition(
                    id: '',
                    enterpriseId: eid,
                    documentType: _selectedDocType,
                    name: nameController.text.trim(),
                    colorValue: selectedColor.toARGB32(),
                    order: _customStatuses.length,
                    isDefault: false,
                  );

                  try {
                    await CustomStatusService.instance.saveCustomStatus(newStatus);
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
      await _loadStatuses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Statut personnalisé ajouté avec succès'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteStatus(CustomStatusDefinition status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            const Text('Supprimer ce statut ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer le statut « ${status.name} » pour le document ${_currentDocTypeInfo['shortLabel']} ?\n\nCe statut ne sera plus proposé dans la liste des statuts.',
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
        await CustomStatusService.instance.deleteCustomStatus(
          status.id,
          documentType: _selectedDocType,
        );
        await _loadStatuses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Statut supprimé avec succès'),
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
              'Statuts Personnalisés',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configurez les statuts pour les types de documents de Vente et d\'Achat',
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
                            _loadStatuses();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── 3. Card: Custom Statuses List & Add Action ──────────
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
                                '${_customStatuses.length} statut(s) personnalisé(s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openAddStatusDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            isMobile ? 'Ajouter' : 'Ajouter un Statut',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
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

                  // Body: Loading, Empty, or List of Custom Statuses
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    // SECTION A: Custom Statuses
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Statuts Personnalisés (${_customStatuses.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_customStatuses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        child: Center(
                          child: Text(
                            'Aucun statut personnalisé configuré pour ce document.',
                            style: TextStyle(
                              fontSize: 13,
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
                        itemCount: _customStatuses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final status = _customStatuses[index];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 14 : 20,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: status.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: status.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: status.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: status.color.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    status.name,
                                    style: TextStyle(
                                      color: status.color,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Text(
                                    'Personnalisé',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              tooltip: 'Supprimer ce statut',
                              onPressed: () => _deleteStatus(status),
                            ),
                          );
                        },
                      ),

                    const Divider(height: 24),

                    // SECTION B: Default System Statuses
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Statuts Système par défaut (${_defaultStatuses.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _defaultStatuses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final status = _defaultStatuses[index];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 14 : 20,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: status.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: status.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: status.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.name,
                                  style: TextStyle(
                                    color: status.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text(
                                  'Système',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.lock_rounded,
                            color: AppColors.textTertiary,
                            size: 16,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
