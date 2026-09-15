import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/delivery_note.dart';
import '../models/purchase_invoice.dart';
import '../models/receiving_voucher.dart';
import '../models/payment_model.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/stock_withdrawal.dart';
import 'enterprise_service.dart';

/// Represents a single KPI summary metric
class ReportKpi {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const ReportKpi({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color = const Color(0xFF2563EB),
  });
}

/// Represents a chart data point
class ReportChartPoint {
  final String label;
  final double value;
  final double? secondaryValue;

  const ReportChartPoint({
    required this.label,
    required this.value,
    this.secondaryValue,
  });
}

/// Complete detail data computed for a clicked report
class ReportDetailData {
  final String reportKey;
  final String title;
  final String category;
  final IconData icon;
  final List<ReportKpi> kpis;
  final List<ReportChartPoint> chartPoints;
  final List<String> headers;
  final List<List<String>> rows;
  final String? notes;

  const ReportDetailData({
    required this.reportKey,
    required this.title,
    required this.category,
    required this.icon,
    required this.kpis,
    required this.chartPoints,
    required this.headers,
    required this.rows,
    this.notes,
  });

  /// Generates CSV content for export
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln(headers.join(';'));
    for (final row in rows) {
      final escaped = row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(';');
      buffer.writeln(escaped);
    }
    return buffer.toString();
  }
}

/// Aggregated global dashboard data
class ReportsDashboardData {
  final double totalSalesTTC;
  final double totalSalesHT;
  final double totalPurchasesTTC;
  final double totalPurchasesHT;
  final double totalMargin;
  final double marginRate;
  final double totalInflows;
  final double totalOutflows;
  final double stockValue;
  final int outOfStockCount;
  final int surplusStockCount;

  final List<Invoice> invoices;
  final List<DeliveryNote> deliveryNotes;
  final List<PurchaseInvoice> purchaseInvoices;
  final List<ReceivingVoucher> receivingVouchers;
  final List<Payment> payments;
  final List<Product> products;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final List<StockWithdrawal> stockWithdrawals;

  const ReportsDashboardData({
    required this.totalSalesTTC,
    required this.totalSalesHT,
    required this.totalPurchasesTTC,
    required this.totalPurchasesHT,
    required this.totalMargin,
    required this.marginRate,
    required this.totalInflows,
    required this.totalOutflows,
    required this.stockValue,
    required this.outOfStockCount,
    required this.surplusStockCount,
    required this.invoices,
    required this.deliveryNotes,
    required this.purchaseInvoices,
    required this.receivingVouchers,
    required this.payments,
    required this.products,
    required this.customers,
    required this.suppliers,
    required this.stockWithdrawals,
  });

  factory ReportsDashboardData.empty() {
    return const ReportsDashboardData(
      totalSalesTTC: 0,
      totalSalesHT: 0,
      totalPurchasesTTC: 0,
      totalPurchasesHT: 0,
      totalMargin: 0,
      marginRate: 0,
      totalInflows: 0,
      totalOutflows: 0,
      stockValue: 0,
      outOfStockCount: 0,
      surplusStockCount: 0,
      invoices: [],
      deliveryNotes: [],
      purchaseInvoices: [],
      receivingVouchers: [],
      payments: [],
      products: [],
      customers: [],
      suppliers: [],
      stockWithdrawals: [],
    );
  }
}

