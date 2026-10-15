import 'package:cloud_firestore/cloud_firestore.dart';

class HrEstablishment {
  final String id;
  final String enterpriseId;
  final String name;
  final String registrationNumber;
  final String address;
  final String addressSuite;
  final String postalCode;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final double geofenceRadius;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HrEstablishment({
    required this.id,
    required this.enterpriseId,
    required this.name,
    this.registrationNumber = '',
    this.address = '',
    this.addressSuite = '',
    this.postalCode = '',
    this.city = '',
    this.country = 'Tunisie',
    this.latitude,
    this.longitude,
    this.geofenceRadius = 100.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  HrEstablishment copyWith({
    String? id,
    String? enterpriseId,
    String? name,
    String? registrationNumber,
    String? address,
    String? addressSuite,
    String? postalCode,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    double? geofenceRadius,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrEstablishment(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      addressSuite: addressSuite ?? this.addressSuite,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'name': name,
      'registrationNumber': registrationNumber,
      'address': address,
      'addressSuite': addressSuite,
      'postalCode': postalCode,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'geofenceRadius': geofenceRadius,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory HrEstablishment.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return HrEstablishment(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id'] as String? ?? ''),
      enterpriseId: map['enterpriseId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      registrationNumber: map['registrationNumber'] as String? ?? '',
      address: map['address'] as String? ?? '',
      addressSuite: map['addressSuite'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      city: map['city'] as String? ?? '',
      country: map['country'] as String? ?? 'Tunisie',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      geofenceRadius: (map['geofenceRadius'] as num?)?.toDouble() ?? 100.0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
