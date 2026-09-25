import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_tax_rate.dart';
import '../services/custom_tax_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class CreateTaxRateDialog extends StatefulWidget {
  final String defaultUsage;

  const CreateTaxRateDialog({
    super.key,
    this.defaultUsage = 'all',
  });

  static Future<CustomTaxRate?> show(BuildContext context, {String defaultUsage = 'all'}) {
    return showDialog<CustomTaxRate>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CreateTaxRateDialog(defaultUsage: defaultUsage),
    );
  }

  @override
  State<CreateTaxRateDialog> createState() => _CreateTaxRateDialogState();
}

class _CreateTaxRateDialogState extends State<CreateTaxRateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _valueCtrl = TextEditingController(text: '0');
  final _priorityCtrl = TextEditingController(text: '0');

  String _taxType = 'percentage'; // 'percentage' or 'fixed'
  String _appliedWhen = 'before_tva'; // 'before_tva' or 'after_tva'
  late String _usage; // 'all', 'sale', 'purchase'
  bool _appliedToArticle = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usage = widget.defaultUsage;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceAlt,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final val = double.tryParse(_valueCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final priority = int.tryParse(_priorityCtrl.text) ?? 0;

    final tax = CustomTaxRate(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      label: _labelCtrl.text.trim().isNotEmpty ? _labelCtrl.text.trim() : _nameCtrl.text.trim(),
      taxType: _taxType,
      value: val,
      appliedWhen: _appliedWhen,
      usage: _usage,
      priority: priority,
      appliedToArticle: _appliedToArticle,
      createdAt: DateTime.now(),
    );

    try {
      await CustomTaxService.instance.saveTax(tax);
      if (mounted) {
        Navigator.of(context).pop(tax);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Erreur lors de l\'enregistrement de la taxe')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final dialogWidth = isDesktop ? 580.0 : (screenWidth * 0.95);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Title + Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Créer un Taux de Taxe'),
                      style: TextStyle(
                        fontSize: isDesktop ? 19 : 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                    splashRadius: 20,
                    tooltip: context.tr('Fermer'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Field 1: Nom de la Taxe
                      RichText(
                        text: TextSpan(
                          text: context.tr('Nom de la Taxe '),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          children: [
                            TextSpan(
                              text: context.tr('(Utilisé dans les listes et paramètres pour identifier cette taxe)'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _buildInputDecoration(hintText: 'ex. TVA 19%, FODEC 1%'),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Veuillez saisir un nom') : null,
                      ),
                      const SizedBox(height: 18),

                      // Field 2: Libellé
                      RichText(
                        text: TextSpan(
                          text: context.tr('Libellé (affiché sur les documents) '),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          children: [
                            TextSpan(
                              text: context.tr('(Libellé court affiché sur les factures et totaux)'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _labelCtrl,
                        decoration: _buildInputDecoration(hintText: 'ex. TVA, FODEC'),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Veuillez saisir un libellé') : null,
                      ),
                      const SizedBox(height: 20),

                      // Layout for parameters: structured row-by-row for perfect horizontal alignment
                      if (isDesktop) ...[
                        // Row 1: Type de Taxe & Valeur de la Taxe
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildTaxTypeField()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildTaxValueField()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Row 2: Appliqué Quand & Usage (Exact same horizontal line)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildAppliedWhenField()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildUsageField()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Row 3: Priorité (Poids) & Appliqué à l'Article
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPriorityField()),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 32),
                                child: _buildAppliedToArticleField(),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        _buildTaxTypeField(),
                        const SizedBox(height: 16),
                        _buildTaxValueField(),
                        const SizedBox(height: 16),
                        _buildAppliedWhenField(),
                        const SizedBox(height: 16),
                        _buildUsageField(),
                        const SizedBox(height: 16),
                        _buildPriorityField(),
                        const SizedBox(height: 16),
                        _buildAppliedToArticleField(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: AppColors.border),

            // Bottom Buttons: Annuler & Créer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      context.tr('Annuler'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            context.tr('Créer'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Type de Taxe'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Radio<String>(
              value: 'percentage',
              groupValue: _taxType,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() => _taxType = v ?? 'percentage'),
            ),
            GestureDetector(
              onTap: () => setState(() => _taxType = 'percentage'),
              child: Text(context.tr('Pourcentage'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],
        ),
        Row(
          children: [
            Radio<String>(
              value: 'fixed',
              groupValue: _taxType,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() => _taxType = v ?? 'fixed'),
            ),
            GestureDetector(
              onTap: () => setState(() => _taxType = 'fixed'),
              child: Text(context.tr('Fixe'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxValueField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _taxType == 'percentage' ? context.tr('Valeur de la Taxe (%)') : context.tr('Valeur de la Taxe (TND)'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _valueCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _buildInputDecoration(hintText: _taxType == 'percentage' ? 'ex. 19' : 'ex. 1.000'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return context.tr('Veuillez saisir une valeur');
            final parsed = double.tryParse(v.replaceAll(',', '.'));
            if (parsed == null || parsed < 0) return context.tr('Valeur invalide');
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAppliedWhenField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Appliqué Quand'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _appliedWhen,
          decoration: _buildInputDecoration(),
          dropdownColor: AppColors.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
          items: [
            DropdownMenuItem(value: 'before_tva', child: Text(context.tr('Avant TVA'), style: const TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'after_tva', child: Text(context.tr('Après TVA'), style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (v) => setState(() => _appliedWhen = v ?? 'before_tva'),
        ),
      ],
    );
  }

  Widget _buildUsageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Usage'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _usage,
          decoration: _buildInputDecoration(),
          dropdownColor: AppColors.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
          items: [
            DropdownMenuItem(value: 'all', child: Text(context.tr('Tous'), style: const TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'sale', child: Text(context.tr('Vente'), style: const TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'purchase', child: Text(context.tr('Achat'), style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (v) => setState(() => _usage = v ?? 'all'),
        ),
      ],
    );
  }

  Widget _buildPriorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Priorité (Poids)'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _priorityCtrl,
          keyboardType: TextInputType.number,
          decoration: _buildInputDecoration(hintText: '0'),
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildAppliedToArticleField() {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: _appliedToArticle,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (v) => setState(() => _appliedToArticle = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _appliedToArticle = !_appliedToArticle),
          child: Text(
            context.tr('Appliqué à l\'Article'),
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
