import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_state.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/leave_request.dart';
import '../models/employee.dart';
import 'leave_request_form_dialog.dart';
import 'leave_allocation_dialog.dart';

/// Vue Tableau de bord des congés & Calendrier annuel (Image 1)
/// Conforme à la vue Odoo ERP pour Desktop, Web et Android
class LeaveDashboardCalendarView extends StatefulWidget {
  final Employee? initialEmployee;

  const LeaveDashboardCalendarView({super.key, this.initialEmployee});

  @override
  State<LeaveDashboardCalendarView> createState() => _LeaveDashboardCalendarViewState();
}

class _LeaveDashboardCalendarViewState extends State<LeaveDashboardCalendarView> {
  static const Color _odooPurple = Color(0xFF1A56DB);
  static const Color _odooAmber = Color(0xFFF59E0B);
  static const Color _odooRed = Color(0xFFEF4444);
  static const Color _odooGray = Color(0xFF94A3B8);

  int _selectedYear = DateTime.now().year;
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployee?.id;
    _selectedEmployeeName = widget.initialEmployee?.fullName;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees.where((e) => e.isActive).toList() : <Employee>[];

        if (_selectedEmployeeId == null && employees.isNotEmpty) {
          _selectedEmployeeId = employees.first.id;
          _selectedEmployeeName = employees.first.fullName;
        }