class ReportsDataService {
  static final ReportsDataService instance = ReportsDataService._();
  ReportsDataService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  /// Loads all enterprise data with optional date filtering
  Future<ReportsDashboardData> loadData({String period = 'Cette Année'}) async {
    final entId = _currentEnterpriseId;
    if (entId == null || entId.isEmpty) {
      return ReportsDashboardData.empty();
    }

    final dateRange = _calculateDateRange(period);
    final startDate = dateRange.$1;
    final endDate = dateRange.$2;

    try {
      final futures = await Future.wait([
        _firestore
            .collection('invoices')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        _firestore
            .collection('delivery_notes')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        _firestore
            .collection('purchase_invoices')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        _firestore
            .collection('receiving_vouchers')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: false)
            .get(),
        _firestore
            .collection('paiements')
            .where('enterprise_id', isEqualTo: entId)
            .get(),
        _firestore
            .collection('articles')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        _firestore
            .collection('customers')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: false)
            .get(),
        _firestore
            .collection('suppliers')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: false)
            .get(),
        _firestore
            .collection('stock_withdrawals')
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: false)
            .get(),
      ]);

      // Parse invoices
      List<Invoice> invoices = [];
      for (final doc in futures[0].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          final inv = Invoice.fromMap(data);
          if (_isWithinPeriod(inv.date, startDate, endDate)) {
            invoices.add(inv);
          }
        } catch (_) {}
      }

      // Parse delivery notes
      List<DeliveryNote> deliveryNotes = [];
      for (final doc in futures[1].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          final dn = DeliveryNote.fromMap(data);
          if (_isWithinPeriod(dn.date, startDate, endDate)) {
            deliveryNotes.add(dn);
          }
        } catch (_) {}
      }

      // Parse purchase invoices
      List<PurchaseInvoice> purchaseInvoices = [];
      for (final doc in futures[2].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          final pi = PurchaseInvoice.fromMap(data);
          if (_isWithinPeriod(pi.date, startDate, endDate)) {
            purchaseInvoices.add(pi);
          }
        } catch (_) {}
      }

      // Parse receiving vouchers
      List<ReceivingVoucher> receivingVouchers = [];
      for (final doc in futures[3].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          final rv = ReceivingVoucher.fromMap(data);
          if (_isWithinPeriod(rv.date, startDate, endDate)) {
            receivingVouchers.add(rv);
          }
        } catch (_) {}
      }

      // Parse payments
      List<Payment> payments = [];
      for (final doc in futures[4].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['is_deleted'] == '1';
        if (!isDeleted) {
          try {
            final p = Payment.fromMap(data);
            if (_isWithinPeriod(p.paymentDate, startDate, endDate)) {
              payments.add(p);
            }
          } catch (_) {}
        }
      }

      // Parse products
      List<Product> products = [];
      for (final doc in futures[5].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          products.add(Product.fromMap(data));
        } catch (_) {}
      }

      // Parse customers
      List<Customer> customers = [];
      for (final doc in futures[6].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          customers.add(Customer.fromMap(data));
        } catch (_) {}
      }

      // Parse suppliers
      List<Supplier> suppliers = [];
      for (final doc in futures[7].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          suppliers.add(Supplier.fromMap(data));
        } catch (_) {}
      }

      // Parse stock withdrawals
      List<StockWithdrawal> stockWithdrawals = [];
      for (final doc in futures[8].docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        try {
          final sw = StockWithdrawal.fromMap(data);
          if (_isWithinPeriod(sw.date, startDate, endDate)) {
            stockWithdrawals.add(sw);
          }
        } catch (_) {}
      }

      // Compute Global KPIs
      double totalSalesTTC = 0;
      double totalSalesHT = 0;
      double totalEstimatedCostOfSales = 0;

      // Product cost lookup
      final productCostMap = <String, double>{};
      for (final p in products) {
        productCostMap[p.id] = p.purchasePrice;
        if (p.reference != null && p.reference!.isNotEmpty) {
          productCostMap[p.reference!] = p.purchasePrice;
        }
      }

      for (final inv in invoices) {
        totalSalesTTC += inv.totalTTC;
        totalSalesHT += inv.totalHT;
        for (final item in inv.items) {
          final unitCost = productCostMap[item.productId] ?? 0.0;
          totalEstimatedCostOfSales += item.quantity * unitCost;
        }
      }

      double totalPurchasesTTC = 0;
      double totalPurchasesHT = 0;
      for (final pi in purchaseInvoices) {
        totalPurchasesTTC += pi.totalTTC;
        totalPurchasesHT += pi.totalHT;
      }

      final totalMargin = totalSalesHT - totalEstimatedCostOfSales;
      final marginRate = totalSalesHT > 0 ? (totalMargin / totalSalesHT) * 100 : 0.0;

      double totalInflows = 0;
      double totalOutflows = 0;
      for (final p in payments) {
        if (p.direction == 'encaissement') {
          totalInflows += p.amount;
        } else if (p.direction == 'decaissement') {
          totalOutflows += p.amount;
        }
      }

      double stockValue = 0;
      int outOfStockCount = 0;
      int surplusStockCount = 0;
      for (final p in products) {
        if (p.productType != 'service') {
          stockValue += p.stockQty * p.purchasePrice;
          if (p.stockQty <= p.lowStockThreshold) {
            outOfStockCount++;
          }
          if (p.highStockThreshold > 0 && p.stockQty >= p.highStockThreshold) {
            surplusStockCount++;
          }
        }
      }

      return ReportsDashboardData(
        totalSalesTTC: totalSalesTTC,
        totalSalesHT: totalSalesHT,
        totalPurchasesTTC: totalPurchasesTTC,
        totalPurchasesHT: totalPurchasesHT,
        totalMargin: totalMargin,
        marginRate: marginRate,
        totalInflows: totalInflows,
        totalOutflows: totalOutflows,
        stockValue: stockValue,
        outOfStockCount: outOfStockCount,
        surplusStockCount: surplusStockCount,
        invoices: invoices,
        deliveryNotes: deliveryNotes,
        purchaseInvoices: purchaseInvoices,
        receivingVouchers: receivingVouchers,
        payments: payments,
        products: products,
        customers: customers,
        suppliers: suppliers,
        stockWithdrawals: stockWithdrawals,
      );
    } catch (e) {
      debugPrint('Error loading reports data: $e');
      return ReportsDashboardData.empty();
    }
  }

  (DateTime?, DateTime?) _calculateDateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Ce Mois':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start, end);
      case 'Mois Dernier':
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final start = DateTime(prevYear, prevMonth, 1);
        final end = DateTime(prevYear, prevMonth + 1, 0, 23, 59, 59);
        return (start, end);
      case 'Ce Trimestre':
        final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        final start = DateTime(now.year, qMonth, 1);
        final end = DateTime(now.year, qMonth + 3, 0, 23, 59, 59);
        return (start, end);
      case 'Cette Année':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start, end);
      case "Tout l'historique":
      default:
        return (null, null);
    }
  }

  bool _isWithinPeriod(DateTime date, DateTime? start, DateTime? end) {
    if (start != null && date.isBefore(start)) return false;
    if (end != null && date.isAfter(end)) return false;
    return true;
  }

  /// Computes detailed report view for any of the 34 sub-reports
  ReportDetailData computeReport(String reportKey, ReportsDashboardData data) {
    switch (reportKey) {
      // ─── 1. Rapports de vente ───────────────────────────────────────
      case 'vente_client':
        return _computeVenteParClient(data);
      case 'vente_article':
        return _computeVenteParArticle(data);
      case 'vente_famille':
        return _computeVenteParFamille(data);
      case 'vente_region':
        return _computeVenteParRegion(data);
      case 'vente_projet':
        return _computeVenteParProjet(data);
      case 'tva_vente':
        return _computeTvaVente(data);
      case 'retenue_client':
        return _computeRetenueClient(data);

      // ─── 2. Rapports d'achat ───────────────────────────────────────
      case 'achat_fournisseur':
        return _computeAchatParFournisseur(data);
      case 'achat_article':
        return _computeAchatParArticle(data);
      case 'achat_famille':
        return _computeAchatParFamille(data);
      case 'achat_region':
        return _computeAchatParRegion(data);
      case 'immo_famille':
        return _computeImmoParFamille(data);
      case 'achat_projet':
        return _computeAchatParProjet(data);
      case 'tva_achat':
        return _computeTvaAchat(data);
      case 'retenue_fournisseur':
        return _computeRetenueFournisseur(data);

      // ─── 3. Rapports de paiement ───────────────────────────────────
      case 'paiement_recu':
        return _computePaiementsRecus(data);
      case 'paiement_emis':
        return _computePaiementsEmis(data);

      // ─── 4. Stock ──────────────────────────────────────────────────
      case 'stock_consommation_dep':
        return _computeStockConsommationDep(data);
      case 'stock_consommation_famille':
        return _computeStockConsommationFamille(data);
      case 'stock_rupture':
        return _computeStockRupture(data);
      case 'stock_surstockage':
        return _computeStockSurstockage(data);

      // ─── 5. Rapports contacts ──────────────────────────────────────
      case 'soldes_clients':
        return _computeSoldesClients(data);
      case 'soldes_fournisseurs':
        return _computeSoldesFournisseurs(data);

      // ─── 6. Marge commerciale [Nouveau] ────────────────────────────
      case 'marge_facture':
        return _computeMargeParFacture(data);
      case 'marge_bl':
        return _computeMargeParBL(data);
      case 'marge_article':
        return _computeMargeParArticle(data);

      // ─── 7. Rapports bons de livraison [Nouveau] ───────────────────
      case 'bl_client':
        return _computeBLParClient(data);
      case 'bl_article':
        return _computeBLParArticle(data);
      case 'bl_famille':
        return _computeBLParFamille(data);
      case 'bl_projet':
        return _computeBLParProjet(data);

      // ─── 8. Rapports bons de réception [Nouveau] ───────────────────
      case 'br_fournisseur':
        return _computeBRParFournisseur(data);
      case 'br_article':
        return _computeBRParArticle(data);
      case 'br_famille':
        return _computeBRParFamille(data);
      case 'br_projet':
        return _computeBRParProjet(data);

      default:
        return _computeDefaultReport(reportKey, data);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // COMPUTE IMPLEMENTATIONS
  // ────────────────────────────────────────────────────────────────────────

  ReportDetailData _computeVenteParClient(ReportsDashboardData data) {
    final clientMap = <String, (int count, double totalHT, double totalTTC, double paid)>{};
    for (final inv in data.invoices) {
      final name = inv.customerName ?? 'Client Inconnu';
      final prev = clientMap[name] ?? (0, 0.0, 0.0, 0.0);
      clientMap[name] = (
        prev.$1 + 1,
        prev.$2 + inv.totalHT,
        prev.$3 + inv.totalTTC,
        prev.$4 + inv.amountPaid,
      );
    }

    final sorted = clientMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final topClient = sorted.isNotEmpty ? sorted.first.key : '-';
    final topRevenue = sorted.isNotEmpty ? sorted.first.value.$3 : 0.0;

    final kpis = [
      ReportKpi(
        title: 'Chiffre d\'Affaires Total',
        value: '${data.totalSalesTTC.toStringAsFixed(2)} TND',
        subtitle: '${sorted.length} clients avec facturation',
        icon: Icons.monetization_on_rounded,
        color: const Color(0xFF2563EB),
      ),
      ReportKpi(
        title: 'Meilleur Client',
        value: topClient,
        subtitle: '${topRevenue.toStringAsFixed(2)} TND générés',
        icon: Icons.star_rounded,
        color: const Color(0xFF10B981),
      ),
      ReportKpi(
        title: 'Panier Moyen Client',
        value: sorted.isNotEmpty ? '${(data.totalSalesTTC / sorted.length).toStringAsFixed(2)} TND' : '0.00 TND',
        subtitle: 'CA moyen par client actif',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFFF59E0B),
      ),
    ];

    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) {
      final balance = e.value.$3 - e.value.$4;
      return [
        e.key,
        e.value.$1.toString(),
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${e.value.$3.toStringAsFixed(2)} TND',
        '${e.value.$4.toStringAsFixed(2)} TND',
        '${balance.toStringAsFixed(2)} TND',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'vente_client',
      title: 'Vente par client',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: kpis,
      chartPoints: chartPoints,
      headers: ['Client', 'Factures', 'Total HT', 'Total TTC', 'Payé', 'Reste Dû'],
      rows: rows,
    );
  }

  ReportDetailData _computeVenteParArticle(ReportsDashboardData data) {
    final articleMap = <String, (double qty, double totalHT, double totalTTC)>{};
    for (final inv in data.invoices) {
      for (final item in inv.items) {
        final name = item.productName ?? 'Article #${item.productId}';
        final prev = articleMap[name] ?? (0.0, 0.0, 0.0);
        articleMap[name] = (
          prev.$1 + item.quantity,
          prev.$2 + item.computedTotalHT,
          prev.$3 + item.totalTTC,
        );
      }
    }

    final sorted = articleMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final topArticle = sorted.isNotEmpty ? sorted.first.key : '-';
    final topQty = sorted.isNotEmpty ? sorted.first.value.$1 : 0.0;

    final kpis = [
      ReportKpi(
        title: 'Total Articles Vendus',
        value: '${sorted.fold<double>(0, (prevVal, e) => prevVal + e.value.$1).toStringAsFixed(0)} unités',
        subtitle: '${sorted.length} références différentes',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF2563EB),
      ),
      ReportKpi(
        title: 'Top Vente Article',
        value: topArticle,
        subtitle: '${topQty.toStringAsFixed(0)} unités écoulées',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFF10B981),
      ),
      ReportKpi(
        title: 'CA Moyen par Article',
        value: sorted.isNotEmpty ? '${(data.totalSalesHT / sorted.length).toStringAsFixed(2)} TND' : '0.00 TND',
        subtitle: 'Moyenne des ventes HT',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) {
      final avgPrice = e.value.$1 > 0 ? e.value.$2 / e.value.$1 : 0.0;
      return [
        e.key,
        e.value.$1.toStringAsFixed(0),
        '${avgPrice.toStringAsFixed(2)} TND',
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${e.value.$3.toStringAsFixed(2)} TND',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'vente_article',
      title: 'Vente par article',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: kpis,
      chartPoints: chartPoints,
      headers: ['Article / Référence', 'Quantité Vendue', 'Prix Moyen HT', 'Total HT', 'Total TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeVenteParFamille(ReportsDashboardData data) {
    final familyProductMap = <String, String>{};
    for (final p in data.products) {
      final fam = p.category ?? 'Sans famille';
      familyProductMap[p.id] = fam;
      if (p.reference != null) familyProductMap[p.reference!] = fam;
      familyProductMap[p.name] = fam;
    }

    final familyMap = <String, (double qty, double totalHT)>{};
    for (final inv in data.invoices) {
      for (final item in inv.items) {
        final fam = familyProductMap[item.productId] ??
            familyProductMap[item.productName ?? ''] ??
            'Général';
        final prev = familyMap[fam] ?? (0.0, 0.0);
        familyMap[fam] = (prev.$1 + item.quantity, prev.$2 + item.computedTotalHT);
      }
    }

    final sorted = familyMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) {
      final share = data.totalSalesHT > 0 ? (e.value.$2 / data.totalSalesHT) * 100 : 0.0;
      return [
        e.key,
        e.value.$1.toStringAsFixed(0),
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${share.toStringAsFixed(1)} %',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'vente_famille',
      title: 'Vente par famille',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: [
        ReportKpi(
          title: 'Familles actives',
          value: '${sorted.length}',
          subtitle: 'Catégories commercialisées',
          icon: Icons.category_rounded,
        ),
        ReportKpi(
          title: 'Top Famille',
          value: sorted.isNotEmpty ? sorted.first.key : '-',
          subtitle: sorted.isNotEmpty ? '${sorted.first.value.$2.toStringAsFixed(2)} TND' : '',
          icon: Icons.star_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Famille / Catégorie', 'Unités Vendues', 'Total Vente HT', 'Part du CA'],
      rows: rows,
    );
  }

  ReportDetailData _computeVenteParRegion(ReportsDashboardData data) {
    final customerRegionMap = <String, String>{};
    for (final c in data.customers) {
      customerRegionMap[c.id] = c.city ?? 'Non spécifiée';
      customerRegionMap[c.name] = c.city ?? 'Non spécifiée';
    }

    final regionMap = <String, (int invCount, double totalHT, double totalTTC)>{};
    for (final inv in data.invoices) {
      final region = customerRegionMap[inv.customerId] ??
          customerRegionMap[inv.customerName ?? ''] ??
          'Grand Tunis';
      final prev = regionMap[region] ?? (0, 0.0, 0.0);
      regionMap[region] = (prev.$1 + 1, prev.$2 + inv.totalHT, prev.$3 + inv.totalTTC);
    }

    final sorted = regionMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) {
      final share = data.totalSalesTTC > 0 ? (e.value.$3 / data.totalSalesTTC) * 100 : 0.0;
      return [
        e.key,
        e.value.$1.toString(),
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${e.value.$3.toStringAsFixed(2)} TND',
        '${share.toStringAsFixed(1)} %',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'vente_region',
      title: 'Vente par région',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: [
        ReportKpi(
          title: 'Régions couvertes',
          value: '${sorted.length}',
          subtitle: 'Zones géographiques',
          icon: Icons.map_rounded,
        ),
        ReportKpi(
          title: 'Région Principale',
          value: sorted.isNotEmpty ? sorted.first.key : '-',
          subtitle: sorted.isNotEmpty ? '${sorted.first.value.$3.toStringAsFixed(2)} TND' : '',
          icon: Icons.location_city_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Région / Gouvernorat', 'Nombre Factures', 'Total HT', 'Total TTC', 'Part de marché'],
      rows: rows,
    );
  }

  ReportDetailData _computeVenteParProjet(ReportsDashboardData data) {
    final projectMap = <String, (int count, double totalHT, double totalTTC)>{};
    for (final inv in data.invoices) {
      final proj = (inv.projectName != null && inv.projectName!.isNotEmpty)
          ? inv.projectName!
          : 'Sans projet spécifique';
      final prev = projectMap[proj] ?? (0, 0.0, 0.0);
      projectMap[proj] = (prev.$1 + 1, prev.$2 + inv.totalHT, prev.$3 + inv.totalTTC);
    }

    final sorted = projectMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
          '${e.value.$3.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'vente_projet',
      title: 'Vente par projet',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: [
        ReportKpi(
          title: 'Projets Facturés',
          value: '${sorted.length}',
          subtitle: 'Projets avec activité',
          icon: Icons.assignment_rounded,
        ),
        ReportKpi(
          title: 'Plus Grand Projet',
          value: sorted.isNotEmpty ? sorted.first.key : '-',
          subtitle: sorted.isNotEmpty ? '${sorted.first.value.$3.toStringAsFixed(2)} TND' : '',
          icon: Icons.military_tech_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Nom du Projet', 'Nombre Factures', 'CA HT', 'CA TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeTvaVente(ReportsDashboardData data) {
    final tvaMap = <double, (double baseHT, double montantTVA)>{};
    for (final inv in data.invoices) {
      for (final item in inv.items) {
        final rate = item.tvaRate;
        final base = item.computedTotalHT;
        final tva = item.tvaAmount;
        final prev = tvaMap[rate] ?? (0.0, 0.0);
        tvaMap[rate] = (prev.$1 + base, prev.$2 + tva);
      }
    }

    final sorted = tvaMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final totalTva = sorted.fold<double>(0, (prevVal, e) => prevVal + e.value.$2);

    final chartPoints = sorted.map((e) => ReportChartPoint(label: '${e.key.toStringAsFixed(0)}%', value: e.value.$2)).toList();

    final rows = sorted.map((e) {
      final totalTTC = e.value.$1 + e.value.$2;
      return [
        '${e.key.toStringAsFixed(0)} %',
        '${e.value.$1.toStringAsFixed(2)} TND',
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${totalTTC.toStringAsFixed(2)} TND',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'tva_vente',
      title: 'TVA vente',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: [
        ReportKpi(
          title: 'TVA Ventes Collectée',
          value: '${totalTva.toStringAsFixed(2)} TND',
          subtitle: 'Montant à déclarer',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
        ),
        ReportKpi(
          title: 'Base Imposable HT',
          value: '${data.totalSalesHT.toStringAsFixed(2)} TND',
          subtitle: 'Total hors taxe soumis à TVA',
          icon: Icons.calculate_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Taux de TVA', 'Base Imposable HT', 'Montant TVA Collectée', 'Total TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeRetenueClient(ReportsDashboardData data) {
    final retenuePayments = data.payments.where((p) => p.direction == 'encaissement' && p.method == 'retenue_source').toList();
    final totalRetenue = retenuePayments.fold<double>(0, (prevVal, p) => prevVal + p.amount);

    final rows = retenuePayments.map((p) => [
          '${p.paymentDate.day.toString().padLeft(2, '0')}/${p.paymentDate.month.toString().padLeft(2, '0')}/${p.paymentDate.year}',
          p.paymentNumber,
          p.contactName ?? 'Client Inconnu',
          p.reference ?? '-',
          '${p.amount.toStringAsFixed(2)} TND',
          p.status == 'paid' ? 'Validé' : 'En attente',
        ]).toList();

    final chartPoints = retenuePayments.take(6).map((p) => ReportChartPoint(label: p.contactName ?? p.paymentNumber, value: p.amount)).toList();

    return ReportDetailData(
      reportKey: 'retenue_client',
      title: 'Retenue clients',
      category: 'Rapports de vente',
      icon: Icons.trending_up,
      kpis: [
        ReportKpi(
          title: 'Total Retenues Clients',
          value: '${totalRetenue.toStringAsFixed(2)} TND',
          subtitle: '${retenuePayments.length} certificats de retenue',
          icon: Icons.request_quote_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Date', 'N° Paiement', 'Client', 'Référence', 'Montant Retenue', 'Statut'],
      rows: rows,
    );
  }

  // ─── 2. Rapports d'achat ───────────────────────────────────────────

  ReportDetailData _computeAchatParFournisseur(ReportsDashboardData data) {
    final suppMap = <String, (int count, double totalHT, double totalTTC)>{};
    for (final pi in data.purchaseInvoices) {
      final name = pi.supplierName ?? 'Fournisseur Inconnu';
      final prev = suppMap[name] ?? (0, 0.0, 0.0);
      suppMap[name] = (prev.$1 + 1, prev.$2 + pi.totalHT, prev.$3 + pi.totalTTC);
    }

    final sorted = suppMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
          '${e.value.$3.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'achat_fournisseur',
      title: 'Achats par fournisseur',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Total Achats TTC',
          value: '${data.totalPurchasesTTC.toStringAsFixed(2)} TND',
          subtitle: '${sorted.length} fournisseurs sollicités',
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFFEF4444),
        ),
        ReportKpi(
          title: 'Fournisseur Principal',
          value: sorted.isNotEmpty ? sorted.first.key : '-',
          subtitle: sorted.isNotEmpty ? '${sorted.first.value.$3.toStringAsFixed(2)} TND' : '',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF2563EB),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Fournisseur', 'Nb Factures', 'Total Achats HT', 'Total Achats TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeAchatParArticle(ReportsDashboardData data) {
    final itemMap = <String, (double qty, double totalHT, double totalTTC)>{};
    for (final pi in data.purchaseInvoices) {
      for (final item in pi.items) {
        final name = item.productName ?? 'Article #${item.productId}';
        final prev = itemMap[name] ?? (0.0, 0.0, 0.0);
        itemMap[name] = (
          prev.$1 + item.quantity,
          prev.$2 + item.computedTotalHT,
          prev.$3 + item.totalTTC,
        );
      }
    }

    final sorted = itemMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) {
      final avg = e.value.$1 > 0 ? e.value.$2 / e.value.$1 : 0.0;
      return [
        e.key,
        e.value.$1.toStringAsFixed(0),
        '${avg.toStringAsFixed(2)} TND',
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${e.value.$3.toStringAsFixed(2)} TND',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'achat_article',
      title: 'Achats par article',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Références Achetées',
          value: '${sorted.length}',
          subtitle: 'Articles approvisionnés',
          icon: Icons.inventory_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Article / Référence', 'Quantité Achetée', 'Prix Moyen HT', 'Total HT', 'Total TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeAchatParFamille(ReportsDashboardData data) {
    final familyMap = <String, double>{};
    for (final pi in data.purchaseInvoices) {
      for (final item in pi.items) {
        final p = data.products.where((prod) => prod.id == item.productId || prod.name == item.productName).firstOrNull;
        final fam = p?.category ?? 'Général';
        familyMap[fam] = (familyMap[fam] ?? 0) + item.computedTotalHT;
      }
    }

    final sorted = familyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value)).toList();

    final rows = sorted.map((e) {
      final share = data.totalPurchasesHT > 0 ? (e.value / data.totalPurchasesHT) * 100 : 0.0;
      return [
        e.key,
        '${e.value.toStringAsFixed(2)} TND',
        '${share.toStringAsFixed(1)} %',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'achat_famille',
      title: 'Achats par famille',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Familles Achetées',
          value: '${sorted.length}',
          subtitle: 'Pôles de dépenses',
          icon: Icons.category_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Famille / Catégorie', 'Total Achats HT', 'Part du Budget'],
      rows: rows,
    );
  }

  ReportDetailData _computeAchatParRegion(ReportsDashboardData data) {
    final suppRegionMap = <String, String>{};
    for (final s in data.suppliers) {
      suppRegionMap[s.id] = s.city ?? 'Non spécifiée';
      suppRegionMap[s.name] = s.city ?? 'Non spécifiée';
    }

    final regionMap = <String, (int count, double totalHT, double totalTTC)>{};
    for (final pi in data.purchaseInvoices) {
      final region = suppRegionMap[pi.supplierId] ??
          suppRegionMap[pi.supplierName ?? ''] ??
          'Grand Tunis';
      final prev = regionMap[region] ?? (0, 0.0, 0.0);
      regionMap[region] = (prev.$1 + 1, prev.$2 + pi.totalHT, prev.$3 + pi.totalTTC);
    }

    final sorted = regionMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
          '${e.value.$3.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'achat_region',
      title: 'Achats par région',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Régions Fournisseurs',
          value: '${sorted.length}',
          subtitle: 'Origine des approvisionnements',
          icon: Icons.location_on_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Région', 'Factures d\'achat', 'Total HT', 'Total TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeImmoParFamille(ReportsDashboardData data) {
    final immoProducts = data.products.where((p) => p.productType.toLowerCase() == 'immobilisation').toList();
    final totalImmoVal = immoProducts.fold<double>(0, (prevVal, p) => prevVal + (p.stockQty * p.purchasePrice));

    final rows = immoProducts.map((p) => [
          p.category ?? 'Matériel',
          p.reference ?? p.code,
          p.name,
          p.stockQty.toStringAsFixed(0),
          '${p.purchasePrice.toStringAsFixed(2)} TND',
          '${(p.stockQty * p.purchasePrice).toStringAsFixed(2)} TND',
        ]).toList();

    final chartPoints = immoProducts.take(6).map((p) => ReportChartPoint(label: p.name, value: p.stockQty * p.purchasePrice)).toList();

    return ReportDetailData(
      reportKey: 'immo_famille',
      title: 'Immobilisation par famille',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Actifs Immobilisés',
          value: '${immoProducts.length}',
          subtitle: 'Biens d\'équipement enregistrés',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF8B5CF6),
        ),
        ReportKpi(
          title: 'Valeur d\'Acquisition',
          value: '${totalImmoVal.toStringAsFixed(2)} TND',
          subtitle: 'Valeur brute au bilan',
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Famille', 'Référence', 'Désignation', 'Quantité', 'Prix d\'Achat', 'Valeur Totale'],
      rows: rows,
    );
  }

  ReportDetailData _computeAchatParProjet(ReportsDashboardData data) {
    final projMap = <String, (int count, double totalHT, double totalTTC)>{};
    for (final pi in data.purchaseInvoices) {
      final proj = (pi.projectName != null && pi.projectName!.isNotEmpty)
          ? pi.projectName!
          : 'Dépenses générales';
      final prev = projMap[proj] ?? (0, 0.0, 0.0);
      projMap[proj] = (prev.$1 + 1, prev.$2 + pi.totalHT, prev.$3 + pi.totalTTC);
    }

    final sorted = projMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
          '${e.value.$3.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'achat_projet',
      title: 'Achat par projet',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Projets Affectés',
          value: '${sorted.length}',
          subtitle: 'Centres de coûts',
          icon: Icons.business_center_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Projet / Chantier', 'Nb Factures', 'Achats HT', 'Achats TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeTvaAchat(ReportsDashboardData data) {
    final tvaMap = <double, (double baseHT, double montantTVA)>{};
    for (final pi in data.purchaseInvoices) {
      for (final item in pi.items) {
        final rate = item.tvaRate;
        final base = item.computedTotalHT;
        final tva = item.tvaAmount;
        final prev = tvaMap[rate] ?? (0.0, 0.0);
        tvaMap[rate] = (prev.$1 + base, prev.$2 + tva);
      }
    }

    final sorted = tvaMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final totalTva = sorted.fold<double>(0, (prevVal, e) => prevVal + e.value.$2);

    final chartPoints = sorted.map((e) => ReportChartPoint(label: '${e.key.toStringAsFixed(0)}%', value: e.value.$2)).toList();

    final rows = sorted.map((e) {
      final totalTTC = e.value.$1 + e.value.$2;
      return [
        '${e.key.toStringAsFixed(0)} %',
        '${e.value.$1.toStringAsFixed(2)} TND',
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${totalTTC.toStringAsFixed(2)} TND',
      ];
    }).toList();

    return ReportDetailData(
      reportKey: 'tva_achat',
      title: 'TVA achats',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'TVA Déductible',
          value: '${totalTva.toStringAsFixed(2)} TND',
          subtitle: 'TVA récupérable sur achats',
          icon: Icons.savings_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Taux de TVA', 'Base HT', 'Montant TVA Déductible', 'Total TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeRetenueFournisseur(ReportsDashboardData data) {
    final retenuePayments = data.payments.where((p) => p.direction == 'decaissement' && p.method == 'retenue_source').toList();
    final total = retenuePayments.fold<double>(0, (prevVal, p) => prevVal + p.amount);

    final rows = retenuePayments.map((p) => [
          '${p.paymentDate.day.toString().padLeft(2, '0')}/${p.paymentDate.month.toString().padLeft(2, '0')}/${p.paymentDate.year}',
          p.paymentNumber,
          p.contactName ?? 'Fournisseur Inconnu',
          p.reference ?? '-',
          '${p.amount.toStringAsFixed(2)} TND',
          p.status == 'paid' ? 'Versé' : 'En attente',
        ]).toList();

    final chartPoints = retenuePayments.take(6).map((p) => ReportChartPoint(label: p.contactName ?? p.paymentNumber, value: p.amount)).toList();

    return ReportDetailData(
      reportKey: 'retenue_fournisseur',
      title: 'Retenue fournisseurs',
      category: 'Rapports d\'achat',
      icon: Icons.shopping_cart_outlined,
      kpis: [
        ReportKpi(
          title: 'Retenues Fournisseurs',
          value: '${total.toStringAsFixed(2)} TND',
          subtitle: 'Montant retenu à la source',
          icon: Icons.receipt_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Date', 'N° Paiement', 'Fournisseur', 'Référence Facture', 'Montant Retenu', 'Statut'],
      rows: rows,
    );
  }

  // ─── 3. Rapports de paiement ───────────────────────────────────────

  ReportDetailData _computePaiementsRecus(ReportsDashboardData data) {
    final encaissements = data.payments.where((p) => p.direction == 'encaissement').toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    final total = encaissements.fold<double>(0, (prevVal, p) => prevVal + p.amount);

    // Group by method
    final methodMap = <String, double>{};
    for (final p in encaissements) {
      final m = p.method.toUpperCase();
      methodMap[m] = (methodMap[m] ?? 0) + p.amount;
    }

    final chartPoints = methodMap.entries.map((e) => ReportChartPoint(label: e.key, value: e.value)).toList();

    final rows = encaissements.map((p) => [
          '${p.paymentDate.day.toString().padLeft(2, '0')}/${p.paymentDate.month.toString().padLeft(2, '0')}/${p.paymentDate.year}',
          p.paymentNumber,
          p.contactName ?? 'Client Inconnu',
          p.method.toUpperCase(),
          '${p.amount.toStringAsFixed(2)} TND',
          p.status == 'paid' ? 'Encaissé' : 'En attente',
        ]).toList();

    return ReportDetailData(
      reportKey: 'paiement_recu',
      title: 'Paiements reçus',
      category: 'Rapports de paiement',
      icon: Icons.account_balance_wallet_outlined,
      kpis: [
        ReportKpi(
          title: 'Total Encaissé',
          value: '${total.toStringAsFixed(2)} TND',
          subtitle: '${encaissements.length} règlements reçus',
          icon: Icons.arrow_downward_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Date', 'N° Paiement', 'Client', 'Mode de Règlement', 'Montant', 'Statut'],
      rows: rows,
    );
  }

  ReportDetailData _computePaiementsEmis(ReportsDashboardData data) {
    final decaissements = data.payments.where((p) => p.direction == 'decaissement').toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    final total = decaissements.fold<double>(0, (prevVal, p) => prevVal + p.amount);

    final methodMap = <String, double>{};
    for (final p in decaissements) {
      final m = p.method.toUpperCase();
      methodMap[m] = (methodMap[m] ?? 0) + p.amount;
    }

    final chartPoints = methodMap.entries.map((e) => ReportChartPoint(label: e.key, value: e.value)).toList();

    final rows = decaissements.map((p) => [
          '${p.paymentDate.day.toString().padLeft(2, '0')}/${p.paymentDate.month.toString().padLeft(2, '0')}/${p.paymentDate.year}',
          p.paymentNumber,
          p.contactName ?? 'Fournisseur Inconnu',
          p.method.toUpperCase(),
          '${p.amount.toStringAsFixed(2)} TND',
          p.status == 'paid' ? 'Payé' : 'En attente',
        ]).toList();

    return ReportDetailData(
      reportKey: 'paiement_emis',
      title: 'Paiements émis',
      category: 'Rapports de paiement',
      icon: Icons.account_balance_wallet_outlined,
      kpis: [
        ReportKpi(
          title: 'Total Décaissé',
          value: '${total.toStringAsFixed(2)} TND',
          subtitle: '${decaissements.length} règlements émis',
          icon: Icons.arrow_upward_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Date', 'N° Paiement', 'Fournisseur', 'Mode de Règlement', 'Montant', 'Statut'],
      rows: rows,
    );
  }

  // ─── 4. Stock ──────────────────────────────────────────────────────

  ReportDetailData _computeStockConsommationDep(ReportsDashboardData data) {
    final depMap = <String, (int count, double totalVal)>{};
    for (final sw in data.stockWithdrawals) {
      final dep = sw.projectName ?? 'Service Principal';
      final val = sw.items.fold<double>(0, (prevVal, i) => prevVal + i.totalHT);
      final prev = depMap[dep] ?? (0, 0.0);
      depMap[dep] = (prev.$1 + 1, prev.$2 + val);
    }

    final sorted = depMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'stock_consommation_dep',
      title: 'Consommation par département',
      category: 'Stock',
      icon: Icons.inventory_2_outlined,
      kpis: [
        ReportKpi(
          title: 'Départements Utilisateurs',
          value: '${sorted.length}',
          subtitle: 'Unités consommatrices',
          icon: Icons.apartment_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Département / Chantier', 'Bons de Sortie', 'Valeur Estimée Consommée'],
      rows: rows,
    );
  }

  ReportDetailData _computeStockConsommationFamille(ReportsDashboardData data) {
    final famMap = <String, (double qty, double val)>{};
    for (final sw in data.stockWithdrawals) {
      for (final item in sw.items) {
        final p = data.products.where((prod) => prod.id == item.productId || prod.name == item.productName).firstOrNull;
        final fam = p?.category ?? 'Général';
        final prev = famMap[fam] ?? (0.0, 0.0);
        famMap[fam] = (prev.$1 + item.quantity, prev.$2 + item.totalHT);
      }
    }

    final sorted = famMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toStringAsFixed(0),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'stock_consommation_famille',
      title: 'Consommation par famille',
      category: 'Stock',
      icon: Icons.inventory_2_outlined,
      kpis: [
        ReportKpi(
          title: 'Familles Consommées',
          value: '${sorted.length}',
          subtitle: 'Sorties de stocks catégorisées',
          icon: Icons.category_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Famille / Catégorie', 'Quantité Sortie', 'Valeur Consommée HT'],
      rows: rows,
    );
  }

  ReportDetailData _computeStockRupture(ReportsDashboardData data) {
    final outOfStock = data.products.where((p) => p.productType != 'service' && p.stockQty <= p.lowStockThreshold).toList()
      ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

    final chartPoints = outOfStock.take(6).map((p) => ReportChartPoint(label: p.name, value: p.stockQty)).toList();

    final rows = outOfStock.map((p) => [
          p.reference ?? p.code,
          p.name,
          p.category ?? 'Général',
          p.stockQty.toStringAsFixed(0),
          p.lowStockThreshold.toStringAsFixed(0),
          p.stockQty <= 0 ? 'RUPTURE TOTALE' : 'SEUIL D\'ALERTE',
        ]).toList();

    return ReportDetailData(
      reportKey: 'stock_rupture',
      title: 'Produits en rupture de stock',
      category: 'Stock',
      icon: Icons.inventory_2_outlined,
      kpis: [
        ReportKpi(
          title: 'Articles en Rupture',
          value: '${outOfStock.length}',
          subtitle: 'Nécessitent un réapprovisionnement urgent',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Référence', 'Désignation', 'Famille', 'Stock Actuel', 'Seuil Min', 'État'],
      rows: rows,
    );
  }

  ReportDetailData _computeStockSurstockage(ReportsDashboardData data) {
    final surstock = data.products
        .where((p) => p.productType != 'service' && p.highStockThreshold > 0 && p.stockQty >= p.highStockThreshold)
        .toList()
      ..sort((a, b) => b.stockQty.compareTo(a.stockQty));

    final chartPoints = surstock.take(6).map((p) => ReportChartPoint(label: p.name, value: p.stockQty)).toList();

    final rows = surstock.map((p) => [
          p.reference ?? p.code,
          p.name,
          p.category ?? 'Général',
          p.stockQty.toStringAsFixed(0),
          p.highStockThreshold.toStringAsFixed(0),
          '${(p.stockQty * p.purchasePrice).toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'stock_surstockage',
      title: 'Produits en sur-stockage',
      category: 'Stock',
      icon: Icons.inventory_2_outlined,
      kpis: [
        ReportKpi(
          title: 'Articles en Surstock',
          value: '${surstock.length}',
          subtitle: 'Trésorerie immobilisée excessive',
          icon: Icons.inventory_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Référence', 'Désignation', 'Famille', 'Stock Actuel', 'Seuil Max', 'Valeur Immobilisée'],
      rows: rows,
    );
  }

  // ─── 5. Rapports contacts ──────────────────────────────────────────

  ReportDetailData _computeSoldesClients(ReportsDashboardData data) {
    final sorted = List<Customer>.from(data.customers)..sort((a, b) => b.balance.compareTo(a.balance));
    final totalDue = sorted.fold<double>(0, (prevVal, c) => prevVal + (c.balance > 0 ? c.balance : 0));

    final chartPoints = sorted.where((c) => c.balance > 0).take(6).map((c) => ReportChartPoint(label: c.name, value: c.balance)).toList();

    final rows = sorted.map((c) => [
          c.code,
          c.name,
          c.phone ?? '-',
          c.city ?? '-',
          '${c.creditLimit.toStringAsFixed(2)} TND',
          '${c.balance.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'soldes_clients',
      title: 'Soldes clients',
      category: 'Rapports contacts',
      icon: Icons.people_outline_rounded,
      kpis: [
        ReportKpi(
          title: 'Total Créances Clients',
          value: '${totalDue.toStringAsFixed(2)} TND',
          subtitle: 'Montant restant dû par les clients',
          icon: Icons.money_off_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Code', 'Client', 'Téléphone', 'Ville', 'Limite Crédit', 'Solde Dû (TND)'],
      rows: rows,
    );
  }

  ReportDetailData _computeSoldesFournisseurs(ReportsDashboardData data) {
    final sorted = List<Supplier>.from(data.suppliers)..sort((a, b) => b.balance.compareTo(a.balance));
    final totalDue = sorted.fold<double>(0, (prevVal, s) => prevVal + (s.balance > 0 ? s.balance : 0));

    final chartPoints = sorted.where((s) => s.balance > 0).take(6).map((s) => ReportChartPoint(label: s.name, value: s.balance)).toList();

    final rows = sorted.map((s) => [
          s.code,
          s.name,
          s.phone ?? '-',
          s.city ?? '-',
          '${s.balance.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'soldes_fournisseurs',
      title: 'Soldes fournisseurs',
      category: 'Rapports contacts',
      icon: Icons.people_outline_rounded,
      kpis: [
        ReportKpi(
          title: 'Dettes Fournisseurs',
          value: '${totalDue.toStringAsFixed(2)} TND',
          subtitle: 'Factures à payer aux partenaires',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Code', 'Fournisseur', 'Téléphone', 'Ville', 'Dette Fournisseur (TND)'],
      rows: rows,
    );
  }

  // ─── 6. Marge commerciale [Nouveau] ────────────────────────────────

  ReportDetailData _computeMargeParFacture(ReportsDashboardData data) {
    final productCostMap = <String, double>{};
    for (final p in data.products) {
      productCostMap[p.id] = p.purchasePrice;
      if (p.reference != null) productCostMap[p.reference!] = p.purchasePrice;
    }

    final rows = <List<String>>[];
    final chartPoints = <ReportChartPoint>[];
    double totalMargin = 0;

    for (final inv in data.invoices) {
      double cost = 0;
      for (final item in inv.items) {
        final c = productCostMap[item.productId] ?? 0.0;
        cost += item.quantity * c;
      }
      final margin = inv.totalHT - cost;
      totalMargin += margin;
      final rate = inv.totalHT > 0 ? (margin / inv.totalHT) * 100 : 0.0;

      rows.add([
        inv.number,
        '${inv.date.day.toString().padLeft(2, '0')}/${inv.date.month.toString().padLeft(2, '0')}/${inv.date.year}',
        inv.customerName ?? 'Client Inconnu',
        '${inv.totalHT.toStringAsFixed(2)} TND',
        '${cost.toStringAsFixed(2)} TND',
        '${margin.toStringAsFixed(2)} TND',
        '${rate.toStringAsFixed(1)} %',
      ]);

      if (chartPoints.length < 8) {
        chartPoints.add(ReportChartPoint(label: inv.number, value: margin));
      }
    }

    final avgRate = data.totalSalesHT > 0 ? (totalMargin / data.totalSalesHT) * 100 : 0.0;

    return ReportDetailData(
      reportKey: 'marge_facture',
      title: 'Marge commerciale par facture',
      category: 'Marge commerciale',
      icon: Icons.attach_money,
      kpis: [
        ReportKpi(
          title: 'Marge Brute Facturée',
          value: '${totalMargin.toStringAsFixed(2)} TND',
          subtitle: 'Bénéfice brut sur factures',
          icon: Icons.savings_rounded,
          color: const Color(0xFF10B981),
        ),
        ReportKpi(
          title: 'Taux de Marge Moyen',
          value: '${avgRate.toStringAsFixed(1)} %',
          subtitle: 'Rendement sur le chiffre d\'affaires HT',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF2563EB),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['N° Facture', 'Date', 'Client', 'Vente HT', 'Coût Achat HT', 'Marge HT', 'Taux Marge'],
      rows: rows,
    );
  }

  ReportDetailData _computeMargeParBL(ReportsDashboardData data) {
    final productCostMap = <String, double>{};
    for (final p in data.products) {
      productCostMap[p.id] = p.purchasePrice;
      if (p.reference != null) productCostMap[p.reference!] = p.purchasePrice;
    }

    final rows = <List<String>>[];
    final chartPoints = <ReportChartPoint>[];
    double totalMargin = 0;
    double totalBLHT = 0;

    for (final dn in data.deliveryNotes) {
      double cost = 0;
      for (final item in dn.items) {
        final c = productCostMap[item.productId] ?? 0.0;
        cost += item.quantity * c;
      }
      final margin = dn.subTotalHT - cost;
      totalMargin += margin;
      totalBLHT += dn.subTotalHT;
      final rate = dn.subTotalHT > 0 ? (margin / dn.subTotalHT) * 100 : 0.0;

      rows.add([
        dn.number,
        '${dn.date.day.toString().padLeft(2, '0')}/${dn.date.month.toString().padLeft(2, '0')}/${dn.date.year}',
        dn.customerName ?? 'Client Inconnu',
        '${dn.subTotalHT.toStringAsFixed(2)} TND',
        '${cost.toStringAsFixed(2)} TND',
        '${margin.toStringAsFixed(2)} TND',
        '${rate.toStringAsFixed(1)} %',
      ]);

      if (chartPoints.length < 8) {
        chartPoints.add(ReportChartPoint(label: dn.number, value: margin));
      }
    }

    final avgRate = totalBLHT > 0 ? (totalMargin / totalBLHT) * 100 : 0.0;

    return ReportDetailData(
      reportKey: 'marge_bl',
      title: 'Marge commerciale par bon de livraison',
      category: 'Marge commerciale',
      icon: Icons.attach_money,
      kpis: [
        ReportKpi(
          title: 'Marge sur BL',
          value: '${totalMargin.toStringAsFixed(2)} TND',
          subtitle: 'Sur l\'ensemble des livraisons',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF10B981),
        ),
        ReportKpi(
          title: 'Taux Moyen sur BL',
          value: '${avgRate.toStringAsFixed(1)} %',
          subtitle: 'Rendement moyen des livraisons',
          icon: Icons.percent_rounded,
          color: const Color(0xFF2563EB),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['N° Bon Livraison', 'Date', 'Client', 'Vente HT', 'Coût Achat HT', 'Marge HT', 'Taux Marge'],
      rows: rows,
    );
  }

  ReportDetailData _computeMargeParArticle(ReportsDashboardData data) {
    final productCostMap = <String, double>{};
    for (final p in data.products) {
      productCostMap[p.id] = p.purchasePrice;
      if (p.reference != null) productCostMap[p.reference!] = p.purchasePrice;
    }

    final articleSales = <String, (double qty, double totalHT, double unitCost)>{};
    for (final inv in data.invoices) {
      for (final item in inv.items) {
        final name = item.productName ?? 'Article #${item.productId}';
        final cost = productCostMap[item.productId] ?? 0.0;
        final prev = articleSales[name] ?? (0.0, 0.0, cost);
        articleSales[name] = (prev.$1 + item.quantity, prev.$2 + item.computedTotalHT, cost);
      }
    }

    final rows = <List<String>>[];
    final chartPoints = <ReportChartPoint>[];

    final sorted = articleSales.entries.toList()..sort((a, b) {
      final marginA = a.value.$2 - (a.value.$1 * a.value.$3);
      final marginB = b.value.$2 - (b.value.$1 * b.value.$3);
      return marginB.compareTo(marginA);
    });

    for (final e in sorted) {
      final totalCost = e.value.$1 * e.value.$3;
      final margin = e.value.$2 - totalCost;
      final rate = e.value.$2 > 0 ? (margin / e.value.$2) * 100 : 0.0;
      final avgPrice = e.value.$1 > 0 ? e.value.$2 / e.value.$1 : 0.0;

      rows.add([
        e.key,
        e.value.$1.toStringAsFixed(0),
        '${avgPrice.toStringAsFixed(2)} TND',
        '${e.value.$3.toStringAsFixed(2)} TND',
        '${e.value.$2.toStringAsFixed(2)} TND',
        '${margin.toStringAsFixed(2)} TND',
        '${rate.toStringAsFixed(1)} %',
      ]);

      if (chartPoints.length < 6) {
        chartPoints.add(ReportChartPoint(label: e.key, value: margin));
      }
    }

    return ReportDetailData(
      reportKey: 'marge_article',
      title: 'Marge commerciale par article',
      category: 'Marge commerciale',
      icon: Icons.attach_money,
      kpis: [
        ReportKpi(
          title: 'Article le plus rentable',
          value: sorted.isNotEmpty ? sorted.first.key : '-',
          subtitle: 'Génère le plus de bénéfice brut',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Article', 'Qté Vendue', 'Prix Vente Moyen', 'Coût Achat Unitaire', 'CA HT', 'Marge Globale', 'Taux Marge'],
      rows: rows,
    );
  }

  // ─── 7. Rapports bons de livraison [Nouveau] ───────────────────────

  ReportDetailData _computeBLParClient(ReportsDashboardData data) {
    final clientMap = <String, (int count, double totalHT, double totalTTC)>{};
    for (final dn in data.deliveryNotes) {
      final name = dn.customerName ?? 'Client Inconnu';
      final prev = clientMap[name] ?? (0, 0.0, 0.0);
      clientMap[name] = (prev.$1 + 1, prev.$2 + dn.subTotalHT, prev.$3 + dn.subTotalTTC);
    }

    final sorted = clientMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
          '${e.value.$3.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'bl_client',
      title: 'BL par client',
      category: 'Rapports bons de livraison',
      icon: Icons.local_shipping_outlined,
      kpis: [
        ReportKpi(
          title: 'Total BL Émis',
          value: '${data.deliveryNotes.length}',
          subtitle: 'Livraisons enregistrées',
          icon: Icons.local_shipping_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Client', 'Nombre de BL', 'Total HT', 'Total TTC'],
      rows: rows,
    );
  }

  ReportDetailData _computeBLParArticle(ReportsDashboardData data) {
    final itemMap = <String, (double qty, double totalHT)>{};
    for (final dn in data.deliveryNotes) {
      for (final item in dn.items) {
        final name = item.productName ?? 'Article #${item.productId}';
        final prev = itemMap[name] ?? (0.0, 0.0);
        itemMap[name] = (prev.$1 + item.quantity, prev.$2 + item.totalHT);
      }
    }

    final sorted = itemMap.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$1)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toStringAsFixed(0),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'bl_article',
      title: 'BL par article',
      category: 'Rapports bons de livraison',
      icon: Icons.local_shipping_outlined,
      kpis: [
        ReportKpi(
          title: 'Articles Livrés',
          value: '${sorted.length}',
          subtitle: 'Références expédiées',
          icon: Icons.inventory_2_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Article / Référence', 'Quantité Livrée', 'Total HT Livré'],
      rows: rows,
    );
  }

  ReportDetailData _computeBLParFamille(ReportsDashboardData data) {
    final famMap = <String, (double qty, double totalHT)>{};
    for (final dn in data.deliveryNotes) {
      for (final item in dn.items) {
        final p = data.products.where((prod) => prod.id == item.productId || prod.name == item.productName).firstOrNull;
        final fam = p?.category ?? 'Général';
        final prev = famMap[fam] ?? (0.0, 0.0);
        famMap[fam] = (prev.$1 + item.quantity, prev.$2 + item.totalHT);
      }
    }

    final sorted = famMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toStringAsFixed(0),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'bl_famille',
      title: 'BL par famille',
      category: 'Rapports bons de livraison',
      icon: Icons.local_shipping_outlined,
      kpis: [
        ReportKpi(
          title: 'Familles Livrées',
          value: '${sorted.length}',
          subtitle: 'Catégories expédiées',
          icon: Icons.category_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Famille', 'Quantité Livrée', 'Total HT'],
      rows: rows,
    );
  }

  ReportDetailData _computeBLParProjet(ReportsDashboardData data) {
    final projMap = <String, (int count, double totalHT, double totalTTC)>{};
    for (final dn in data.deliveryNotes) {
      final proj = (dn.projectName != null && dn.projectName!.isNotEmpty)
          ? dn.projectName!
          : 'Sans projet';
      final prev = projMap[proj] ?? (0, 0.0, 0.0);
      projMap[proj] = (prev.$1 + 1, prev.$2 + dn.subTotalHT, prev.$3 + dn.subTotalTTC);
    }

    final sorted = projMap.entries.toList()..sort((a, b) => b.value.$3.compareTo(a.value.$3));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$3)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
          '${e.value.$3.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'bl_projet',
      title: 'BL par projet',
      category: 'Rapports bons de livraison',
      icon: Icons.local_shipping_outlined,
      kpis: [
        ReportKpi(
          title: 'Projets Livrés',
          value: '${sorted.length}',
          subtitle: 'Destinations chantiers / projets',
          icon: Icons.business_center_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Projet', 'Nb Bons de Livraison', 'Total HT', 'Total TTC'],
      rows: rows,
    );
  }

  // ─── 8. Rapports bons de réception [Nouveau] ───────────────────────

  ReportDetailData _computeBRParFournisseur(ReportsDashboardData data) {
    final suppMap = <String, (int count, double totalHT)>{};
    for (final rv in data.receivingVouchers) {
      final name = rv.supplierName ?? 'Fournisseur Inconnu';
      final totalHT = rv.items.fold<double>(0, (prevVal, item) => prevVal + item.computedTotalHT);
      final prev = suppMap[name] ?? (0, 0.0);
      suppMap[name] = (prev.$1 + 1, prev.$2 + totalHT);
    }

    final sorted = suppMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'br_fournisseur',
      title: 'BR par fournisseur',
      category: 'Rapports bons de réception',
      icon: Icons.all_inbox_rounded,
      kpis: [
        ReportKpi(
          title: 'Bons de Réception',
          value: '${data.receivingVouchers.length}',
          subtitle: 'Réceptions marchandises effectuées',
          icon: Icons.all_inbox_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Fournisseur', 'Nombre de BR', 'Total Réceptionné HT'],
      rows: rows,
    );
  }

  ReportDetailData _computeBRParArticle(ReportsDashboardData data) {
    final itemMap = <String, (double qty, double totalHT)>{};
    for (final rv in data.receivingVouchers) {
      for (final item in rv.items) {
        final name = item.productName ?? 'Article #${item.productId}';
        final prev = itemMap[name] ?? (0.0, 0.0);
        itemMap[name] = (prev.$1 + item.quantityReceived, prev.$2 + item.computedTotalHT);
      }
    }

    final sorted = itemMap.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$1)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toStringAsFixed(0),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'br_article',
      title: 'BR par article',
      category: 'Rapports bons de réception',
      icon: Icons.all_inbox_rounded,
      kpis: [
        ReportKpi(
          title: 'Articles Réceptionnés',
          value: '${sorted.length}',
          subtitle: 'Références réceptionnées en entrepôt',
          icon: Icons.inventory_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Article / Référence', 'Quantité Réceptionnée', 'Total HT Réceptionné'],
      rows: rows,
    );
  }

  ReportDetailData _computeBRParFamille(ReportsDashboardData data) {
    final famMap = <String, (double qty, double totalHT)>{};
    for (final rv in data.receivingVouchers) {
      for (final item in rv.items) {
        final p = data.products.where((prod) => prod.id == item.productId || prod.name == item.productName).firstOrNull;
        final fam = p?.category ?? 'Général';
        final prev = famMap[fam] ?? (0.0, 0.0);
        famMap[fam] = (prev.$1 + item.quantityReceived, prev.$2 + item.computedTotalHT);
      }
    }

    final sorted = famMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toStringAsFixed(0),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'br_famille',
      title: 'BR par famille',
      category: 'Rapports bons de réception',
      icon: Icons.all_inbox_rounded,
      kpis: [
        ReportKpi(
          title: 'Familles Réceptionnées',
          value: '${sorted.length}',
          subtitle: 'Catégories approvisionnées',
          icon: Icons.category_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Famille', 'Quantité Réceptionnée', 'Total HT'],
      rows: rows,
    );
  }

  ReportDetailData _computeBRParProjet(ReportsDashboardData data) {
    final projMap = <String, (int count, double totalHT)>{};
    for (final rv in data.receivingVouchers) {
      final proj = (rv.orderId != null && rv.orderId!.isNotEmpty) ? 'Commande #${rv.orderId}' : 'Stock Général';
      final totalHT = rv.items.fold<double>(0, (prevVal, item) => prevVal + item.computedTotalHT);
      final prev = projMap[proj] ?? (0, 0.0);
      projMap[proj] = (prev.$1 + 1, prev.$2 + totalHT);
    }

    final sorted = projMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final chartPoints = sorted.take(6).map((e) => ReportChartPoint(label: e.key, value: e.value.$2)).toList();

    final rows = sorted.map((e) => [
          e.key,
          e.value.$1.toString(),
          '${e.value.$2.toStringAsFixed(2)} TND',
        ]).toList();

    return ReportDetailData(
      reportKey: 'br_projet',
      title: 'BR par projet',
      category: 'Rapports bons de réception',
      icon: Icons.all_inbox_rounded,
      kpis: [
        ReportKpi(
          title: 'Affectations Réception',
          value: '${sorted.length}',
          subtitle: 'Destinations enregistrées',
          icon: Icons.assignment_turned_in_rounded,
        ),
      ],
      chartPoints: chartPoints,
      headers: ['Destination / Projet', 'Nb Bons de Réception', 'Total Réceptionné HT'],
      rows: rows,
    );
  }

  ReportDetailData _computeDefaultReport(String reportKey, ReportsDashboardData data) {
    return ReportDetailData(
      reportKey: reportKey,
      title: reportKey,
      category: 'Rapports',
      icon: Icons.analytics_outlined,
      kpis: const [],
      chartPoints: const [],
      headers: const ['Désignation', 'Valeur'],
      rows: const [],
    );
  }
}
