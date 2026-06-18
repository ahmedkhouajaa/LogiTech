import 'package:intl/intl.dart';

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
String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
}

String formatDateTime(DateTime date) {
  return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(date);
}

String formatDateShort(DateTime date) {
  return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
}

String formatDateRelative(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return "A l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  return formatDate(date);
}

// ─── Document Number Generator ────────────────────────────────────
String generateDocNumber(String prefix, int sequence) {
  final year = DateTime.now().year;
  final seq = sequence.toString().padLeft(5, '0');
  return '$prefix-$year-$seq';
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
String formatDateLong(DateTime date) {
  return DateFormat('d MMMM yyyy', 'fr_FR').format(date);
}

// ─── Date + Time Format (e.g., "11 juin 2026 - 18:18") ───────────
String formatDateTimeLong(DateTime date) {
  return '${DateFormat('d MMMM yyyy', 'fr_FR').format(date)} - ${DateFormat('HH:mm', 'fr_FR').format(date)}';
}
