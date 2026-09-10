import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/payment_model.dart';
import '../models/delivery_note.dart';
import '../models/quote.dart';
import '../models/customer_order.dart';
import '../models/stock_withdrawal.dart';
import '../utils/constants.dart';
import '../services/enterprise_service.dart';
import '../services/offline_document_service.dart';
import '../screens/history_pdf_preview_screen.dart';

class CustomerHistoryDialog extends StatefulWidget {
  final Customer customer;

  const CustomerHistoryDialog({super.key, required this.customer});

  @override
  State<CustomerHistoryDialog> createState() => _CustomerHistoryDialogState();
}

class _CustomerHistoryDialogState extends State<CustomerHistoryDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;
  String? _errorMessage;

  List<Invoice> _allInvoices = [];
  List<Payment> _allPayments = [];
  List<DeliveryNote> _allDeliveryNotes = [];
  List<Quote> _allQuotes = [];
  List<CustomerOrder> _allCustomerOrders = [];
  List<StockWithdrawal> _allExitVouchers = [];

  // Collapsible section states (collapsed by default)
  bool _unpaidExpanded = false;
  bool _invoicesExpanded = false;
  bool _paymentsExpanded = false;
  bool _deliveryNotesExpanded = false;
  bool _quotesExpanded = false;
  bool _customerOrdersExpanded = false;
  bool _exitVouchersExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final entId = EnterpriseService.instance.currentEnterpriseId;
      final custId = widget.customer.id.trim();
      final cName = widget.customer.name.trim().toLowerCase();
      final cComp = widget.customer.companyName?.trim().toLowerCase();
      final cResp = widget.customer.responsibleName?.trim().toLowerCase();
      final cCode = widget.customer.code.trim().toLowerCase();

      bool matchesCustomer(String? docCustId, String? docCustName, String? docCustCompany) {
        final dId = docCustId?.trim() ?? '';
        if (dId.isNotEmpty && dId == custId) return true;

        final docName = docCustName?.trim().toLowerCase() ?? '';
        final docComp = docCustCompany?.trim().toLowerCase() ?? '';

        if (cName.isNotEmpty && (docName == cName || docComp == cName)) return true;
        if (cComp != null && cComp.isNotEmpty && (docName == cComp || docComp == cComp)) return true;
        if (cResp != null && cResp.isNotEmpty && (docName == cResp || docComp == cResp)) return true;
        if (cCode.isNotEmpty && (docName.contains(cCode) || docComp.contains(cCode))) return true;

        final isDefault = widget.customer.isDefault || cName == 'client passager' || custId.isEmpty;
        if (isDefault) {
          if (docName == 'client passager' || docName.contains('passager')) return true;
          if (dId.isEmpty || dId == 'default' || dId == 'passager') return true;
        }
        return false;
      }

      // 1. Fetch Invoices
      Query invoiceQuery = firestore.collection('invoices').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        invoiceQuery = invoiceQuery.where('enterprise_id', isEqualTo: entId);
      }
      final invSnapshot = await invoiceQuery.get();
      final invoices = invSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return Invoice.fromMap(data);
      }).where((inv) => matchesCustomer(inv.customerId, inv.customerName, null)).toList();

      // 2. Fetch Payments
      Query paymentQuery = firestore.collection('paiements');
      if (entId != null && entId.isNotEmpty) {
        paymentQuery = paymentQuery.where('enterprise_id', isEqualTo: entId);
      }
      final paySnapshot = await paymentQuery.get();
      final payments = paySnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        if (data['payment_date'] == null) {
          data['payment_date'] = data['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        return Payment.fromMap(data);
      }).where((p) => !p.isDeleted && matchesCustomer(p.contactId, p.contactName, null)).toList();

      // 3. Fetch Delivery Notes (Bons de livraison)
      // Query Firestore notes with enterprise filter if present, plus offline pending notes
      Query dnQuery = firestore.collection('delivery_notes').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        dnQuery = dnQuery.where('enterprise_id', isEqualTo: entId);
      }
      var dnSnapshot = await dnQuery.get();
      // If enterprise query returned 0 documents, also try without enterprise_id as fallback in case documents lacked enterprise_id
      if (dnSnapshot.docs.isEmpty && entId != null && entId.isNotEmpty) {
        try {
          final fallbackSnap = await firestore.collection('delivery_notes').where('is_deleted', isEqualTo: 0).limit(200).get();
          if (fallbackSnap.docs.isNotEmpty) {
            dnSnapshot = fallbackSnap;
          }
        } catch (_) {}
      }

      final Map<String, DeliveryNote> dnMap = {};
      for (final doc in dnSnapshot.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          final dn = DeliveryNote.fromMap(data);
          if (matchesCustomer(dn.customerId, dn.customerName, dn.customerCompany)) {
            dnMap[dn.id] = dn;
          }
        } catch (_) {}
      }

      // Also load pending offline delivery notes
      try {
        final pendingDns = await OfflineDocumentService.instance.getPendingDocuments('delivery_notes');
        for (final m in pendingDns) {
          try {
            final dn = DeliveryNote.fromMap(m);
            if (!dn.isDeleted && matchesCustomer(dn.customerId, dn.customerName, dn.customerCompany)) {
              dnMap[dn.id] = dn;
            }
          } catch (_) {}
        }
      } catch (_) {}

      final deliveryNotes = dnMap.values.toList();
      deliveryNotes.sort((a, b) => b.date.compareTo(a.date));

      // 4. Fetch Quotes (Devis)
      Query quoteQuery = firestore.collection('quotes').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        quoteQuery = quoteQuery.where('enterprise_id', isEqualTo: entId);
      }
      final quoteSnapshot = await quoteQuery.get();
      final quotes = quoteSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return Quote.fromMap(data);
      }).where((q) => matchesCustomer(q.customerId, q.customerName, null)).toList();

      // 5. Fetch Customer Orders (Commandes client)
      Query coQuery = firestore.collection('customer_orders').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        coQuery = coQuery.where('enterprise_id', isEqualTo: entId);
      }
      final coSnapshot = await coQuery.get();
      final customerOrders = coSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return CustomerOrder.fromMap(data);
      }).where((co) => matchesCustomer(co.customerId, co.customerName, co.customerCompany)).toList();

      // 6. Fetch Exit Vouchers (Bons de sortie)
      Query exitQuery = firestore.collection('bons_sortie').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        exitQuery = exitQuery.where('enterprise_id', isEqualTo: entId);
      }
      final exitSnapshot = await exitQuery.get();
      final exitVouchers = exitSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return StockWithdrawal.fromMap(data);
      }).where((ev) => matchesCustomer(ev.customerId, ev.customerName, ev.customerCompany)).toList();

      if (mounted) {
        setState(() {
          _allInvoices = invoices;
          _allPayments = payments;
          _allDeliveryNotes = deliveryNotes;
          _allQuotes = quotes;
          _allCustomerOrders = customerOrders;
          _allExitVouchers = exitVouchers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // --- Filtering ---
  List<Invoice> get _filteredInvoices {
    return _allInvoices.where((inv) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (inv.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (inv.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Payment> get _filteredPayments {
    return _allPayments.where((pay) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (pay.paymentDate.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (pay.paymentDate.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
  }

  List<DeliveryNote> get _filteredDeliveryNotes {
    return _allDeliveryNotes.where((dn) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (dn.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (dn.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Quote> get _filteredQuotes {
    return _allQuotes.where((q) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (q.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (q.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<CustomerOrder> get _filteredCustomerOrders {
    return _allCustomerOrders.where((co) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (co.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (co.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<StockWithdrawal> get _filteredExitVouchers {
    return _allExitVouchers.where((ev) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (ev.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (ev.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Unpaid invoices
  List<Invoice> get _filteredUnpaidInvoices {
    return _filteredInvoices.where((inv) {
      final remaining = inv.totalTTC - inv.amountPaid;
      return remaining > 0.001 && inv.status != InvoiceStatus.paid && inv.status != InvoiceStatus.cancelled;
    }).toList();
  }

  // KPI Calculations
  double get _totalFacture => _filteredInvoices.fold(0.0, (acc, inv) => acc + inv.totalTTC);
  double get _totalPaye => _filteredPayments.fold(0.0, (acc, pay) => acc + pay.amount);
  double get _totalRestant {
    final diff = _totalFacture - _totalPaye;
    return diff > 0.001 ? diff : 0.0;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // --- Print Document Generator ---
  Future<void> _printHistory() async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontRegular = await PdfGoogleFonts.robotoRegular();

    final dateRangeStr = (_startDate != null || _endDate != null)
        ? 'Du ${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : '---'} au ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : '---'}'
        : 'Toutes les dates';

    final enterprise = EnterpriseService.instance.currentEnterprise;
    final enterpriseName = enterprise?.name.isNotEmpty == true
        ? enterprise!.name
        : 'Nom de votre société';

    final invoices = _filteredInvoices;
    final payments = _filteredPayments;
    final deliveryNotes = _filteredDeliveryNotes;
    final unpaidInvoices = _filteredUnpaidInvoices;
    final quotes = _filteredQuotes;
    final customerOrders = _filteredCustomerOrders;
    final exitVouchers = _filteredExitVouchers;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        build: (context) => [
          // Header: Title on Left, Company Name on Right
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Historique Client: ${widget.customer.name}',
                    style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    dateRangeStr,
                    style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Text(
                enterpriseName,
                style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.black),
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Divider(thickness: 0.8, color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // Summary Section Title
          pw.Text(
            'Un résumé global du compte client :',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
          ),
          pw.SizedBox(height: 12),

          // 3 KPI Cards Row with light colored backgrounds matching UI design
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfKpiCard(
                  title: 'Total facturé',
                  amount: '${_totalFacture.toStringAsFixed(3)} TND',
                  bgColor: const PdfColor.fromInt(0xFFEFF6FF), // Soft blue
                  textColor: PdfColors.black,
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildPdfKpiCard(
                  title: 'Total payé',
                  amount: '${_totalPaye.toStringAsFixed(3)} TND',
                  bgColor: const PdfColor.fromInt(0xFFECFDF5), // Soft green
                  textColor: PdfColors.black,
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildPdfKpiCard(
                  title: 'Total restant à payer',
                  amount: '${_totalRestant.toStringAsFixed(3)} TND',
                  bgColor: const PdfColor.fromInt(0xFFFEF2F2), // Soft red/pink
                  textColor: PdfColors.black,
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // 0. Montants encore impayés
          if (unpaidInvoices.isNotEmpty) ...[
            pw.Text(
              'Montants encore impayés',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° Facture', 'Date', 'Total', 'Payé', 'Reste à payer', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2, 2],
              rows: unpaidInvoices.map((inv) {
                final reste = inv.totalTTC - inv.amountPaid;
                return [
                  inv.number,
                  DateFormat('yyyy-MM-dd').format(inv.date),
                  inv.totalTTC.toStringAsFixed(3),
                  inv.amountPaid.toStringAsFixed(3),
                  (reste > 0 ? reste : 0.0).toStringAsFixed(3),
                  inv.status.label,
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
            pw.SizedBox(height: 20),
          ],

          // 1. Invoices Table
          pw.Text(
            'Les factures du client',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
          ),
          pw.SizedBox(height: 8),
          if (invoices.isEmpty)
            pw.Text('Aucune facture.', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600))
          else
            _buildCustomPdfTable(
              headers: ['N° Facture', 'Date de la facture', 'Total', 'Payé', 'Reste', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2, 2],
              rows: invoices.map((inv) {
                final reste = inv.totalTTC - inv.amountPaid;
                return [
                  inv.number,
                  DateFormat('yyyy-MM-dd').format(inv.date),
                  inv.totalTTC.toStringAsFixed(3),
                  inv.amountPaid.toStringAsFixed(3),
                  (reste > 0 ? reste : 0.0).toStringAsFixed(3),
                  inv.status.label,
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),

          // 2. Payments Table
          if (payments.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les paiements effectués',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['Date Paiement', 'N° Réf / Paiement', 'Montant', 'Méthode'],
              columnFlex: [2, 3, 2, 2],
              rows: payments.map((p) {
                return [
                  DateFormat('yyyy-MM-dd').format(p.paymentDate),
                  p.reference?.isNotEmpty == true ? p.reference! : p.paymentNumber,
                  '${p.amount.toStringAsFixed(3)} TND',
                  p.method.toUpperCase(),
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
          ],

          // 3. Delivery Notes (Bons de livraison)
          if (deliveryNotes.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les bons de livraison',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° BL', 'Date', 'Montant Total', 'Facturation', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2],
              rows: deliveryNotes.map((dn) {
                final isFacture = dn.isConvertedToInvoice || (dn.convertedToInvoiceId != null && dn.convertedToInvoiceId!.isNotEmpty);
                final factStr = isFacture ? 'Facturé' : 'Non facturé';
                return [
                  dn.number,
                  DateFormat('yyyy-MM-dd').format(dn.date),
                  '${dn.totalTTC.toStringAsFixed(3)} TND',
                  factStr,
                  dn.status.toUpperCase(),
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
          ],

          // 4. Quotes (Devis)
          if (quotes.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les devis du client',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° Devis', 'Date', 'Date Validité', 'Montant Total', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2],
              rows: quotes.map((q) {
                return [
                  q.number,
                  DateFormat('yyyy-MM-dd').format(q.date),
                  DateFormat('yyyy-MM-dd').format(q.validityDate),
                  '${q.totalTTC.toStringAsFixed(3)} TND',
                  q.status.label,
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
          ],

          // 5. Customer Orders (Commandes client)
          if (customerOrders.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les commandes du client',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° Commande', 'Date', 'Date Livraison', 'Montant Total', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2],
              rows: customerOrders.map((co) {
                final deliv = co.deliveryDate != null ? DateFormat('yyyy-MM-dd').format(co.deliveryDate!) : '-';
                return [
                  co.number,
                  DateFormat('yyyy-MM-dd').format(co.date),
                  deliv,
                  '${co.totalTTC.toStringAsFixed(3)} TND',
                  co.status.toUpperCase(),
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
          ],

          // 6. Exit Vouchers (Bons de sortie)
          if (exitVouchers.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les bons de sortie',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° Bon de Sortie', 'Date', 'Montant Total', 'Statut'],
              columnFlex: [3, 2, 2, 2],
              rows: exitVouchers.map((ev) {
                return [
                  ev.number,
                  DateFormat('yyyy-MM-dd').format(ev.date),
                  '${ev.totalTTC.toStringAsFixed(3)} TND',
                  ev.status.toUpperCase(),
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
          ],
        ],
      ),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPdfPreviewScreen(
          title: 'Historique Client: ${widget.customer.name}',
          pdfFileName: 'Historique_${widget.customer.name.replaceAll(' ', '_')}.pdf',
          buildPdf: (PdfPageFormat format) async => pdf.save(),
        ),
      ),
    );
  }

  // --- Helper Widget for Clean Table with soft grey header ---
  pw.Widget _buildCustomPdfTable({
    required List<String> headers,
    required List<int> columnFlex,
    required List<List<String>> rows,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Column(
      children: [
        // Table Header with soft light grey background
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF1F5F9), // Subtle light slate/grey
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            children: List.generate(headers.length, (i) {
              return pw.Expanded(
                flex: columnFlex[i],
                child: pw.Text(
                  headers[i],
                  style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                ),
              );
            }),
          ),
        ),
        // Table Rows
        ...rows.map((row) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF1F5F9), width: 0.8),
              ),
            ),
            child: pw.Row(
              children: List.generate(row.length, (i) {
                return pw.Expanded(
                  flex: columnFlex[i],
                  child: pw.Text(
                    row[i],
                    style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  // --- Clean KPI Card for PDF ---
  pw.Widget _buildPdfKpiCard({
    required String title,
    required String amount,
    required PdfColor bgColor,
    required PdfColor textColor,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      height: 65,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textColor),
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(font: fontBold, fontSize: 14, color: textColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
        child: Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Historique Client : ${widget.customer.name}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _printHistory,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Imprimer l\'historique', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ─── Date Picker Bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Text('Du', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  _buildDateButton(
                    label: _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Date début',
                    isSelected: _startDate != null,
                    onTap: _selectStartDate,
                  ),
                  const SizedBox(width: 16),
                  Text('au', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  _buildDateButton(
                    label: _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Date fin',
                    isSelected: _endDate != null,
                    onTap: _selectEndDate,
                  ),
                  if (_startDate != null || _endDate != null) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _clearDates,
                      icon: Icon(Icons.clear, size: 14, color: AppColors.error),
                      label: Text('Réinitialiser', style: TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                  ],
                ],
              ),
            ),

            // ─── Content Body ───
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text('Chargement de l\'historique...',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 36, color: AppColors.error),
                              const SizedBox(height: 8),
                              Text('Erreur: $_errorMessage', style: TextStyle(color: AppColors.error)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadCustomerData,
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── 3 KPI Cards Row ──
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 700;
                                  final cardWidth = isWide
                                      ? (constraints.maxWidth - (2 * 12)) / 3
                                      : constraints.maxWidth;

                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: cardWidth,
                                        child: _buildKpiCard(
                                          title: 'Total facturé',
                                          amount: '${_totalFacture.toStringAsFixed(3)} TND',
                                          color: AppColors.primary,
                                          bgColor: isDark
                                              ? AppColors.primary.withValues(alpha: 0.12)
                                              : const Color(0xFFEFF6FF),
                                          borderColor: AppColors.primary.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _buildKpiCard(
                                          title: 'Total payé',
                                          amount: '${_totalPaye.toStringAsFixed(3)} TND',
                                          color: AppColors.success,
                                          bgColor: isDark
                                              ? AppColors.success.withValues(alpha: 0.12)
                                              : const Color(0xFFECFDF5),
                                          borderColor: AppColors.success.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _buildKpiCard(
                                          title: 'Total restant à payer',
                                          amount: '${_totalRestant.toStringAsFixed(3)} TND',
                                          color: AppColors.error,
                                          bgColor: isDark
                                              ? AppColors.error.withValues(alpha: 0.12)
                                              : const Color(0xFFFEF2F2),
                                          borderColor: AppColors.error.withValues(alpha: 0.25),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 24),

                              // ── Section 1: Montants encore impayés ──
                              _buildCollapsibleCard(
                                isExpanded: _unpaidExpanded,
                                onToggle: () => setState(() => _unpaidExpanded = !_unpaidExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les montants encore impayés',
                                count: _filteredUnpaidInvoices.length,
                                child: _filteredUnpaidInvoices.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'Aucun montant impayé.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      )
                                    : _buildInvoicesTable(_filteredUnpaidInvoices),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 2: Les factures du client ──
                              _buildCollapsibleCard(
                                isExpanded: _invoicesExpanded,
                                onToggle: () => setState(() => _invoicesExpanded = !_invoicesExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les factures du client',
                                count: _filteredInvoices.length,
                                child: _filteredInvoices.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucune facture trouvée pour ce client.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildInvoicesTable(_filteredInvoices),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 3: Les paiements effectués ──
                              _buildCollapsibleCard(
                                isExpanded: _paymentsExpanded,
                                onToggle: () => setState(() => _paymentsExpanded = !_paymentsExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les paiements effectués',
                                count: _filteredPayments.length,
                                child: _filteredPayments.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucun paiement effectué.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildPaymentsTable(_filteredPayments),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 4: Les bons de livraison ──
                              _buildCollapsibleCard(
                                isExpanded: _deliveryNotesExpanded,
                                onToggle: () => setState(() => _deliveryNotesExpanded = !_deliveryNotesExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les bons de livraison',
                                count: _filteredDeliveryNotes.length,
                                child: _filteredDeliveryNotes.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucun bon de livraison trouvé pour ce client.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildDeliveryNotesTable(_filteredDeliveryNotes),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 5: Les devis du client ──
                              _buildCollapsibleCard(
                                isExpanded: _quotesExpanded,
                                onToggle: () => setState(() => _quotesExpanded = !_quotesExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les devis du client',
                                count: _filteredQuotes.length,
                                child: _filteredQuotes.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucun devis trouvé pour ce client.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildQuotesTable(_filteredQuotes),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 6: Les commandes client ──
                              _buildCollapsibleCard(
                                isExpanded: _customerOrdersExpanded,
                                onToggle: () => setState(() => _customerOrdersExpanded = !_customerOrdersExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les commandes du client',
                                count: _filteredCustomerOrders.length,
                                child: _filteredCustomerOrders.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucune commande trouvée pour ce client.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildCustomerOrdersTable(_filteredCustomerOrders),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 7: Les bons de sortie ──
                              _buildCollapsibleCard(
                                isExpanded: _exitVouchersExpanded,
                                onToggle: () => setState(() => _exitVouchersExpanded = !_exitVouchersExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Les bons de sortie',
                                count: _filteredExitVouchers.length,
                                child: _filteredExitVouchers.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucun bon de sortie trouvé pour ce client.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildExitVouchersTable(_filteredExitVouchers),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Date Picker Button ---
  Widget _buildDateButton({
    required String label,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // --- KPI Card Widget ---
  Widget _buildKpiCard({
    required String title,
    required String amount,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.9),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Collapsible Card Frame ---
  Widget _buildCollapsibleCard({
    required bool isExpanded,
    required VoidCallback onToggle,
    required Color headerColor,
    required String title,
    required int count,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                    color: headerColor,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: headerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            child,
          ],
        ],
      ),
    );
  }

  // --- Invoices Table ---
  Widget _buildInvoicesTable(List<Invoice> invoices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt.withValues(alpha: 0.5)),
              columnSpacing: 24,
              horizontalMargin: 16,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('N° Facture')),
                DataColumn(label: Text('Date de la facture')),
                DataColumn(label: Text('Date d\'échéance')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Payé')),
                DataColumn(label: Text('Reste')),
                DataColumn(label: Text('Statut')),
              ],
              rows: invoices.map((inv) {
                final reste = inv.totalTTC - inv.amountPaid;
                final statusColor = inv.status == InvoiceStatus.paid
                    ? AppColors.success
                    : (inv.status == InvoiceStatus.partial ? AppColors.warning : AppColors.error);

                return DataRow(
                  cells: [
                    DataCell(Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(inv.date))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(inv.dueDate))),
                    DataCell(Text('${inv.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text('${inv.amountPaid.toStringAsFixed(3)} TND', style: TextStyle(color: AppColors.success))),
                    DataCell(Text('${(reste > 0 ? reste : 0.0).toStringAsFixed(3)} TND',
                        style: TextStyle(color: reste > 0.001 ? AppColors.error : AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          inv.status.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- Payments Table ---
  Widget _buildPaymentsTable(List<Payment> payments) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt.withValues(alpha: 0.5)),
              columnSpacing: 28,
              horizontalMargin: 16,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('Date du paiement')),
                DataColumn(label: Text('N° Paiement / Réf')),
                DataColumn(label: Text('Montant du paiement')),
                DataColumn(label: Text('Méthode de Paiement')),
              ],
              rows: payments.map((p) {
                final ref = p.reference?.isNotEmpty == true ? p.reference! : p.paymentNumber;
                return DataRow(
                  cells: [
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(p.paymentDate))),
                    DataCell(Text(ref, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text('${p.amount.toStringAsFixed(3)} TND',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.method.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- Delivery Notes Table ---
  Widget _buildDeliveryNotesTable(List<DeliveryNote> deliveryNotes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt.withValues(alpha: 0.5)),
              columnSpacing: 28,
              horizontalMargin: 16,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('N° Bon de Livraison')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Montant Total')),
                DataColumn(label: Text('Facturation')),
                DataColumn(label: Text('Statut')),
              ],
              rows: deliveryNotes.map((dn) {
                final isFacture = dn.isConvertedToInvoice || (dn.convertedToInvoiceId != null && dn.convertedToInvoiceId!.isNotEmpty);
                final factColor = isFacture ? AppColors.success : const Color(0xFFB45309);
                final factLabel = isFacture ? 'Facturé' : 'Non facturé';

                final isDelivered = dn.status.toLowerCase() == 'delivered';
                final isCancelled = dn.status.toLowerCase() == 'cancelled';
                final statusColor = isDelivered ? AppColors.success : (isCancelled ? AppColors.error : AppColors.primary);

                return DataRow(
                  cells: [
                    DataCell(Text(dn.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(dn.date))),
                    DataCell(Text('${dn.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: factColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: factColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          factLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: factColor),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          dn.status.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- Quotes Table ---
  Widget _buildQuotesTable(List<Quote> quotes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt.withValues(alpha: 0.5)),
              columnSpacing: 28,
              horizontalMargin: 16,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('N° Devis')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Date de validité')),
                DataColumn(label: Text('Montant Total')),
                DataColumn(label: Text('Statut')),
              ],
              rows: quotes.map((q) {
                final statusColor = q.status.color;
                return DataRow(
                  cells: [
                    DataCell(Text(q.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(q.date))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(q.validityDate))),
                    DataCell(Text('${q.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          q.status.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- Customer Orders Table ---
  Widget _buildCustomerOrdersTable(List<CustomerOrder> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt.withValues(alpha: 0.5)),
              columnSpacing: 28,
              horizontalMargin: 16,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('N° Commande')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Date de livraison')),
                DataColumn(label: Text('Montant Total')),
                DataColumn(label: Text('Statut')),
              ],
              rows: orders.map((co) {
                final deliv = co.deliveryDate != null ? DateFormat('dd/MM/yyyy').format(co.deliveryDate!) : '-';
                final isDelivered = co.status.toLowerCase().contains('livr');
                final isCancelled = co.status.toLowerCase().contains('annul');
                final isDraft = co.status.toLowerCase().contains('brouillon') || co.status.toLowerCase() == 'draft';
                final statusColor = isDelivered
                    ? AppColors.success
                    : (isCancelled ? AppColors.error : (isDraft ? AppColors.warning : AppColors.primary));

                return DataRow(
                  cells: [
                    DataCell(Text(co.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(co.date))),
                    DataCell(Text(deliv)),
                    DataCell(Text('${co.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          co.status.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- Exit Vouchers Table ---
  Widget _buildExitVouchersTable(List<StockWithdrawal> exitVouchers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt.withValues(alpha: 0.5)),
              columnSpacing: 28,
              horizontalMargin: 16,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('N° Bon de Sortie')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Montant Total')),
                DataColumn(label: Text('Statut')),
              ],
              rows: exitVouchers.map((ev) {
                final isVal = ev.status.toLowerCase() == 'validated';
                final isCanc = ev.status.toLowerCase() == 'cancelled';
                final statusColor = isVal ? AppColors.success : (isCanc ? AppColors.error : AppColors.warning);

                return DataRow(
                  cells: [
                    DataCell(Text(ev.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(ev.date))),
                    DataCell(Text('${ev.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          ev.status.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
