import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/payment_model.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../models/treasury_account.dart';
import '../models/treasury_transaction.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class InvoicePaymentDialog extends StatefulWidget {
  final Invoice invoice;

  const InvoicePaymentDialog({Key? key, required this.invoice}) : super(key: key);

  @override
  State<InvoicePaymentDialog> createState() => _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState extends State<InvoicePaymentDialog> {
  int _selectedTab = 0; // 0: Nouveau, 1: Existant, 2: Avoir
  bool _applyWithholdingTax = false;
  
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

  final List<Map<String, dynamic>> _taxRates = [
    {'rate': 1.0, 'label': 'Achats (supérieurs à 1000DT)', 'category': 'Acquisitions des marchandises, matériel équipements et de services'},
    {'rate': 1.5, 'label': 'Achats (supérieurs à 1000DT)', 'category': 'Acquisitions des marchandises, matériel équipements et de services'},
    {'rate': 0.5, 'label': 'Achats (supérieurs à 1000DT)', 'category': 'Acquisitions des marchandises, matériel équipements et de services'},
    {'rate': 3.0, 'label': 'Honoraires (régime réel)', 'category': 'Rémunération des activités non commerciales'},
    {'rate': 10.0, 'label': 'Honoraires (forfait d\'assiette) et commissions, courtage, autre BNC', 'category': 'Rémunération des activités non commerciales'},
    {'rate': 10.0, 'label': 'Loyers', 'category': 'Loyers'},
  ];

  @override
  void initState() {
    super.initState();
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
    _updateAmountField();
  }
  
  void _updateAmountField() {
    double amount = widget.invoice.totalTTC + widget.invoice.timbreFiscal - widget.invoice.amountPaid;
    if (_applyWithholdingTax) {
      double taxAmount = ((widget.invoice.totalTTC + widget.invoice.timbreFiscal) * _withholdingTaxRate) / 100;
      amount -= taxAmount;
    }
    _amountCtrl = TextEditingController(text: amount.toStringAsFixed(3).replaceAll('.', ','));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un compte de trésorerie', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
      return;
    }

    double parsedAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (parsedAmount <= 0) return;

    final db = context.read<PaymentsBloc>();
    final now = DateTime.now();
    final paymentNumber = 'PAI-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');

    final payment = Payment(
      id: const Uuid().v4(),
      paymentNumber: paymentNumber,
      direction: 'encaissement',
      contactId: widget.invoice.customerId,
      contactType: 'customer',
      contactName: widget.invoice.customerName,
      amount: parsedAmount,
      method: _paymentMethod,
      accountId: _selectedAccountId,
      reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : null,
      paymentDate: _paymentDate,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      status: 'paid',
      relatedInvoiceId: widget.invoice.id,
      createdAt: now,
      updatedAt: now,
    );

    db.add(AddPayment(payment));

    // Create TreasuryTransaction to increase caisse
    final treasuryTx = TreasuryTransaction(
      id: const Uuid().v4(),
      transactionNumber: 'TR-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0'),
      accountId: _selectedAccountId!,
      amount: parsedAmount,
      type: 'income',
      category: 'Paiement Client',
      dateTransaction: _paymentDate,
      description: 'Paiement de la facture ${widget.invoice.number}',
      paymentId: payment.id,
      createdAt: now,
      updatedAt: now,
    );
    context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(treasuryTx));

    // Update Invoice status and amount paid
    double taxAmount = _applyWithholdingTax ? ((widget.invoice.totalTTC + widget.invoice.timbreFiscal) * _withholdingTaxRate) / 100 : 0;

    if (_applyWithholdingTax && taxAmount > 0) {
      final rsPaymentNumber = 'RS-${now.year}-${(now.millisecondsSinceEpoch + 1) % 1000000}'.padRight(6, '0');
      
      final rsPayment = Payment(
        id: const Uuid().v4(),
        paymentNumber: rsPaymentNumber,
        direction: 'encaissement',
        contactId: widget.invoice.customerId,
        contactType: 'customer',
        contactName: widget.invoice.customerName,
        amount: taxAmount,
        method: 'retenue_source',
        accountId: _selectedAccountId,
        reference: widget.invoice.number,
        paymentDate: _withholdingTaxDate,
        notes: 'Retenue à la source ($_withholdingTaxRate%)',
        status: 'paid',
        relatedInvoiceId: widget.invoice.id,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );
      
      db.add(AddPayment(rsPayment));

      final rsTreasuryTx = TreasuryTransaction(
        id: const Uuid().v4(),
        transactionNumber: 'TR-RS-${now.year}-${(now.millisecondsSinceEpoch + 1) % 1000000}'.padRight(6, '0'),
        accountId: _selectedAccountId!,
        amount: taxAmount,
        type: 'income',
        category: 'Retenue à la source (Ventes)',
        dateTransaction: _withholdingTaxDate,
        description: 'Retenue à la source ($_withholdingTaxRate%) pour la facture ${widget.invoice.number}',
        paymentId: rsPayment.id,
        withholdingTax: taxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );
      context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(rsTreasuryTx));
    }

    double newAmountPaid = widget.invoice.amountPaid + parsedAmount + taxAmount;
    
    InvoiceStatus newStatus = widget.invoice.status;
    double totalDue = widget.invoice.totalTTC + widget.invoice.timbreFiscal;
    
    if (newAmountPaid >= totalDue - 0.01) { // 0.01 tolerance for floating point issues
      newStatus = InvoiceStatus.paid;
    } else if (newAmountPaid > 0) {
      newStatus = InvoiceStatus.partial;
    }

    final updatedInvoice = widget.invoice.copyWith(
      amountPaid: newAmountPaid,
      status: newStatus,
    );
    context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    double remainingAmount = widget.invoice.totalTTC + widget.invoice.timbreFiscal - widget.invoice.amountPaid;
    double taxAmount = _applyWithholdingTax ? ((widget.invoice.totalTTC + widget.invoice.timbreFiscal) * _withholdingTaxRate) / 100 : 0;
    double netAmount = remainingAmount - taxAmount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 800,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text('Paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.play_circle_filled, color: Colors.red, size: 24),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save, size: 16, color: Colors.white),
                    label: const Text('Créer', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Invoice Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Réf: ${widget.invoice.number}', style: const TextStyle(fontWeight: FontWeight.w500))),
                              Expanded(child: Text('Date: ${formatDateTime(widget.invoice.date)}')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text('Contact: ${widget.invoice.customerName ?? '—'}')),
                              Expanded(child: Text('Statut: ${widget.invoice.status.label}')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text('Montant total: ${formatCurrencyDT(widget.invoice.totalTTC + widget.invoice.timbreFiscal)}', style: const TextStyle(fontWeight: FontWeight.w600))),
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
                          _buildTab(1, 'Paiement existant 1'),
                          _buildTab(2, 'Avoir 1'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nouveau paiement content
                    if (_selectedTab == 0) ...[
                      // Withholding tax toggle
                      Row(
                        children: [
                          const Text('Retenue à la source', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 24),
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
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Taux et type de retenue', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<double>(
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date de la création de la retenue', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(context: context, initialDate: _withholdingTaxDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                      if (d != null) setState(() => _withholdingTaxDate = d);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('dd MMM yyyy', 'fr_FR').format(_withholdingTaxDate)),
                                          const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                          child: Row(
                            children: [
                              const Text('Retenue à la source: ', style: TextStyle(color: AppColors.textSecondary)),
                              Text('-${formatCurrencyDT(taxAmount)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              const Text('Montant: ', style: TextStyle(color: AppColors.textSecondary)),
                              Text(formatCurrencyDT(netAmount), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
                                    child: const Text('Paiement 1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18), onPressed: () {}, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.keyboard_arrow_up, color: AppColors.textSecondary, size: 20),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormField('Méthode de paiement', DropdownButtonFormField<String>(
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
                                            List<TreasuryAccount> accounts = [];
                                            if (state is TreasuryAccountsLoaded) {
                                              accounts = state.accounts;
                                            }
                                            return DropdownButtonFormField<String>(
                                              value: _selectedAccountId,
                                              hint: const Text('Sélectionner un compte'),
                                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                              items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                                              onChanged: (v) => setState(() => _selectedAccountId = v),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('dd MMM yyyy', 'fr_FR').format(_paymentDate)),
                                          const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))] : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
              if (index > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          border: isSelected ? Border.all(color: AppColors.primary) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            if (isSelected && value) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
