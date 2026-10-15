import 'package:flutter/material.dart';
import '../models/salary_rule.dart';
import 'salary_rule_dialog.dart';

/// Dialogue Structure Salariale conforme à Odoo ERP (Images 1, 2, 3 & 4)
/// Permet de consulter la structure, visualiser les règles (TRANCHE0, IRPP, etc.)
/// et d'ajouter de nouvelles règles via le modal "Ajouter : Règles salariales" (notamment "Absence / ABS").
class SalaryStructureDialog extends StatefulWidget {
  final String structureName;
  final Function(SalaryRule)? onRuleAdded;
  final Function(List<SalaryRule>)? onRulesUpdated;

  const SalaryStructureDialog({
    super.key,
    this.structureName = 'Standard',
    this.onRuleAdded,
    this.onRulesUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    String? structureName,
    Function(SalaryRule)? onRuleAdded,
    Function(List<SalaryRule>)? onRulesUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SalaryStructureDialog(
        structureName: structureName ?? 'Standard',
        onRuleAdded: onRuleAdded,
        onRulesUpdated: onRulesUpdated,
      ),
    );
  }

  @override
  State<SalaryStructureDialog> createState() => _SalaryStructureDialogState();
}

class _SalaryStructureDialogState extends State<SalaryStructureDialog> {
  static const Color _odooPurple = Color(0xFF1A56DB);
  static const Color _odooPurpleLight = Color(0xFFEFF6FF);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  // Active rules in this Salary Structure (Image 4 background)
  late List<Map<String, dynamic>> _structureRules;

  @override
  void initState() {
    super.initState();
    _structureRules = [
      {'name': 'TRANCHE0', 'code': 'TRANCHE0', 'category': 'Déduction', 'sequence': 10, 'formula': 'Barème 0 - 5 000 DT'},
      {'name': 'TRANCHE1', 'code': 'TRANCHE1', 'category': 'Déduction', 'sequence': 20, 'formula': 'Barème 5 000 - 20 000 DT'},
      {'name': 'TRANCHE2', 'code': 'TRANCHE2', 'category': 'Déduction', 'sequence': 30, 'formula': 'Barème 20 000 - 30 000 DT'},
      {'name': 'TRANCHE3', 'code': 'TRANCHE3', 'category': 'Déduction', 'sequence': 40, 'formula': 'Barème 30 000 - 50 000 DT'},
      {'name': 'TRANCHES', 'code': 'TRANCHES', 'category': 'Déduction', 'sequence': 50, 'formula': 'Barème > 50 000 DT'},
      {'name': 'IRPP', 'code': 'IRPP', 'category': 'Déduction', 'sequence': 60, 'formula': 'Somme des tranches fiscales'},
      {'name': 'Total Déductions d\'impôt', 'code': 'TAX_DED', 'category': 'Déduction', 'sequence': 70, 'formula': 'Déductions chef de famille & enfants'},
      {'name': 'Contribution Sociale Solidaire', 'code': 'CSS', 'category': 'Déduction', 'sequence': 80, 'formula': 'NET_IMP × 1.0%'},
      {'name': 'Avance sur salaire', 'code': 'ADV', 'category': 'Déduction', 'sequence': 90, 'formula': 'Avances accordées dans le mois'},
      {'name': 'Remboursement de prêt', 'code': 'LOAN', 'category': 'Déduction', 'sequence': 100, 'formula': 'Échéance mensuelle de prêt'},
      {'name': 'Nouvelle arrondi', 'code': 'ROUND', 'category': 'Autre', 'sequence': 110, 'formula': 'Arrondi au millime près'},
      {'name': 'Salaire Net', 'code': 'NET', 'category': 'Net', 'sequence': 200, 'formula': 'Brut - Déductions'},
    ];
  }

