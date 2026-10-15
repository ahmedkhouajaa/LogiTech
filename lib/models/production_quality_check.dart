import 'package:flutter/material.dart';

enum QualityCheckResult {
  conforme,
  avecReserves,
  nonConforme;

  String get label {
    switch (this) {
      case QualityCheckResult.conforme:
        return 'Conforme';
      case QualityCheckResult.avecReserves:
        return 'Avec réserves';
      case QualityCheckResult.nonConforme:
        return 'Non conforme';
    }
  }

  Color get color {
    switch (this) {
      case QualityCheckResult.conforme:
        return const Color(0xFF10B981); // Vert
      case QualityCheckResult.avecReserves:
        return const Color(0xFFF59E0B); // Ambre
      case QualityCheckResult.nonConforme:
        return const Color(0xFFEF4444); // Rouge
    }
  }
}

class QualityCheckPoint {
  final String title;
  final String expectedValue;
  final String actualValue;
  final bool isPassed;
  final String? notes;

  QualityCheckPoint({
    required this.title,
    this.expectedValue = '',
    this.actualValue = '',
    this.isPassed = true,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'expected_value': expectedValue,
        'actual_value': actualValue,
        'is_passed': isPassed,
        'notes': notes,
      };

  factory QualityCheckPoint.fromMap(Map<String, dynamic> map) =>
      QualityCheckPoint(
        title: map['title']?.toString() ?? '',
        expectedValue: map['expected_value']?.toString() ?? '',
        actualValue: map['actual_value']?.toString() ?? '',
        isPassed: map['is_passed'] == true || map['is_passed'] == 1,
        notes: map['notes']?.toString(),
      );

  QualityCheckPoint copyWith({
    String? title,
    String? expectedValue,
    String? actualValue,
    bool? isPassed,
    String? notes,
  }) =>
      QualityCheckPoint(
        title: title ?? this.title,
        expectedValue: expectedValue ?? this.expectedValue,
        actualValue: actualValue ?? this.actualValue,
        isPassed: isPassed ?? this.isPassed,
        notes: notes ?? this.notes,
      );
}

class ProductionQualityCheck {
  final String id;
  final String orderId;
  final String orderNumber;
  final String productId;
  final String productName;
  final String checkType; // 'reception', 'inProcess', 'final'
  final List<QualityCheckPoint> points;
  final QualityCheckResult result;
  final double qtyChecked;
  final double qtyRejected;
  final String? inspectorName;
  final DateTime inspectionDate;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;

  ProductionQualityCheck({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.productId,
    required this.productName,
    this.checkType = 'final',
    this.points = const [],
    this.result = QualityCheckResult.conforme,
    this.qtyChecked = 0.0,
    this.qtyRejected = 0.0,
    this.inspectorName,
    DateTime? inspectionDate,
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
  })  : inspectionDate = inspectionDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'order_number': orderNumber,
        'product_id': productId,
        'product_name': productName,
        'check_type': checkType,
        'points': points.map((p) => p.toMap()).toList(),
        'result': result.name,
        'qty_checked': qtyChecked,
        'qty_rejected': qtyRejected,
        'inspector_name': inspectorName,
        'inspection_date': inspectionDate.toIso8601String(),
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProductionQualityCheck.fromMap(Map<String, dynamic> map) =>
      ProductionQualityCheck(
        id: map['id']?.toString() ?? '',
        orderId: map['order_id']?.toString() ?? '',
        orderNumber: map['order_number']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        productName: map['product_name']?.toString() ?? '',
        checkType: map['check_type']?.toString() ?? 'final',
        points: (map['points'] as List?)
                ?.map((item) =>
                    QualityCheckPoint.fromMap(Map<String, dynamic>.from(item)))
                .toList() ??
            [],
        result: QualityCheckResult.values.firstWhere(
          (e) => e.name == map['result'],
          orElse: () => QualityCheckResult.conforme,
        ),
        qtyChecked: (map['qty_checked'] as num?)?.toDouble() ?? 0.0,
        qtyRejected: (map['qty_rejected'] as num?)?.toDouble() ?? 0.0,
        inspectorName: map['inspector_name']?.toString(),
        inspectionDate: map['inspection_date'] != null
            ? (DateTime.tryParse(map['inspection_date'].toString()) ??
                DateTime.now())
            : DateTime.now(),
        notes: map['notes']?.toString(),
        enterpriseId: map['enterprise_id']?.toString(),
        createdAt: map['created_at'] != null
            ? (DateTime.tryParse(map['created_at'].toString()) ??
                DateTime.now())
            : DateTime.now(),
      );
}

class ProductionNonConformity {
  final String id;
  final String checkId;
  final String orderId;
  final String orderNumber;
  final String defectType; // ex: Dimensionnel, Aspect, Fonctionnel, Matière
  final String severity; // 'faible', 'moyenne', 'critique'
  final String rootCause;
  final String correctiveAction;
  final String status; // 'ouverte', 'enCours', 'resolue'
  final String? enterpriseId;
  final DateTime createdAt;

  ProductionNonConformity({
    required this.id,
    required this.checkId,
    required this.orderId,
    required this.orderNumber,
    required this.defectType,
    this.severity = 'moyenne',
    this.rootCause = '',
    this.correctiveAction = '',
    this.status = 'ouverte',
    this.enterpriseId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'critique':
        return const Color(0xFFEF4444);
      case 'moyenne':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'check_id': checkId,
        'order_id': orderId,
        'order_number': orderNumber,
        'defect_type': defectType,
        'severity': severity,
        'root_cause': rootCause,
        'corrective_action': correctiveAction,
        'status': status,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProductionNonConformity.fromMap(Map<String, dynamic> map) =>
      ProductionNonConformity(
        id: map['id']?.toString() ?? '',
        checkId: map['check_id']?.toString() ?? '',
        orderId: map['order_id']?.toString() ?? '',
        orderNumber: map['order_number']?.toString() ?? '',
        defectType: map['defect_type']?.toString() ?? '',
        severity: map['severity']?.toString() ?? 'moyenne',
        rootCause: map['root_cause']?.toString() ?? '',
        correctiveAction: map['corrective_action']?.toString() ?? '',
        status: map['status']?.toString() ?? 'ouverte',
        enterpriseId: map['enterprise_id']?.toString(),
        createdAt: map['created_at'] != null
            ? (DateTime.tryParse(map['created_at'].toString()) ??
                DateTime.now())
            : DateTime.now(),
      );
}
