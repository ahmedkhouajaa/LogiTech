import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';

import '../../models/stock_withdrawal.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../database/database_helper.dart';

import '../../screens/document_preview_screen.dart';
import 'forms/mobile_exit_voucher_form_screen.dart';

class MobileStockWithdrawalDetailScreen extends StatefulWidget {
  final StockWithdrawal withdrawal;

  const MobileStockWithdrawalDetailScreen({super.key, required this.withdrawal});

  @override
  State<MobileStockWithdrawalDetailScreen> createState() => _MobileStockWithdrawalDetailScreenState();
}

class _MobileStockWithdrawalDetailScreenState extends State<MobileStockWithdrawalDetailScreen> {
  late StockWithdrawal currentWithdrawal;

  @override
  void initState() {
    super.initState();
    currentWithdrawal = widget.withdrawal;
    _loadFullWithdrawal();
  }

  Future<void> _loadFullWithdrawal() async {
    final fullWithdrawal = await DatabaseHelper.instance.getStockWithdrawal(currentWithdrawal.id);
    if (fullWithdrawal != null && mounted) {
      setState(() {
        currentWithdrawal = fullWithdrawal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockWithdrawalsBloc, StockWithdrawalsState>(
      listener: (context, state) {
        if (state is StockWithdrawalsLoaded) {
          try {
            final updatedWithdrawal = state.withdrawals.firstWhere((q) => (q as StockWithdrawal).id == currentWithdrawal.id);
            if ((updatedWithdrawal as StockWithdrawal).id == currentWithdrawal.id && mounted) {
              setState(() {
                currentWithdrawal = updatedWithdrawal.copyWith(items: currentWithdrawal.items);
              });
            }
          } catch (_) {
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('BS ${currentWithdrawal.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentWithdrawal),
              itemBuilder: (_) => [
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Réf: ${currentWithdrawal.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Builder(
                            builder: (context) {
                              final statusEnum = StockWithdrawalStatus.values.firstWhere((s) => s.name == currentWithdrawal.status, orElse: () => StockWithdrawalStatus.draft);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusEnum.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(statusEnum.label, style: TextStyle(color: statusEnum.color, fontWeight: FontWeight.bold, fontSize: 12)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentWithdrawal.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Client', currentWithdrawal.customerName ?? currentWithdrawal.customerCompany ?? 'Non spécifié'),
                      if (currentWithdrawal.projectName != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Projet', currentWithdrawal.projectName!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (currentWithdrawal.items.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('Aucun article', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                )
              else
                ...currentWithdrawal.items.map((item) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.description ?? 'Article', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${item.quantity} x ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  Text(formatCurrencyDT(item.unitPrice), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  if (item.discountPercent > 0)
                                    Text(' (-${item.discountPercent}%)', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(formatCurrencyDT(item.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                )),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: AppColors.surfaceAlt,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoRow('Total HT', formatCurrencyDT(currentWithdrawal.totalHTAfterDiscount)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Total TVA', formatCurrencyDT(currentWithdrawal.totalTVA)),
                      if ((currentWithdrawal.totalTTC - currentWithdrawal.totalHTAfterDiscount - currentWithdrawal.totalTVA) > 0.01) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Timbre fiscal', formatCurrencyDT(currentWithdrawal.totalTTC - currentWithdrawal.totalHTAfterDiscount - currentWithdrawal.totalTVA)),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total TTC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatCurrencyDT(currentWithdrawal.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (currentWithdrawal.notes != null && currentWithdrawal.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(currentWithdrawal.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, StockWithdrawal withdrawal) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<StockWithdrawalsBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileExitVoucherFormScreen(existing: withdrawal),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce bon de sortie ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<StockWithdrawalsBloc>().add(DeleteStockWithdrawal(withdrawal.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'print':
        final doc = DocumentWrapper.fromStockWithdrawal(withdrawal);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }
}