  // Open "Ajouter : Règles salariales" Modal (Image 4)
  void _openAddRuleModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AddSalaryRulesModal(
        onRuleSelected: (rule) {
          setState(() {
            // Check if rule already exists
            final exists = _structureRules.any((r) => r['code'] == rule.code);
            if (!exists) {
              _structureRules.insert(0, {
                'name': rule.name,
                'code': rule.code,
                'category': rule.category,
                'sequence': rule.sequence,
                'formula': rule.code == 'ABS' ? 'Soustraire absence non rémunérée' : (rule.description ?? 'Règle active'),
              });
            }
          });

          widget.onRuleAdded?.call(rule);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _odooPurple,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Règle "${rule.name} (${rule.code})" ajoutée à la structure ${widget.structureName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 750;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? media.size.width * 0.98 : 960,
          maxHeight: isMobile ? media.size.height * 0.94 : 740,
        ),
        child: Column(
          children: [
            // Top Header matching Image 4
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: _borderLight)),
              ),
              child: Row(
                children: [
                  // Button "Nouveau"
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _odooPurple,
                      side: const BorderSide(color: _odooPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      SalaryRuleDialog.show(context);
                    },
                    child: const Text('Nouveau', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),

                  // Breadcrumb title: Fiches de Paie des Employés / Standard
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Fiches de Paie des Employés / ',
                          style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          widget.structureName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.settings_outlined, size: 16, color: _textMuted),
                      ],
                    ),
                  ),

                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: _textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Structure Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _odooPurpleLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _odooPurple.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem('Nom de structure', widget.structureName),
                          ),
                          Expanded(
                            child: _buildInfoItem('Code', 'STRUCT_${widget.structureName.toUpperCase().replaceAll(' ', '_')}'),
                          ),
                          Expanded(
                            child: _buildInfoItem('Type de salaire', 'Mensuel / Standard'),
                          ),
                          if (!isMobile)
                            Expanded(
                              child: _buildInfoItem('Règles actives', '${_structureRules.length} règles'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Rules Table Title
                    Row(
                      children: [
                        const Icon(Icons.format_list_bulleted_rounded, size: 18, color: _odooPurple),
                        const SizedBox(width: 8),
                        const Text(
                          'Règles Salariales Associées à la Structure',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _odooPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          onPressed: _openAddRuleModal,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter une ligne', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rules Table (Image 4 background)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderLight),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          children: [
                            Container(
                              color: const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: const Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Nom de la règle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Catégorie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text('Calcul / Formule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                                  SizedBox(width: 45, child: Text('', textAlign: TextAlign.center)),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: _borderLight),

                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _structureRules.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, idx) {
                                final r = _structureRules[idx];
                                final isAbsence = r['code'] == 'ABS';

                                return Container(
                                  color: isAbsence ? const Color(0xFFFEF2F2) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            if (isAbsence) ...[
                                              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                r['name'] ?? '',
                                                style: TextStyle(
                                                  fontWeight: isAbsence ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isAbsence ? Colors.red.shade900 : _textDark,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          r['code'] ?? '',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAbsence ? Colors.red : _odooPurple),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          r['category'] ?? '',
                                          style: const TextStyle(fontSize: 12, color: _textMuted),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          r['formula'] ?? '',
                                          style: TextStyle(fontSize: 12, color: isAbsence ? Colors.red.shade700 : const Color(0xFF334155), fontStyle: isAbsence ? FontStyle.italic : FontStyle.normal),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 45,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                                          tooltip: 'Retirer',
                                          onPressed: () {
                                            setState(() {
                                              _structureRules.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // "Ajouter une ligne" at bottom of table
                    TextButton.icon(
                      onPressed: _openAddRuleModal,
                      icon: const Icon(Icons.add, size: 16, color: _odooPurple),
                      label: const Text('Ajouter une ligne', style: TextStyle(color: _odooPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11.5, color: _textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Modal : "Ajouter : Règles salariales" matching Image 4
class _AddSalaryRulesModal extends StatefulWidget {
  final Function(SalaryRule) onRuleSelected;

  const _AddSalaryRulesModal({required this.onRuleSelected});

  @override
  State<_AddSalaryRulesModal> createState() => _AddSalaryRulesModalState();
}

class _AddSalaryRulesModalState extends State<_AddSalaryRulesModal> {
  static const Color _odooPurple = Color(0xFF1A56DB);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  SalaryRule? _selectedRule;

  // Complete rules matching Image 4
  final List<SalaryRule> _allRules = [
    const SalaryRule(
      id: 'rule_basic',
      name: 'Salaire de base',
      code: 'BASIC',
      category: 'Basique',
      sequence: 10,
      contributionRegister: null,
      description: 'Salaire de base contractuel',
    ),
    const SalaryRule(
      id: 'rule_sivp',
      name: 'Indemnité SIVP',
      code: 'BASIC',
      category: 'Basique',
      sequence: 10,
      contributionRegister: null,
      description: 'Allocation pour stage d\'initiation',
    ),
    const SalaryRule(
      id: 'rule_basehr',
      name: 'Salaire de Base Horaire',
      code: 'BASEHR',
      category: 'Basique',
      sequence: 10,
      contributionRegister: null,
      description: 'Taux horaire de base',
    ),
    const SalaryRule(
      id: 'rule_p1_prime',
      name: 'prime',
      code: 'P1',
      category: 'Allocation',
      sequence: 20,
      contributionRegister: null,
      description: 'Prime variable',
    ),
    const SalaryRule(
      id: 'rule_p1_capital',
      name: 'Prime',
      code: 'P1',
      category: 'Allocation',
      sequence: 20,
      contributionRegister: null,
      description: 'Prime générale',
    ),
    // ABSENCE RULE (Requested by User & Featured in Image 4!)
    const SalaryRule(
      id: 'rule_abs',
      name: 'Absence',
      code: 'ABS',
      category: 'Allocation',
      sequence: 25,
      contributionRegister: 'Déduction sur salaire non rémunéré',
      description: 'Soustraire les absences non rémunérées et congés sans solde',
    ),
    const SalaryRule(
      id: 'rule_panier',
      name: 'Prime de panier',
      code: 'INDMPP',
      category: 'Allocation',
      sequence: 30,
      contributionRegister: null,
      description: 'Indemnité de panier journalier',
    ),
    const SalaryRule(
      id: 'rule_diff',
      name: 'Prime différentielle',
      code: 'INDMPDF',
      category: 'Allocation',
      sequence: 35,
      contributionRegister: null,
      description: 'Prime compensatoire différentielle',
    ),
    const SalaryRule(
      id: 'rule_autre_prime',
      name: 'Autre Prime',
      code: 'INDMAP',
      category: 'Allocation',
      sequence: 40,
      contributionRegister: null,
      description: 'Indemnité complémentaire diverse',
    ),
    const SalaryRule(
      id: 'rule_cnss',
      name: 'CNSS',
      code: 'CNSS',
      category: 'Total Charges Salariales',
      sequence: 100,
      contributionRegister: 'La Caisse Nationale de Sécurité Sociale',
      description: 'Cotisation CNSS Salariale (9.18%)',
    ),
    const SalaryRule(
      id: 'rule_css',
      name: 'CSS',
      code: 'CSS',
      category: 'Déduction',
      sequence: 110,
      contributionRegister: 'Cotisation de Solidarité',
      description: 'Contribution Sociale de Solidarité 1%',
    ),
    const SalaryRule(
      id: 'rule_irpp',
      name: 'IRPP',
      code: 'IRPP',
      category: 'Déduction',
      sequence: 120,
      contributionRegister: 'Retenue à la source fiscale',
      description: 'Impôt sur le Revenu des Personnes Physiques',
    ),
    const SalaryRule(
      id: 'rule_avance',
      name: 'Avance sur salaire',
      code: 'ADV',
      category: 'Déduction',
      sequence: 130,
      contributionRegister: null,
      description: 'Retenue sur avances accordées',
    ),
    const SalaryRule(
      id: 'rule_pret',
      name: 'Remboursement de prêt',
      code: 'LOAN',
      category: 'Déduction',
      sequence: 140,
      contributionRegister: null,
      description: 'Échéance de prêt collaborateur',
    ),
    const SalaryRule(
      id: 'rule_net',
      name: 'Salaire Net',
      code: 'NET',
      category: 'Net',
      sequence: 200,
      contributionRegister: null,
      description: 'Montant net final à payer',
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;

    final filtered = _allRules.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q) ||
          (r.contributionRegister ?? '').toLowerCase().contains(q);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 30,
        vertical: isMobile ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? media.size.width * 0.98 : 840,
          maxHeight: isMobile ? media.size.height * 0.94 : 640,
        ),
        child: Column(
          children: [
            // Modal Title (Image 4: "Ajouter : Règles salariales")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Text(
                    'Ajouter : Règles salariales',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Toolbar (Search, Filter, Pagination: 1-22 / 22 < >)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '1-${filtered.length} / ${filtered.length}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left, size: 18, color: Color(0xFF94A3B8)),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
            ),

            // Table Header matching Image 4
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: const [
                  SizedBox(width: 32),
                  Expanded(flex: 3, child: Text('Nom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 1, child: Text('Séquence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Registre de contribution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Table Content matching Image 4
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final rule = filtered[idx];
                  final isSelected = _selectedRule?.id == rule.id;
                  final isAbsence = rule.code == 'ABS';

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRule = rule;
                      });
                    },
                    hoverColor: const Color(0xFFF8FAFC),
                    child: Container(
                      color: isSelected
                          ? const Color(0xFFE0F2FE) // Selected highlight like Image 4
                          : (isAbsence ? const Color(0xFFFEF2F2).withValues(alpha: 0.5) : Colors.transparent),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: _odooPurple,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) {
                                setState(() {
                                  _selectedRule = val == true ? rule : null;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              rule.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: (isSelected || isAbsence) ? FontWeight.bold : FontWeight.w500,
                                color: isAbsence ? Colors.red.shade900 : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              rule.code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isAbsence ? Colors.red : _odooPurple,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              rule.category,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${rule.sequence}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              rule.contributionRegister ?? '',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Footer (Image 4: Sélectionner | Nouveau | Fermer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _odooPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _odooPurple.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: _selectedRule == null
                        ? null
                        : () {
                            widget.onRuleSelected(_selectedRule!);
                            Navigator.of(context).pop();
                          },
                    child: const Text('Sélectionner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _odooPurple,
                      side: const BorderSide(color: _odooPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      SalaryRuleDialog.show(context);
                    },
                    child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer', style: TextStyle(fontSize: 13)),
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
