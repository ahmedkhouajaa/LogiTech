import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/checks_traites/checks_traites_bloc.dart';
import '../models/check_traite.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

class ChecksTraitesScreen extends StatefulWidget {
  const ChecksTraitesScreen({super.key});

  @override
  State<ChecksTraitesScreen> createState() => _ChecksTraitesScreenState();
}

class _ChecksTraitesScreenState extends State<ChecksTraitesScreen> {
  String _search = '';
  String _filterType = 'all'; // all, check_received, check_issued, traite_received, traite_issued

  @override
  void initState() {
    super.initState();
    context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chèques & Traites',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text('Gérer vos chèques et traites', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              // Type Filter
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType,
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous les types', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'check_received', child: Text('Chèque (Client)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'check_issued', child: Text('Chèque (Fournisseur)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'traite_received', child: Text('Traite (Client)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'traite_issued', child: Text('Traite (Fournisseur)', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Search
              SizedBox(
                width: 220,
                height: 32,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un n° ou nom...',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Table
        Expanded(
          child: BlocBuilder<ChecksTraitesBloc, ChecksTraitesState>(
            builder: (context, state) {
              if (state is ChecksTraitesLoading || state is ChecksTraitesInitial) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ShimmerTable(
                    headerColumns: [
                      Expanded(flex: 2, child: Text('N° Document', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 3, child: Text('Tiers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Échéance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Banque', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                );
              }
              if (state is ChecksTraitesError) return AppErrorWidget(message: state.message);
              if (state is ChecksTraitesLoaded) {
                final filtered = state.documents.where((doc) {
                  final matchesSearch = doc.documentNumber.toLowerCase().contains(_search) ||
                                        doc.partyName.toLowerCase().contains(_search);
                  final matchesType = _filterType == 'all' || doc.type == _filterType;
                  return matchesSearch && matchesType;
                }).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DataTableWidget<CheckTraite>(
                      columns: const ['N° Document', 'Type', 'Tiers', 'Montant', 'Échéance', 'Banque', 'Statut', 'Actions'],
                      rows: filtered,
                      emptyMessage: 'Aucun document trouvé',
                      cellBuilder: (doc) {
                        return [
                          DataCell(Text(doc.documentNumber, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.primary))),
                          DataCell(Text(_getTypeLabel(doc.type), style: const TextStyle(fontSize: 12.5))),
                          DataCell(Text(doc.partyName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5))),
                          DataCell(Text(formatCurrencyDT(doc.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                          DataCell(Text(DateFormat('dd/MM/yyyy').format(doc.maturityDate), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(doc.bankName ?? '—', style: const TextStyle(fontSize: 12))),
                          DataCell(_buildStatusBadge(doc.status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (doc.status == 'pending' && PermissionService.instance.canUpdate(UserPermissionResources.treasuryChecks)) ...[
                                  IconButton(
                                    icon: Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => context.read<ChecksTraitesBloc>().add(UpdateCheckTraiteStatus(doc.id, 'cashed')),
                                    tooltip: 'Marquer encaissé',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => context.read<ChecksTraitesBloc>().add(UpdateCheckTraiteStatus(doc.id, 'bounced')),
                                    tooltip: 'Marquer impayé',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'check_received': return 'Cheque (Recouvrement)';
      case 'check_issued': return 'Cheque (Paiement)';
      case 'traite_received': return 'Traite (Recouvrement)';
      case 'traite_issued': return 'Traite (Paiement)';
      default: return type;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'En attente';
        break;
      case 'cashed':
        color = AppColors.success;
        label = 'Encaisse';
        break;
      case 'bounced':
        color = AppColors.error;
        label = 'Impaye';
        break;
      default:
        color = AppColors.textTertiary;
        label = status;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
