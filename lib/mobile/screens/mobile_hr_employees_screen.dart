import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_event.dart';
import '../../blocs/employees/employees_state.dart';
import '../../models/employee.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/employee_form_dialog.dart';
import '../../widgets/contract_form_dialog.dart';
import '../../screens/employee_detail_profile_screen.dart';

class MobileHrEmployeesScreen extends StatefulWidget {
  const MobileHrEmployeesScreen({super.key});

  @override
  State<MobileHrEmployeesScreen> createState() => _MobileHrEmployeesScreenState();
}

class _MobileHrEmployeesScreenState extends State<MobileHrEmployeesScreen> {
  bool _isFirstLoad = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<EmployeesBloc>().add(const LoadEmployees());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final fmt = NumberFormat('#,##0.000', 'fr_FR');
    return '${fmt.format(amount)} TND';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('Personnel (Employés)'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            tooltip: 'Nouveau Contrat',
            onPressed: () => ContractFormDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => context.read<EmployeesBloc>().add(const LoadEmployees()),
          ),
        ],
      ),
      body: BlocConsumer<EmployeesBloc, EmployeesState>(
        listener: (context, state) {
          if (_isFirstLoad && (state is EmployeesLoaded || state is EmployeesError)) {
            setState(() {
              _isFirstLoad = false;
            });
          }
        },
        builder: (context, state) {
          final employees = (!_isFirstLoad && state is EmployeesLoaded) ? state.employees : <Employee>[];

          final filtered = employees.where((e) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return e.fullName.toLowerCase().contains(q) || e.jobTitle.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un collaborateur...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),

              // Count badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('${filtered.length} employé(s)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ],
                ),
              ),

              // List
              Expanded(
                child: (_isFirstLoad || state is EmployeesLoading || state is EmployeesInitial)
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.badge_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text('Aucun employé trouvé', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final emp = filtered[idx];
                              return _buildCard(emp);
                            },
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Nouvel Employé'),
        onPressed: () => _showEmployeeForm(),
      ),
    );
  }

  Widget _buildCard(Employee emp) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeDetailProfileScreen(employee: emp),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                child: Text(
                  emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text('${emp.jobTitle} • ${emp.department}', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              InkWell(
                onTap: () => ContractFormDialog.show(context, employee: emp),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF1A56DB).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 10, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 3),
                      Text(
                        emp.contractType,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: emp.isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emp.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emp.isActive ? const Color(0xFF10B981) : Colors.red),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text('Salaire base : ', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
              Text(_formatCurrency(emp.baseSalary), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              const Spacer(),
              IconButton(
                tooltip: 'Gérer Contrat',
                icon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF1A56DB)),
                onPressed: () => ContractFormDialog.show(context, employee: emp),
              ),
              if (emp.phone != null && emp.phone!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF2563EB)),
                  onPressed: () => launchUrl(Uri.parse('tel:${emp.phone}')),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _showEmployeeForm(employee: emp),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  void _showEmployeeForm({Employee? employee}) {
    EmployeeFormDialog.show(context, employee: employee);
  }
}
