import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/supplier.dart';
import '../models/purchase_invoice.dart';
import '../models/payment_model.dart';
import '../models/receiving_voucher.dart';
import '../models/supplier_order.dart';
import '../utils/constants.dart';
import '../services/enterprise_service.dart';
import '../services/offline_document_service.dart';
import '../screens/history_pdf_preview_screen.dart';

class SupplierHistoryDialog extends StatefulWidget {
  final Supplier supplier;

  const SupplierHistoryDialog({super.key, required this.supplier});

  @override
  State<SupplierHistoryDialog> createState() => _SupplierHistoryDialogState();
}

class _SupplierHistoryDialogState extends State<SupplierHistoryDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;
  String? _errorMessage;

  List<PurchaseInvoice> _allPurchaseInvoices = [];
  List<Payment> _allPayments = [];
  List<ReceivingVoucher> _allReceivingVouchers = [];
  List<SupplierOrder> _allSupplierOrders = [];

  // Collapsible section states (collapsed by default)
  bool _unpaidExpanded = false;
  bool _invoicesExpanded = false;
  bool _paymentsExpanded = false;
  bool _receivingVouchersExpanded = false;
  bool _supplierOrdersExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSupplierData();
  }

  Future<void> _loadSupplierData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final entId = EnterpriseService.instance.currentEnterpriseId;
      final suppId = widget.supplier.id.trim();
      final sName = widget.supplier.name.trim().toLowerCase();
      final sComp = widget.supplier.companyName?.trim().toLowerCase();
      final sResp = widget.supplier.responsibleName?.trim().toLowerCase();
      final sCode = widget.supplier.code.trim().toLowerCase();

      bool matchesSupplier(String? docSuppId, String? docSuppName, String? docSuppCompany) {
        final dId = docSuppId?.trim() ?? '';
        if (dId.isNotEmpty && dId == suppId) return true;

        final docName = docSuppName?.trim().toLowerCase() ?? '';
        final docComp = docSuppCompany?.trim().toLowerCase() ?? '';

        if (sName.isNotEmpty && (docName == sName || docComp == sName)) return true;
        if (sComp != null && sComp.isNotEmpty && (docName == sComp || docComp == sComp)) return true;
        if (sResp != null && sResp.isNotEmpty && (docName == sResp || docComp == sResp)) return true;
        if (sCode.isNotEmpty && (docName.contains(sCode) || docComp.contains(sCode))) return true;

        final isDefault = widget.supplier.isDefault || suppId.isEmpty;
        if (isDefault) {
          if (docName == 'fournisseur par defaut' || docName.contains('defaut')) return true;
          if (dId.isEmpty || dId == 'default') return true;
        }
        return false;
      }

      // 1. Fetch Purchase Invoices (Factures d'achat)
      Query invoiceQuery = firestore.collection('purchase_invoices').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        invoiceQuery = invoiceQuery.where('enterprise_id', isEqualTo: entId);
      }
      var invSnapshot = await invoiceQuery.get();
      if (invSnapshot.docs.isEmpty && entId != null && entId.isNotEmpty) {
        try {
          final fallbackSnap = await firestore.collection('purchase_invoices').where('is_deleted', isEqualTo: 0).limit(200).get();
          if (fallbackSnap.docs.isNotEmpty) {
            invSnapshot = fallbackSnap;
          }
        } catch (_) {}
      }

      final Map<String, PurchaseInvoice> invMap = {};
      for (final doc in invSnapshot.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          final inv = PurchaseInvoice.fromMap(data);
          if (matchesSupplier(inv.supplierId, inv.supplierName, null)) {
            invMap[inv.id] = inv;
          }
        } catch (_) {}
      }

      try {
        final pendingInvs = await OfflineDocumentService.instance.getPendingDocuments('purchase_invoices');
        for (final m in pendingInvs) {
          try {
            final inv = PurchaseInvoice.fromMap(m);
            if (!inv.isDeleted && matchesSupplier(inv.supplierId, inv.supplierName, null)) {
              invMap[inv.id] = inv;
            }
          } catch (_) {}
        }
      } catch (_) {}

      final purchaseInvoices = invMap.values.toList();
      purchaseInvoices.sort((a, b) => b.date.compareTo(a.date));

      // 2. Fetch Payments (Paiements / Décaissements)
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
      }).where((p) => !p.isDeleted && matchesSupplier(p.contactId, p.contactName, null)).toList();

      // 3. Fetch Receiving Vouchers (Bons de réception)
      Query rvQuery = firestore.collection('receiving_vouchers').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        rvQuery = rvQuery.where('enterprise_id', isEqualTo: entId);
      }
      var rvSnapshot = await rvQuery.get();
      if (rvSnapshot.docs.isEmpty && entId != null && entId.isNotEmpty) {
        try {
          final fallbackSnap = await firestore.collection('receiving_vouchers').where('is_deleted', isEqualTo: 0).limit(200).get();
          if (fallbackSnap.docs.isNotEmpty) {
            rvSnapshot = fallbackSnap;
          }
        } catch (_) {}
      }

      final Map<String, ReceivingVoucher> rvMap = {};
      for (final doc in rvSnapshot.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          final rv = ReceivingVoucher.fromMap(data);
          if (matchesSupplier(rv.supplierId, rv.supplierName, null)) {
            rvMap[rv.id] = rv;
          }
        } catch (_) {}
      }

      try {
        final pendingRvs = await OfflineDocumentService.instance.getPendingDocuments('receiving_vouchers');
        for (final m in pendingRvs) {
          try {
            final rv = ReceivingVoucher.fromMap(m);
            if (!rv.isDeleted && matchesSupplier(rv.supplierId, rv.supplierName, null)) {
              rvMap[rv.id] = rv;
            }
          } catch (_) {}
        }
      } catch (_) {}

      final receivingVouchers = rvMap.values.toList();
      receivingVouchers.sort((a, b) => b.date.compareTo(a.date));

      // 4. Fetch Supplier Orders (Commandes fournisseur)
      Query soQuery = firestore.collection('supplier_orders').where('is_deleted', isEqualTo: 0);
      if (entId != null && entId.isNotEmpty) {
        soQuery = soQuery.where('enterprise_id', isEqualTo: entId);
      }
      var soSnapshot = await soQuery.get();
      if (soSnapshot.docs.isEmpty && entId != null && entId.isNotEmpty) {
        try {
          final fallbackSnap = await firestore.collection('supplier_orders').where('is_deleted', isEqualTo: 0).limit(200).get();
          if (fallbackSnap.docs.isNotEmpty) {
            soSnapshot = fallbackSnap;
          }
        } catch (_) {}
      }

      final Map<String, SupplierOrder> soMap = {};
      for (final doc in soSnapshot.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          final so = SupplierOrder.fromMap(data);
          if (matchesSupplier(so.supplierId, so.supplierName, so.supplierCompany)) {
            soMap[so.id] = so;
          }
        } catch (_) {}
      }

      try {
        final pendingSos = await OfflineDocumentService.instance.getPendingDocuments('supplier_orders');
        for (final m in pendingSos) {
          try {
            final so = SupplierOrder.fromMap(m);
            if (!so.isDeleted && matchesSupplier(so.supplierId, so.supplierName, so.supplierCompany)) {
              soMap[so.id] = so;
            }
          } catch (_) {}
        }
      } catch (_) {}

      final supplierOrders = soMap.values.toList();
      supplierOrders.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _allPurchaseInvoices = purchaseInvoices;
          _allPayments = payments;
          _allReceivingVouchers = receivingVouchers;
          _allSupplierOrders = supplierOrders;
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
  List<PurchaseInvoice> get _filteredPurchaseInvoices {
    return _allPurchaseInvoices.where((inv) {
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

  List<ReceivingVoucher> get _filteredReceivingVouchers {
    return _allReceivingVouchers.where((rv) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (rv.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (rv.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<SupplierOrder> get _filteredSupplierOrders {
    return _allSupplierOrders.where((so) {
      if (_startDate != null) {
        final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (so.date.isBefore(s)) return false;
      }
      if (_endDate != null) {
        final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (so.date.isAfter(e)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Unpaid purchase invoices
  List<PurchaseInvoice> get _filteredUnpaidInvoices {
    return _filteredPurchaseInvoices.where((inv) {
      final remaining = inv.totalTTC - inv.amountPaid;
      return remaining > 0.001 && inv.status != InvoiceStatus.paid && inv.status != InvoiceStatus.cancelled;
    }).toList();
  }

  // KPI Calculations
  double get _totalFacture => _filteredPurchaseInvoices.fold(0.0, (acc, inv) => acc + inv.totalTTC);
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
  }  // --- Print Document Generator ---
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

    final invoices = _filteredPurchaseInvoices;
    final payments = _filteredPayments;
    final receivingVouchers = _filteredReceivingVouchers;
    final unpaidInvoices = _filteredUnpaidInvoices;
    final supplierOrders = _filteredSupplierOrders;

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
                    'Historique Fournisseur: ${widget.supplier.name}',
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
            'Un résumé global du compte fournisseur :',
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

          // 1. Invoices Table (Factures d'achat)
          pw.Text(
            'Les factures du fournisseur',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
          ),
          pw.SizedBox(height: 8),
          if (invoices.isEmpty)
            pw.Text('Aucune facture d\'achat.', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600))
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

          // 3. Receiving Vouchers (Bons de réception)
          if (receivingVouchers.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les bons de réception',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° BR', 'Date', 'Montant Total', 'Facturation', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2],
              rows: receivingVouchers.map((rv) {
                final isFacture = rv.isConvertedToPurchaseInvoice || (rv.convertedToPurchaseInvoiceId != null && rv.convertedToPurchaseInvoiceId!.isNotEmpty);
                final factStr = isFacture ? 'Facturé' : 'Non facturé';
                return [
                  rv.number,
                  DateFormat('yyyy-MM-dd').format(rv.date),
                  '${rv.computedTotalTTC.toStringAsFixed(3)} TND',
                  factStr,
                  rv.status.toUpperCase(),
                ];
              }).toList(),
              fontBold: fontBold,
              fontRegular: fontRegular,
            ),
          ],

          // 4. Supplier Orders (Commandes fournisseur)
          if (supplierOrders.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Les commandes fournisseur',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),
            _buildCustomPdfTable(
              headers: ['N° Commande', 'Date', 'Date Prévue', 'Montant Total', 'Statut'],
              columnFlex: [2, 2, 2, 2, 2],
              rows: supplierOrders.map((so) {
                final exp = so.expectedDate != null ? DateFormat('yyyy-MM-dd').format(so.expectedDate!) : '-';
                return [
                  so.number,
                  DateFormat('yyyy-MM-dd').format(so.date),
                  exp,
                  '${so.totalTTC.toStringAsFixed(3)} TND',
                  so.status.toUpperCase(),
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
          title: 'Historique Fournisseur: ${widget.supplier.name}',
          pdfFileName: 'Historique_Fournisseur_${widget.supplier.name.replaceAll(' ', '_')}.pdf',
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
                            'Historique Fournisseur : ${widget.supplier.name}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.supplier.code.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.supplier.code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    tooltip: 'Fermer',
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─── Filter Bar ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: isDark ? AppColors.surfaceAlt.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(
                    'Période :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Start Date Button
                  OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    label: Text(
                      _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Date début',
                      style: TextStyle(
                        fontSize: 12,
                        color: _startDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.surface : Colors.white,
                      side: BorderSide(
                        color: _startDate != null ? AppColors.primary : AppColors.border,
                        width: _startDate != null ? 1.5 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('à', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),

                  // End Date Button
                  OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    icon: Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    label: Text(
                      _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Date fin',
                      style: TextStyle(
                        fontSize: 12,
                        color: _endDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: _endDate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.surface : Colors.white,
                      side: BorderSide(
                        color: _endDate != null ? AppColors.primary : AppColors.border,
                        width: _endDate != null ? 1.5 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
                                onPressed: _loadSupplierData,
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

                              // ── Section 2: Les factures d'achat ──
                              _buildCollapsibleCard(
                                isExpanded: _invoicesExpanded,
                                onToggle: () => setState(() => _invoicesExpanded = !_invoicesExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Factures d\'achat',
                                count: _filteredPurchaseInvoices.length,
                                child: _filteredPurchaseInvoices.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucune facture d\'achat trouvée pour ce fournisseur.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildInvoicesTable(_filteredPurchaseInvoices),
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

                              // ── Section 4: Bons de réception ──
                              _buildCollapsibleCard(
                                isExpanded: _receivingVouchersExpanded,
                                onToggle: () => setState(() => _receivingVouchersExpanded = !_receivingVouchersExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Bons de réception',
                                count: _filteredReceivingVouchers.length,
                                child: _filteredReceivingVouchers.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucun bon de réception trouvé pour ce fournisseur.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildReceivingVouchersTable(_filteredReceivingVouchers),
                              ),

                              const SizedBox(height: 16),

                              // ── Section 5: Commandes fournisseur ──
                              _buildCollapsibleCard(
                                isExpanded: _supplierOrdersExpanded,
                                onToggle: () => setState(() => _supplierOrdersExpanded = !_supplierOrdersExpanded),
                                headerColor: AppColors.textPrimary,
                                title: 'Commandes fournisseur',
                                count: _filteredSupplierOrders.length,
                                child: _filteredSupplierOrders.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('Aucune commande fournisseur trouvée pour ce fournisseur.',
                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      )
                                    : _buildSupplierOrdersTable(_filteredSupplierOrders),
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

  // --- KPI Card ---
  Widget _buildKpiCard({
    required String title,
    required String amount,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Collapsible Section Card ---
  Widget _buildCollapsibleCard({
    required bool isExpanded,
    required VoidCallback onToggle,
    required Color headerColor,
    required String title,
    required int count,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? AppColors.surfaceAlt.withValues(alpha: 0.2) : const Color(0xFFFAFAFA),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
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

  // --- Purchase Invoices Table ---
  Widget _buildInvoicesTable(List<PurchaseInvoice> invoices) {
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

  // --- Receiving Vouchers (Bons de réception) Table ---
  Widget _buildReceivingVouchersTable(List<ReceivingVoucher> receivingVouchers) {
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
                DataColumn(label: Text('N° Bon de Réception')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Montant Total')),
                DataColumn(label: Text('Facturation')),
                DataColumn(label: Text('Statut')),
              ],
              rows: receivingVouchers.map((rv) {
                final isFacture = rv.isConvertedToPurchaseInvoice || (rv.convertedToPurchaseInvoiceId != null && rv.convertedToPurchaseInvoiceId!.isNotEmpty);
                final factColor = isFacture ? AppColors.success : const Color(0xFFB45309);
                final factLabel = isFacture ? 'Facturé' : 'Non facturé';

                final isDelivered = rv.status.toLowerCase() == 'delivered' || rv.status.toLowerCase() == 'received';
                final isCancelled = rv.status.toLowerCase() == 'cancelled';
                final statusColor = isDelivered ? AppColors.success : (isCancelled ? AppColors.error : AppColors.primary);

                return DataRow(
                  cells: [
                    DataCell(Text(rv.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(rv.date))),
                    DataCell(Text('${rv.computedTotalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700))),
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
                          rv.status.toUpperCase(),
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

  // --- Supplier Orders (Commandes fournisseur) Table ---
  Widget _buildSupplierOrdersTable(List<SupplierOrder> orders) {
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
                DataColumn(label: Text('Date Prévue')),
                DataColumn(label: Text('Montant Total')),
                DataColumn(label: Text('Statut')),
              ],
              rows: orders.map((so) {
                final isConfirmed = so.status.toLowerCase() == 'confirmed' || so.status.toLowerCase() == 'validated';
                final isCancelled = so.status.toLowerCase() == 'cancelled';
                final statusColor = isConfirmed ? AppColors.success : (isCancelled ? AppColors.error : AppColors.info);

                final expStr = so.expectedDate != null ? DateFormat('dd/MM/yyyy').format(so.expectedDate!) : '-';

                return DataRow(
                  cells: [
                    DataCell(Text(so.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(so.date))),
                    DataCell(Text(expStr)),
                    DataCell(Text('${so.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          so.status.toUpperCase(),
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
