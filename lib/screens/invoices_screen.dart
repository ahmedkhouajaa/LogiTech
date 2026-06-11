import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../models/invoice.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import 'create_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _search = '';
  InvoiceStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    context.read<InvoicesBloc>().add(LoadInvoices());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              const SizedBox(width: 12),
              _buildStatusFilter(),
              const Spacer(),
              AppButton(
                label: 'Nouvelle facture',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: context.read<InvoicesBloc>(), child: const CreateInvoiceScreen()))),
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<InvoicesBloc, InvoicesState>(
            builder: (context, state) {
              if (state is InvoicesLoading) return const Center(child: CircularProgressIndicator());
              if (state is InvoicesError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is InvoicesLoaded) {
                var filtered = state.filteredInvoices;
                if (_search.isNotEmpty) {
                  filtered = filtered.where((i) =>
                    i.number.toLowerCase().contains(_search) ||
                    (i.customerName ?? '').toLowerCase().contains(_search)
                  ).toList();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Invoice>(
                      columns: const ['N°', 'Client', 'Date', 'Échéance', 'Total TTC', 'Payé', 'Reste', 'Statut'],
                      rows: filtered,
                      emptyMessage: 'Aucune facture trouvée',
                      cellBuilder: (inv) => [
                        DataCell(Text(inv.number, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(inv.customerName ?? '—', overflow: TextOverflow.ellipsis)),
                        DataCell(Text(formatDate(inv.date))),
                        DataCell(Text(formatDate(inv.dueDate), style: TextStyle(color: inv.isOverdue ? AppColors.error : AppColors.textPrimary))),
                        DataCell(Text(formatCurrency(inv.totalTTC + inv.stampTax), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatCurrency(inv.amountPaid), style: const TextStyle(color: AppColors.success))),
                        DataCell(Text(formatCurrency(inv.amountRemaining), style: TextStyle(color: inv.amountRemaining > 0 ? AppColors.error : AppColors.success))),
                        DataCell(StatusBadge(label: inv.status.label, color: inv.status.color)),
                      ],
                      onView: (inv) => _showPaymentDialog(context, inv),
                      onPrint: (inv) {},
                      onDelete: (inv) => context.read<InvoicesBloc>().add(DeleteInvoice(inv.id)),
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

  Widget _buildStatusFilter() {
    return Row(
      children: [null, ...InvoiceStatus.values].map((status) {
        final isSelected = _statusFilter == status;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(status == null ? 'Tous' : status.label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textSecondary)),
            selected: isSelected,
            selectedColor: status == null ? AppColors.primary : status.color,
            backgroundColor: AppColors.surfaceAlt,
            checkmarkColor: Colors.white,
            side: BorderSide(color: isSelected ? (status?.color ?? AppColors.primary) : AppColors.border),
            onSelected: (_) {
              setState(() => _statusFilter = status);
              context.read<InvoicesBloc>().add(FilterInvoicesByStatus(status));
            },
          ),
        );
      }).toList(),
    );
  }

  void _showPaymentDialog(BuildContext context, Invoice invoice) {
    final ctrl = TextEditingController(text: invoice.amountRemaining.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Enregistrer paiement — ${invoice.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reste à payer: ${formatCurrency(invoice.amountRemaining)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            AppTextField(label: 'Montant payé (DA)', controller: ctrl, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final amount = (double.tryParse(ctrl.text) ?? 0) + invoice.amountPaid;
              context.read<InvoicesBloc>().add(MarkInvoicePaid(invoice.id, amount));
              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
