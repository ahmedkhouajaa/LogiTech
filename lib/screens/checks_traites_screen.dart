import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/checks_traites/checks_traites_bloc.dart';
import '../models/check_traite.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';

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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Text(
                'Cheques & Traites',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              const Spacer(),
              // Type Filter
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous les types')),
                      DropdownMenuItem(value: 'check_received', child: Text('Cheque (Client)')),
                      DropdownMenuItem(value: 'check_issued', child: Text('Cheque (Fournisseur)')),
                      DropdownMenuItem(value: 'traite_received', child: Text('Traite (Client)')),
                      DropdownMenuItem(value: 'traite_issued', child: Text('Traite (Fournisseur)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search
              SizedBox(
                width: 250,
                height: 36,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un n° ou nom...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: BlocBuilder<ChecksTraitesBloc, ChecksTraitesState>(
            builder: (context, state) {
              if (state is ChecksTraitesLoading) return const Center(child: CircularProgressIndicator());
              if (state is ChecksTraitesError) return Center(child: Text('Erreur: \${state.message}'));
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DataTableWidget<CheckTraite>(
                      columns: const ['N° Document', 'Type', 'Tiers', 'Montant', 'Echeance', 'Banque', 'Statut', 'Actions'],
                      rows: filtered,
                      emptyMessage: 'Aucun document trouve',
                      cellBuilder: (doc) {
                        return [
                          DataCell(Text(doc.documentNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                          DataCell(Text(_getTypeLabel(doc.type))),
                          DataCell(Text(doc.partyName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(formatCurrencyDT(doc.amount), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(DateFormat('dd/MM/yyyy').format(doc.maturityDate))),
                          DataCell(Text(doc.bankName ?? '—')),
                          DataCell(_buildStatusBadge(doc.status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (doc.status == 'pending') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
                                    onPressed: () => context.read<ChecksTraitesBloc>().add(UpdateCheckTraiteStatus(doc.id, 'cashed')),
                                    tooltip: 'Marquer encaisse',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                                    onPressed: () => context.read<ChecksTraitesBloc>().add(UpdateCheckTraiteStatus(doc.id, 'bounced')),
                                    tooltip: 'Marquer impaye',
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
        const SizedBox(height: AppSpacing.lg),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
