import 'package:cloud_firestore/cloud_firestore.dart';

class RetenueSourceVente {
  final String id;
  final String invoiceReference;
  final String clientName;
  final DateTime date;
  final double amount;
  final String status;

  RetenueSourceVente({
    required this.id,
    required this.invoiceReference,
    required this.clientName,
    required this.date,
    required this.amount,
    required this.status,
  });

  factory RetenueSourceVente.fromMap(Map<String, dynamic> map, String documentId) {
    return RetenueSourceVente(
      id: documentId,
      invoiceReference: map['reference'] ?? map['payment_number'] ?? '',
      clientName: map['contact_name'] ?? '',
      date: map['payment_date'] != null
          ? (map['payment_date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['payment_date'] as int)
              : DateTime.parse(map['payment_date'].toString()))
          : DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] == 'paid' ? 'Payé' : (map['status'] == 'cancelled' ? 'Annulé' : 'En attente'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reference': invoiceReference,
      'contact_name': clientName,
      'payment_date': date.millisecondsSinceEpoch,
      'amount': amount,
      'status': status == 'Payé' ? 'paid' : (status == 'Annulé' ? 'cancelled' : 'pending'),
      'method': 'retenue_source',
      'direction': 'encaissement',
    };
  }
}
