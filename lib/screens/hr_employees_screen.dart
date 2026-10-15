import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_event.dart';
import '../blocs/employees/employees_state.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../utils/platform_utils.dart';
import '../l10n/app_localizations.dart';
import '../widgets/employee_form_dialog.dart';
import '../widgets/contract_form_dialog.dart';
import 'employee_detail_profile_screen.dart';
import '../utils/offline_action_helper.dart';

class HrEmployeesScreen extends StatefulWidget {
  const HrEmployeesScreen({super.key});

  @override
  State<HrEmployeesScreen> createState() => _HrEmployeesScreenState();
}

class _HrEmployeesScreenState extends State<HrEmployeesScreen> {
  bool _isFirstLoad = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartment = 'Tous';
  String _selectedStatus = 'all'; // all, active, inactive
  String _selectedContract = 'Tous';
  bool _isTableView = true;

  final List<String> _departments = [
    'Tous', 'Direction', 'Commercial', 'Technique', 'Finance & Comptabilité',
    'Ressources Humaines', 'Production', 'Logistique', 'Marketing'
  ];

  final List<String> _contracts = ['Tous', 'CDI', 'CDD', 'SIVP', 'Stage', 'Freelance'];

  @override
  void initState() {
    super.initState();
    _isTableView = PlatformUtils.isDesktop || PlatformUtils.isWeb;
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
          final activeList = employees.where((e) => e.isActive).toList();

          double totalBaseSalary = 0;
          for (final e in activeList) {
            totalBaseSalary += e.baseSalary;
          }

          // Filter
          final filtered = employees.where((e) {
            if (_selectedStatus == 'active' && !e.isActive) return false;
            if (_selectedStatus == 'inactive' && e.isActive) return false;
            if (_selectedDepartment != 'Tous' && e.department != _selectedDepartment) return false;
            if (_selectedContract != 'Tous' && e.contractType != _selectedContract) return false;

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchName = e.fullName.toLowerCase().contains(q);
              final matchCode = e.code.toLowerCase().contains(q);
              final matchJob = e.jobTitle.toLowerCase().contains(q);
              final matchPhone = (e.phone ?? '').toLowerCase().contains(q);
              if (!matchName && !matchCode && !matchJob && !matchPhone) return false;
            }
            return true;
          }).toList();

          final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(context),

              // 2. Metrics Bar
              _buildMetricsBanner(
                total: employees.length,
                active: activeList.length,
                inactive: employees.length - activeList.length,
                totalSalary: totalBaseSalary,
              ),

              // 3. Search & Filter Bar
              _buildFilterBar(),

