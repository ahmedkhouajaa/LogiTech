import 'dart:convert';

class EmployeeChild {
  final String id;
  final String name;
  final DateTime? birthDate;
  final bool isDependent; // En charge
  final bool isDisabled; // Estropié / Handicapé
  final bool isStudent; // Étudiant
  final bool hasScholarship; // Bourse

  EmployeeChild({
    required this.id,
    required this.name,
    this.birthDate,
    this.isDependent = true,
    this.isDisabled = false,
    this.isStudent = false,
    this.hasScholarship = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'birth_date': birthDate?.toIso8601String(),
        'is_dependent': isDependent,
        'is_disabled': isDisabled,
        'is_student': isStudent,
        'has_scholarship': hasScholarship,
      };

  factory EmployeeChild.fromMap(Map<String, dynamic> map) => EmployeeChild(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        birthDate: DateTime.tryParse(map['birth_date']?.toString() ?? ''),
        isDependent: map['is_dependent'] == true || map['is_dependent'] == 1,
        isDisabled: map['is_disabled'] == true || map['is_disabled'] == 1,
        isStudent: map['is_student'] == true || map['is_student'] == 1,
        hasScholarship: map['has_scholarship'] == true || map['has_scholarship'] == 1,
      );

  EmployeeChild copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    bool? isDependent,
    bool? isDisabled,
    bool? isStudent,
    bool? hasScholarship,
  }) =>
      EmployeeChild(
        id: id ?? this.id,
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        isDependent: isDependent ?? this.isDependent,
        isDisabled: isDisabled ?? this.isDisabled,
        isStudent: isStudent ?? this.isStudent,
        hasScholarship: hasScholarship ?? this.hasScholarship,
      );
}

class Employee {
  final String id;
  final String code; // e.g., EMP-001 / Matricule
  final String firstName;
  final String lastName;
  final String? photoUrl;

  // Professional Contact
  final String? phone; // Téléphone fixe ou pro
  final String? workPhone; // Téléphone pro
  final String? workMobile; // Téléphone portable pro
  final String? email; // Email pro
  final String? workEmail; // Email pro alias
  final String department; // Direction, Commercial, Technique, Finance, RH, Production, Logistique, Administration
  final String jobTitle; // Poste / Fonction
  final String? manager; // Responsable / Manager
  final String? mentor; // Tuteur / Mentor
  final List<String> tags; // Étiquettes
  final DateTime hireDate;
  final String contractType; // CDI, CDD, SIVP, Stage, Freelance
  final double baseSalary;
  final String paymentMethod; // Virement bancaire, Chèque, Espèces
  final String? rib; // Compte bancaire

  // Private Info & Family
  final String? maritalStatus; // Célibataire, Marié(e), Divorcé(e), Veuf/Veuve, Autre
  final bool isHeadOfFamily; // Chef de Famille
  final String? spouseName; // Nom complet du conjoint
  final DateTime? spouseBirthDate; // Date de naissance du conjoint
  final String? spouseJob; // Profession du conjoint / des parents
  final int childrenCount; // Nombre d'enfants total ou en charge
  final List<EmployeeChild> children; // Liste détaillée des enfants

  // Private Address & Contact
  final String? address; // Rue
  final String? privateAddressStreet2; // Rue 2
  final String? city; // Ville
  final String? privateAddressState; // Région / Gouvernorat
  final String? privateAddressZip; // Code postal
  final String? privateAddressCountry; // Pays
  final String? personalEmail; // Email privé
  final String? personalPhone; // Téléphone privé
  final String? preferredLanguage; // Langue
  final double? homeWorkDistanceKm; // Distance Domicile-Travail
  final String? carPlate; // Plaque d'immatriculation du véhicule

  // Citizenship & Identification
  final String? nationality; // Nationalité (pays)
  final String? cin; // Carte d'Identité Nationale
  final String? cnssNumber; // Numéro CNSS
  final String? employerCode; // Numéro chez l'employeur
  final String? socialSecurityNumber; // Numéro de sécurité sociale
  final String? passportNumber; // N° de passeport
  final String? gender; // Homme, Femme, Autre
  final DateTime? birthDate; // Date de naissance
  final String? birthPlace; // Lieu de naissance
  final String? birthCountry; // Pays de naissance
  final String? visaType; // Type de visa
  final DateTime? workPermitExpiration; // Expiration permis de travail
  final String? workPermitNumber; // Permis de travail

