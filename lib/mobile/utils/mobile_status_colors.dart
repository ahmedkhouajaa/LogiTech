import 'package:flutter/material.dart';

class MobileStatusColors {
  static Color getColorForStatus(String status) {
    final lower = status.toLowerCase().trim();

    // 1. Facturé / Converti / Invoiced (Vibrant Indigo - #6366F1)
    if (lower.contains('factur') ||
        lower.contains('converti') ||
        lower == 'invoiced') {
      return const Color(0xFF6366F1); // Modern Indigo
    }

    // 2. Validé / Accepté / Livré / Payé / Reçu / Confirmé / Delivered / Paid / Validated (Emerald Green - #10B981)
    if ((lower.contains('valid') ||
            lower.contains('valide') ||
            lower.contains('accep') ||
            lower.contains('livr') ||
            lower.contains('pay') ||
            lower.contains('recu') ||
            lower.contains('reçu') ||
            lower.contains('confirm') ||
            lower.contains('entree') ||
            lower.contains('entrée') ||
            lower.contains('encais') ||
            lower == 'cree' ||
            lower == 'créé' ||
            lower == 'delivered' ||
            lower == 'paid' ||
            lower == 'validated') &&
        !lower.contains('non')) {
      return const Color(0xFF10B981); // Emerald Green
    }

    // 3. Retourné / Returned / En cours / En attente / Partiellement payée (Warm Amber - #F59E0B)
    if (lower.contains('retour') ||
        lower == 'returned' ||
        lower.contains('cours') ||
        lower.contains('attent') ||
        lower.contains('prepar') ||
        lower.contains('prépar') ||
        lower.contains('partiel') ||
        lower.contains('pending')) {
      return const Color(0xFFF59E0B); // Amber
    }

    // 4. Envoyé / Sent (Royal Purple / Violet - #8B5CF6)
    if (lower.contains('envoy') || lower == 'sent') {
      return const Color(0xFF8B5CF6); // Royal Purple / Violet
    }

    // 5. Annulé / Refusé / Rejeté / Non payé / En retard / Cancelled (Rose Red - #EF4444)
    if (lower.contains('annul') ||
        lower.contains('refus') ||
        lower.contains('rejet') ||
        lower.contains('non') ||
        lower.contains('retard') ||
        lower.contains('expir') ||
        lower == 'cancelled' ||
        lower == 'rejected') {
      return const Color(0xFFEF4444); // Crimson / Rose Red
    }

    // 6. Brouillon / Draft (Amber / Orange - #F59E0B)
    if (lower.contains('brouillon') || lower == 'draft') {
      return const Color(0xFFF59E0B); // Amber / Orange
    }

    // Default fallback - Slate Grey
    return const Color(0xFF64748B);
  }
}
