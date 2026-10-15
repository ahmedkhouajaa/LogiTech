import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_state.dart';
import '../models/cnss_declaration.dart';
import '../models/employee.dart';
import '../models/payslip.dart';
import '../services/cnss_declaration_service.dart';
import '../services/cnss_pdf_service.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';

/// Écran complet de Déclaration Trimestrielle CNSS (Screenshots 1 & 2)
/// Permet de sélectionner les employés, renseigner le trimestre, l'année,
/// calculer les salaires bruts des 3 mois et [Générer le fichier] PDF officiel (Image 3).
class HrCnssDeclarationScreen extends StatefulWidget {
  const HrCnssDeclarationScreen({super.key});

  @override
  State<HrCnssDeclarationScreen> createState() => _HrCnssDeclarationScreenState();
}

class _HrCnssDeclarationScreenState extends State<HrCnssDeclarationScreen> {
  static const Color _odooPurple = Color(0xFF1A56DB);
  static const Color _odooLightBg = Color(0xFFF9FAFB);

  late CnssDeclaration _currentDeclaration;
  bool _isEditingEmployerDetails = false;
  bool _isSaving = false;

  final TextEditingController _employerNumberCtrl = TextEditingController();
  final TextEditingController _exploitationCodeCtrl = TextEditingController();
  final TextEditingController _companyNameCtrl = TextEditingController();
  final TextEditingController _companyAddressCtrl = TextEditingController();
  final TextEditingController _taxIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    CnssDeclarationService.instance.addListener(_onServiceChanged);
    _loadInitialDeclaration();
  }

  @override
  void dispose() {
    CnssDeclarationService.instance.removeListener(_onServiceChanged);
    _employerNumberCtrl.dispose();
    _exploitationCodeCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      final updated = CnssDeclarationService.instance.getDeclaration(_currentDeclaration.id);
      if (updated != null) {
        setState(() => _currentDeclaration = updated);
      }
    }
  }

  void _loadInitialDeclaration() {
    final list = CnssDeclarationService.instance.declarations;
    if (list.isNotEmpty) {
      _currentDeclaration = list.first;
    } else {
      _currentDeclaration = CnssDeclarationService.instance.createNewDeclaration(
        quarter: 4,
        year: 2024,
      );
    }
    _syncControllers();
  }

  void _syncControllers() {
    _employerNumberCtrl.text = _currentDeclaration.employerNumber;
    _exploitationCodeCtrl.text = _currentDeclaration.exploitationCode;
    _companyNameCtrl.text = _currentDeclaration.companyName;
    _companyAddressCtrl.text = _currentDeclaration.companyAddress;
    _taxIdCtrl.text = _currentDeclaration.taxIdNumber;
  }

  void _createNewDeclaration() {
    setState(() {
      _currentDeclaration = CnssDeclarationService.instance.createNewDeclaration();
      _syncControllers();
    });
  }

  void _selectDeclaration(CnssDeclaration declaration) {
    setState(() {
      _currentDeclaration = declaration;
      _syncControllers();
    });
  }

  Future<void> _saveCurrent() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      _currentDeclaration = _currentDeclaration.copyWith(
        employerNumber: _employerNumberCtrl.text.trim(),
        exploitationCode: _exploitationCodeCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        companyAddress: _companyAddressCtrl.text.trim(),
        taxIdNumber: _taxIdCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );
      await CnssDeclarationService.instance.saveDeclaration(_currentDeclaration);
      if (mounted) {
        final isOnline = ConnectivityService.instance.isOnline;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Déclaration CNSS enregistrée avec succès'
                        : 'Déclaration CNSS enregistrée hors ligne - synchronisation en attente',
                  ),
                ),
              ],
            ),
            backgroundColor: isOnline ? AppColors.success : AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setStatus(String status) async {
    if (status == 'done') {
      final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!allowed) return;
    }
    setState(() {
      _currentDeclaration = _currentDeclaration.copyWith(status: status);
    });
    _saveCurrent();
  }

  // Dialogue de sélection des employés pour alimenter la déclaration
  Future<void> _showEmployeeSelectionDialog(List<Employee> allEmployees, List<Payslip> allPayslips) async {
    final Set<String> selectedIds = _currentDeclaration.lines.map((l) => l.employeeId).toSet();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: _odooPurple, size: 22),
                  const SizedBox(width: 8),
                  const Text('Sélectionner les employés à déclarer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 550,
                height: 400,
                child: Column(
                  children: [
                    // Barre de sélection globale
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${selectedIds.length} sélectionné(s) sur ${allEmployees.length}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (selectedIds.length == allEmployees.length) {
                                selectedIds.clear();
                              } else {
                                selectedIds.addAll(allEmployees.map((e) => e.id));
                              }
                            });
                          },
                          child: Text(selectedIds.length == allEmployees.length ? 'Tout désélectionner' : 'Tout sélectionner',
                              style: const TextStyle(fontSize: 12, color: _odooPurple, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: allEmployees.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final emp = allEmployees[index];
                          final isSelected = selectedIds.contains(emp.id);
                          return CheckboxListTile(
                            dense: true,
                            activeColor: _odooPurple,
                            value: isSelected,
                            title: Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(
                              'CNSS: ${emp.cnssNumber ?? emp.socialSecurityNumber ?? "Non renseigné"} • Poste: ${emp.jobTitle}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIds.add(emp.id);
                                } else {
                                  selectedIds.remove(emp.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final chosen = allEmployees.where((e) => selectedIds.contains(e.id)).toList();
                    final updated = CnssDeclarationService.instance.populateLinesFromEmployees(
                      _currentDeclaration,
                      chosen,
                      payslips: allPayslips,
                    );
                    setState(() {
                      _currentDeclaration = updated;
                    });
                    _saveCurrent();
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Valider la sélection', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Éditer manuellement une ligne d'employé
  Future<void> _editLineDialog(CnssDeclarationLine line) async {
    final nameCtrl = TextEditingController(text: line.employeeName);
    final cnssCtrl = TextEditingController(text: line.cnssNumber);
    final regCtrl = TextEditingController(text: line.employerRegistrationNumber);
    final catCtrl = TextEditingController(text: line.professionalCategory);
    final m1Ctrl = TextEditingController(text: line.grossMonth1.toStringAsFixed(2));
    final m2Ctrl = TextEditingController(text: line.grossMonth2.toStringAsFixed(2));
    final m3Ctrl = TextEditingController(text: line.grossMonth3.toStringAsFixed(2));

    final monthNames = _currentDeclaration.monthLabels;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('Modifier les salaires - ${line.employeeName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: cnssCtrl,
                    decoration: const InputDecoration(labelText: 'Numéro CNSS', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: catCtrl,
                          decoration: const InputDecoration(labelText: 'Catégorie prof.', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: regCtrl,
                          decoration: const InputDecoration(labelText: 'N° chez employeur', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Salaires bruts déclarés :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: m1Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '1er mois (${monthNames[0]})',
                      border: const OutlineInputBorder(),
                      suffixText: _currentDeclaration.currency,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: m2Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '2ème mois (${monthNames[1]})',
                      border: const OutlineInputBorder(),
                      suffixText: _currentDeclaration.currency,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: m3Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '3ème mois (${monthNames[2]})',
                      border: const OutlineInputBorder(),
                      suffixText: _currentDeclaration.currency,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedLines = _currentDeclaration.lines.map((l) {
                  if (l.id == line.id) {
                    return l.copyWith(
                      employeeName: nameCtrl.text.trim(),
                      cnssNumber: cnssCtrl.text.trim(),
                      employerRegistrationNumber: regCtrl.text.trim(),
                      professionalCategory: catCtrl.text.trim(),
                      grossMonth1: double.tryParse(m1Ctrl.text.replaceAll(',', '.')) ?? 0.0,
                      grossMonth2: double.tryParse(m2Ctrl.text.replaceAll(',', '.')) ?? 0.0,
                      grossMonth3: double.tryParse(m3Ctrl.text.replaceAll(',', '.')) ?? 0.0,
                    );
                  }
                  return l;
                }).toList();

                setState(() {
                  _currentDeclaration = _currentDeclaration.copyWith(lines: updatedLines);
                });
                _saveCurrent();
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _odooPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _removeLine(String lineId) {
    final updated = _currentDeclaration.lines.where((l) => l.id != lineId).toList();
    // Ré-indexer les numéros de ligne
    for (int i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(lineNumber: i + 1);
    }
    setState(() {
      _currentDeclaration = _currentDeclaration.copyWith(lines: updated);
    });
    _saveCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
        final activeEmployees = employees.where((e) => e.isActive).toList();

        return BlocBuilder<PayrollBloc, PayrollState>(
          builder: (context, payrollState) {
            final payslips = payrollState is PayrollLoaded ? payrollState.payslips : <Payslip>[];

            return Scaffold(
              backgroundColor: _odooLightBg,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP NAV BAR (Odoo Paie Style - Screenshot 1 & 2)
                  _buildTopNavigationBar(),

                  // 2. SUB-ACTION BAR ([Imprimer] [Générer le fichier] ... Status: [Brouillon | Fait])
                  _buildSubActionBar(activeEmployees, payslips),

                  // 3. MAIN FORM BODY
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // FORMULAIRE PRINCIPAL (Trimestre, Année, Type contrat, Date déclaration)
                          _buildDeclarationHeaderCard(),

                          const SizedBox(height: 16),

                          // TABLEAU DES SALARIES DECLARES (Screenshots 1 & 2)
                          _buildEmployeesTableCard(activeEmployees, payslips),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 1. BARRE DE NAVIGATION SUPÉRIEURE ODOO PAIE
  Widget _buildTopNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Bouton Nouveau
          ElevatedButton(
            onPressed: _createNewDeclaration,
            style: ElevatedButton.styleFrom(
              backgroundColor: _odooPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
          const SizedBox(width: 14),

          // Breadcrumb : hr.cnss / 4-2024
          const Text(
            'hr.cnss',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          const Text('/', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          const SizedBox(width: 6),
          Text(
            _currentDeclaration.reference,
            style: const TextStyle(fontSize: 14, color: _odooPurple, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.settings_outlined, size: 15, color: Color(0xFF94A3B8)),

          const Spacer(),

          // Sélecteur de déclarations existantes
          PopupMenuButton<CnssDeclaration>(
            tooltip: 'Déclarations existantes',
            onSelected: _selectDeclaration,
            itemBuilder: (context) {
              return CnssDeclarationService.instance.declarations.map((d) {
                return PopupMenuItem(
                  value: d,
                  child: Row(
                    children: [
                      Icon(Icons.assignment_outlined, size: 16, color: d.id == _currentDeclaration.id ? _odooPurple : Colors.grey),
                      const SizedBox(width: 8),
                      Text(d.reference, style: TextStyle(fontWeight: d.id == _currentDeclaration.id ? FontWeight.bold : FontWeight.normal)),
                      const Spacer(),
                      Text('T${d.quarter} ${d.year}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 15, color: Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Text('Historique (${CnssDeclarationService.instance.declarations.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. BARRE D'ACTIONS CONFORME SCREENSHOTS 1 & 2
  Widget _buildSubActionBar(List<Employee> allEmployees, List<Payslip> allPayslips) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Bouton [Imprimer] (Screenshot 1 & 2)
          OutlinedButton.icon(
            onPressed: () => CnssPdfService.instance.printDeclaration(context, _currentDeclaration),
            icon: const Icon(Icons.print_outlined, size: 15, color: Color(0xFF475569)),
            label: const Text('Imprimer', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton [Générer le fichier] (Screenshot 1 & 2) -> Déclenche le PDF officiel Image 3 avec partage
          ElevatedButton.icon(
            onPressed: () => CnssPdfService.instance.showPreviewDialog(context, _currentDeclaration),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Colors.white),
            label: const Text('Générer le fichier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _odooPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton [Sélectionner les employés]
          OutlinedButton.icon(
            onPressed: () => _showEmployeeSelectionDialog(allEmployees, allPayslips),
            icon: const Icon(Icons.group_add_outlined, size: 15, color: Color(0xFF0D9488)),
            label: const Text('Sélectionner les employés', style: TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              side: const BorderSide(color: Color(0xFF99F6E4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),

          // Enregistrer
          IconButton(
            tooltip: 'Enregistrer les modifications',
            onPressed: _isSaving ? null : _saveCurrent,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _odooPurple),
                  )
                : const Icon(Icons.save_outlined, size: 20, color: _odooPurple),
          ),

          const Spacer(),

          // Pipeline d'état : [Brouillon] [Fait] (Screenshot 1 & 2)
          _buildStatusPipeline(),
        ],
      ),
    );
  }

  // Pipeline Odoo : Brouillon | Fait
  Widget _buildStatusPipeline() {
    final isDraft = _currentDeclaration.isDraft;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brouillon
          InkWell(
            onTap: () => _setStatus('draft'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDraft ? _odooPurple : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
              ),
              child: Text(
                'Brouillon',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isDraft ? FontWeight.bold : FontWeight.w500,
                  color: isDraft ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          // Fait
          InkWell(
            onTap: () => _setStatus('done'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: !isDraft ? const Color(0xFF10B981) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
              ),
              child: Text(
                'Fait',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: !isDraft ? FontWeight.bold : FontWeight.w500,
                  color: !isDraft ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. CARTE FORMULAIRE PRINCIPAL (Trimestre, Année, Type contrat, Date de déclaration)
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: Color(0xFF334155),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: Color(0xFFE11D48),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSleekDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSleekDatePicker({
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclarationHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : Trimestre & Année
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trimestre *
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Trimestre', isRequired: true),
                    _buildSleekDropdown<int>(
                      value: _currentDeclaration.quarter,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 (Janvier - Mars)')),
                        DropdownMenuItem(value: 2, child: Text('2 (Avril - Juin)')),
                        DropdownMenuItem(value: 3, child: Text('3 (Juillet - Septembre)')),
                        DropdownMenuItem(value: 4, child: Text('4 (Octobre - Décembre)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _currentDeclaration = _currentDeclaration.copyWith(
                              quarter: val,
                              reference: 'hr.cnss $val-${_currentDeclaration.year}',
                            );
                          });
                          _saveCurrent();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // Année *
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Année', isRequired: true),
                    _buildSleekDropdown<int>(
                      value: _currentDeclaration.year,
                      items: [2022, 2023, 2024, 2025, 2026, 2027, 2028].map((y) {
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _currentDeclaration = _currentDeclaration.copyWith(
                              year: val,
                              reference: 'hr.cnss ${_currentDeclaration.quarter}-$val',
                            );
                          });
                          _saveCurrent();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ligne 2 : Type de contrat & Date de déclaration
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type de contrat
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Type de contrat'),
                    _buildSleekDropdown<String>(
                      value: _currentDeclaration.contractType,
                      items: const [
                        DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                        DropdownMenuItem(value: 'CDD', child: Text('CDD')),
                        DropdownMenuItem(value: 'CDI', child: Text('CDI')),
                        DropdownMenuItem(value: 'SIVP', child: Text('SIVP')),
                        DropdownMenuItem(value: 'Tous', child: Text('Tous types de contrats')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _currentDeclaration = _currentDeclaration.copyWith(contractType: val);
                          });
                          _saveCurrent();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // Date de déclaration *
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Date de déclaration', isRequired: true),
                    _buildSleekDatePicker(
                      date: _currentDeclaration.declarationDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _currentDeclaration.declarationDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() {
                            _currentDeclaration = _currentDeclaration.copyWith(declarationDate: picked);
                          });
                          _saveCurrent();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Volet dépliable : Informations Employeur / Entreprise (N° Employeur, Code exploitation, Adresse)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _isEditingEmployerDetails,
              onExpansionChanged: (val) => setState(() => _isEditingEmployerDetails = val),
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  const Icon(Icons.business_outlined, size: 16, color: _odooPurple),
                  const SizedBox(width: 6),
                  Text(
                    'Informations Employeur (N° CNSS: ${_currentDeclaration.employerNumber} • Code: ${_currentDeclaration.exploitationCode})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _odooPurple),
                  ),
                ],
              ),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _employerNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'N° Employeur CNSS',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _currentDeclaration = _currentDeclaration.copyWith(employerNumber: v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _exploitationCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Code d\'exploitation',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _currentDeclaration = _currentDeclaration.copyWith(exploitationCode: v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _taxIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Matricule fiscal / NIF',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _currentDeclaration = _currentDeclaration.copyWith(taxIdNumber: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _companyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom de l\'employeur / Société',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _currentDeclaration = _currentDeclaration.copyWith(companyName: v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _companyAddressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse de l\'entreprise',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _currentDeclaration = _currentDeclaration.copyWith(companyAddress: v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. TABLEAU DES SALARIES DECLARES (Exactement Screenshots 1 & 2)
  Widget _buildEmployeesTableCard(List<Employee> allEmployees, List<Payslip> allPayslips) {
    final lines = _currentDeclaration.lines;
    final currency = _currentDeclaration.currency;
    final f = NumberFormat('#,##0.00', 'fr_FR');
    final monthNames = _currentDeclaration.monthLabels;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête du tableau avec titre et bouton d'action rapide
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.table_rows_rounded, size: 18, color: _odooPurple),
                const SizedBox(width: 8),
                Text(
                  'Salariés et salaires déclarés (${lines.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showEmployeeSelectionDialog(allEmployees, allPayslips),
                  icon: const Icon(Icons.add, size: 16, color: _odooPurple),
                  label: const Text('Ajouter un employé', style: TextStyle(color: _odooPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tableau de données horizontalement scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1000),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 48,
                columnSpacing: 18,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                columns: [
                  const DataColumn(label: Text('page')),
                  const DataColumn(label: Text('ligne')),
                  const DataColumn(label: Text('Numéro de séc...')),
                  const DataColumn(label: Text('Employé')),
                  const DataColumn(label: Text('Numéro d\'enre...')),
                  const DataColumn(label: Text('Catégorie prof...')),
                  DataColumn(label: Text('brut ${monthNames[0]}')),
                  DataColumn(label: Text('brut ${monthNames[1]}')),
                  DataColumn(label: Text('brut ${monthNames[2]}')),
                  const DataColumn(label: Text('Total')),
                  const DataColumn(label: Text('Société')),
                  const DataColumn(label: Text('')),
                ],
                rows: lines.map((l) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${l.page}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                      DataCell(Text('${l.lineNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(l.cnssNumber, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                      DataCell(Text(l.employeeName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                      DataCell(Text(l.employerRegistrationNumber, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l.professionalCategory, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Text('${f.format(l.grossMonth1)} $currency', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${f.format(l.grossMonth2)} $currency', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${f.format(l.grossMonth3)} $currency', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                        '${f.format(l.total)} $currency',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _odooPurple),
                      )),
                      DataCell(Text(l.companyName, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                            tooltip: 'Modifier les montants',
                            onPressed: () => _editLineDialog(l),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            tooltip: 'Supprimer',
                            onPressed: () => _removeLine(l.id),
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.playlist_add_rounded, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    const Text('Aucun employé dans cette déclaration',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    const Text('Cliquez sur "Sélectionner les employés" ci-dessus pour charger les salariés.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showEmployeeSelectionDialog(allEmployees, allPayslips),
                      icon: const Icon(Icons.group_add, size: 16),
                      label: const Text('Sélectionner les employés'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _odooPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // BARRE RÉCAPITULATIVE DES TOTAUX (Image 2 & 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      '${lines.length} salarié(s) déclaré(s) au titre du ${_currentDeclaration.quarterLabel}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('TOTAL DÉCLARÉ : ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: Text(
                        _currentDeclaration.formattedTotal(_currentDeclaration.totalQuarter),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _odooPurple),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
