import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_event.dart';
import '../blocs/payroll/payroll_state.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/payslip.dart';
import '../models/payslip_batch.dart';
import '../models/employee.dart';
import '../services/payslip_pdf_service.dart';
import 'payslip_form_dialog.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

/// Formulaire & Assistant de "Génération par lots de bulletins de paie"
/// Conforme à l'ergonomie Odoo ERP (Images 1, 2, 3, 4, 5).
/// Compatible Desktop, Android et Web.
class PayslipBatchDialog extends StatefulWidget {
  final PayslipBatch? batch;

  const PayslipBatchDialog({super.key, this.batch});

  static Future<void> show(BuildContext context, {PayslipBatch? batch}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PayslipBatchDialog(batch: batch),
    );
  }

  @override
  State<PayslipBatchDialog> createState() => _PayslipBatchDialogState();
}

class _PayslipBatchDialogState extends State<PayslipBatchDialog> {
  static const Color _primaryPurple = Color(0xFF1A56DB); // LogiTech Primary Blue
  bool _isSaving = false;
  static const Color _borderLight = Color(0xFFCBD5E1);
  static const Color _surfaceLight = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  static const List<String> _monthsList = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  late TextEditingController _nameCtrl;
  late int _selectedMonth;
  late int _selectedYear;
  String _salaryJournal = 'Opérations diverses';
  bool _isCreditNote = false;
  String _status = 'draft'; // 'draft' ("Brouillon") or 'closed' ("Fermer")

  // Locally tracked payslips in this batch
  final List<Payslip> _batchPayslips = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.batch?.periodMonth ?? now.month;
    _selectedYear = widget.batch?.periodYear ?? now.year;

    final defaultName = '${_selectedMonth.toString().padLeft(2, '0')}-$_selectedYear';
    _nameCtrl = TextEditingController(text: widget.batch?.name ?? defaultName);
    _salaryJournal = widget.batch?.salaryJournal ?? 'Opérations diverses';
    _isCreditNote = widget.batch?.isCreditNote ?? false;
    _status = widget.batch?.status ?? 'draft';

    // Populate existing payslips for this batch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pState = context.read<PayrollBloc>().state;
      if (pState is PayrollLoaded) {
        final existing = pState.payslips.where((p) {
          if (widget.batch != null) {
            return (p.batchNumber == widget.batch!.name) ||
                widget.batch!.payslipIds.contains(p.id);
          }
          return p.batchNumber == _nameCtrl.text.trim();
        }).toList();

        setState(() {
          _batchPayslips.clear();
          _batchPayslips.addAll(existing);
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _periodMonthYearLabel =>
      '${_monthsList[_selectedMonth - 1].toLowerCase()}-$_selectedYear';

  String get _periodDateRange {
    final start = '01/${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final end = '$lastDay/${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';
    return '$start - $end';
  }

  void _pickMonthYear() async {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Sélectionner la période du lot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: tempMonth,
                  decoration: const InputDecoration(labelText: 'Mois', border: OutlineInputBorder()),
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text(_monthsList[m - 1])))
                      .toList(),
                  onChanged: (v) => setDlgState(() => tempMonth = v ?? tempMonth),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: tempYear,
                  decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                  items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1]
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setDlgState(() => tempYear = v ?? tempYear),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryPurple, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );

    if (picked == true) {
      setState(() {
        _selectedMonth = tempMonth;
        _selectedYear = tempYear;
        if (_nameCtrl.text.isEmpty || _nameCtrl.text.contains('-')) {
          _nameCtrl.text = '${_selectedMonth.toString().padLeft(2, '0')}-$_selectedYear';
        }
      });
    }
  }