  // Emergency & Education
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? educationLevel; // Niveau d'études / Diplôme
  final String? fieldOfStudy; // Spécialité
  final List<String> skills; // Compétences

  final bool isActive;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Employee({
    required this.id,
    required this.code,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.phone,
    this.workPhone,
    this.workMobile,
    this.email,
    this.workEmail,
    this.department = 'Général',
    this.jobTitle = 'Employé',
    this.manager,
    this.mentor,
    this.tags = const [],
    DateTime? hireDate,
    this.contractType = 'CDI',
    this.baseSalary = 0.0,
    this.paymentMethod = 'Virement bancaire',
    this.rib,
    this.maritalStatus = 'Célibataire',
    this.isHeadOfFamily = false,
    this.spouseName,
    this.spouseBirthDate,
    this.spouseJob,
    this.childrenCount = 0,
    this.children = const [],
    this.address,
    this.privateAddressStreet2,
    this.city,
    this.privateAddressState,
    this.privateAddressZip,
    this.privateAddressCountry = 'Tunisie',
    this.personalEmail,
    this.personalPhone,
    this.preferredLanguage = 'Français',
    this.homeWorkDistanceKm,
    this.carPlate,
    this.nationality = 'Tunisienne',
    this.cin,
    this.cnssNumber,
    this.employerCode,
    this.socialSecurityNumber,
    this.passportNumber,
    this.gender = 'Homme',
    this.birthDate,
    this.birthPlace,
    this.birthCountry = 'Tunisie',
    this.visaType,
    this.workPermitExpiration,
    this.workPermitNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.educationLevel,
    this.fieldOfStudy,
    this.skills = const [],
    this.isActive = true,
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : hireDate = hireDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName'.trim();

  int get dependentChildrenCount =>
      children.isNotEmpty ? children.where((c) => c.isDependent).length : childrenCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'first_name': firstName,
        'last_name': lastName,
        'photo_url': photoUrl,
        'phone': phone ?? workPhone,
        'work_phone': workPhone ?? phone,
        'work_mobile': workMobile,
        'email': email ?? workEmail,
        'work_email': workEmail ?? email,
        'department': department,
        'job_title': jobTitle,
        'manager': manager,
        'mentor': mentor,
        'tags': tags,
        'hire_date': hireDate.toIso8601String(),
        'contract_type': contractType,
        'base_salary': baseSalary,
        'payment_method': paymentMethod,
        'rib': rib,
        'marital_status': maritalStatus,
        'is_head_of_family': isHeadOfFamily,
        'spouse_name': spouseName,
        'spouse_birth_date': spouseBirthDate?.toIso8601String(),
        'spouse_job': spouseJob,
        'children_count': childrenCount,
        'children': children.map((c) => c.toMap()).toList(),
        'address': address,
        'private_address_street2': privateAddressStreet2,
        'city': city,
        'private_address_state': privateAddressState,
        'private_address_zip': privateAddressZip,
        'private_address_country': privateAddressCountry,
        'personal_email': personalEmail,
        'personal_phone': personalPhone,
        'preferred_language': preferredLanguage,
        'home_work_distance_km': homeWorkDistanceKm,
        'car_plate': carPlate,
        'nationality': nationality,
        'cin': cin,
        'cnss_number': cnssNumber,
        'employer_code': employerCode,
        'social_security_number': socialSecurityNumber,
        'passport_number': passportNumber,
        'gender': gender,
        'birth_date': birthDate?.toIso8601String(),
        'birth_place': birthPlace,
        'birth_country': birthCountry,
        'visa_type': visaType,
        'work_permit_expiration': workPermitExpiration?.toIso8601String(),
        'work_permit_number': workPermitNumber,
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
        'education_level': educationLevel,
        'field_of_study': fieldOfStudy,
        'skills': skills,
        'is_active': isActive ? 1 : 0,
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Employee.fromMap(Map<String, dynamic> map) {
    List<EmployeeChild> parsedChildren = [];
    if (map['children'] is List) {
      parsedChildren = (map['children'] as List)
          .whereType<Map>()
          .map((m) => EmployeeChild.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } else if (map['children'] is String && (map['children'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['children'] as String);
        if (decoded is List) {
          parsedChildren = decoded
              .whereType<Map>()
              .map((m) => EmployeeChild.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}
    }

    List<String> parsedTags = [];
    if (map['tags'] is List) {
      parsedTags = (map['tags'] as List).map((t) => t.toString()).toList();
    }

    List<String> parsedSkills = [];
    if (map['skills'] is List) {
      parsedSkills = (map['skills'] as List).map((s) => s.toString()).toList();
    }

    return Employee(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? (map['firstName']?.toString() ?? ''),
      lastName: map['last_name']?.toString() ?? (map['lastName']?.toString() ?? ''),
      photoUrl: map['photo_url']?.toString() ?? map['photoUrl']?.toString(),
      phone: map['phone']?.toString(),
      workPhone: map['work_phone']?.toString() ?? map['phone']?.toString(),
      workMobile: map['work_mobile']?.toString(),
      email: map['email']?.toString(),
      workEmail: map['work_email']?.toString() ?? map['email']?.toString(),
      department: map['department']?.toString() ?? 'Général',
      jobTitle: (map['job_title'] ?? map['jobTitle'])?.toString() ?? 'Employé',
      manager: map['manager']?.toString(),
      mentor: map['mentor']?.toString(),
      tags: parsedTags,
      hireDate: DateTime.tryParse(map['hire_date']?.toString() ?? '') ?? DateTime.now(),
      contractType: (map['contract_type'] ?? map['contractType'])?.toString() ?? 'CDI',
      baseSalary: (map['base_salary'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (map['payment_method'] ?? map['paymentMethod'])?.toString() ?? 'Virement bancaire',
      rib: map['rib']?.toString(),
      maritalStatus: (map['marital_status'] ?? map['maritalStatus'])?.toString() ?? 'Célibataire',
      isHeadOfFamily: map['is_head_of_family'] == true || map['is_head_of_family'] == 1,
      spouseName: map['spouse_name']?.toString(),
      spouseBirthDate: DateTime.tryParse(map['spouse_birth_date']?.toString() ?? ''),
      spouseJob: map['spouse_job']?.toString(),
      childrenCount: (map['children_count'] as num?)?.toInt() ?? parsedChildren.length,
      children: parsedChildren,
      address: map['address']?.toString(),
      privateAddressStreet2: map['private_address_street2']?.toString(),
      city: map['city']?.toString(),
      privateAddressState: map['private_address_state']?.toString(),
      privateAddressZip: map['private_address_zip']?.toString(),
      privateAddressCountry: map['private_address_country']?.toString() ?? 'Tunisie',
      personalEmail: map['personal_email']?.toString(),
      personalPhone: map['personal_phone']?.toString(),
      preferredLanguage: map['preferred_language']?.toString() ?? 'Français',
      homeWorkDistanceKm: (map['home_work_distance_km'] as num?)?.toDouble(),
      carPlate: map['car_plate']?.toString(),
      nationality: map['nationality']?.toString() ?? 'Tunisienne',
      cin: map['cin']?.toString(),
      cnssNumber: (map['cnss_number'] ?? map['cnssNumber'])?.toString(),
      employerCode: map['employer_code']?.toString(),
      socialSecurityNumber: map['social_security_number']?.toString(),
      passportNumber: map['passport_number']?.toString(),
      gender: map['gender']?.toString() ?? 'Homme',
      birthDate: DateTime.tryParse(map['birth_date']?.toString() ?? ''),
      birthPlace: map['birth_place']?.toString(),
      birthCountry: map['birth_country']?.toString() ?? 'Tunisie',
      visaType: map['visa_type']?.toString(),
      workPermitExpiration: DateTime.tryParse(map['work_permit_expiration']?.toString() ?? ''),
      workPermitNumber: map['work_permit_number']?.toString(),
      emergencyContactName: map['emergency_contact_name']?.toString(),
      emergencyContactPhone: map['emergency_contact_phone']?.toString(),
      educationLevel: map['education_level']?.toString(),
      fieldOfStudy: map['field_of_study']?.toString(),
      skills: parsedSkills,
      isActive: map['is_active'] == 1 || map['is_active'] == true || map['isActive'] == true || map['isActive'] == 1 || map['is_active'] == null,
      notes: map['notes']?.toString(),
      enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == true,
    );
  }

  Employee copyWith({
    String? id,
    String? code,
    String? firstName,
    String? lastName,
    String? photoUrl,
    String? phone,
    String? workPhone,
    String? workMobile,
    String? email,
    String? workEmail,
    String? department,
    String? jobTitle,
    String? manager,
    String? mentor,
    List<String>? tags,
    DateTime? hireDate,
    String? contractType,
    double? baseSalary,
    String? paymentMethod,
    String? rib,
    String? maritalStatus,
    bool? isHeadOfFamily,
    String? spouseName,
    DateTime? spouseBirthDate,
    String? spouseJob,
    int? childrenCount,
    List<EmployeeChild>? children,
    String? address,
    String? privateAddressStreet2,
    String? city,
    String? privateAddressState,
    String? privateAddressZip,
    String? privateAddressCountry,
    String? personalEmail,
    String? personalPhone,
    String? preferredLanguage,
    double? homeWorkDistanceKm,
    String? carPlate,
    String? nationality,
    String? cin,
    String? cnssNumber,
    String? employerCode,
    String? socialSecurityNumber,
    String? passportNumber,
    String? gender,
    DateTime? birthDate,
    String? birthPlace,
    String? birthCountry,
    String? visaType,
    DateTime? workPermitExpiration,
    String? workPermitNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? educationLevel,
    String? fieldOfStudy,
    List<String>? skills,
    bool? isActive,
    String? notes,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      Employee(
        id: id ?? this.id,
        code: code ?? this.code,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        photoUrl: photoUrl ?? this.photoUrl,
        phone: phone ?? this.phone,
        workPhone: workPhone ?? this.workPhone,
        workMobile: workMobile ?? this.workMobile,
        email: email ?? this.email,
        workEmail: workEmail ?? this.workEmail,
        department: department ?? this.department,
        jobTitle: jobTitle ?? this.jobTitle,
        manager: manager ?? this.manager,
        mentor: mentor ?? this.mentor,
        tags: tags ?? this.tags,
        hireDate: hireDate ?? this.hireDate,
        contractType: contractType ?? this.contractType,
        baseSalary: baseSalary ?? this.baseSalary,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        rib: rib ?? this.rib,
        maritalStatus: maritalStatus ?? this.maritalStatus,
        isHeadOfFamily: isHeadOfFamily ?? this.isHeadOfFamily,
        spouseName: spouseName ?? this.spouseName,
        spouseBirthDate: spouseBirthDate ?? this.spouseBirthDate,
        spouseJob: spouseJob ?? this.spouseJob,
        childrenCount: childrenCount ?? this.childrenCount,
        children: children ?? this.children,
        address: address ?? this.address,
        privateAddressStreet2: privateAddressStreet2 ?? this.privateAddressStreet2,
        city: city ?? this.city,
        privateAddressState: privateAddressState ?? this.privateAddressState,
        privateAddressZip: privateAddressZip ?? this.privateAddressZip,
        privateAddressCountry: privateAddressCountry ?? this.privateAddressCountry,
        personalEmail: personalEmail ?? this.personalEmail,
        personalPhone: personalPhone ?? this.personalPhone,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        homeWorkDistanceKm: homeWorkDistanceKm ?? this.homeWorkDistanceKm,
        carPlate: carPlate ?? this.carPlate,
        nationality: nationality ?? this.nationality,
        cin: cin ?? this.cin,
        cnssNumber: cnssNumber ?? this.cnssNumber,
        employerCode: employerCode ?? this.employerCode,
        socialSecurityNumber: socialSecurityNumber ?? this.socialSecurityNumber,
        passportNumber: passportNumber ?? this.passportNumber,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        birthPlace: birthPlace ?? this.birthPlace,
        birthCountry: birthCountry ?? this.birthCountry,
        visaType: visaType ?? this.visaType,
        workPermitExpiration: workPermitExpiration ?? this.workPermitExpiration,
        workPermitNumber: workPermitNumber ?? this.workPermitNumber,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
        educationLevel: educationLevel ?? this.educationLevel,
        fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
        skills: skills ?? this.skills,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