        return BlocBuilder<LeavesBloc, LeavesState>(
          builder: (context, lState) {
            final allLeaves = lState is LeavesLoaded ? lState.leaves : <LeaveRequest>[];

            // Filter leaves for this employee and year
            final employeeLeaves = allLeaves.where((l) {
              final matchEmp = _selectedEmployeeId == null || l.employeeId == _selectedEmployeeId;
              final matchYear = l.startDate.year == _selectedYear || l.endDate.year == _selectedYear;
              return matchEmp && matchYear && !l.isDeleted;
            }).toList();

            // Calculate Available Days
            double totalAllocated = 0;
            double totalTaken = 0;

            for (final l in allLeaves) {
              if (l.employeeId == _selectedEmployeeId && !l.isDeleted) {
                if (l.isAllocation && l.isApproved) {
                  totalAllocated += l.daysCount;
                } else if (!l.isAllocation && l.isApproved) {
                  totalTaken += l.daysCount;
                }
              }
            }

            if (totalAllocated <= 0) totalAllocated = 20.0;
            final availableDays = (totalAllocated - totalTaken).clamp(0, 365);
            final availableStr = availableDays.toStringAsFixed(availableDays.truncateToDouble() == availableDays ? 0 : 1);

            return Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Controls Bar: Nouveau + Breadcrumb + Year Controls
                    _buildTopControls(employees),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // 2. Metrics & Legend Header (Image 1)
                    _buildMetricsAndLegend(availableStr, isMobile),

                    const SizedBox(height: 24),

                    // 3. 12-Month Year Calendar Grid
                    _buildYearCalendarGrid(employeeLeaves, isMobile),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Top Controls Bar
  Widget _buildTopControls(List<Employee> employees) {
    return Row(
      children: [
        // Button "Nouveau"
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _odooPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          onPressed: () => LeaveRequestFormDialog.show(context, isQuickMode: true),
          child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 14),

        // Breadcrumb: Employés / [Name] / Tableau de bord des congés
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Employés / ${_selectedEmployeeName ?? "Alex"}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const Text(
                'Tableau de bord des congés',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),

        // Employee dropdown selector
        if (employees.length > 1) ...[
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedEmployeeId,
                items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final emp = employees.firstWhere((e) => e.id == val);
                    setState(() {
                      _selectedEmployeeId = emp.id;
                      _selectedEmployeeName = emp.fullName;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Year navigation: ← → | Année ▾ | Aujourd'hui | [2024]
        Container(
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => setState(() => _selectedYear--),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => setState(() => _selectedYear++),
              ),
              Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
              InkWell(
                onTap: () => setState(() => _selectedYear = DateTime.now().year),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Aujourd\'hui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_selectedYear', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _odooPurple)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Metrics and Legend (Image 1 top part)
  Widget _buildMetricsAndLegend(String availableStr, bool isMobile) {
    final balanceCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          const Text('Congés payés', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.beach_access_rounded, size: 28, color: _odooPurple), // Umbrella icon like Image 1
              const SizedBox(width: 8),
              Text(
                availableStr,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _odooPurple),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('JOURS DISPONIBLE(S)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text('(VALIDE JUSQU\'AU 31/12/$_selectedYear)', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );

    final actionsAndLegend = Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        // Button "Nouvelle demande d'allocation"
        OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16, color: _odooPurple),
          label: const Text('Nouvelle demande d\'allocation', style: TextStyle(color: _odooPurple, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () => LeaveAllocationDialog.show(context),
        ),

        const SizedBox(height: 16),

        // Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Légende', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _odooPurple, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  const Text('Validé', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  const SizedBox(width: 12),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _odooAmber, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  const Text('À approuver', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  const SizedBox(width: 12),
                  Container(width: 12, height: 2, color: _odooGray),
                  const SizedBox(width: 6),
                  const Text('Refusée', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          balanceCard,
          const SizedBox(height: 12),
          actionsAndLegend,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        balanceCard,
        const Spacer(),
        actionsAndLegend,
      ],
    );
  }

  // 12-Month Year Calendar Grid (Image 1)
  Widget _buildYearCalendarGrid(List<LeaveRequest> leaves, bool isMobile) {
    final columns = isMobile ? 1 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: isMobile ? 1.25 : 1.15,
      ),
      itemCount: 12,
      itemBuilder: (context, monthIndex) {
        return _buildMonthCard(monthIndex + 1, leaves);
      },
    );
  }

  Widget _buildMonthCard(int month, List<LeaveRequest> leaves) {
    final monthDate = DateTime(_selectedYear, month, 1);
    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(monthDate);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, month);
    final firstWeekday = DateTime(_selectedYear, month, 1).weekday; // 1 = Monday, 7 = Sunday

    // Check which days have leaves
    final leaveDaysMap = <int, LeaveRequest>{};
    for (final l in leaves) {
      if (l.isAllocation) continue; // Only leave requests are on calendar
      DateTime cur = l.startDate;
      while (!cur.isAfter(l.endDate)) {
        if (cur.year == _selectedYear && cur.month == month) {
          leaveDaysMap[cur.day] = l;
        }
        cur = cur.add(const Duration(days: 1));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Title (ex: "janvier 2024")
          Text(
            monthName,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),

          // Days of week header: L M M J V S D
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text('L', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              Text('M', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              Text('M', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              Text('J', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              Text('V', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              Text('S', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              Text('D', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),

          // Days Grid
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: (firstWeekday - 1) + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox();
                }

                final day = index - (firstWeekday - 1) + 1;
                final leave = leaveDaysMap[day];

                Color? cellBg;
                Color textColor = const Color(0xFF334155);

                if (leave != null) {
                  if (leave.isApproved) {
                    cellBg = _odooPurple;
                    textColor = Colors.white;
                  } else if (leave.isPending || leave.isSecondApproval) {
                    cellBg = _odooAmber;
                    textColor = Colors.white;
                  } else if (leave.isRejected) {
                    cellBg = const Color(0xFFFEE2E2);
                    textColor = _odooRed;
                  }
                }

                return InkWell(
                  onTap: () {
                    if (leave != null) {
                      LeaveRequestFormDialog.show(context, leave: leave);
                    } else {
                      final selectedDt = DateTime(_selectedYear, month, day);
                      LeaveRequestFormDialog.show(
                        context,
                        isQuickMode: true,
                        leave: LeaveRequest(
                          id: '',
                          employeeId: _selectedEmployeeId ?? '',
                          employeeName: _selectedEmployeeName ?? '',
                          startDate: selectedDt,
                          endDate: selectedDt,
                          daysCount: 1.0,
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cellBg ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: leave != null ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
