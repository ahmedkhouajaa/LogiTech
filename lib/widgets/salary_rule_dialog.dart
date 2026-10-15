import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/salary_rule.dart';

/// Modal de configuration d'une Règle Salariale (Images 2 & 3)
/// Conforme à la structure Odoo ERP :
/// - Fil d'Ariane : `Fiches de Paie des Employés / [Bulletin] / [Nom de règle]`
/// - Nom, Catégorie, Code, Séquence, Actif, Non Périodique, Apparaît sur le bulletin
/// - Onglets : Général (Conditions, Calcul, Contribution), Règles enfant, Accounting, Entrées, Description
class SalaryRuleDialog extends StatefulWidget {
  final SalaryRule? initialRule;
  final String? payslipName;
  final Function(SalaryRule updatedRule)? onSave;

  const SalaryRuleDialog({
    super.key,
    this.initialRule,
    this.payslipName,
    this.onSave,
  });

  static Future<SalaryRule?> show(
    BuildContext context, {
    SalaryRule? rule,
    String? payslipName,
    Function(SalaryRule)? onSave,
  }) {
    return showDialog<SalaryRule>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SalaryRuleDialog(
        initialRule: rule,
        payslipName: payslipName,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SalaryRuleDialog> createState() => _SalaryRuleDialogState();
}

class _SalaryRuleDialogState extends State<SalaryRuleDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _sequenceCtrl;
  late TextEditingController _fixedAmountCtrl;
  late TextEditingController _percentageCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _contributionRegisterCtrl;
  late TextEditingController _debitAccountCtrl;
  late TextEditingController _creditAccountCtrl;
  late TextEditingController _descriptionCtrl;

  String _category = 'Allocation';
  bool _isActive = true;
  bool _isNonPeriodic = true;
  bool _appearsOnPayslip = true;

  String _conditionBasedOn = 'Toujours vrai';
  String _amountType = 'Montant fixe';

  static const Color _primaryBlue = Color(0xFF1A56DB);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _surfaceLight = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  final List<String> _categories = [
    'Allocation',
    'Brut',
    'Net',
    'Déduction',
    'Cotisation Patronale',
  ];

  final List<String> _conditionsList = [
    'Toujours vrai',
    'Plage',
    'Code Python',
  ];

  final List<String> _amountTypesList = [
    'Montant fixe',
    'Pourcentage (%)',
    'Code Python',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final rule = widget.initialRule ??
        const SalaryRule(
          id: 'new_rule',
          name: 'prime',
          category: 'Allocation',
          code: 'P1',
          sequence: 5,
          fixedAmount: 150.0,
          quantity: 1.0,
        );

    _nameCtrl = TextEditingController(text: rule.name);
    _codeCtrl = TextEditingController(text: rule.code);
    _sequenceCtrl = TextEditingController(text: rule.sequence.toString());
    _fixedAmountCtrl = TextEditingController(
      text: rule.fixedAmount > 0 ? NumberFormat('#,##0.00', 'fr_FR').format(rule.fixedAmount) : '150,00',
    );
    _percentageCtrl = TextEditingController(text: rule.percentage.toStringAsFixed(2));
    _quantityCtrl = TextEditingController(text: rule.quantity.toStringAsFixed(1));
    _contributionRegisterCtrl = TextEditingController(text: rule.contributionRegister ?? 'Cotisations patronales');
    _debitAccountCtrl = TextEditingController(text: rule.debitAccount ?? '641100 - Salaires et appointements');
    _creditAccountCtrl = TextEditingController(text: rule.creditAccount ?? '421000 - Personnel rémunérations dues');
    _descriptionCtrl = TextEditingController(text: rule.description ?? 'Prime de rendement ou indemnité variable.');

    _category = rule.category;
    _isActive = rule.isActive;
    _isNonPeriodic = rule.isNonPeriodic;
    _appearsOnPayslip = rule.appearsOnPayslip;
    _conditionBasedOn = rule.conditionBasedOn;
    _amountType = rule.amountType;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _sequenceCtrl.dispose();
    _fixedAmountCtrl.dispose();
    _percentageCtrl.dispose();
    _quantityCtrl.dispose();
    _contributionRegisterCtrl.dispose();
    _debitAccountCtrl.dispose();
    _creditAccountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  double _parseAmount(String text) {
    final clean = text.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  void _saveRule() {
    final rule = (widget.initialRule ?? const SalaryRule(id: '', name: '', code: '')).copyWith(
      id: widget.initialRule?.id.isNotEmpty == true ? widget.initialRule!.id : 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'prime',
      category: _category,
      code: _codeCtrl.text.trim().isNotEmpty ? _codeCtrl.text.trim() : 'P1',
      sequence: int.tryParse(_sequenceCtrl.text.trim()) ?? 5,
      isActive: _isActive,
      isNonPeriodic: _isNonPeriodic,
      appearsOnPayslip: _appearsOnPayslip,
      conditionBasedOn: _conditionBasedOn,
      amountType: _amountType,
      fixedAmount: _parseAmount(_fixedAmountCtrl.text),
      percentage: _parseAmount(_percentageCtrl.text),
      quantity: double.tryParse(_quantityCtrl.text.trim()) ?? 1.0,
      contributionRegister: _contributionRegisterCtrl.text.trim(),
      debitAccount: _debitAccountCtrl.text.trim(),
      creditAccount: _creditAccountCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
    );

    widget.onSave?.call(rule);
    Navigator.of(context).pop(rule);
  }

  void _resetToNew() {
    setState(() {
      _nameCtrl.text = 'nouvelle_regle';
      _codeCtrl.text = 'R1';
      _sequenceCtrl.text = '10';
      _fixedAmountCtrl.text = '0,00';
      _category = 'Allocation';
      _isActive = true;
      _isNonPeriodic = true;
      _appearsOnPayslip = true;
      _conditionBasedOn = 'Toujours vrai';
      _amountType = 'Montant fixe';
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 750;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final payslipTitle = widget.payslipName ?? 'Bulletin de paie de Alex pour octobre-2024';
    final ruleName = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'prime';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 28,
        vertical: isMobile ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? media.size.width : 920,
          maxHeight: isMobile ? media.size.height * 0.95 : 780,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP HEADER (Matching Image 2: "Nouveau", Breadcrumbs, Settings, Pagination)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _borderLight)),
              ),
              child: Row(
                children: [
                  // "Nouveau" Button (Odoo purple/blue style)
                  ElevatedButton(
                    onPressed: _resetToNew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B46C1), // Odoo primary purple/indigo
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: const Text('Nouveau', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),

                  // Breadcrumb (Matching Image 2: Fiches de Paie des Employés / Bulletin ... / prime)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Fiches de Paie des Employés',
                              style: TextStyle(fontSize: 12, color: _primaryBlue, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Text('  /  ', style: TextStyle(fontSize: 12, color: _textMuted)),
                          Text(
                            payslipTitle,
                            style: const TextStyle(fontSize: 12, color: _primaryBlue, fontWeight: FontWeight.w500),
                          ),
                          const Text('  /  ', style: TextStyle(fontSize: 12, color: _textMuted)),
                          Text(
                            ruleName,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.settings_outlined, size: 15, color: _textMuted),
                        ],
                      ),
                    ),
                  ),

                  // Pagination (Image 2: 1/1 < >)
                  const Text('1/1', style: TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFFCBD5E1)),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                  const SizedBox(width: 8),

                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: _textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. SCROLLABLE BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Field: Nom (Image 2: "prime")
                    const Text(
                      'Nom',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        hintText: 'prime',
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Catégorie (Image 2: Allocation)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text(
                            'Catégorie',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _categories.contains(_category) ? _category : 'Allocation',
                              isDense: true,
                              items: _categories.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _textDark)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _category = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Code ? (Image 2: P1)
                    Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Row(
                            children: [
                              const Text('Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted)),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Code utilisé pour identifier cette règle dans les calculs',
                                child: Icon(Icons.help_outline_rounded, size: 14, color: _textMuted.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _codeCtrl,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Séquence ? (Image 2: 5)
                    Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Row(
                            children: [
                              const Text('Séquence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted)),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Ordre d\'exécution de la règle dans la structure',
                                child: Icon(Icons.help_outline_rounded, size: 14, color: _textMuted.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _sequenceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Checkboxes: Actif, Non Périodique, Apparaît sur le bulletin (Image 2)
                    _buildCheckboxRow('Actif', 'Indique si la règle est active dans la structure', _isActive, (v) => setState(() => _isActive = v)),
                    _buildCheckboxRow('Non Périodique', 'Indique si la règle ne s\'applique pas automatiquement chaque mois', _isNonPeriodic, (v) => setState(() => _isNonPeriodic = v)),
                    _buildCheckboxRow('Apparaît sur le bulletin de paie', 'Affiche cette ligne sur le bulletin imprimé', _appearsOnPayslip, (v) => setState(() => _appearsOnPayslip = v)),

                    const SizedBox(height: 16),

                    // 3. SUB-TABS (Image 2: Général, Règles enfant, Accounting, Entrées, Description)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _borderLight, width: 1.5)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: const Color(0xFF6B46C1),
                        unselectedLabelColor: _textMuted,
                        indicatorColor: const Color(0xFF6B46C1),
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        tabs: const [
                          Tab(text: 'Général'),
                          Tab(text: 'Règles enfant'),
                          Tab(text: 'Accounting'),
                          Tab(text: 'Entrées'),
                          Tab(text: 'Description'),
                        ],
                      ),
                    ),

                    // Sub-Tabs content
                    SizedBox(
                      height: 320,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Général (Matching Image 3)
                          _buildGeneralTab(),

                          // Tab 2: Règles enfant
                          _buildChildRulesTab(),

                          // Tab 3: Accounting
                          _buildAccountingTab(),

                          // Tab 4: Entrées
                          _buildInputsTab(),

                          // Tab 5: Description
                          _buildDescriptionTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. BOTTOM ACTION BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: _surfaceLight,
                border: Border(top: BorderSide(color: _borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textMuted,
                      side: const BorderSide(color: _borderLight),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _saveRule,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Enregistrer & Appliquer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
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

  // ---------------------------------------------------------------------------
  // TAB 1: GÉNÉRAL (Image 3)
  // ---------------------------------------------------------------------------
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CONDITIONS (Image 3)
          const Text(
            'CONDITIONS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: _textDark),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const SizedBox(
                width: 160,
                child: Text('Condition basée sur', style: TextStyle(fontSize: 12.5, color: _textMuted, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _conditionsList.contains(_conditionBasedOn) ? _conditionBasedOn : 'Toujours vrai',
                    isDense: true,
                    items: _conditionsList.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, color: _textDark)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _conditionBasedOn = val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 28),

          // CALCUL (Image 3)
          const Text(
            'CALCUL',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: _textDark),
          ),
          const SizedBox(height: 10),

          // Type de montant ? (Image 3)
          Row(
            children: [
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    const Text('Type de montant', style: TextStyle(fontSize: 12.5, color: _textMuted, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Mode de calcul appliqué (Montant fixe, Pourcentage ou Code Python)',
                      child: Icon(Icons.help_outline_rounded, size: 14, color: _textMuted.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _amountTypesList.contains(_amountType) ? _amountType : 'Montant fixe',
                    isDense: true,
                    items: _amountTypesList.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13, color: _textDark)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _amountType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Quantité ? (Image 3: 1.0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Quantité', style: TextStyle(fontSize: 12.5, color: _textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Multiplicateur appliqué au montant',
                    child: Icon(Icons.help_outline_rounded, size: 14, color: _textMuted.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _quantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Montant fixe (Image 3)
          if (_amountType == 'Montant fixe') ...[
            Row(
              children: [
                const SizedBox(
                  width: 160,
                  child: Text('Montant fixe', style: TextStyle(fontSize: 12.5, color: _textMuted, fontWeight: FontWeight.w500)),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _fixedAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      suffixText: 'DT',
                      suffixStyle: TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.bold),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_amountType == 'Pourcentage (%)') ...[
            Row(
              children: [
                const SizedBox(
                  width: 160,
                  child: Text('Pourcentage (%)', style: TextStyle(fontSize: 12.5, color: _textMuted, fontWeight: FontWeight.w500)),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _percentageCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      suffixText: '%',
                      suffixStyle: TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.bold),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 28),

          // CONTRIBUTION DE LA SOCIÉTÉ (Image 3)
          const Text(
            'CONTRIBUTION DE LA SOCIÉTÉ',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: _textDark),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    const Text('Registre de contribution', style: TextStyle(fontSize: 12.5, color: _textMuted, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Registre tiers recevant la contribution (ex: CNSS, Mutuelle)',
                      child: Icon(Icons.help_outline_rounded, size: 14, color: _textMuted.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _contributionRegisterCtrl,
                  style: const TextStyle(fontSize: 13, color: _textDark),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
                    hintText: 'Cotisations patronales',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: RÈGLES ENFANT
  // ---------------------------------------------------------------------------
  Widget _buildChildRulesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined, size: 40, color: _textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            const Text(
              'Aucune règle enfant rattachée',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Les règles enfants héritent automatiquement des conditions de cette règle.',
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: ACCOUNTING
  // ---------------------------------------------------------------------------
  Widget _buildAccountingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PARAMÈTRES COMPTABLES', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _textDark, letterSpacing: 0.6)),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 140, child: Text('Compte de débit', style: TextStyle(fontSize: 12.5, color: _textMuted))),
              Expanded(
                child: TextField(
                  controller: _debitAccountCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 140, child: Text('Compte de crédit', style: TextStyle(fontSize: 12.5, color: _textMuted))),
              Expanded(
                child: TextField(
                  controller: _creditAccountCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: ENTRÉES
  // ---------------------------------------------------------------------------
  Widget _buildInputsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.input_rounded, size: 36, color: _textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              'Code d\'entrée : ${_codeCtrl.text.isNotEmpty ? _codeCtrl.text : "P1"}_INPUT',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryBlue),
            ),
            const SizedBox(height: 4),
            const Text(
              'Utilisé par les lots de paie pour surcharger le montant d\'indemnité mensuel.',
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: DESCRIPTION
  // ---------------------------------------------------------------------------
  Widget _buildDescriptionTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: TextField(
        controller: _descriptionCtrl,
        maxLines: 6,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Saisissez une description détaillée ou la convention collective applicable...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderLight)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(String label, String tooltip, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted)),
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  child: Icon(Icons.help_outline_rounded, size: 14, color: _textMuted.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Checkbox(
            value: value,
            activeColor: const Color(0xFF6B46C1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
