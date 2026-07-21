import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/payments/payments_bloc.dart';
import '../models/document_wrapper.dart';
import '../models/payment_model.dart';
import '../services/pdf_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';
import 'document_preview_screen.dart';

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
          children: [            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Export Button
                  ElevatedButton.icon(
                    onPressed: () {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Export TEJ bientôt disponible')),
                       );
                    },
                    icon: const Icon(Icons.file_download_outlined, size: 16, color: AppColors.textSecondary),
                    label: const Text('Export TEJ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceAlt,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Recherche',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: _SearchField(
                                  hint: 'Rechercher par ref. facture ou certificat..',
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
                        const SizedBox(width: AppSpacing.md),
                        // Dummy dropdowns and date pickers to match screenshot
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.isSales ? 'Client' : 'Fournisseur',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.isSales ? 'Rechercher un client...' : 'Rechercher un fournisseur...',
                                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                        ),
                                      ),
                                      const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Date Du
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Date de début',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: _buildDateDummy('Choisir une date', Icons.calendar_today_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Date Au
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Date de fin',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: _buildDateDummy('Choisir une date', Icons.calendar_today_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_searchQuery.isNotEmpty) // Placeholder logic for active filter
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _page = 0;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Réinitialiser les filtres'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: state is PaymentsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : Column(
                              children: [
                                _buildTableHeader(),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: pageRows.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                                    itemBuilder: (context, index) => _buildRow(pageRows[index]),
                                  ),
                                ),
                                _buildPagination(filtered.length, totalPages),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildDateDummy(String hint, IconData icon) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(hint, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Aucun certificat trouvé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Les retenues à la source s\'afficheront ici', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('Facture / Réf', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          Expanded(flex: 3, child: Text(widget.isSales ? 'Client' : 'Fournisseur', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          const Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          const Expanded(flex: 2, child: Text('Montant RS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          const SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildRow(Payment p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(p.reference ?? p.paymentNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(widget.isSales ? Icons.person_outline : Icons.business_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.contactName ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      Text(widget.isSales ? 'Client' : 'Fournisseur', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDate(p.paymentDate), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text('${formatCurrency(p.amount, symbol: '')} DT', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'print') {
                    final doc = DocumentWrapper.fromWithholdingTax(p, widget.isSales);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
                  } else if (val == 'pdf') {
                    final doc = DocumentWrapper.fromWithholdingTax(p, widget.isSales);
                    PdfService.instance.downloadDocument(context, doc);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'print',
                    height: 40,
                    child: Row(
                      children: const [
                        Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text('Imprimer', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'pdf',
                    height: 40,
                    child: Row(
                      children: const [
                        Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.error),
                        SizedBox(width: 12),
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
    final start = _page * _rowsPerPage + 1;
    final end = ((_page + 1) * _rowsPerPage).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          const Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 30,
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.sm)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                items: [10, 20, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: (v) => setState(() {
                  _rowsPerPage = v!;
                  _page = 0;
                }),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Text('Page ${_page + 1} sur $totalPages', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('Affichage de $start à $end sur $total résultats', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
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
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          prefixIcon: Icon(icon, size: 16, color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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