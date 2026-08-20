import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';
import '../blocs/payments/payments_bloc.dart';
import '../models/document_wrapper.dart';
import '../models/payment_model.dart';
import '../services/pdf_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/tej_export_dialog.dart';
import 'document_preview_screen.dart';
import 'document_detail_screen.dart';

class WithholdingTaxScreen extends StatefulWidget {
  final bool isSales;
  const WithholdingTaxScreen({super.key, required this.isSales});

  @override
  State<WithholdingTaxScreen> createState() => _WithholdingTaxScreenState();
}

class _WithholdingTaxScreenState extends State<WithholdingTaxScreen> {
  String _searchQuery = '';
  int _rowsPerPage = 20;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    context.read<PaymentsBloc>().add(LoadPayments());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      builder: (context, state) {
        List<Payment> payments = [];

        if (state is PaymentsLoaded) {
          payments = state.payments;
        }

        // Apply filters
        final filtered = payments.where((p) {
          // Only Retenue à la source
          if (p.method != 'retenue_source') return false;
          
          // Direction
          if (widget.isSales && p.direction != 'encaissement') return false;
          if (!widget.isSales && p.direction != 'decaissement') return false;



          final matchesSearch = _searchQuery.isEmpty ||
              (p.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
              p.paymentNumber.toLowerCase().contains(_searchQuery.toLowerCase()) || 
              (p.contactName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

          return matchesSearch;
        }).toList();

        final totalPages = (_rowsPerPage > 0 && filtered.isNotEmpty)
            ? (filtered.length / _rowsPerPage).ceil()
            : 1;
        final start = _page * _rowsPerPage;
        final end = (start + _rowsPerPage).clamp(0, filtered.length);
        final pageRows = start < filtered.length ? filtered.sublist(start, end) : <Payment>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isSales ? 'Retenue à la source (Ventes)' : 'Retenue à la source (Achats)',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text('Gérer vos retenues à la source', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  // Export Button
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => TejExportDialog(
                          payments: payments,
                          isSales: widget.isSales,
                        ),
                      );
                    },
                    icon: Icon(Icons.file_download_outlined, size: 16, color: AppColors.textSecondary),
                    label: Text('Export TEJ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceAlt,
                      elevation: 0,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Recherche',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: _SearchField(
                              hint: 'Rechercher par réf. facture ou certificat..',
                              icon: Icons.search_rounded,
                              value: _searchQuery,
                              onChanged: (v) => setState(() {
                                _searchQuery = v;
                                _page = 0;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Dummy dropdowns and date pickers to match screenshot
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.isSales ? 'Client' : 'Fournisseur',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.isSales ? 'Rechercher un client...' : 'Rechercher un fournisseur...',
                                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                    ),
                                  ),
                                  Icon(Icons.unfold_more_rounded, size: 14, color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Date Du
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Date de début',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: _buildDateDummy('Choisir une date', Icons.calendar_today_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Date Au
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Date de fin',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: _buildDateDummy('Choisir une date', Icons.calendar_today_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _page = 0;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: 'Réinitialiser les filtres',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.error,
                            backgroundColor: AppColors.error.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: state is PaymentsLoading || state is PaymentsInitial
                      ? ShimmerTable(
                          headerColumns: [
                            Expanded(flex: 3, child: Text('Facture / Réf', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 3, child: Text(widget.isSales ? 'Client' : 'Fournisseur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Montant RS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                          ],
                        )
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : Column(
                              children: [
                                _buildTableHeader(),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: pageRows.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                                    itemBuilder: (context, index) => _buildRow(pageRows[index], index),
                                  ),
                                ),
                                _buildPagination(filtered.length, totalPages),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildDateDummy(String hint, IconData icon) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(hint, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.account_balance_rounded, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text('Aucun certificat trouvé', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Les retenues à la source s\'afficheront ici', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Facture / Réf', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          Expanded(flex: 3, child: Text(widget.isSales ? 'Client' : 'Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text('Montant RS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildRow(Payment p, int index) {
    return Container(
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(p.reference ?? p.paymentNumber, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(widget.isSales ? Icons.person_outline : Icons.business_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.contactName ?? '—', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      Text(widget.isSales ? 'Client' : 'Fournisseur', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDate(p.paymentDate), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text('${formatCurrency(p.amount, symbol: '')} DT', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'view') {
                    final doc = DocumentWrapper.fromWithholdingTax(p, widget.isSales);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(
                      document: doc,
                      status: 'Validé',
                      statusColor: AppColors.success,
                    )));
                  } else if (val == 'print') {
                    final doc = DocumentWrapper.fromWithholdingTax(p, widget.isSales);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
                  } else if (val == 'pdf') {
                    final doc = DocumentWrapper.fromWithholdingTax(p, widget.isSales);
                    PdfService.instance.downloadDocument(context, doc);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'view',
                    height: 36,
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        Text('Voir', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'print',
                    height: 36,
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Imprimer', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'pdf',
                    height: 36,
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Télécharger PDF', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int total, int totalPages) {
    final start = total == 0 ? 0 : _page * _rowsPerPage + 1;
    final end = ((_page + 1) * _rowsPerPage).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
              color: AppColors.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                items: [20, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() {
                  _rowsPerPage = v!;
                  _page = 0;
                }),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text('Page ${_page + 1} sur $totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(total == 0 ? 'Affichage de 0 à 0 sur 0 résultats' : 'Affichage de $start à $end sur $total résultats', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          _PaginationButton(icon: Icons.chevron_left_rounded, enabled: _page > 0, onTap: () => setState(() => _page--)),
          const SizedBox(width: 4),
          _PaginationButton(icon: Icons.chevron_right_rounded, enabled: _page < totalPages - 1, onTap: () => setState(() => _page++)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: TextField(
        controller: TextEditingController.fromValue(TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length))),
        onChanged: onChanged,
        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary),
          prefixIcon: Icon(icon, size: 16, color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.textSecondary : AppColors.textTertiary),
      ),
    );
  }
}