  Future<void> _saveBatch() async {
    if (_isSaving) return;
    if (widget.batch != null) {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final batch = PayslipBatch(
        id: widget.batch?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : '${_selectedMonth.toString().padLeft(2, '0')}-$_selectedYear',
        periodMonth: _selectedMonth,
        periodYear: _selectedYear,
        salaryJournal: _salaryJournal,
        isCreditNote: _isCreditNote,
        status: _status,
        payslipIds: _batchPayslips.map((p) => p.id).toList(),
        createdAt: widget.batch?.createdAt ?? now,
        updatedAt: now,
      );

      final isOnline = ConnectivityService.instance.isOnline;
      if (widget.batch != null) {
        context.read<PayrollBloc>().add(UpdatePayslipBatch(batch));
      } else {
        context.read<PayrollBloc>().add(AddPayslipBatch(batch));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle_outline_rounded : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline
                      ? 'Lot "${batch.name}" enregistré avec succès !'
                      : 'Lot "${batch.name}" enregistré hors ligne (en attente de synchronisation)',
                ),
              ],
            ),
            backgroundColor: isOnline ? const Color(0xFF10B981) : AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toggleCloseBatch() {
    setState(() {
      _status = _status == 'draft' ? 'closed' : 'draft';
    });
    _saveBatch();
  }

  void _removePayslipFromBatch(Payslip p) {
    setState(() {
      _batchPayslips.removeWhere((item) => item.id == p.id);
    });
    // Update payslip to remove batch reference
    final updated = p.copyWith(batchNumber: null);
    context.read<PayrollBloc>().add(AddPayslip(updated));
    _saveBatch();
  }

