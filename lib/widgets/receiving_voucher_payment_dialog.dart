import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receiving_voucher.dart';
import '../models/product.dart';
import '../blocs/products/products_bloc.dart';
import '../models/payment_model.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../models/treasury_account.dart';
import '../models/treasury_transaction.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';
import '../services/enterprise_service.dart';
import '../services/firestore_repository.dart';
import '../services/firestore_pagination_service.dart';
import '../widgets/searchable_dropdown_field.dart';

class ReceivingVoucherPaymentDialog extends StatefulWidget {
  final ReceivingVoucher receivingVoucher;

  const ReceivingVoucherPaymentDialog({Key? key, required this.receivingVoucher}) : super(key: key);

  @override
  State<ReceivingVoucherPaymentDialog> createState() => _ReceivingVoucherPaymentDialogState();
}

class _ReceivingVoucherPaymentDialogState extends State<ReceivingVoucherPaymentDialog>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Nouveau, 1: Existant, 2: Avoir
  bool _applyWithholdingTax = false;
  
  // Treasury accounts loaded directly from DB
  List<TreasuryAccount> _treasuryAccounts = [];
  bool _isLoadingAccounts = true;
  
  // Tax state
  double _withholdingTaxRate = 1.0;
  DateTime _withholdingTaxDate = DateTime.now();
  
  // Payment state
  String _paymentMethod = 'especes';
  late TextEditingController _amountCtrl;
  String? _selectedAccountId;
  final _referenceCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  final _notesCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _taxRates = [
    {'rate': 1.0, 'label': 'Achats (supérieurs à 1000DT)', 'category': 'Acquisitions des marchandises, matériel équipements et de services'},
    {'rate': 1.5, 'label': 'Achats (supérieurs à 1000DT)', 'category': 'Acquisitions des marchandises, matériel équipements et de services'},
    {'rate': 0.5, 'label': 'Achats (supérieurs à 1000DT)', 'category': 'Acquisitions des marchandises, matériel équipements et de services'},
    {'rate': 3.0, 'label': 'Honoraires (régime réel)', 'category': 'Rémunération des activités non commerciales'},
    {'rate': 10.0, 'label': 'Honoraires (forfait d\'assiette) et commissions, courtage, autre BNC', 'category': 'Rémunération des activités non commerciales'},
    {'rate': 10.0, 'label': 'Loyers', 'category': 'Loyers'},
  ];

  static const _paymentMethods = [
    {'value': 'especes', 'label': 'Espèces', 'icon': Icons.payments_outlined},
    {'value': 'cheque', 'label': 'Chèque', 'icon': Icons.description_outlined},
    {'value': 'virement', 'label': 'Virement', 'icon': Icons.account_balance_outlined},
    {'value': 'carte', 'label': 'Carte', 'icon': Icons.credit_card_outlined},
  ];

  double get _calculatedTotalTTC => widget.receivingVoucher.computedTotalTTC;

  @override
  void initState() {
    super.initState();
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
    _updateAmountField();
    _loadTreasuryAccounts();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }
  
  Future<void> _loadTreasuryAccounts() async {
    try {
      final accounts = await FirestorePaginationService.instance.getFirstTreasuryAccounts(pageSize: 100);
      if (mounted) {
        setState(() {
          _treasuryAccounts = accounts;
          _isLoadingAccounts = false;
          if (_selectedAccountId == null && _treasuryAccounts.isNotEmpty) {
            final defAcc = _treasuryAccounts.firstWhere((a) => a.isDefault, orElse: () => _treasuryAccounts.first);
            _selectedAccountId = defAcc.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAccounts = false);
      }
    }
  }

  void _updateAmountField() {
    double amount = _calculatedTotalTTC - widget.receivingVoucher.amountPaid;
    if (_applyWithholdingTax) {
      double taxAmount = (_calculatedTotalTTC * _withholdingTaxRate) / 100;
      amount -= taxAmount;
    }
    _amountCtrl = TextEditingController(text: amount.toStringAsFixed(3).replaceAll('.', ','));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }



  void _save() async {
    if (_selectedAccountId == null) {
      if (_treasuryAccounts.isNotEmpty) {
        _selectedAccountId = _treasuryAccounts.firstWhere((a) => a.isDefault, orElse: () => _treasuryAccounts.first).id;
      } else {
        final state = context.read<TreasuryAccountsBloc>().state;
        if (state is TreasuryAccountsLoaded && state.accounts.isNotEmpty) {
          _selectedAccountId = state.accounts.firstWhere((a) => a.isDefault, orElse: () => state.accounts.first).id;
        }
      }
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Veuillez sélectionner un compte de trésorerie', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    double parsedAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Veuillez saisir un montant valide', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final db = context.read<PaymentsBloc>();
    final now = DateTime.now();
    final paymentNumber = 'PAI-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');



    final payment = Payment(
      id: const Uuid().v4(),
      paymentNumber: paymentNumber,
      direction: 'decaissement',
      contactId: widget.receivingVoucher.supplierId,
      contactType: 'supplier',
      contactName: widget.receivingVoucher.supplierName,
      amount: parsedAmount,
      method: _paymentMethod,
      accountId: _selectedAccountId,
      reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : null,
      paymentDate: _paymentDate,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      status: 'paid',
      createdAt: now,
      updatedAt: now,
    );

    await FirestoreRepository.instance.savePayment(payment);
    db.add(AddPayment(payment));

    // Create TreasuryTransaction to decrease caisse (expense)
    final treasuryTx = TreasuryTransaction(
      id: const Uuid().v4(),
      transactionNumber: 'TR-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0'),
      accountId: _selectedAccountId!,
      amount: parsedAmount,
      type: 'expense',
      category: 'Paiement Fournisseur',
      dateTransaction: _paymentDate,
      description: 'Paiement du bon de réception ${widget.receivingVoucher.number}',
      paymentId: payment.id,
      createdAt: now,
      updatedAt: now,
    );
    context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(treasuryTx));
    await FirestoreRepository.instance.saveDocument('treasury_transactions', treasuryTx.id, treasuryTx.toMap());

    // Update ReceivingVoucher status and amount paid
    double taxAmount = _applyWithholdingTax ? (_calculatedTotalTTC * _withholdingTaxRate) / 100 : 0;

    if (_applyWithholdingTax && taxAmount > 0) {
      final rsPaymentNumber = 'RS-${now.year}-${(now.millisecondsSinceEpoch + 1) % 1000000}'.padRight(6, '0');
      
      final rsPayment = Payment(
        id: const Uuid().v4(),
        paymentNumber: rsPaymentNumber,
        direction: 'decaissement',
        contactId: widget.receivingVoucher.supplierId,
        contactType: 'supplier',
        contactName: widget.receivingVoucher.supplierName,
        amount: taxAmount,
        method: 'retenue_source',
        reference: widget.receivingVoucher.number,
        paymentDate: _withholdingTaxDate,
        notes: 'Retenue à la source ($_withholdingTaxRate%)',
        status: 'paid',
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );
      
      await FirestoreRepository.instance.savePayment(rsPayment);
      db.add(AddPayment(rsPayment));
    }

    double newAmountPaid = 0.0 + parsedAmount + taxAmount;
    
    String newStatus = widget.receivingVoucher.status;
    double totalDue = _calculatedTotalTTC;
    
    if (newAmountPaid >= totalDue - 0.01) { // 0.01 tolerance for floating point issues
      newStatus = 'payee';
    }

    final updatedReceivingVoucher = widget.receivingVoucher.copyWith(
      status: newStatus,
    );
    context.read<ReceivingVouchersBloc>().add(UpdateReceivingVoucher(updatedReceivingVoucher));
    await FirestoreRepository.instance.saveDocument('receiving_vouchers', updatedReceivingVoucher.id, updatedReceivingVoucher.toMap());

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    double remainingAmount = _calculatedTotalTTC - 0.0;
    double taxAmount = _applyWithholdingTax ? (_calculatedTotalTTC * _withholdingTaxRate) / 100 : 0;
    double netAmount = remainingAmount - taxAmount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: isMobile ? double.infinity : 800,
        height: isMobile ? double.infinity : null,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Row(
                children: [
                  Text('Paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.play_circle_filled, color: Colors.red, size: 24),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      padding: isMobile ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: Icon(Icons.save, size: 16, color: Colors.white),
                    label: Text('Créer', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: isMobile ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ReceivingVoucher Info Box
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Réf: ${widget.receivingVoucher.number}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    Text('Date: ${formatDateTime(widget.receivingVoucher.date)}'),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: Text('Réf: ${widget.receivingVoucher.number}', style: const TextStyle(fontWeight: FontWeight.w500))),
                                    Expanded(child: Text('Date: ${formatDateTime(widget.receivingVoucher.date)}')),
                                  ],
                                ),
                          const SizedBox(height: 12),
                          isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Contact: ${widget.receivingVoucher.supplierName ?? '—'}'),
                                    const SizedBox(height: 8),
                                    Text('Statut: ${widget.receivingVoucher.status}'),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: Text('Contact: ${widget.receivingVoucher.supplierName ?? '—'}')),
                                    Expanded(child: Text('Statut: ${widget.receivingVoucher.status}')),
                                  ],
                                ),
                          const SizedBox(height: 12),
                          isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Montant total: ${formatCurrencyDT(_calculatedTotalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('Montant restant: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                        Text(formatCurrencyDT(remainingAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: Text('Montant total: ${formatCurrencyDT(_calculatedTotalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Text('Montant restant: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                          Text(formatCurrencyDT(remainingAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildTab(0, 'Nouveau paiement'),
                          _buildTab(1, isMobile ? 'Existant' : 'Paiement existant 1'),
                          _buildTab(2, isMobile ? 'Avoir' : 'Avoir 1'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nouveau paiement content
                    if (_selectedTab == 0) ...[
                      // Withholding tax toggle
                      Row(
                        children: [
                          Text('Retenue à la source', style: TextStyle(fontWeight: FontWeight.w500)),
                          SizedBox(width: isMobile ? 12 : 24),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                _buildToggleBtn(false, 'Non'),
                                _buildToggleBtn(true, 'Oui'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_applyWithholdingTax) ...[
                        const SizedBox(height: 16),
                        isMobile
                            ? Column(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Statut: ${widget.receivingVoucher.status}', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField(
                                        dropdownColor: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                        value: _withholdingTaxRate,
                                        isExpanded: true,
                                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                        items: _taxRates.map((t) {
                                          return DropdownMenuItem<double>(
                                            value: t['rate'],
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                  child: Text('${t['rate']}%', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(t['label'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _withholdingTaxRate = v;
                                              _updateAmountField();
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Date de la création de la retenue', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final d = await showDatePicker(context: context, initialDate: _withholdingTaxDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                          if (d != null) setState(() => _withholdingTaxDate = d);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(DateFormat('dd MMM yyyy', 'fr_FR').format(_withholdingTaxDate)),
                                              Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Statut: ${widget.receivingVoucher.status}', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField(
                                          dropdownColor: AppColors.surfaceAlt,
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                          value: _withholdingTaxRate,
                                          isExpanded: true,
                                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                          items: _taxRates.map((t) {
                                            return DropdownMenuItem<double>(
                                              value: t['rate'],
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                    child: Text('${t['rate']}%', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(t['label'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() {
                                                _withholdingTaxRate = v;
                                                _updateAmountField();
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date de la création de la retenue', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () async {
                                            final d = await showDatePicker(context: context, initialDate: _withholdingTaxDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                            if (d != null) setState(() => _withholdingTaxDate = d);
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(DateFormat('dd MMM yyyy', 'fr_FR').format(_withholdingTaxDate)),
                                                Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                          child: isMobile
                              ? Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Retenue à la source: ', style: TextStyle(color: AppColors.textSecondary)),
                                        Text('-${formatCurrencyDT(taxAmount)}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Montant: ', style: TextStyle(color: AppColors.textSecondary)),
                                        Text(formatCurrencyDT(netAmount), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Text('Retenue à la source: ', style: TextStyle(color: AppColors.textSecondary)),
                                    Text('-${formatCurrencyDT(taxAmount)}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                    Spacer(),
                                    Text('Montant: ', style: TextStyle(color: AppColors.textSecondary)),
                                    Text(formatCurrencyDT(netAmount), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ],
                      SizedBox(height: 24),

                      // Payment block
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
                                    child: Text('Paiement 1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18), onPressed: () {}, constraints: BoxConstraints(), padding: EdgeInsets.zero),
                                      SizedBox(width: 12),
                                      Icon(Icons.keyboard_arrow_up, color: AppColors.textSecondary, size: 20),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              child: Column(
                                children: [
                                  isMobile
                                      ? Column(
                                          children: [
                                            _buildFormField('Méthode de paiement', DropdownButtonFormField(
                                              dropdownColor: AppColors.surfaceAlt,
                                              borderRadius: BorderRadius.circular(AppRadius.md),
                                              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                              value: _paymentMethod,
                                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                              items: const [
                                                DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                                                DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                                                DropdownMenuItem(value: 'virement', child: Text('Virement')),
                                                DropdownMenuItem(value: 'carte', child: Text('Carte')),
                                              ],
                                              onChanged: (v) => setState(() => _paymentMethod = v!),
                                            )),
                                            const SizedBox(height: 16),
                                            _buildFormField('Montant', TextField(
                                              controller: _amountCtrl,
                                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), suffixText: 'DT'),
                                            )),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: _buildFormField('Méthode de paiement', DropdownButtonFormField(
                                                dropdownColor: AppColors.surfaceAlt,
                                                borderRadius: BorderRadius.circular(AppRadius.md),
                                                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                                value: _paymentMethod,
                                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                                items: const [
                                                  DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                                                  DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                                                  DropdownMenuItem(value: 'virement', child: Text('Virement')),
                                                  DropdownMenuItem(value: 'carte', child: Text('Carte')),
                                                ],
                                                onChanged: (v) => setState(() => _paymentMethod = v!),
                                              )),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildFormField('Montant', TextField(
                                                controller: _amountCtrl,
                                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), suffixText: 'DT'),
                                              )),
                                            ),
                                          ],
                                        ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormField('Compte de trésorerie *', BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                                          builder: (context, state) {
                                            final accounts = state is TreasuryAccountsLoaded ? state.accounts : <TreasuryAccount>[];
                                            String? displayName;
                                            if (_selectedAccountId != null) {
                                              final acc = accounts.cast<TreasuryAccount?>().firstWhere((a) => a?.id == _selectedAccountId, orElse: () => null);
                                              if (acc != null) displayName = '${acc.name} (${formatCurrencyDT(acc.balance)})';
                                            }
                                            return SearchableSelectorField(
                                              hint: 'Sélectionner un compte',
                                              selectedText: displayName,
                                              onTap: () async {
                                                final res = await showTreasuryAccountSelectDialog(context, accounts, selectedAccountId: _selectedAccountId);
                                                if (res != null) setState(() => _selectedAccountId = res);
                                              },
                                            );
                                          },
                                        )),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormField('Référence externe', TextField(
                                    controller: _referenceCtrl,
                                    decoration: const InputDecoration(hintText: 'Saisir la référence', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                  )),
                                  const SizedBox(height: 16),
                                  _buildFormField('Date de paiement', InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(context: context, initialDate: _paymentDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                      if (d != null) setState(() => _paymentDate = d);
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('dd MMM yyyy', 'fr_FR').format(_paymentDate)),
                                          Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  )),
                                  const SizedBox(height: 16),
                                  _buildFormField('Notes', TextField(
                                    controller: _notesCtrl,
                                    maxLines: 3,
                                    decoration: const InputDecoration(hintText: 'Saisir les notes du paiement', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))] : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
              if (index > 0) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(bool value, String label) {
    final isSelected = _applyWithholdingTax == value;
    return GestureDetector(
      onTap: () => setState(() {
        _applyWithholdingTax = value;
        _updateAmountField();
      }),
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          border: isSelected ? Border.all(color: AppColors.primary) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            if (isSelected && value) ...[
              SizedBox(width: 4),
              Icon(Icons.check_circle, size: 14, color: AppColors.primary),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
