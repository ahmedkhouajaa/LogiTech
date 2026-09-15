import 'package:intl/intl.dart';
import '../models/document_numbering_config.dart';
import '../services/document_numbering_service.dart';

// ─── Currency Formatting ──────────────────────────────────────────
String formatCurrency(double amount, {String symbol = 'TND'}) {
  final formatter = NumberFormat('#,##0.00', 'fr_FR');
  return '${formatter.format(amount)} $symbol';
}

String formatCurrencyCompact(double amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M TND';
  } else if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K TND';
  }
  return formatCurrency(amount);
}

// ─── Date Formatting ──────────────────────────────────────────────
String formatDate(DateTime date, [String? locale]) {
  return DateFormat('dd/MM/yyyy', locale ?? Intl.defaultLocale ?? 'fr_FR').format(date.toLocal());
}

String formatDateTime(DateTime date, [String? locale]) {
  return DateFormat('dd/MM/yyyy HH:mm', locale ?? Intl.defaultLocale ?? 'fr_FR').format(date.toLocal());
}

String formatDateShort(DateTime date, [String? locale]) {
  return DateFormat('dd MMM yyyy', locale ?? Intl.defaultLocale ?? 'fr_FR').format(date.toLocal());
}

String formatDateRelative(DateTime date) {
  final d = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return "A l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  return formatDate(d);
}

// ─── Document Number Generator ────────────────────────────────────
String generateDocNumber(String prefix, int sequence, {String? docCollection}) {
  final col = docCollection != null
      ? DocumentTypeDefinition.normalizeKey(docCollection)
      : _mapPrefixToCollection(prefix);

  if (col != null) {
    return DocumentNumberingService.formatDocumentNumber(
      col,
      sequence,
      defaultPrefix: prefix,
    );
  }

  final year = DateTime.now().year;
  final seq = sequence.toString().padLeft(6, '0');
  return '$prefix-$year-$seq';
}

String? _mapPrefixToCollection(String prefix) {
  final p = prefix.toUpperCase().trim();
  switch (p) {
    case 'FAC':
    case 'FA':
      return 'invoices';
    case 'DV':
    case 'DEV':
      return 'quotes';
    case 'CC':
    case 'CMD':
    case 'BC':
      return 'customer_orders';
    case 'BL':
      return 'delivery_notes';
    case 'BS':
      return 'bons_sortie';
    case 'AV':
      return 'credit_notes';
    case 'BR':
      return 'return_notes';
    case 'CF':
    case 'BCF':
      return 'supplier_orders';
    case 'BRC':
      return 'receiving_vouchers';
    case 'FACH':
      return 'purchase_invoices';
    case 'AVF':
    case 'AF':
      return 'supplier_credit_notes';
    case 'BRF':
    case 'RF':
      return 'supplier_returns';
    default:
      return null;
  }
}

// ─── Number Helpers ───────────────────────────────────────────────
double calculateTva(double amountHT, double tvaRate) {
  return amountHT * (tvaRate / 100);
}

double calculateTTC(double amountHT, double tvaRate) {
  return amountHT + calculateTva(amountHT, tvaRate);
}

double calculateHT(double amountTTC, double tvaRate) {
  return amountTTC / (1 + tvaRate / 100);
}

String formatPercentage(double value) {
  return '${value.toStringAsFixed(1)}%';
}

String formatQuantity(double qty) {
  if (qty == qty.roundToDouble()) {
    return qty.toInt().toString();
  }
  return qty.toStringAsFixed(2);
}

// ─── String Helpers ───────────────────────────────────────────────
String truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

// ─── Validation ───────────────────────────────────────────────────
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

bool isValidPhone(String phone) {
  return RegExp(r'^[0-9+\- ]{8,15}$').hasMatch(phone);
}

// ─── Invoice Status Color Helper ──────────────────────────────────
double calculatePaymentPercentage(double totalTTC, double amountPaid) {
  if (totalTTC <= 0) return 0;
  return (amountPaid / totalTTC * 100).clamp(0, 100);
}

// ─── Stamp Tax Calculator (Algeria) ───────────────────────────────
double calculateStampTax(double totalTTC) {
  // Algeria stamp tax: 1% of TTC with min 2500 DA
  if (totalTTC <= 0) return 0;
  final tax = totalTTC * 0.01;
  return tax < 2500 ? 0 : tax;
}

// ─── Tunisian Currency Formatting (TND) ────────────────────────────
String formatCurrencyDT(double amount) {
  final formatter = NumberFormat('#,##0.000', 'fr_FR');
  return '${formatter.format(amount)} TND';
}

// ─── Long Date Format (e.g., "11 juin 2026") ──────────────────────
String formatDateLong(DateTime date, [String? locale]) {
  return DateFormat('d MMMM yyyy', locale ?? Intl.defaultLocale ?? 'fr_FR').format(date.toLocal());
}

// ─── Date + Time Format (e.g., "11 juin 2026 - 18:18") ───────────
String formatDateTimeLong(DateTime date, [String? locale]) {
  final d = date.toLocal();
  final loc = locale ?? Intl.defaultLocale ?? 'fr_FR';
  return '${DateFormat('d MMMM yyyy', loc).format(d)} - ${DateFormat('HH:mm', loc).format(d)}';
}