  // ---------------------------------------------------------------------------
  // WIZARD: "Générer les bulletins de paie" (Image 2 & 4)
  // ---------------------------------------------------------------------------
  void _openGenerateWizard() {
    final empState = context.read<EmployeesBloc>().state;
    final allEmployees = empState is EmployeesLoaded
        ? empState.employees.where((e) => e.isActive).toList()
        : <Employee>[];

    // Already selected employees in the wizard
    final List<Employee> wizardEmployees = [];

    // Pre-populate with employees not yet in this batch
    final existingEmpIds = _batchPayslips.map((p) => p.employeeId).toSet();
    for (final emp in allEmployees) {
      if (!existingEmpIds.contains(emp.id)) {
        wizardEmployees.add(emp);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setWizardState) {
          final isMobile = MediaQuery.of(ctx).size.width < 700;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 680,
                maxHeight: 640,
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wizard Header: "Générer les bulletins de paie" with close icon (Image 2)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Générer les bulletins de paie',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: _textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Top Action: [⚙ Générer] (Image 2 & 4)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                      label: const Text('Générer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeGenerateBatch(wizardEmployees);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Descriptive Text (Image 2)
                    const Text(
                      'Cet assistant va générer les fiches de paie de(s) l\'employé(s) sélectionné(s) sur base des dates et des notes de crédit figurant sur les bulletins de paie.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Section Title: "EMPLOYÉS" (Image 2 & 4)
                    const Text(
                      'EMPLOYÉS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),

                    // Table of Selected Employees (Image 4)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _borderLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: _borderLight)),
                              ),
                              child: const Row(
                                children: [
                                  Text(
                                    'Nom de l\'employé',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark),
                                  ),
                                ],
                              ),
                            ),

                            // Employees Rows
                            Expanded(
                              child: wizardEmployees.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Aucun employé sélectionné.\nCliquez sur "Ajouter une ligne" ci-dessous.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: _textMuted),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: wizardEmployees.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (_, i) {
                                        final emp = wizardEmployees[i];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                emp.fullName,
                                                style: const TextStyle(fontSize: 13, color: _textDark, fontWeight: FontWeight.w500),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 16, color: _textMuted),
                                                tooltip: 'Retirer',
                                                onPressed: () {
                                                  setWizardState(() {
                                                    wizardEmployees.removeAt(i);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),

                            // "Ajouter une ligne" (Image 2 & 4)
                            InkWell(
                              onTap: () async {
                                final picked = await _openEmployeePickerSubModal(allEmployees, wizardEmployees);
                                if (picked != null) {
                                  setWizardState(() {
                                    for (final e in picked) {
                                      if (!wizardEmployees.any((x) => x.id == e.id)) {
                                        wizardEmployees.add(e);
                                      }
                                    }
                                  });
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(top: BorderSide(color: _borderLight)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add, size: 16, color: _primaryPurple),
                                    SizedBox(width: 8),
                                    Text(
                                      'Ajouter une ligne',
                                      style: TextStyle(color: _primaryPurple, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Wizard Bottom Buttons: [Enregistrer] [Ignorer] (Image 2 & 4)
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _executeGenerateBatch(wizardEmployees);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            side: const BorderSide(color: _borderLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Ignorer', style: TextStyle(color: _textDark, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-MODAL: "Ajouter : Employés" (Image 3)
  // ---------------------------------------------------------------------------
  Future<List<Employee>?> _openEmployeePickerSubModal(
    List<Employee> allEmployees,
    List<Employee> alreadyInWizard,
  ) {
    final Set<String> selectedEmpIds = alreadyInWizard.map((e) => e.id).toSet();
    String searchQuery = '';

    return showDialog<List<Employee>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          final isMobile = MediaQuery.of(ctx).size.width < 700;

          final filtered = allEmployees.where((e) {
            if (searchQuery.isNotEmpty) {
              return e.fullName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  e.jobTitle.toLowerCase().contains(searchQuery.toLowerCase());
            }
            return true;
          }).toList();

          final allChecked = filtered.isNotEmpty && filtered.every((e) => selectedEmpIds.contains(e.id));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
                maxHeight: 560,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: "Ajouter : Employés" with close icon (Image 3)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ajouter : Employés',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: _textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search & Pagination Bar (Image 3)
                    Row(
                      children: [
                        const Icon(Icons.settings_outlined, size: 18, color: _textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              onChanged: (v) => setPickerState(() => searchQuery = v),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Rechercher...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                                filled: true,
                                fillColor: _surfaceLight,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: _borderLight),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: _borderLight),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '1-${filtered.length} / ${filtered.length}',
                          style: const TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_left, size: 18, color: _textMuted),
                        const Icon(Icons.chevron_right, size: 18, color: _textMuted),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Selection Table (Image 3)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _borderLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            // Header with master checkbox
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: _borderLight)),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: allChecked,
                                    activeColor: _primaryPurple,
                                    onChanged: (val) {
                                      setPickerState(() {
                                        if (val == true) {
                                          selectedEmpIds.addAll(filtered.map((e) => e.id));
                                        } else {
                                          for (final e in filtered) {
                                            selectedEmpIds.remove(e.id);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Nom de l\'employé',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark),
                                  ),
                                ],
                              ),
                            ),

                            // List of employees with checkboxes (Administrator, Alex, Mohamed...)
                            Expanded(
                              child: filtered.isEmpty
                                  ? const Center(child: Text('Aucun employé trouvé', style: TextStyle(fontSize: 12, color: _textMuted)))
                                  : ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (_, i) {
                                        final emp = filtered[i];
                                        final isChecked = selectedEmpIds.contains(emp.id);

                                        return InkWell(
                                          onTap: () {
                                            setPickerState(() {
                                              if (isChecked) {
                                                selectedEmpIds.remove(emp.id);
                                              } else {
                                                selectedEmpIds.add(emp.id);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: isChecked,
                                                  activeColor: _primaryPurple,
                                                  onChanged: (v) {
                                                    setPickerState(() {
                                                      if (v == true) {
                                                        selectedEmpIds.add(emp.id);
                                                      } else {
                                                        selectedEmpIds.remove(emp.id);
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  emp.fullName,
                                                  style: const TextStyle(fontSize: 13, color: _textDark),
                                                ),
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
                    ),
                    const SizedBox(height: 16),

                    // Bottom Buttons: [Sélectionner] [Nouveau] [Fermer] (Image 3)
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final chosen = allEmployees.where((e) => selectedEmpIds.contains(e.id)).toList();
                            Navigator.pop(ctx, chosen);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          child: const Text('Sélectionner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            side: const BorderSide(color: _borderLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Fermer', style: TextStyle(color: _textDark, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GENERATE PAYSLIPS ACTION
  // ---------------------------------------------------------------------------
  void _executeGenerateBatch(List<Employee> employees) {
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun employé sélectionné pour la génération.')),
      );
      return;
    }

    final batchName = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : '${_selectedMonth.toString().padLeft(2, '0')}-$_selectedYear';

    final currentBatch = PayslipBatch(
      id: widget.batch?.id ?? const Uuid().v4(),
      name: batchName,
      periodMonth: _selectedMonth,
      periodYear: _selectedYear,
      salaryJournal: _salaryJournal,
      isCreditNote: _isCreditNote,
      status: _status,
      payslipIds: _batchPayslips.map((p) => p.id).toList(),
      createdAt: widget.batch?.createdAt,
      updatedAt: DateTime.now(),
    );

    context.read<PayrollBloc>().add(
          GenerateBatchPayslips(
            batch: currentBatch,
            selectedEmployees: employees,
          ),
        );

    // Refresh local list
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final pState = context.read<PayrollBloc>().state;
      if (pState is PayrollLoaded) {
        setState(() {
          _batchPayslips.clear();
          _batchPayslips.addAll(
            pState.payslips.where((p) => p.batchNumber == batchName).toList(),
          );
        });
      }
    });

    final isOnline = ConnectivityService.instance.isOnline;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isOnline ? Icons.check_circle_outline_rounded : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isOnline
                  ? '${employees.length} bulletin(s) généré(s) pour le lot "$batchName" !'
                  : '${employees.length} bulletin(s) généré(s) hors ligne pour le lot "$batchName" (en attente de synchronisation)',
            ),
          ],
        ),
        backgroundColor: isOnline ? const Color(0xFF10B981) : AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? media.size.width * 0.96 : 1100,
          maxHeight: isMobile ? media.size.height * 0.95 : 880,
        ),
        child: Column(
          children: [
            // Top Navigation Bar (Image 1 & 5: Nouveau, Breadcrumbs, ⚙, Refresh, Pagination)
            _buildTopNavBar(isMobile),
            const Divider(height: 1, color: _borderLight),

            // Sub Action Bar: [Fermer] [Générer les bulletins de paie] ... Pipeline: [Brouillon | Fermer]
            _buildSubActionBar(isMobile),
            const Divider(height: 1, color: _borderLight),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Header Form Fields (Image 1 & 5: Nom, Période, Salary Journal, Avoir ?)
                    _buildHeaderFormFields(isMobile),
                    const SizedBox(height: 24),

                    // Section Title: "FEUILLES DE PAYE" (Image 1 & 5)
                    const Text(
                      'FEUILLES DE PAYE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payslips Table (Image 1 & 5)
                    _buildPayslipsTable(isMobile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP NAV BAR (Image 1 & 5)
  // ---------------------------------------------------------------------------
  Widget _buildTopNavBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 10,
      ),
      child: Row(
        children: [
          // "Nouveau" Button (Image 1 & 5)
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              PayslipBatchDialog.show(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: const BorderSide(color: _primaryPurple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Nouveau', style: TextStyle(color: _primaryPurple, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),

          // Breadcrumbs: "Lots de bulletins de paie / Nom ⚙" (Image 1 & 5)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Lots de bulletins de paie',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _primaryPurple),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('/', style: TextStyle(color: _textMuted, fontSize: 14)),
              ),
              Text(
                _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Nouveau',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
              ),
              const SizedBox(width: 6),

              // Gear Icon Popup Menu (Image 1 & 5)
              PopupMenuButton<String>(
                tooltip: 'Actions du lot',
                icon: const Icon(Icons.settings_outlined, size: 18, color: _textMuted),
                offset: const Offset(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (val) {
                  if (val == 'print') {
                    PayslipPdfService.instance.printBatchPayslips(
                      context,
                      _batchPayslips,
                      type: 'standard',
                    );
                  } else if (val == 'report') {
                    PayslipPdfService.instance.printBatchPayslips(
                      context,
                      _batchPayslips,
                      type: 'report',
                    );
                  } else if (val == 'delete') {
                    if (widget.batch != null) {
                      OfflineActionHelper.executeAction(
                        context: context,
                        action: 'delete',
                        customActionLabel: 'le lot de bulletins',
                        onConfirmed: () {
                          context.read<PayrollBloc>().add(DeletePayslipBatch(widget.batch!.id));
                          Navigator.pop(context);
                        },
                      );
                    }
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, size: 16, color: _primaryPurple),
                        SizedBox(width: 8),
                        Text('Imprimer les bulletins (Lot)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                        SizedBox(width: 8),
                        Text('Rapport récapitulatif (PDF)'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Supprimer ce lot', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Cloud Sync & Refresh Icons (Image 1)
          const Icon(Icons.cloud_done_outlined, size: 18, color: _textMuted),
          const SizedBox(width: 8),
          const Icon(Icons.refresh, size: 18, color: _textMuted),
          const SizedBox(width: 14),

          // Pagination (Image 5: 1/1 < >)
          const Text('1/1', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textMuted)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_left, size: 18, color: _textMuted),
          const Icon(Icons.chevron_right, size: 18, color: _textMuted),
          const SizedBox(width: 12),

          // Close Dialog
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: _textMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. SUB ACTION BAR (Image 1 & 5: Fermer | Générer les bulletins de paie)
  // ---------------------------------------------------------------------------
  Widget _buildSubActionBar(bool isMobile) {
    final isClosed = _status == 'closed';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 8,
      ),
      child: Row(
        children: [
          // "Fermer" / "Rouvrir" Button (Image 1 & 5)
          ElevatedButton(
            onPressed: _toggleCloseBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: isClosed ? const Color(0xFF64748B) : _primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: Text(isClosed ? 'Rouvrir' : 'Fermer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),

          // "Générer les bulletins de paie" Button (Image 1 & 5)
          ElevatedButton(
            onPressed: _openGenerateWizard,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Générer les bulletins de paie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),

          // "🖨 Imprimer" Button (Multiplateforme)
          PopupMenuButton<String>(
            tooltip: 'Imprimer ce lot',
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) {
              if (_batchPayslips.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aucun bulletin à imprimer dans ce lot.')),
                );
                return;
              }
              PayslipPdfService.instance.printBatchPayslips(
                context,
                _batchPayslips,
                type: val,
              );
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'standard',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                    SizedBox(width: 8),
                    Text('Bulletins Standards (Lot)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, size: 16, color: _primaryPurple),
                    SizedBox(width: 8),
                    Text('Rapport Récapitulatif (PDF)'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _borderLight),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 6),
                  Text('Imprimer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Pipeline Status: [Brouillon | Fermer] (Image 1 & 5)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPipelineStep('Brouillon', _status == 'draft'),
                Container(width: 1, height: 26, color: _borderLight),
                _buildPipelineStep('Fermer', _status == 'closed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStep(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEDE9FE) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? _primaryPurple : _textMuted,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MAIN HEADER FORM FIELDS (Image 1 & 5: Nom, Période, Salary Journal, Avoir ?)
  // ---------------------------------------------------------------------------
  Widget _buildHeaderFormFields(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom (Image 1: empty underline textfield; Image 5: "12-2024" in large font)
        const Text('Nom', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textMuted)),
        const SizedBox(height: 4),
        SizedBox(
          width: isMobile ? double.infinity : 340,
          child: TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: UnderlineInputBorder(borderSide: BorderSide(color: _borderLight)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _borderLight)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryPurple, width: 2)),
            ),
            onChanged: (v) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),

        // Période (Image 1 & 5: "novembre-2024   01/11/2024 - 30/11/2024")
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 130,
              child: Text('Période', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodMonthYearLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _pickMonthYear,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 15, color: _primaryPurple),
                      const SizedBox(width: 6),
                      Text(
                        _periodDateRange,
                        style: const TextStyle(fontSize: 12.5, color: _textDark),
                      ),
                      const SizedBox(width: 8),
                      const Text('Changer', style: TextStyle(fontSize: 11.5, color: _primaryPurple, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Salary Journal (Image 1 & 5: Opérations diverses)
        Row(
          children: [
            const SizedBox(
              width: 130,
              child: Text('Salary Journal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted)),
            ),
            Text(
              _salaryJournal,
              style: const TextStyle(fontSize: 13, color: _textDark, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Avoir ? (Image 1 & 5: checkbox)
        Row(
          children: [
            const SizedBox(
              width: 130,
              child: Row(
                children: [
                  Text('Avoir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted)),
                  SizedBox(width: 2),
                  Icon(Icons.help_outline, size: 13, color: _textMuted),
                ],
              ),
            ),
            Checkbox(
              value: _isCreditNote,
              activeColor: _primaryPurple,
              onChanged: (val) {
                setState(() => _isCreditNote = val ?? false);
                _saveBatch();
              },
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. PAYSLIPS TABLE (Image 1 & 5: FEUILLES DE PAYE)
  // ---------------------------------------------------------------------------
  Widget _buildPayslipsTable(bool isMobile) {
    final batchName = _nameCtrl.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 50,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Référence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Nom de bulletin de paie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Date début', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Date de fin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Lots de bulletins de paie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _textDark))),
              ],
              rows: _batchPayslips.map((p) {
                final isPaid = p.paymentStatus == 'paid';
                final periodStr = '${_monthsList[p.periodMonth - 1].toLowerCase()}-${p.periodYear}';
                final lastDay = DateTime(p.periodYear, p.periodMonth + 1, 0).day;
                final startStr = '01/${p.periodMonth.toString().padLeft(2, '0')}/${p.periodYear}';
                final endStr = '$lastDay/${p.periodMonth.toString().padLeft(2, '0')}/${p.periodYear}';

                return DataRow(
                  onSelectChanged: (_) => PayslipFormDialog.show(context, payslip: p),
                  cells: [
                    // Référence (Image 5: SLIP/017)
                    DataCell(Text(p.reference, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _primaryPurple))),

                    // Employé (Image 5: Administrator, Alex, Mohamed)
                    DataCell(Text(p.employeeName, style: const TextStyle(fontSize: 12.5))),

                    // Nom de bulletin de paie (Image 5: Bulletin de paie de Administrator...)
                    DataCell(Text(p.payslipName ?? 'Bulletin de paie de ${p.employeeName}', style: const TextStyle(fontSize: 12.5))),

                    // Period (Image 5: décembre-2024)
                    DataCell(Text(periodStr, style: const TextStyle(fontSize: 12.5, color: _textMuted))),

                    // Date début (Image 5: 01/12/2024)
                    DataCell(Text(startStr, style: const TextStyle(fontSize: 12.5))),

                    // Date de fin (Image 5: 31/12/2024)
                    DataCell(Text(endStr, style: const TextStyle(fontSize: 12.5))),

                    // Statut (Image 5: Brouillon orange badge)
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Brouillon',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Lots de bulletins de paie (Image 5: batch name or blank)
                    DataCell(Text(p.batchNumber ?? batchName, style: const TextStyle(fontSize: 12, color: _textMuted))),

                    // Action: Delete 🗑 and Print 🖨
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print_outlined, size: 16, color: _primaryPurple),
                            tooltip: 'Imprimer',
                            onPressed: () {
                              PayslipPdfService.instance.printPayslip(context, p, type: 'standard');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: _textMuted),
                            tooltip: 'Retirer du lot',
                            onPressed: () => _removePayslipFromBatch(p),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          // "Ajouter une ligne" (Image 1 & 5)
          InkWell(
            onTap: _openGenerateWizard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _borderLight)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 16, color: _primaryPurple),
                  SizedBox(width: 8),
                  Text(
                    'Ajouter une ligne',
                    style: TextStyle(color: _primaryPurple, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
