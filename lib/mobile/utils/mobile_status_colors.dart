import 'package:flutter/material.dart';

class MobileStatusColors {
  static Color getColorForStatus(String status) {
    final lowerStatus = status.toLowerCase();
    
    // Green
    if (['payée', 'payee', 'acceptée', 'acceptee', 'accepté', 'accepte', 'livrée', 'livree', 'livré', 'livre', 'validé', 'valide', 'reçu', 'recu', 'confirmé', 'confirme', 'entrée', 'entree', 'encaisé', 'encaissé', 'encaissée', 'payé', 'paye'].contains(lowerStatus)) {
      return Colors.green;
    }
    
    // Red
    if (['non payée', 'non payee', 'non payé', 'non paye', 'refusé', 'refuse', 'annulée', 'annulee', 'annulé', 'annule', 'rejeté', 'rejete', 'sortie'].contains(lowerStatus)) {
      return Colors.red;
    }
    
    // Orange
    if (['en cours', 'en attente', 'en préparation', 'en preparation', 'partiellement payee', 'partiellement payée'].contains(lowerStatus)) {
      return Colors.orange;
    }

    if (['brouillon'].contains(lowerStatus)) {
      return Colors.blueGrey;
    }

    // Default fallback
    return Colors.grey;
  }
}
