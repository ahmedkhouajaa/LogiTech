import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/checks_traites/checks_traites_bloc.dart';
import '../../models/check_traite.dart';

class MobileChecksTraitesScreen extends StatefulWidget {
  const MobileChecksTraitesScreen({super.key});

  @override
  State<MobileChecksTraitesScreen> createState() => _MobileChecksTraitesScreenState();
}

class _MobileChecksTraitesScreenState extends State<MobileChecksTraitesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  int _selectedTab = 0; // 0: Clients, 1: Fournisseurs

  final List<String> _statusFilters = ['Tous', 'En attente', 'Déposé', 'Encaissé', 'Rejeté'];

  @override
  void initState() {
    super.initState();
    context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChecksTraitesBloc, ChecksTraitesState>(
      builder: (context, state) {
        bool isLoading = state is ChecksTraitesLoading || state is ChecksTraitesInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        int clientCount = 0;
        int fournisseurCount = 0;

        if (state is ChecksTraitesLoaded) {
          clientCount = state.documents.where((d) => d.isClient).length;
          fournisseurCount = state.documents.where((d) => d.isFournisseur).length;

          final isClientTab = _selectedTab == 0;
          final filteredItems = state.documents.where((doc) {
            // Tab filter
            final matchesTab = isClientTab ? doc.isClient : doc.isFournisseur;
            if (!matchesTab) return false;

            // Search filter
            if (_searchQuery.isNotEmpty) {
              final ref = doc.reference.toLowerCase();
              final num = doc.documentNumber.toLowerCase();
              final party = doc.partyName.toLowerCase();
              final docRef = (doc.documentRef ?? '').toLowerCase();
              final bank = (doc.compteTresorerieName ?? '').toLowerCase();
              if (!ref.contains(_searchQuery) &&
                  !num.contains(_searchQuery) &&
                  !party.contains(_searchQuery) &&
                  !docRef.contains(_searchQuery) &&
                  !bank.contains(_searchQuery)) {
                return false;
              }
            }

            // Status filter
            if (_selectedFilter != 'Tous') {
              final s = doc.status.toLowerCase().replaceAll('é', 'e');
              switch (_selectedFilter) {
                case 'En attente':
                  if (s != 'en_attente' && s != 'pending') return false;
                  break;
                case 'Déposé':
                  if (s != 'depose' && s != 'deposited') return false;
                  break;
                case 'Encaissé':
                  if (s != 'encaisse' && s != 'cashed') return false;
                  break;
                case 'Rejeté':
                  if (s != 'rejete' && s != 'bounced') return false;
                  break;
              }
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;
          cards = filteredItems.map((doc) => _buildCheckTraiteCard(context, doc)).toList();
        }

        return MobileGenericListScreen(
          title: 'Chèques & Traites',
          activeModule: AppModule.checksTraites,
          onModuleSelected: (module) {},
          onRefresh: () {
            context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: _statusFilters,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          customFilterWidget: _buildTabsToggle(clientCount, fournisseurCount),
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: _selectedTab == 0
              ? 'Aucun chèque ou traite client trouvé.'
              : 'Aucun chèque ou traite fournisseur trouvé.',
          fabText: null, // Read-only list: no add button
          onFabPressed: null,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildTabsToggle(int clientCount, int fournisseurCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTab == 0 ? AppShadows.sm : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: _selectedTab == 0 ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Clients',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _selectedTab == 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0
                            ? AppColors.primary.withOpacity(0.12)
                            : AppColors.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$clientCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0 ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTab == 1 ? AppShadows.sm : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 16,
                      color: _selectedTab == 1 ? AppColors.secondary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fournisseurs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _selectedTab == 1 ? AppColors.secondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1
                            ? AppColors.secondary.withOpacity(0.12)
                            : AppColors.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$fournisseurCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1 ? AppColors.secondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTraiteCard(BuildContext context, CheckTraite doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type + Reference + Status
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (doc.type == 'traite' ? AppColors.secondary : AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        doc.type == 'traite' ? Icons.receipt_long_outlined : Icons.description_outlined,
                        size: 14,
                        color: doc.type == 'traite' ? AppColors.secondary : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doc.type == 'traite' ? 'Traite' : 'Chèque',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: doc.type == 'traite' ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.reference.isNotEmpty ? doc.reference : doc.documentNumber,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(doc.status),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Entité & Montant
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.isClient ? 'Client' : 'Fournisseur',
                            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doc.partyName.isNotEmpty ? doc.partyName : '—',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Montant',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrencyDT(doc.amount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Échéance & Compte
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Échéance: ${DateFormat('dd/MM/yyyy').format(doc.maturityDate)}',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (doc.compteTresorerieName != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_outlined, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                doc.compteTresorerieName!,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Document lié link
                if (doc.documentRef != null && doc.documentRef!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showLinkedDocDialog(context, doc),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Doc lié: ${doc.documentRef!}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Action Buttons: Voir, Déposer, Rejeter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Voir 👁️
                TextButton.icon(
                  onPressed: () => _showDetailsDialog(context, doc),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Voir'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                // Déposer ⬆️
                if (doc.canDeposit) ...[
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _confirmDeposit(context, doc),
                    icon: const Icon(Icons.file_upload_outlined, size: 15, color: Colors.white),
                    label: const Text('Déposer', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                // Rejeter ❌
                if (doc.canReject) ...[
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: () => _confirmReject(context, doc),
                    icon: Icon(Icons.cancel_outlined, size: 15, color: AppColors.error),
                    label: Text('Rejeter', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _confirmDeposit(BuildContext context, CheckTraite doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MobileDepositConfirmDialog(
        doc: doc,
        isDeposit: true,
        onConfirm: (dialogCtx) async {
          context.read<ChecksTraitesBloc>().add(DepositCheckTraite(doc));
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
      builder: (ctx) => _MobileDepositConfirmDialog(
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
        title: Text('Détails ${doc.type == 'traite' ? 'Traite' : 'Chèque'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Référence:', doc.reference.isNotEmpty ? doc.reference : doc.documentNumber),
              _buildDetailRow('Type:', doc.type == 'traite' ? 'Traite' : 'Chèque'),
              _buildDetailRow('Entité (${doc.isClient ? "Client" : "Fournisseur"}):', doc.partyName),
              _buildDetailRow('Montant:', formatCurrencyDT(doc.amount), isBold: true),
              _buildDetailRow('Émission:', DateFormat('dd/MM/yyyy').format(doc.issueDate)),
              _buildDetailRow('Échéance:', DateFormat('dd/MM/yyyy').format(doc.maturityDate)),
              _buildDetailRow('Compte:', doc.compteTresorerieName ?? '—'),
              _buildDetailRow('Statut:', doc.status),
              _buildDetailRow('Document lié:', doc.documentRef ?? 'Aucun'),
              if (doc.notes != null && doc.notes!.isNotEmpty)
                _buildDetailRow('Notes:', doc.notes!),
            ],
          ),
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

  void _showLinkedDocDialog(BuildContext context, CheckTraite doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Document Lié: ${doc.documentRef ?? ""}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type:', doc.documentType ?? 'Document'),
            _buildDetailRow('Numéro:', doc.documentRef ?? '—'),
            _buildDetailRow('Entité:', doc.partyName),
            _buildDetailRow('Montant:', formatCurrencyDT(doc.amount)),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile version of the stateful deposit/reject confirmation dialog
// ---------------------------------------------------------------------------
class _MobileDepositConfirmDialog extends StatefulWidget {
  final CheckTraite doc;
  final bool isDeposit;
  final Future<void> Function(BuildContext dialogCtx) onConfirm;

  const _MobileDepositConfirmDialog({
    required this.doc,
    required this.isDeposit,
    required this.onConfirm,
  });

  @override
  State<_MobileDepositConfirmDialog> createState() =>
      _MobileDepositConfirmDialogState();
}

class _MobileDepositConfirmDialogState
    extends State<_MobileDepositConfirmDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;
    final doc = widget.doc;
    final label = doc.type == 'traite' ? 'traite' : 'chèque';
    final accentColor = isDeposit ? AppColors.primary : AppColors.error;
    final title = isDeposit
        ? 'Déposer ce $label ?'
        : 'Rejeter ce $label ?';
    final actionLabel = isDeposit ? 'Déposer' : 'Rejeter';
    final content = isDeposit
        ? 'Voulez-vous marquer le $label (${doc.reference}) de ${formatCurrencyDT(doc.amount)} comme déposé ?\n\n'
            'Cela mettra à jour le document lié (${doc.documentRef ?? 'N/A'}) et la trésorerie.'
        : 'Le document lié (${doc.documentRef ?? 'N/A'}) passera à "Impayée" et les transactions associées seront annulées.';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title),
      content: Text(content, style: const TextStyle(fontSize: 13.5)),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            minimumSize: const Size(90, 36),
          ),
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  await widget.onConfirm(context);
                },
          child: _loading
              ? const SizedBox(
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