              // 4. Employees Display (Table on Desktop & Web, Cards Grid on Mobile)
              Expanded(
                child: (_isFirstLoad || state is EmployeesLoading || state is EmployeesInitial)
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : (isDesktopOrWeb && _isTableView)
                            ? _buildEmployeesTable(filtered)
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 380,
                                    mainAxisExtent: 225,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) {
                                    final emp = filtered[idx];
                                    return _buildEmployeeCard(emp);
                                  },
                                ),
                              ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A56DB), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A56DB).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.tr('Personnel (Employés)'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Équipe & Contrats',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A56DB),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                context.tr('Gérez les fiches collaborateurs, contrats de travail et salaires de base'),
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: context.tr('Actualiser'),
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () => context.read<EmployeesBloc>().add(const LoadEmployees()),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined, size: 17, color: Color(0xFF1A56DB)),
            label: Text(
              context.tr('Nouveau contrat'),
              style: const TextStyle(
                color: Color(0xFF1A56DB),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              side: const BorderSide(color: Color(0xFF1A56DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => ContractFormDialog.show(context),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(context.tr('Nouvel employé')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _showEmployeeDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBanner({
    required int total,
    required int active,
    required int inactive,
    required double totalSalary,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _metricCard(
              title: context.tr('Masse Salariale Brute'),
              value: _formatCurrency(totalSalary),
              subtitle: 'Base mensuelle des actifs',
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: _metricCard(
              title: context.tr('Effectif Total'),
              value: '$total collaborateurs',
              subtitle: '$active en poste actif',
              icon: Icons.badge_outlined,
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: _metricCard(
              title: context.tr('Statut des Contrats'),
              value: '$active Actif(s)',
              subtitle: inactive > 0 ? '$inactive collaborateur(s) inactif(s)' : '100% de l\'équipe active',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: context.tr('Rechercher par nom, matricule, poste ou téléphone...'),
                  hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
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
          const SizedBox(width: 10),
          // Department Filter
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDepartment,
                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDepartment = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Contract Filter
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedContract,
                items: _contracts.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedContract = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Status Segmented Filter
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusBtn('Tous', 'all'),
                _statusBtn('Actifs', 'active'),
                _statusBtn('Inactifs', 'inactive'),
              ],
            ),
          ),

          // View Mode Toggle (Tableau / Cartes) for Desktop & Web
          if (PlatformUtils.isDesktop || PlatformUtils.isWeb) ...[
            const SizedBox(width: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Affichage Tableau',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _isTableView = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isTableView ? const Color(0xFF1A56DB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.table_chart_outlined,
                          size: 16,
                          color: _isTableView ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Affichage Cartes',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _isTableView = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isTableView ? const Color(0xFF1A56DB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: !_isTableView ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBtn(String label, String val) {
    final isSelected = _selectedStatus == val;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _selectedStatus = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A56DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            context.tr('Aucun collaborateur trouvé'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Ajoutez vos employés pour suivre leurs contrats et rémunérations.'),
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: Text(context.tr('Ajouter un employé')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
            onPressed: () => _showEmployeeDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeDetailProfileScreen(employee: emp),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                child: Text(
                  emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB), fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      emp.jobTitle,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                onSelected: (val) {
                  if (val == 'view_profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeeDetailProfileScreen(employee: emp),
                      ),
                    );
                  } else if (val == 'contract') {
                    ContractFormDialog.show(context, employee: emp);
                  } else if (val == 'edit') {
                    _showEmployeeDialog(employee: emp);
                  } else if (val == 'toggle') {
                    context.read<EmployeesBloc>().add(UpdateEmployee(emp.copyWith(isActive: !emp.isActive)));
                  } else if (val == 'delete') {
                    _confirmDeleteEmployee(emp);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'view_profile',
                    child: Row(children: const [
                      Icon(Icons.badge_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 8),
                      Text('Dossier employé (360°)'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'contract',
                    child: Row(children: const [
                      Icon(Icons.description_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 8),
                      Text('Gérer Contrat'),
                    ]),
                  ),
                  PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 16), const SizedBox(width: 8), Text(context.tr('Modifier'))])),
                  PopupMenuItem(value: 'toggle', child: Row(children: [Icon(emp.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 16), const SizedBox(width: 8), Text(emp.isActive ? 'Désactiver' : 'Activer')])),
                  PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1A56DB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(emp.department, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB))),
              ),
              InkWell(
                onTap: () => ContractFormDialog.show(context, employee: emp),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 10, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 3),
                      Text(emp.contractType, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: emp.isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emp.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: emp.isActive ? const Color(0xFF10B981) : Colors.red),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 16),
          // Bottom Info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salaire de base', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
                  Text(_formatCurrency(emp.baseSalary), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Gérer contrat',
                icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF1A56DB)),
                onPressed: () => ContractFormDialog.show(context, employee: emp),
              ),
              if (emp.phone != null && emp.phone!.isNotEmpty)
                IconButton(
                  tooltip: 'Appeler ${emp.phone}',
                  icon: const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF2563EB)),
                  onPressed: () => launchUrl(Uri.parse('tel:${emp.phone}')),
                ),
              if (emp.email != null && emp.email!.isNotEmpty)
                IconButton(
                  tooltip: 'Email ${emp.email}',
                  icon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF1A56DB)),
                  onPressed: () => launchUrl(Uri.parse('mailto:${emp.email}')),
                ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildEmployeesTable(List<Employee> employees) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 46,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 60,
                          columnSpacing: 22,
                          horizontalMargin: 16,
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Poste', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Département', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Date d\'embauche', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Salaire de base', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                          ],
                          rows: employees.map((emp) {
                            return DataRow(
                              onSelectChanged: (_) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmployeeDetailProfileScreen(employee: emp),
                                ),
                              ),
                              cells: [
                                // 1. Employé
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                                        child: Text(
                                          emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB), fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            emp.fullName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                          ),
                                          if (emp.code.isNotEmpty)
                                            Text(
                                              emp.code,
                                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // 2. Poste
                                DataCell(
                                  Text(
                                    emp.jobTitle.isNotEmpty ? emp.jobTitle : '—',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                                  ),
                                ),

                                // 3. Département
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF1A56DB).withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      emp.department,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB)),
                                    ),
                                  ),
                                ),

                                // 4. Contrat
                                DataCell(
                                  InkWell(
                                    onTap: () => ContractFormDialog.show(context, employee: emp),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.description_outlined, size: 12, color: Color(0xFF1A56DB)),
                                          const SizedBox(width: 4),
                                          Text(
                                            emp.contractType,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // 5. Date d'embauche
                                DataCell(
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(emp.hireDate),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ),

                                // 6. Salaire de base
                                DataCell(
                                  Text(
                                    _formatCurrency(emp.baseSalary),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ),

                                // 7. Contact (Phone & Email)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (emp.phone != null && emp.phone!.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Appeler ${emp.phone}',
                                          icon: const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF2563EB)),
                                          onPressed: () => launchUrl(Uri.parse('tel:${emp.phone}')),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                        ),
                                      if (emp.email != null && emp.email!.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Email ${emp.email}',
                                          icon: const Icon(Icons.email_outlined, size: 15, color: Color(0xFF1A56DB)),
                                          onPressed: () => launchUrl(Uri.parse('mailto:${emp.email}')),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                        ),
                                      if ((emp.phone == null || emp.phone!.isEmpty) && (emp.email == null || emp.email!.isEmpty))
                                        const Text('—', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),

                                // 8. Statut
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: emp.isActive
                                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: emp.isActive ? const Color(0xFF10B981) : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          emp.isActive ? 'Actif' : 'Inactif',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: emp.isActive ? const Color(0xFF10B981) : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 9. Actions
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Gérer contrat',
                                        icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF1A56DB)),
                                        onPressed: () => ContractFormDialog.show(context, employee: emp),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        tooltip: 'Modifier',
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                                        onPressed: () => _showEmployeeDialog(employee: emp),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                      ),
                                      const SizedBox(width: 2),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                        onSelected: (val) {
                                          if (val == 'view_profile') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EmployeeDetailProfileScreen(employee: emp),
                                              ),
                                            );
                                          } else if (val == 'contract') {
                                            ContractFormDialog.show(context, employee: emp);
                                          } else if (val == 'edit') {
                                            _showEmployeeDialog(employee: emp);
                                          } else if (val == 'toggle') {
                                            context.read<EmployeesBloc>().add(UpdateEmployee(emp.copyWith(isActive: !emp.isActive)));
                                          } else if (val == 'delete') {
                                            _confirmDeleteEmployee(emp);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: 'view_profile',
                                            child: Row(children: const [
                                              Icon(Icons.badge_outlined, size: 16, color: Color(0xFF1A56DB)),
                                              SizedBox(width: 8),
                                              Text('Dossier employé (360°)'),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'contract',
                                            child: Row(children: const [
                                              Icon(Icons.description_outlined, size: 16, color: Color(0xFF1A56DB)),
                                              SizedBox(width: 8),
                                              Text('Gérer Contrat'),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [
                                              const Icon(Icons.edit_outlined, size: 16),
                                              const SizedBox(width: 8),
                                              Text(context.tr('Modifier')),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Row(children: [
                                              Icon(emp.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 16),
                                              const SizedBox(width: 8),
                                              Text(emp.isActive ? 'Désactiver' : 'Activer'),
                                            ]),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(children: const [
                                              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Supprimer', style: TextStyle(color: Colors.red)),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Text(
                    'Total : ${employees.length} collaborateur(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  Text(
                    '${employees.where((e) => e.isActive).length} Actif(s) • ${employees.where((e) => !e.isActive).length} Inactif(s)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeDialog({Employee? employee}) {
    EmployeeFormDialog.show(context, employee: employee);
  }

  void _confirmDeleteEmployee(Employee emp) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'supprimer cet employé',
      onConfirmed: () {
        context.read<EmployeesBloc>().add(DeleteEmployee(emp.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employé "${emp.fullName}" supprimé.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
