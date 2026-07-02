import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/delivery_note.dart';
import '../models/payment_model.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../models/treasury_account.dart';
import '../models/treasury_transaction.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';

class DeliveryNotePaymentDialog extends StatefulWidget {
  final DeliveryNote deliveryNote;

  const DeliveryNotePaymentDialog({Key? key, required this.deliveryNote}) : super(key: key);

  @override
  State<DeliveryNotePaymentDialog> createState() => _DeliveryNotePaymentDialogState();
}

class _DeliveryNotePaymentDialogState extends State<DeliveryNotePaymentDialog>
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

  @override
  void initState() {
    super.initState();
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
      final maps = await DatabaseHelper.instance.getTreasuryAccounts();
      if (mounted) {
        setState(() {
          _treasuryAccounts = maps.map((e) => TreasuryAccount.fromMap(e)).toList();
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAccounts = false);
      }
    }
  }
  
  void _updateAmountField() {
    double amount = widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal - 0.0;
    if (_applyWithholdingTax) {
      double taxAmount = ((widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal) * _withholdingTaxRate) / 100;
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
      contactId: widget.deliveryNote.customerId,
      contactType: 'customer',
      contactName: widget.deliveryNote.customerName,
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
      description: 'Paiement de la facture ${widget.deliveryNote.number}',
      paymentId: payment.id,
      createdAt: now,
      updatedAt: now,
    );
    context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(treasuryTx));

    // Update DeliveryNote status and amount paid
    double taxAmount = _applyWithholdingTax ? ((widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal) * _withholdingTaxRate) / 100 : 0;

    if (_applyWithholdingTax && taxAmount > 0) {
      final rsPaymentNumber = 'RS-${now.year}-${(now.millisecondsSinceEpoch + 1) % 1000000}'.padRight(6, '0');
      
      final rsPayment = Payment(
        id: const Uuid().v4(),
        paymentNumber: rsPaymentNumber,
        direction: 'encaissement',
        contactId: widget.deliveryNote.customerId,
        contactType: 'customer',
        contactName: widget.deliveryNote.customerName,
        amount: taxAmount,
        method: 'retenue_source',
        accountId: _selectedAccountId,
        reference: widget.deliveryNote.number,
        paymentDate: _withholdingTaxDate,
        notes: 'Retenue à la source ($_withholdingTaxRate%)',
        status: 'paid',
        
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
        description: 'Retenue à la source ($_withholdingTaxRate%) pour la facture ${widget.deliveryNote.number}',
        paymentId: rsPayment.id,
        withholdingTax: taxAmount,
        withholdingTaxRate: _withholdingTaxRate,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );
      context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(rsTreasuryTx));
    }

    double newAmountPaid = 0.0 + parsedAmount + taxAmount;
    
    String newStatus = widget.deliveryNote.status;
    double totalDue = widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal;
    
    if (newAmountPaid >= totalDue - 0.01) { // 0.01 tolerance for floating point issues
      newStatus = 'paid';
    } else if (newAmountPaid > 0) {
      newStatus = 'partial';
    }

    final updatedDeliveryNote = widget.deliveryNote.copyWith(
      status: newStatus,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedDeliveryNote));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    double remainingAmount = widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal - 0.0;
    double taxAmount = _applyWithholdingTax ? ((widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal) * _withholdingTaxRate) / 100 : 0;
    double netAmount = remainingAmount - taxAmount;

    if (!isMobile) {
      return _buildDesktopDialog(remainingAmount, taxAmount, netAmount);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.background,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildMobileAppBar(),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(remainingAmount),
                  const SizedBox(height: 20),
                  _buildMobileTabs(),
                  const SizedBox(height: 20),
                  if (_selectedTab == 0) ...[
                    _buildWithholdingTaxSection(taxAmount, netAmount),
                    const SizedBox(height: 20),
                    _buildPaymentMethodChips(),
                    const SizedBox(height: 20),
                    _buildPaymentFormCard(),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomBar(),
          ),
        ),
      ),
    );
  }

  // ─── MOBILE APP BAR ──────────────────────────────────────────────
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppGradients.primary),
      ),
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveau paiement', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          Text('Bon de livraison', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            label: const Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  // ─── SUMMARY CARD ────────────────────────────────────────────────
  Widget _buildSummaryCard(double remainingAmount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Header with gradient accent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.06), AppColors.primary.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.deliveryNote.number,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDateShort(widget.deliveryNote.date),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(widget.deliveryNote.status),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.person_outline,
                  'Client',
                  widget.deliveryNote.customerName ?? '—',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountBlock(
                        'Montant total',
                        formatCurrencyDT(widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal),
                        AppColors.textPrimary,
                      ),
                    ),
                    Container(width: 1, height: 36, color: AppColors.borderLight),
                    Expanded(
                      child: _buildAmountBlock(
                        'Reste à payer',
                        formatCurrencyDT(remainingAmount),
                        AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String label;
    switch (status) {
      case 'paid':
        chipColor = AppColors.success;
        label = 'Payé';
        break;
      case 'partial':
        chipColor = AppColors.warning;
        label = 'Partiel';
        break;
      case 'delivered':
        chipColor = AppColors.primary;
        label = 'Livré';
        break;
      case 'draft':
        chipColor = AppColors.textTertiary;
        label = 'Brouillon';
        break;
      default:
        chipColor = AppColors.info;
        label = translateStatus(status);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: chipColor),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.end),
        ),
      ],
    );
  }

  Widget _buildAmountBlock(String label, String amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ─── MOBILE TABS ─────────────────────────────────────────────────
  Widget _buildMobileTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildMobileTab(0, 'Nouveau', Icons.add_circle_outline),
          _buildMobileTab(1, 'Existant', Icons.history),
          _buildMobileTab(2, 'Avoir', Icons.receipt_outlined),
        ],
      ),
    );
  }

  Widget _buildMobileTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: isSelected ? AppShadows.sm : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WITHHOLDING TAX SECTION ─────────────────────────────────────
  Widget _buildWithholdingTaxSection(double taxAmount, double netAmount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Toggle
          SwitchListTile(
            value: _applyWithholdingTax,
            onChanged: (v) => setState(() {
              _applyWithholdingTax = v;
              _updateAmountField();
            }),
            title: const Text('Retenue à la source', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: const Text('Appliquer la retenue fiscale', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _applyWithholdingTax ? AppColors.warning.withOpacity(0.1) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: _applyWithholdingTax ? AppColors.warning : AppColors.textTertiary,
              ),
            ),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),

          if (_applyWithholdingTax) ...[
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tax rate dropdown
                  _buildMobileFormField(
                    'Taux de retenue',
                    Icons.percent,
                    DropdownButtonFormField<double>(
                      value: _withholdingTaxRate,
                      isExpanded: true,
                      decoration: _mobileInputDecoration('Sélectionner le taux'),
                      items: _taxRates.map((t) {
                        return DropdownMenuItem<double>(
                          value: t['rate'],
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '${t['rate']}%',
                                  style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t['label'],
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
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
                  ),
                  const SizedBox(height: 16),
                  // Date picker
                  _buildMobileFormField(
                    'Date de la retenue',
                    Icons.calendar_today_outlined,
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _withholdingTaxDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _withholdingTaxDate = d);
                      },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: AppColors.surfaceAlt.withOpacity(0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd MMM yyyy', 'fr_FR').format(_withholdingTaxDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tax summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.warning.withOpacity(0.06), AppColors.warning.withOpacity(0.02)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Retenue à la source', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            Text(
                              '-${formatCurrencyDT(taxAmount)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Montant net', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text(
                              formatCurrencyDT(netAmount),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── PAYMENT METHOD CHIPS ────────────────────────────────────────
  Widget _buildPaymentMethodChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Mode de paiement',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
        Row(
          children: _paymentMethods.map((method) {
            final isSelected = _paymentMethod == method['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentMethod = method['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : AppShadows.sm,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        method['icon'] as IconData,
                        size: 22,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        method['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── PAYMENT FORM CARD ───────────────────────────────────────────
  Widget _buildPaymentFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text('Détails du paiement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),

          // Amount field
          _buildMobileFormField(
            'Montant',
            Icons.attach_money,
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
              decoration: _mobileInputDecoration('0,000').copyWith(
                suffixText: 'TND',
                suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Treasury account
          _buildMobileFormField(
            'Compte de trésorerie *',
            Icons.account_balance_outlined,
            _buildTreasuryAccountDropdown(),
          ),
          const SizedBox(height: 16),

          // Payment date
          _buildMobileFormField(
            'Date de paiement',
            Icons.calendar_today_outlined,
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _paymentDate = d);
              },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppColors.surfaceAlt.withOpacity(0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd MMM yyyy', 'fr_FR').format(_paymentDate),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Reference
          _buildMobileFormField(
            'Référence externe',
            Icons.tag,
            TextField(
              controller: _referenceCtrl,
              decoration: _mobileInputDecoration('Saisir la référence'),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          _buildMobileFormField(
            'Notes',
            Icons.note_alt_outlined,
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _mobileInputDecoration('Ajouter des notes...').copyWith(
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM BAR ──────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                label: const Text('Confirmer le paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPER: MOBILE FORM FIELD ───────────────────────────────────
  Widget _buildTreasuryAccountDropdown() {
    if (_isLoadingAccounts) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: AppColors.surfaceAlt.withOpacity(0.3),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 10),
            Text('Chargement des comptes...', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
          ],
        ),
      );
    }
    if (_treasuryAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: AppColors.surfaceAlt.withOpacity(0.3),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
            SizedBox(width: 8),
            Text('Aucun compte disponible', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedAccountId,
      hint: const Text('Sélectionner un compte', style: TextStyle(fontSize: 14)),
      isExpanded: true,
      decoration: _mobileInputDecoration(''),
      items: _treasuryAccounts.map((a) => DropdownMenuItem<String>(
        value: a.id,
        child: Text(
          a.name,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: (v) => setState(() => _selectedAccountId = v),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      dropdownColor: Colors.white,
      menuMaxHeight: 300,
    );
  }

  Widget _buildMobileFormField(String label, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _mobileInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppColors.surfaceAlt.withOpacity(0.3),
    );
  }

  // ─── DESKTOP DIALOG (ORIGINAL LAYOUT) ────────────────────────────
  Widget _buildDesktopDialog(double remainingAmount, double taxAmount, double netAmount) {
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
                    // DeliveryNote Info Box
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
                              Expanded(child: Text('Réf: ${widget.deliveryNote.number}', style: const TextStyle(fontWeight: FontWeight.w500))),
                              Expanded(child: Text('Date: ${formatDateTime(widget.deliveryNote.date)}')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text('Contact: ${widget.deliveryNote.customerName ?? '—'}')),
                              Expanded(child: Text('Statut: ${widget.deliveryNote.status}')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text('Montant total: ${formatCurrencyDT(widget.deliveryNote.totalTTC + widget.deliveryNote.timbreFiscal)}', style: const TextStyle(fontWeight: FontWeight.w600))),
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
                                  Text('Statut: ${widget.deliveryNote.status}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
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
