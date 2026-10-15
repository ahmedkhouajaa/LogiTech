import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/leaves/leaves_bloc.dart';
import '../../blocs/leaves/leaves_event.dart';
import '../../blocs/leaves/leaves_state.dart';
import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_event.dart';
import '../../blocs/employees/employees_state.dart';
import 'package:uuid/uuid.dart';

import '../../models/leave_request.dart';
import '../../models/public_holiday.dart';
import '../../services/public_holiday_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../services/permission_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/offline_action_helper.dart';
import '../../widgets/leave_allocation_dialog.dart';
import '../../widgets/leave_request_form_dialog.dart';
import '../../widgets/odoo_datetime_picker_dialog.dart';

/// Vue mobile des allocations et demandes de congés (Prise de congés)
/// Conforme à la structure Odoo ERP (Images 1, 2, 3, 4 & 5)
class MobileHrLeavesScreen extends StatefulWidget {
  const MobileHrLeavesScreen({super.key});

  @override
  State<MobileHrLeavesScreen> createState() => _MobileHrLeavesScreenState();
}

class _MobileHrLeavesScreenState extends State<MobileHrLeavesScreen> with SingleTickerProviderStateMixin {
  bool _isFirstLoad = true;
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<LeavesBloc>().add(const LoadLeaves());
    context.read<EmployeesBloc>().add(const LoadEmployees());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return const Color(0xFFC2410C);
    final code = name.codeUnitAt(0) % 5;
    switch (code) {
      case 0:
        return const Color(0xFFC2410C);
      case 1:
        return const Color(0xFF16A34A);
      case 2:
        return const Color(0xFF0D9488);
      case 3:
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('Congés & Absences'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1A56DB),
          labelColor: const Color(0xFF1A56DB),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Prises de congés'),
            Tab(text: 'Allocations de crédit'),
            Tab(text: 'Jours fériés'),
          ],
        ),
        actions: [
          _buildActivityButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => context.read<LeavesBloc>().add(const LoadLeaves()),
          ),
        ],
      ),
      body: BlocBuilder<EmployeesBloc, EmployeesState>(
        builder: (context, empState) {
          return BlocConsumer<LeavesBloc, LeavesState>(
            listener: (context, state) {
              if (_isFirstLoad && (state is LeavesLoaded || state is LeavesError)) {
                setState(() {
                  _isFirstLoad = false;
                });
              }
            },
            builder: (context, state) {
              if (_isFirstLoad || state is LeavesLoading || state is LeavesInitial) {
                return Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allLeaves = state is LeavesLoaded ? state.leaves : <LeaveRequest>[];

              final requests = allLeaves.where((l) => !l.isAllocation).toList();
              final allocations = allLeaves.where((l) => l.isAllocation).toList();

              int pendingCount = 0;
              int secondApproveCount = 0;
              int approvedCount = 0;
              double totalDays = 0;

              for (final l in requests) {
                totalDays += l.daysCount;
                if (l.isPending) pendingCount++;
                if (l.isSecondApproval) secondApproveCount++;
                if (l.isApproved) approvedCount++;
              }

              final filteredRequests = _filterList(requests);
              final filteredAllocations = _filterList(allocations);

              return Column(
                children: [
                  // Top Summary Metrics
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _mobileMetricItem('À approuver', '$pendingCount', const Color(0xFFF59E0B)),
                        Container(width: 1, height: 28, color: AppColors.border),
                        _mobileMetricItem('2ème approb.', '$secondApproveCount', const Color(0xFFD97706)),
                        Container(width: 1, height: 28, color: AppColors.border),
                        _mobileMetricItem('Approuvés', '$approvedCount', const Color(0xFF10B981)),
                        Container(width: 1, height: 28, color: AppColors.border),
                        _mobileMetricItem('Total jours', '${totalDays.toStringAsFixed(0)} j', const Color(0xFF1A56DB)),
                      ],
                    ),
                  ),

                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par nom ou motif...',
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

                  // Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('Tous', 'all'),
                          const SizedBox(width: 6),
                          _filterChip('À approuver ($pendingCount)', 'pending'),
                          const SizedBox(width: 6),
                          _filterChip('2ème approbation ($secondApproveCount)', 'second_approval'),
                          const SizedBox(width: 6),
                          _filterChip('Approuvés ($approvedCount)', 'approved'),
                          const SizedBox(width: 6),
                          _filterChip('Refusés', 'rejected'),
                        ],
                      ),
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: state is LeavesLoading && allLeaves.isEmpty
                        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              // TAB 1: Prises de congés
                              filteredRequests.isEmpty
                                   ? _buildEmptyState('Aucune prise de congé')
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                                      itemCount: filteredRequests.length,
                                      itemBuilder: (context, idx) => _buildRequestCard(filteredRequests[idx]),
                                    ),

                              // TAB 2: Allocations
                              filteredAllocations.isEmpty
                                  ? _buildEmptyState('Aucune allocation de crédit')
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                                      itemCount: filteredAllocations.length,
                                      itemBuilder: (context, idx) => _buildAllocationCard(filteredAllocations[idx]),
                                    ),

                              // TAB 3: Jours fériés
                              _buildMobileHolidaysTab(),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Nouveau congé', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddActionMenu(context),
      ),
    );
  }

  void _showAddActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Action rapide RH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.beach_access_rounded, color: Color(0xFF1A56DB))),
              title: const Text('Demande de congé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Enregistrer une absence pour un collaborateur', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                LeaveRequestFormDialog.show(context, isQuickMode: true);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFECFDF5), child: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981))),
              title: const Text('Allouer un solde', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Attribuer des jours de congés annuels ou cumuls', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                LeaveAllocationDialog.show(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.celebration_rounded, color: Color(0xFFD97706))),
              title: const Text('Nouveau jour férié', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Ajouter un jour férié ou congé officiel', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddHolidayDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityButton() {
    return BlocBuilder<LeavesBloc, LeavesState>(
      builder: (context, state) {
        final allLeaves = state is LeavesLoaded ? state.leaves : <LeaveRequest>[];
        final pendingCount = allLeaves.where((l) => !l.isAllocation && (l.isPending || l.isSecondApproval)).length;

        return PopupMenuButton<String>(
          tooltip: 'Activités',
          offset: const Offset(0, 45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.access_time_rounded, size: 22),
                if (pendingCount > 0)
                  Positioned(
                    top: 8,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              enabled: false,
              child: Container(
                width: 260,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.beach_access_rounded, color: Color(0xFF0284C7), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Congés', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Text('0 En retard', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(width: 6),
                              Text('$pendingCount Aujourd\'hui', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                              const SizedBox(width: 6),
                              const Text('0 Futur(e)s', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'filter_pending',
              child: Row(
                children: const [
                  Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF1A56DB)),
                  SizedBox(width: 8),
                  Text('En attente de validation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
                ],
              ),
            ),
          ],
          onSelected: (val) {
            if (val == 'filter_pending') {
              setState(() => _selectedFilter = 'pending');
            }
          },
        );
      },
    );
  }

  List<LeaveRequest> _filterList(List<LeaveRequest> list) {
    return list.where((l) {
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'pending' && !l.isPending) return false;
        if (_selectedFilter == 'second_approval' && !l.isSecondApproval) return false;
        if (_selectedFilter == 'approved' && !l.isApproved) return false;
        if (_selectedFilter == 'rejected' && !l.isRejected) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = l.employeeName.toLowerCase().contains(q);
        final matchType = l.leaveType.toLowerCase().contains(q);
        final matchDesc = (l.description ?? '').toLowerCase().contains(q);
        if (!matchName && !matchType && !matchDesc) return false;
      }
      return true;
    }).toList();
  }

  Widget _mobileMetricItem(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600)),
      selected: sel,
      selectedColor: const Color(0xFF1A56DB),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: sel ? Colors.transparent : AppColors.border)),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildEmptyState(String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // Request Card (Prise de congé)
  Widget _buildRequestCard(LeaveRequest l) {
    final avatarColor = _getAvatarColor(l.employeeName);
    final initial = l.employeeName.trim().isNotEmpty ? l.employeeName.trim()[0].toUpperCase() : 'A';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: InkWell(
        onTap: () => LeaveRequestFormDialog.show(context, leave: l),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: avatarColor, borderRadius: BorderRadius.circular(4)),
                    alignment: Alignment.center,
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: l.statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l.statusDisplay,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Text(l.leaveType, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const Spacer(),
                  Text(l.formatDuration(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
                ],
              ),
              const SizedBox(height: 4),

              Text(
                'Du ${l.formatStartWithTime()} au ${l.formatEndWithTime()}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),

              if (l.description != null && l.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(l.description!, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              ],

              // Inline Action buttons matching Odoo workflow
              if (l.isSecondApproval) ...[
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () {
                        OfflineActionHelper.executeAction(
                          context: context,
                          action: 'reject',
                          customActionLabel: 'le refus du congé',
                          onConfirmed: () {
                            context.read<LeavesBloc>().add(UpdateLeaveStatus(
                              id: l.id,
                              newStatus: 'rejected',
                              approvedBy: PermissionService.instance.userName,
                            ));
                          },
                        );
                      },
                      icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                      label: const Text('Refuser', style: TextStyle(fontSize: 11.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 30),
                        elevation: 0,
                      ),
                      onPressed: () {
                        OfflineActionHelper.executeAction(
                          context: context,
                          action: 'validate',
                          customActionLabel: 'la validation finale du congé',
                          onConfirmed: () {
                            context.read<LeavesBloc>().add(UpdateLeaveStatus(
                              id: l.id,
                              newStatus: 'approved',
                              approvedBy: PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
                            ));
                          },
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      label: const Text('Valider', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else if (l.isPending) ...[
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () {
                        OfflineActionHelper.executeAction(
                          context: context,
                          action: 'reject',
                          customActionLabel: 'le refus du congé',
                          onConfirmed: () {
                            context.read<LeavesBloc>().add(UpdateLeaveStatus(
                              id: l.id,
                              newStatus: 'rejected',
                              approvedBy: PermissionService.instance.userName,
                            ));
                          },
                        );
                      },
                      icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                      label: const Text('Refuser', style: TextStyle(fontSize: 11.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 30),
                        elevation: 0,
                      ),
                      onPressed: () {
                        OfflineActionHelper.executeAction(
                          context: context,
                          action: 'validate',
                          customActionLabel: "l'approbation du congé",
                          onConfirmed: () {
                            context.read<LeavesBloc>().add(UpdateLeaveStatus(
                              id: l.id,
                              newStatus: 'second_approval',
                              approvedBy: PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
                            ));
                          },
                        );
                      },
                      icon: const Icon(Icons.thumb_up_rounded, size: 13, color: Colors.white),
                      label: const Text('Approuver', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else if (l.isApproved) ...[
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    const Text('Validé', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: const Size(0, 26),
                      ),
                      onPressed: () {
                        OfflineActionHelper.executeAction(
                          context: context,
                          action: 'reject',
                          customActionLabel: 'le refus du congé',
                          onConfirmed: () {
                            context.read<LeavesBloc>().add(UpdateLeaveStatus(
                              id: l.id,
                              newStatus: 'rejected',
                              approvedBy: PermissionService.instance.userName,
                            ));
                          },
                        );
                      },
                      child: const Text('Refuser', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Allocation Card
  Widget _buildAllocationCard(LeaveRequest l) {
    final avatarColor = _getAvatarColor(l.employeeName);
    final initial = l.employeeName.trim().isNotEmpty ? l.employeeName.trim()[0].toUpperCase() : 'A';
    final daysStr = '${l.daysCount.toStringAsFixed(l.daysCount.truncateToDouble() == l.daysCount ? 0 : 1)} ${l.unit.toLowerCase()}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: InkWell(
        onTap: () => LeaveAllocationDialog.show(context, leave: l),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: avatarColor, borderRadius: BorderRadius.circular(4)),
                    alignment: Alignment.center,
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: l.isApproved ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l.statusDisplay,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Text(l.leaveType, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  const SizedBox(width: 6),
                  Text('• ${l.displayDescription}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Text('Montant : $daysStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
                  const Spacer(),
                  Text(l.allocationType, style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                !l.isUnlimitedValidity && l.validityEndDate != null
                    ? 'Valide : ${_formatDate(l.validityStartDate)} au ${_formatDate(l.validityEndDate!)}'
                    : 'Période : ${_formatDate(l.validityStartDate)} ➔ Sans limites',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 3: Jours fériés (Mobile)
  Widget _buildMobileHolidaysTab() {
    return AnimatedBuilder(
      animation: PublicHolidayService.instance,
      builder: (context, _) {
        final allHolidays = PublicHolidayService.instance.holidays;
        final filtered = allHolidays.where((h) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return h.name.toLowerCase().contains(q) || h.workingHoursSchedule.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('Aucun jour férié trouvé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter un jour férié'),
                    onPressed: () => _showAddHolidayDialog(context),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
          itemCount: filtered.length,
          itemBuilder: (context, idx) => _buildHolidayCard(filtered[idx]),
        );
      },
    );
  }

  Widget _buildHolidayCard(PublicHoliday h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.celebration_rounded, size: 16, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1A56DB)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showAddHolidayDialog(context, holiday: h),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    await PublicHolidayService.instance.deleteHoliday(h.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Du ${h.formattedDateFrom} au ${h.formattedDateTo}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                h.workingHoursSchedule,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHolidayDialog(BuildContext context, {PublicHoliday? holiday}) {
    final nameCtrl = TextEditingController(text: holiday?.name ?? '');
    DateTime start = holiday?.dateFrom ?? DateTime(DateTime.now().year, 1, 1, 0, 0, 0);
    DateTime end = holiday?.dateTo ?? DateTime(DateTime.now().year, 1, 1, 23, 59, 59);
    String schedule = holiday?.workingHoursSchedule ?? 'Standard 40 hours/week';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        holiday != null ? 'Modifier jour férié' : 'Nouveau jour férié',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du jour férié',
                      hintText: 'ex: Jour de l\'An, Fête du Travail',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & heure de début', style: TextStyle(fontSize: 12.5)),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(start), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await OdooDateTimePickerDialog.show(context, initialDateTime: start);
                      if (picked != null) setModalState(() => start = picked);
                    },
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & heure de fin', style: TextStyle(fontSize: 12.5)),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(end), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await OdooDateTimePickerDialog.show(context, initialDateTime: end);
                      if (picked != null) setModalState(() => end = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSaving ? null : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      if (holiday != null) {
                        final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                        if (!isOnline) return;
                      }
                      setModalState(() => isSaving = true);
                      try {
                        final h = PublicHoliday(
                          id: holiday?.id ?? const Uuid().v4(),
                          name: name,
                          dateFrom: start,
                          dateTo: end,
                          workingHoursSchedule: schedule,
                        );
                        await PublicHolidayService.instance.saveHoliday(h);
                        final isOnline = ConnectivityService.instance.isOnline;
                        if (ctx.mounted) {
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
                                        ? 'Jour férié enregistré'
                                        : 'Jour férié enregistré hors ligne (en attente de synchronisation)',
                                  ),
                                ],
                              ),
                              backgroundColor: isOnline ? AppColors.success : AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      } finally {
                        if (modalCtx.mounted) setModalState(() => isSaving = false);
                      }
                    },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
