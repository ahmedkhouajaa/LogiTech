import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_state.dart';
import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../models/cnss_declaration.dart';
import '../../models/employee.dart';
import '../../models/payslip.dart';
import '../../services/cnss_declaration_service.dart';
import '../../services/cnss_pdf_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';

/// Écran tactile optimisé de Déclaration Trimestrielle CNSS pour Mobile / Android
class MobileHrCnssDeclarationScreen extends StatefulWidget {
  const MobileHrCnssDeclarationScreen({super.key});

  @override
  State<MobileHrCnssDeclarationScreen> createState() => _MobileHrCnssDeclarationScreenState();
}

class _MobileHrCnssDeclarationScreenState extends State<MobileHrCnssDeclarationScreen> {
  static const Color _odooPurple = Color(0xFF1A56DB);

  late CnssDeclaration _currentDeclaration;

  @override
  void initState() {
    super.initState();
    CnssDeclarationService.instance.addListener(_onServiceChanged);
    _loadInitialDeclaration();
  }

  @override
  void dispose() {
    CnssDeclarationService.instance.removeListener(_onServiceChanged);
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
  }

  bool _isSaving = false;

  void _createNew() {
    setState(() {
      _currentDeclaration = CnssDeclarationService.instance.createNewDeclaration();
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
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
                        ? 'Déclaration CNSS enregistrée'
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

  Future<void> _toggleStatus() async {
    final newStatus = _currentDeclaration.isDraft ? 'done' : 'draft';
    if (newStatus == 'done') {
      final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!allowed) return;
    }
    setState(() {
      _currentDeclaration = _currentDeclaration.copyWith(
        status: newStatus,
      );
    });
    _save();
  }

  // Sélection des employés via bottom-sheet
  Future<void> _showEmployeeSelectionSheet(List<Employee> allEmployees, List<Payslip> allPayslips) async {
    final Set<String> selectedIds = _currentDeclaration.lines.map((l) => l.employeeId).toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sélectionner les salariés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (selectedIds.length == allEmployees.length) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds.addAll(allEmployees.map((e) => e.id));
                                }
                              });
                            },
                            child: Text(selectedIds.length == allEmployees.length ? 'Désélectionner tout' : 'Tout sélectionner',
                                style: const TextStyle(color: _odooPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: allEmployees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final emp = allEmployees[index];
                            final isSel = selectedIds.contains(emp.id);
                            return CheckboxListTile(
                              dense: true,
                              activeColor: _odooPurple,
                              value: isSel,
                              title: Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('CNSS: ${emp.cnssNumber ?? "N/A"} • ${emp.jobTitle}', style: const TextStyle(fontSize: 11)),
                              onChanged: (val) {
                                setSheetState(() {
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
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          final chosen = allEmployees.where((e) => selectedIds.contains(e.id)).toList();
                          final updated = CnssDeclarationService.instance.populateLinesFromEmployees(
                            _currentDeclaration,
                            chosen,
                            payslips: allPayslips,
                          );
                          setState(() => _currentDeclaration = updated);
                          _save();
                          Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _odooPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Valider (${selectedIds.length} salariés)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Modifier les salaires bruts d'un employé
  Future<void> _editLineSheet(CnssDeclarationLine line) async {
    final m1Ctrl = TextEditingController(text: line.grossMonth1.toStringAsFixed(2));
    final m2Ctrl = TextEditingController(text: line.grossMonth2.toStringAsFixed(2));
    final m3Ctrl = TextEditingController(text: line.grossMonth3.toStringAsFixed(2));
    final catCtrl = TextEditingController(text: line.professionalCategory);
    final cnssCtrl = TextEditingController(text: line.cnssNumber);
    final monthNames = _currentDeclaration.monthLabels;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        line.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: cnssCtrl,
                        decoration: const InputDecoration(labelText: 'Numéro CNSS', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: catCtrl,
                        decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: m1Ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '1er mois (${monthNames[0]})',
                    border: const OutlineInputBorder(),
                    suffixText: _currentDeclaration.currency,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: m2Ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '2ème mois (${monthNames[1]})',
                    border: const OutlineInputBorder(),
                    suffixText: _currentDeclaration.currency,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: m3Ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '3ème mois (${monthNames[2]})',
                    border: const OutlineInputBorder(),
                    suffixText: _currentDeclaration.currency,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final updatedLines = _currentDeclaration.lines.map((l) {
                      if (l.id == line.id) {
                        return l.copyWith(
                          cnssNumber: cnssCtrl.text.trim(),
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
                    _save();
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              color: Color(0xFF475569),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: Color(0xFFE11D48),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMobileDatePicker({
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
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
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = _currentDeclaration.currency;
    final f = NumberFormat('#,##0.00', 'fr_FR');
    final monthNames = _currentDeclaration.monthLabels;

    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
        final activeEmployees = employees.where((e) => e.isActive).toList();

        return BlocBuilder<PayrollBloc, PayrollState>(
          builder: (context, payrollState) {
            final payslips = payrollState is PayrollLoaded ? payrollState.payslips : <Payslip>[];

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                backgroundColor: _odooPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Déclaration CNSS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      _currentDeclaration.reference,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE9D5FF)),
                    ),
                  ],
                ),
                actions: [
                  // Sélecteur d'historique
                  PopupMenuButton<CnssDeclaration>(
                    icon: const Icon(Icons.history_rounded),
                    tooltip: 'Historique des déclarations',
                    onSelected: (d) => setState(() => _currentDeclaration = d),
                    itemBuilder: (ctx) {
                      return CnssDeclarationService.instance.declarations.map((d) {
                        return PopupMenuItem(
                          value: d,
                          child: Text('${d.reference} (T${d.quarter} ${d.year})'),
                        );
                      }).toList();
                    },
                  ),
                  // Nouveau
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    tooltip: 'Nouvelle déclaration',
                    onPressed: _createNew,
                  ),
                ],
              ),
              body: Column(
                children: [
                  // 1. CARTE PARAMÈTRES (Trimestre, Année, Type contrat, Date, Statut)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1 : Trimestre & Année & Statut
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Trimestre
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMobileFieldLabel('Trimestre', isRequired: true),
                                  _buildMobileDropdown<int>(
                                    value: _currentDeclaration.quarter,
                                    items: const [
                                      DropdownMenuItem(value: 1, child: Text('T1 (Jan-Mar)')),
                                      DropdownMenuItem(value: 2, child: Text('T2 (Avr-Juin)')),
                                      DropdownMenuItem(value: 3, child: Text('T3 (Juil-Sep)')),
                                      DropdownMenuItem(value: 4, child: Text('T4 (Oct-Déc)')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _currentDeclaration = _currentDeclaration.copyWith(
                                            quarter: v,
                                            reference: 'hr.cnss $v-${_currentDeclaration.year}',
                                          );
                                        });
                                        _save();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Année
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMobileFieldLabel('Année', isRequired: true),
                                  _buildMobileDropdown<int>(
                                    value: _currentDeclaration.year,
                                    items: [2022, 2023, 2024, 2025, 2026, 2027, 2028].map((y) {
                                      return DropdownMenuItem(value: y, child: Text('$y'));
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _currentDeclaration = _currentDeclaration.copyWith(
                                            year: v,
                                            reference: 'hr.cnss ${_currentDeclaration.quarter}-$v',
                                          );
                                        });
                                        _save();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Statut Brouillon / Fait
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMobileFieldLabel('Statut'),
                                InkWell(
                                  onTap: _toggleStatus,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: _currentDeclaration.isDraft ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _currentDeclaration.isDraft ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _currentDeclaration.isDraft ? Icons.edit_note_rounded : Icons.check_circle_rounded,
                                          size: 15,
                                          color: _currentDeclaration.isDraft ? const Color(0xFFB45309) : const Color(0xFF065F46),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _currentDeclaration.isDraft ? 'Brouillon' : 'Fait',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: _currentDeclaration.isDraft ? const Color(0xFFB45309) : const Color(0xFF065F46),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Row 2 : Type de contrat & Date de déclaration
                        Row(
                          children: [
                            // Type de contrat
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMobileFieldLabel('Type de contrat'),
                                  _buildMobileDropdown<String>(
                                    value: _currentDeclaration.contractType,
                                    items: const [
                                      DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                                      DropdownMenuItem(value: 'CDD', child: Text('CDD')),
                                      DropdownMenuItem(value: 'CDI', child: Text('CDI')),
                                      DropdownMenuItem(value: 'SIVP', child: Text('SIVP')),
                                      DropdownMenuItem(value: 'Tous', child: Text('Tous types')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _currentDeclaration = _currentDeclaration.copyWith(contractType: v);
                                        });
                                        _save();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Date de déclaration
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMobileFieldLabel('Date de déclaration', isRequired: true),
                                  _buildMobileDatePicker(
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
                                        _save();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),

                        // Row 3 : Salariés déclarés & Sélectionner
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people_alt_outlined, size: 15, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  '${_currentDeclaration.lines.length} salarié(s) déclaré(s)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => _showEmployeeSelectionSheet(activeEmployees, payslips),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.group_add_rounded, size: 16, color: _odooPurple),
                              label: const Text('Sélectionner', style: TextStyle(color: _odooPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. LISTE DES EMPLOYÉS DÉCLARÉS (CARTES TACTILES)
                  Expanded(
                    child: _currentDeclaration.lines.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 8),
                                const Text('Aucun employé déclaré', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showEmployeeSelectionSheet(activeEmployees, payslips),
                                  icon: const Icon(Icons.group_add, size: 16),
                                  label: const Text('Ajouter des employés'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _odooPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _currentDeclaration.lines.length,
                            itemBuilder: (context, index) {
                              final line = _currentDeclaration.lines[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Ligne supérieure : N° ligne, Nom, Badge catégorie, bouton modifier
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            child: Text('${line.lineNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(line.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                                Text('CNSS : ${line.cnssNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('Cat. ${line.professionalCategory}',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                            onPressed: () => _editLineSheet(line),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      // Détail des 3 mois
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildMonthBox(monthNames[0], line.grossMonth1, currency, f),
                                          _buildMonthBox(monthNames[1], line.grossMonth2, currency, f),
                                          _buildMonthBox(monthNames[2], line.grossMonth3, currency, f),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Total Ligne
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Text('Total Trimestre : ', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                          Text(
                                            '${f.format(line.total)} $currency',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _odooPurple),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // 3. BARRE INFÉRIEURE STICKY : TOTAL & BOUTON [GÉNÉRER LE FICHIER]
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL DÉCLARÉ :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                              Text(
                                _currentDeclaration.formattedTotal(_currentDeclaration.totalQuarter),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _odooPurple),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => CnssPdfService.instance.showPreviewDialog(context, _currentDeclaration),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                              label: const Text('Générer le fichier (PDF & Partage)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _odooPurple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
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

  Widget _buildMonthBox(String month, double amount, String currency, NumberFormat f) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(month, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              '${f.format(amount)} $currency',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
