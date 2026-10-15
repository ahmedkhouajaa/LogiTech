import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_event.dart';
import '../../blocs/employees/employees_state.dart';
import '../../blocs/leaves/leaves_bloc.dart';
import '../../blocs/leaves/leaves_event.dart';
import '../../blocs/leaves/leaves_state.dart';
import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_event.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../services/app_navigation_service.dart';
import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';

class MobileHrDashboardScreen extends StatefulWidget {
  const MobileHrDashboardScreen({super.key});

  @override
  State<MobileHrDashboardScreen> createState() => _MobileHrDashboardScreenState();
}

class _MobileHrDashboardScreenState extends State<MobileHrDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EmployeesBloc>().add(const LoadEmployees());
        context.read<LeavesBloc>().add(const LoadLeaves());
        context.read<PayrollBloc>().add(const LoadPayslips());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM', 'fr_FR').format(now);
    final capitalizedMonth = monthName.isNotEmpty
        ? '${monthName[0].toUpperCase()}${monthName.substring(1)}'
        : 'Octobre';
    final monthShort = DateFormat('MMM', 'fr_FR').format(now).toUpperCase();

    final closingDay = 25;
    final paymentDay = 28;
    final daysUntilClosing = closingDay >= now.day ? (closingDay - now.day) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<EmployeesBloc>().add(const LoadEmployees());
          context.read<LeavesBloc>().add(const LoadLeaves());
          context.read<PayrollBloc>().add(const LoadPayslips());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Top 3 Stat Cards ──────────────────────────────────────────
              _buildTopKpis(capitalizedMonth),
              const SizedBox(height: 16),

              // ─── Payroll Timeline Card ─────────────────────────────────────
              _buildPayrollTimelineCard(
                capitalizedMonth: capitalizedMonth,
                monthShort: monthShort,
                now: now,
                closingDay: closingDay,
                paymentDay: paymentDay,
                daysUntilClosing: daysUntilClosing,
              ),
              const SizedBox(height: 16),

              // ─── Qui est absent aujourd'hui ? ──────────────────────────────
              _buildAbsentTodayCard(),
              const SizedBox(height: 16),

              // ─── À l'agenda ────────────────────────────────────────────────
              _buildAgendaCard(),
              const SizedBox(height: 16),

              // ─── Demandes à valider ────────────────────────────────────────
              _buildPendingApprovalsCard(),
              const SizedBox(height: 16),

              // ─── Paie du mois : vos tâches en attente ──────────────────────
              _buildPendingTasksCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. Top 3 Stat Cards (Mobile)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTopKpis(String monthName) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        return BlocBuilder<PayrollBloc, PayrollState>(
          builder: (context, payState) {
            int employeeCount = 1;
            double grossSalary = 647.619;
            double totalCost = 647.619;

            if (empState is EmployeesLoaded && empState.employees.isNotEmpty) {
              final activeEmps = empState.employees.where((e) => e.isActive).toList();
              if (activeEmps.isNotEmpty) {
                employeeCount = activeEmps.length;
              }
            }

            if (payState is PayrollLoaded && payState.payslips.isNotEmpty) {
              final sumGross = payState.payslips.fold<double>(
                0.0,
                (sum, p) => sum + p.grossSalary,
              );
              if (sumGross > 0) {
                grossSalary = sumGross;
                totalCost = sumGross;
              }
            }

            return Column(
              children: [
                _buildStatCard(
                  title: 'Masse salariale brute — $monthName',
                  value: '${_formatAmount(grossSalary)} TND',
                ),
                const SizedBox(height: 10),
                _buildStatCard(
                  title: 'Coût global — $monthName',
                  value: '${_formatAmount(totalCost)} TND',
                ),
                const SizedBox(height: 10),
                _buildStatCard(
                  title: 'Effectif — $monthName',
                  value: '$employeeCount collaborateur(s)',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Timeline Card: "Votre paie de [Mois]" (Mobile)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPayrollTimelineCard({
    required String capitalizedMonth,
    required String monthShort,
    required DateTime now,
    required int closingDay,
    required int paymentDay,
    required int daysUntilClosing,
  }) {
    final openDateStr = '25/10/2026';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre paie de $capitalizedMonth',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Clôture dans $daysUntilClosing jours',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
              Text(
                'Paie ouverte le $openDateStr',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                AppNavigationService.instance.navigateToModule(context, AppModule.hrPayroll);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              child: const Text(
                'Gérer la paie',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stepper progress bar
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                height: 4,
                width: MediaQuery.of(context).size.width * 0.65,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Milestones
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMilestoneItem(
                  day: '1',
                  month: monthShort,
                  title: 'Ouverture',
                  subtitle: 'Début',
                  align: CrossAxisAlignment.start,
                ),
              ),
              Expanded(
                child: _buildMilestoneItem(
                  day: '$closingDay',
                  month: monthShort,
                  title: 'Clôture',
                  subtitle: 'Préparation',
                  align: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: _buildMilestoneItem(
                  day: '$paymentDay',
                  month: monthShort,
                  title: 'Paiement',
                  subtitle: 'Virement',
                  align: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneItem({
    required String day,
    required String month,
    required String title,
    required String subtitle,
    required CrossAxisAlignment align,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          day,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          month,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: align == CrossAxisAlignment.center
              ? TextAlign.center
              : (align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          subtitle,
          textAlign: align == CrossAxisAlignment.center
              ? TextAlign.center
              : (align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start),
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Qui est absent aujourd'hui ? (Mobile)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAbsentTodayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Qui est absent aujourd\'hui ?',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () {
                  AppNavigationService.instance.navigateToModule(context, AppModule.hrLeaves);
                },
                child: Text(
                  'Voir calendrier',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: const [
                Icon(
                  Icons.group_outlined,
                  size: 34,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 8),
                Text(
                  'Toute l\'équipe est là aujourd\'hui',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. À l'agenda (Mobile)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAgendaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'À l\'agenda',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'À venir',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '15 octobre 2026',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: const Text(
                              'Fête de l\'Évacuation',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Non payé',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Jour férié',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. Demandes à valider (Mobile)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPendingApprovalsCard() {
    return BlocBuilder<LeavesBloc, LeavesState>(
      builder: (context, leavesState) {
        int pendingLeaves = 0;
        if (leavesState is LeavesLoaded) {
          pendingLeaves = leavesState.leaves.where((l) => l.isPending).length;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Demandes à valider',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              _buildApprovalItem(
                title: 'Demandes de congés',
                count: pendingLeaves,
                subtitle: pendingLeaves > 0
                    ? '$pendingLeaves demande(s) en attente'
                    : 'Aucune demande en attente',
                onTap: () {
                  AppNavigationService.instance.navigateToModule(context, AppModule.hrLeaves);
                },
              ),
              const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),

              _buildApprovalItem(
                title: 'Demandes de documents',
                count: 0,
                subtitle: 'Aucune demande de document en attente',
                onTap: () {
                  AppNavigationService.instance.navigateToModule(context, AppModule.hrDocuments);
                },
              ),
              const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),

              _buildApprovalItem(
                title: 'Acomptes à valider',
                count: 0,
                subtitle: 'Aucun acompte à valider',
                onTap: () {
                  AppNavigationService.instance.navigateToModule(context, AppModule.hrPayroll);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalItem({
    required String title,
    required int count,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: count > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: count > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. Paie du mois : vos tâches en attente (Mobile)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPendingTasksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Paie du mois : vos tâches en attente',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () {
                  AppNavigationService.instance.navigateToModule(context, AppModule.hrPayroll);
                },
                child: Text(
                  'Voir tâches',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '0',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tâches',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.000', 'fr_FR');
    return formatter.format(amount).replaceAll(' ', '');
  }
}
