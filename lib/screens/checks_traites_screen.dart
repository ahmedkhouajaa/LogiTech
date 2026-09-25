import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/checks_traites/checks_traites_bloc.dart';
import '../models/check_traite.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_table_row.dart';
import '../l10n/app_localizations.dart';

class ChecksTraitesScreen extends StatefulWidget {
  const ChecksTraitesScreen({super.key});

  @override
  State<ChecksTraitesScreen> createState() => _ChecksTraitesScreenState();
}

class _ChecksTraitesScreenState extends State<ChecksTraitesScreen> with SingleTickerProviderStateMixin {
  String _search = '';
  String _statusFilter = 'all'; // all, en_attente, depose, encaisse, rejete
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  Text(
                    'Gestion et suivi des chèques et traites clients et fournisseurs',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              // Statut filter
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(context.tr('Tous les statuts'))),
                      DropdownMenuItem(value: 'en_attente', child: Text(context.tr('En attente'))),
                      DropdownMenuItem(value: 'depose', child: Text(context.tr('Déposé'))),
                      DropdownMenuItem(value: 'encaisse', child: Text(context.tr('Encaissé'))),
                      DropdownMenuItem(value: 'rejete', child: Text(context.tr('Rejeté'))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Search field
              SizedBox(
                width: 250,
                height: 34,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.tr('Rechercher réf, tiers, doc...'),
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabs: Clients vs Fournisseurs
        BlocBuilder<ChecksTraitesBloc, ChecksTraitesState>(
          builder: (context, state) {
            int clientCount = 0;
            int fournisseurCount = 0;
            if (state is ChecksTraitesLoaded) {
              clientCount = state.documents.where((d) => d.isClient).length;
              fournisseurCount = state.documents.where((d) => d.isFournisseur).length;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        isSelected: _tabController.index == 0,
                        icon: _tabController.index == 0 ? Icons.person_rounded : Icons.person_outline_rounded,
                        title: context.tr('Chèques & Traites Clients'),
                        count: clientCount,
                        onTap: () {
                          if (_tabController.index != 0) {
                            _tabController.animateTo(0);
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildSegmentButton(
                        isSelected: _tabController.index == 1,
                        icon: _tabController.index == 1 ? Icons.local_shipping_rounded : Icons.local_shipping_outlined,
                        title: context.tr('Chèques & Traites Fournisseurs'),
                        count: fournisseurCount,
                        onTap: () {
                          if (_tabController.index != 1) {
                            _tabController.animateTo(1);
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Table
        Expanded(
          child: BlocBuilder<ChecksTraitesBloc, ChecksTraitesState>(
            builder: (context, state) {
              if (state is ChecksTraitesLoading || state is ChecksTraitesInitial) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ShimmerTable(
                    headerColumns: [
                      Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 3, child: Text('Entité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Échéance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Compte Trésorerie', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Document Lié', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      SizedBox(width: 100, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                );
              }
              if (state is ChecksTraitesError) return AppErrorWidget(message: state.message);
              if (state is ChecksTraitesLoaded) {
                final isClientTab = _tabController.index == 0;
                final filtered = state.documents.where((doc) {
                  // Tab match
                  final matchesTab = isClientTab ? doc.isClient : doc.isFournisseur;
                  if (!matchesTab) return false;

                  // Status match
                  if (_statusFilter != 'all') {
                    final normalizedStatus = doc.status.toLowerCase().replaceAll('é', 'e');
                    if (normalizedStatus != _statusFilter) return false;
                  }

                  // Search match
                  if (_search.isNotEmpty) {
                    final ref = doc.reference.toLowerCase();
                    final num = doc.documentNumber.toLowerCase();
                    final party = doc.partyName.toLowerCase();
                    final docRef = (doc.documentRef ?? '').toLowerCase();
                    final bank = (doc.compteTresorerieName ?? '').toLowerCase();
                    if (!ref.contains(_search) && !num.contains(_search) && !party.contains(_search) && !docRef.contains(_search) && !bank.contains(_search)) {
                      return false;
                    }
                  }

                  return true;
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
                      columns: const [
                        'Type',
                        'Référence',
                        'Entité',
                        'Montant',
                        'Date d\'Échéance',
                        'Compte de Trésorerie',
                        'Statut',
                        'Document lié',
                        'Actions',
                      ],
                      rows: filtered,
                      emptyMessage: isClientTab
                          ? 'Aucun chèque ou traite client trouvé'
                          : 'Aucun chèque ou traite fournisseur trouvé',
                      cellBuilder: (doc) {
                        return [
                          // Type
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  doc.type == 'traite' ? Icons.receipt_long_outlined : Icons.description_outlined,
                                  size: 16,
                                  color: doc.type == 'traite' ? AppColors.secondary : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  doc.type == 'traite' ? 'Traite' : 'Chèque',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          // Référence
                          DataCell(
                            Text(
                              doc.reference.isNotEmpty ? doc.reference : doc.documentNumber,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.primary),
                            ),
                          ),
                          // Entité
                          DataCell(
                            Text(
                              doc.partyName.isNotEmpty ? doc.partyName : '—',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
                            ),
                          ),
                          // Montant
                          DataCell(
                            Text(
                              formatCurrencyDT(doc.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                          // Date d'Échéance
                          DataCell(
                            Text(
                              DateFormat('dd/MM/yyyy').format(doc.maturityDate),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          // Compte de Trésorerie
                          DataCell(
                            Text(
                              doc.compteTresorerieName ?? '—',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          // Statut
                          DataCell(_buildStatusBadge(doc.status)),
                          // Document lié (clickable)
                          DataCell(
                            doc.documentRef != null && doc.documentRef!.isNotEmpty
                                ? InkWell(
                                    onTap: () => _showLinkedDocDialog(context, doc),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            doc.documentRef!,
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const Text('—', style: TextStyle(color: Colors.grey)),
                          ),
                          // Actions: Voir 👁️, Déposer ⬆️, Rejeter ❌
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Voir 👁️
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Voir les détails',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showDetailsDialog(context, doc),
                                ),
                                const SizedBox(width: 10),
                                // Déposer ⬆️
                                if (doc.canDeposit)
                                  IconButton(
                                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                                    color: AppColors.primary,
                                    tooltip: 'Déposer',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDeposit(context, doc),
                                  ),
                                if (doc.canDeposit) const SizedBox(width: 10),
                                // Rejeter ❌
                                if (doc.canReject)
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, size: 18),
                                    color: AppColors.error,
                                    tooltip: 'Rejeter',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmReject(context, doc),
                                  ),
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

  Widget _buildSegmentButton({
    required bool isSelected,
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: AppColors.border) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: isSelected ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;
    final s = status.toLowerCase().replaceAll('é', 'e');

    switch (s) {
      case 'en_attente':
      case 'pending':
        color = const Color(0xFFF59E0B);
        label = 'En attente';
        icon = Icons.access_time_rounded;
        break;
      case 'depose':
      case 'deposited':
        color = const Color(0xFF3B82F6);
        label = 'Déposé';
        icon = Icons.file_upload_outlined;
        break;
      case 'encaisse':
      case 'cashed':
        color = const Color(0xFF10B981);
        label = 'Encaissé';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'rejete':
      case 'bounced':
        color = const Color(0xFFEF4444);
        label = 'Rejeté';
        icon = Icons.cancel_outlined;
        break;
      case 'annule':
      case 'cancelled':
        color = AppColors.textTertiary;
        label = 'Annulé';
        icon = Icons.block_outlined;
        break;
      default:
        color = AppColors.textTertiary;
        label = status;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _confirmDeposit(BuildContext context, CheckTraite doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DepositConfirmDialog(
        doc: doc,
        isDeposit: true,
        onConfirm: (dialogCtx) async {
          context.read<ChecksTraitesBloc>().add(DepositCheckTraite(doc));
          // Wait for the bloc to emit ChecksTraitesLoaded (op completed)
          await context.read<ChecksTraitesBloc>().stream
              .firstWhere((s) => s is ChecksTraitesLoaded || s is ChecksTraitesError);
          if (!dialogCtx.mounted) return;
          Navigator.of(dialogCtx).pop();
          if (!context.mounted) return;
          final label = doc.type == 'traite' ? 'Traite' : 'Chèque';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label déposé(e) avec succès'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _confirmReject(BuildContext context, CheckTraite doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DepositConfirmDialog(
        doc: doc,
        isDeposit: false,
        onConfirm: (dialogCtx) async {
          context.read<ChecksTraitesBloc>().add(RejectCheckTraite(doc));
          await context.read<ChecksTraitesBloc>().stream
              .firstWhere((s) => s is ChecksTraitesLoaded || s is ChecksTraitesError);
          if (!dialogCtx.mounted) return;
          Navigator.of(dialogCtx).pop();
          if (!context.mounted) return;
          final label = doc.type == 'traite' ? 'Traite' : 'Chèque';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label rejeté(e)'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }


  void _showDetailsDialog(BuildContext context, CheckTraite doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  doc.type == 'traite' ? Icons.receipt_long_outlined : Icons.description_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Détails ${doc.type == 'traite' ? 'Traite' : 'Chèque'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            _buildStatusBadge(doc.status),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildDetailRow('Référence:', doc.reference.isNotEmpty ? doc.reference : doc.documentNumber),
              _buildDetailRow('Type:', doc.type == 'traite' ? 'Traite' : 'Chèque'),
              _buildDetailRow('Entité (${doc.isClient ? "Client" : "Fournisseur"}):', doc.partyName),
              _buildDetailRow('Montant:', formatCurrencyDT(doc.amount), isBold: true),
              _buildDetailRow('Date d\'émission:', DateFormat('dd/MM/yyyy').format(doc.issueDate)),
              _buildDetailRow('Date d\'échéance:', DateFormat('dd/MM/yyyy').format(doc.maturityDate)),
              _buildDetailRow('Compte de Trésorerie:', doc.compteTresorerieName ?? '—'),
              _buildDetailRow('Document lié:', doc.documentRef != null ? '${doc.documentRef} (${doc.documentType ?? ""})' : 'Aucun'),
              if (doc.dateDepot != null)
                _buildDetailRow('Date de dépôt:', DateFormat('dd/MM/yyyy HH:mm').format(doc.dateDepot!)),
              if (doc.notes != null && doc.notes!.isNotEmpty)
                _buildDetailRow('Notes:', doc.notes!),
            ],
          ),
        ),
        actions: [
          if (doc.canReject)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmReject(context, doc);
              },
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Rejeter'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            ),
          if (doc.canDeposit)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeposit(context, doc);
              },
              icon: const Icon(Icons.file_upload_outlined, size: 16, color: Colors.white),
              label: const Text('Déposer', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showLinkedDocDialog(BuildContext context, CheckTraite doc) {
    String docTypeLabel = 'Document';
    if (doc.documentType == 'facture_vente') docTypeLabel = 'Facture de vente';
    if (doc.documentType == 'facture_achat') docTypeLabel = 'Facture d\'achat';
    if (doc.documentType == 'bon_livraison') docTypeLabel = 'Bon de livraison';
    if (doc.documentType == 'bon_reception') docTypeLabel = 'Bon de réception';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.link_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Document Lié: ${doc.documentRef ?? ""}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type de document:', docTypeLabel),
            _buildDetailRow('Numéro / Réf:', doc.documentRef ?? '—'),
            _buildDetailRow('Entité:', doc.partyName),
            _buildDetailRow('Montant du paiement:', formatCurrencyDT(doc.amount)),
            _buildDetailRow('Statut paiement:', doc.status),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable stateful deposit/reject confirmation dialog with loading indicator
// ---------------------------------------------------------------------------
class _DepositConfirmDialog extends StatefulWidget {
  final CheckTraite doc;
  final bool isDeposit;
  final Future<void> Function(BuildContext dialogCtx) onConfirm;

  const _DepositConfirmDialog({
    required this.doc,
    required this.isDeposit,
    required this.onConfirm,
  });

  @override
  State<_DepositConfirmDialog> createState() => _DepositConfirmDialogState();
}

class _DepositConfirmDialogState extends State<_DepositConfirmDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;
    final doc = widget.doc;
    final label = doc.type == 'traite' ? 'traite' : 'chèque';
    final accentColor = isDeposit ? AppColors.primary : AppColors.error;
    final icon = isDeposit ? Icons.file_upload_outlined : Icons.cancel_outlined;
    final title = isDeposit ? 'Confirmer le dépôt' : 'Confirmer le rejet';
    final actionLabel = isDeposit ? 'Déposer' : 'Rejeter';
    final content = isDeposit
        ? 'Voulez-vous marquer ce $label (${doc.reference}) de ${formatCurrencyDT(doc.amount)} comme déposé ?\n\n'
            'Cela va mettre à jour le document lié (${doc.documentRef ?? 'N/A'}) et impacter la trésorerie.'
        : 'Voulez-vous vraiment rejeter ce $label (${doc.reference}) ?\n\n'
            'Le statut du document lié (${doc.documentRef ?? 'N/A'}) passera à "Impayée".';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      content: Text(
        content,
        style: const TextStyle(fontSize: 13.5, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            minimumSize: const Size(100, 36),
          ),
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  await widget.onConfirm(context);
                  // dialog is popped inside onConfirm; nothing to do here
                },
          child: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(actionLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
