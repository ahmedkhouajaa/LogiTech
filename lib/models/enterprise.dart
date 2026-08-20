/// Enterprise model for multi-enterprise/workspace support.
///
/// Each enterprise represents a separate business entity with its own
/// data, settings, and members.
class Enterprise {
  final String id;
  final String name;
  final String? description;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxId;
  final String? rcNumber;
  final String? address;
  final String? rib;
  final String ownerId;
  final List<EnterpriseMember> members;
  final bool defaultsCreated;
  final DateTime createdAt;
  final DateTime updatedAt;

  Enterprise({
    required this.id,
    required this.name,
    this.description,
    this.phone,
    this.email,
    this.website,
    this.taxId,
    this.rcNumber,
    this.address,
    this.rib,
    required this.ownerId,
    this.members = const [],
    this.defaultsCreated = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'phone': phone,
        'email': email,
        'website': website,
        'tax_id': taxId,
        'rc_number': rcNumber,
        'address': address,
        'rib': rib,
        'owner_id': ownerId,
        'members': members.map((m) => m.toMap()).toList(),
        'defaults_created': defaultsCreated,
        'defaultsCreated': defaultsCreated,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Enterprise.fromMap(Map<String, dynamic> map, {String? id}) {
    List<EnterpriseMember> parsedMembers = [];
    if (map['members'] != null && map['members'] is List) {
      parsedMembers = (map['members'] as List)
          .map((m) => EnterpriseMember.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    return Enterprise(
      id: id ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      website: map['website']?.toString(),
      taxId: map['tax_id']?.toString() ?? map['taxId']?.toString(),
      rcNumber: map['rc_number']?.toString() ?? map['rcNumber']?.toString(),
      address: map['address']?.toString(),
      rib: map['rib']?.toString(),
      ownerId: map['owner_id']?.toString() ?? map['ownerId']?.toString() ?? map['userId']?.toString() ?? '',
      members: parsedMembers,
      defaultsCreated: map['defaults_created'] == true ||
          map['defaults_created'] == 1 ||
          map['defaults_created'] == 'true' ||
          map['defaultsCreated'] == true ||
          map['defaultsCreated'] == 1 ||
          map['defaultsCreated'] == 'true',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : (map['updatedAt'] != null
              ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Enterprise copyWith({
    String? id,
    String? name,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? taxId,
    String? rcNumber,
    String? address,
    String? rib,
    String? ownerId,
    List<EnterpriseMember>? members,
    bool? defaultsCreated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Enterprise(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        website: website ?? this.website,
        taxId: taxId ?? this.taxId,
        rcNumber: rcNumber ?? this.rcNumber,
        address: address ?? this.address,
        rib: rib ?? this.rib,
        ownerId: ownerId ?? this.ownerId,
        members: members ?? this.members,
        defaultsCreated: defaultsCreated ?? this.defaultsCreated,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Convenience: SQLite-friendly map (no nested members list)
  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'name': name,
        'description': description,
        'phone': phone,
        'email': email,
        'website': website,
        'tax_id': taxId,
        'rc_number': rcNumber,
        'address': address,
        'rib': rib,
        'owner_id': ownerId,
        'defaults_created': defaultsCreated ? 1 : 0,
        'defaultsCreated': defaultsCreated,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Enterprise &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          phone == other.phone &&
          email == other.email &&
          website == other.website &&
          taxId == other.taxId &&
          rcNumber == other.rcNumber &&
          address == other.address &&
          rib == other.rib &&
          ownerId == other.ownerId &&
          defaultsCreated == other.defaultsCreated &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      phone.hashCode ^
      email.hashCode ^
      website.hashCode ^
      taxId.hashCode ^
      rcNumber.hashCode ^
      address.hashCode ^
      rib.hashCode ^
      ownerId.hashCode ^
      defaultsCreated.hashCode ^
      updatedAt.hashCode;
}

class EnterpriseMember {
  final String uid;
  final String role; // 'admin' or 'member'

  EnterpriseMember({
    required this.uid,
    this.role = 'member',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role,
      };

  factory EnterpriseMember.fromMap(Map<String, dynamic> map) =>
      EnterpriseMember(
        uid: map['uid']?.toString() ?? '',
        role: map['role']?.toString() ?? 'member',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnterpriseMember &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          role == other.role;

  @override
  int get hashCode => uid.hashCode ^ role.hashCode;
}
