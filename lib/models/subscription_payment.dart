import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPayment {
  final String id;
  final String enterpriseId;
  final String userId;
  final String planName; // 'Plan Mensuel', 'Plan Annuel', 'Plan Personnalisé'
  final double amount; // e.g. 60.0 or 600.0
  final String method; // 'card' or 'bank_transfer'
  final String status; // 'pending' (En attente), 'paid' (Validé), 'failed' (Échoué)
  final DateTime createdAt;
  final DateTime? paidAt;
  final int durationDays;

  SubscriptionPayment({
    required this.id,
    required this.enterpriseId,
    required this.userId,
    required this.planName,
    required this.amount,
    required this.method,
    this.status = 'pending',
    required this.createdAt,
    this.paidAt,
    this.durationDays = 30,
  });

  String get methodLabel => method == 'card' ? 'Carte bancaire' : 'Virement bancaire';

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Validé';
      case 'failed':
        return 'Échoué';
      case 'pending':
      default:
        return 'En attente';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'enterpriseId': enterpriseId,
        'userId': userId,
        'planName': planName,
        'amount': amount,
        'method': method,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
        'durationDays': durationDays,
      };

  factory SubscriptionPayment.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return SubscriptionPayment(
      id: id,
      enterpriseId: map['enterpriseId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      planName: map['planName']?.toString() ?? 'Plan Annuel',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 50.0,
      method: map['method']?.toString() ?? 'bank_transfer',
      status: map['status']?.toString() ?? 'pending',
      createdAt: parseDate(map['createdAt']),
      paidAt: map['paidAt'] != null ? parseDate(map['paidAt']) : null,
      durationDays: int.tryParse(map['durationDays']?.toString() ?? '30') ?? 30,
    );
  }
}
