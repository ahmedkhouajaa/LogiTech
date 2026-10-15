class CrmEmailTemplate {
  final String id;
  final String enterpriseId;
  final String name;
  final String subject;
  final String body;
  final List<String> availableVariables;
  final DateTime createdAt;

  CrmEmailTemplate({
    required this.id,
    required this.enterpriseId,
    required this.name,
    required this.subject,
    required this.body,
    this.availableVariables = const ['{client}', '{titre}', '{montant}', '{commercial}', '{entreprise}'],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CrmEmailTemplate copyWith({
    String? id,
    String? enterpriseId,
    String? name,
    String? subject,
    String? body,
    List<String>? availableVariables,
    DateTime? createdAt,
  }) {
    return CrmEmailTemplate(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      availableVariables: availableVariables ?? this.availableVariables,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Replaces {variable} tokens with concrete opportunity/customer data
  String formatBody({
    required String clientName,
    required String opportunityTitle,
    required String expectedAmount,
    required String ownerName,
    required String enterpriseName,
  }) {
    return body
        .replaceAll('{client}', clientName)
        .replaceAll('{titre}', opportunityTitle)
        .replaceAll('{montant}', expectedAmount)
        .replaceAll('{commercial}', ownerName)
        .replaceAll('{entreprise}', enterpriseName);
  }

  String formatSubject({
    required String clientName,
    required String opportunityTitle,
    required String enterpriseName,
  }) {
    return subject
        .replaceAll('{client}', clientName)
        .replaceAll('{titre}', opportunityTitle)
        .replaceAll('{entreprise}', enterpriseName);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'name': name,
      'subject': subject,
      'body': body,
      'availableVariables': availableVariables,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CrmEmailTemplate.fromMap(Map<String, dynamic> map) {
    return CrmEmailTemplate(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      name: map['name'] ?? '',
      subject: map['subject'] ?? '',
      body: map['body'] ?? '',
      availableVariables: map['availableVariables'] is List
          ? List<String>.from(map['availableVariables'].map((e) => e.toString()))
          : const ['{client}', '{titre}', '{montant}', '{commercial}', '{entreprise}'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static List<CrmEmailTemplate> defaultTemplates(String enterpriseId) {
    return [
      CrmEmailTemplate(
        id: 'tpl_1',
        enterpriseId: enterpriseId,
        name: 'Prise de contact / Découverte',
        subject: 'Échange concernant votre projet - {entreprise}',
        body: 'Bonjour {client},\n\n'
            'Je fais suite à nos récents échanges concernant votre projet "{titre}".\n\n'
            'Je serais ravi de planifier un court appel de 15 minutes afin de faire le point sur vos priorités et vous présenter nos solutions adaptées.\n\n'
            'Quelles seraient vos disponibilités cette semaine ?\n\n'
            'Bien cordialement,\n{commercial}\n{entreprise}',
      ),
      CrmEmailTemplate(
        id: 'tpl_2',
        enterpriseId: enterpriseId,
        name: 'Envoi et suivi de proposition',
        subject: 'Notre proposition commerciale pour {titre} - {entreprise}',
        body: 'Bonjour {client},\n\n'
            'Veuillez trouver ci-joint notre proposition commerciale d\'un montant de {montant} concernant le projet "{titre}".\n\n'
            'Nous restons à votre entière disposition pour tout renseignement complémentaire ou ajustement.\n\n'
            'Dans l\'attente de votre retour,\n\n'
            'Excellente journée,\n{commercial}\n{entreprise}',
      ),
      CrmEmailTemplate(
        id: 'tpl_3',
        enterpriseId: enterpriseId,
        name: 'Relance commerciale bienveillante',
        subject: 'Des nouvelles concernant votre projet "{titre}" ?',
        body: 'Bonjour {client},\n\n'
            'Je me permets de revenir vers vous concernant notre proposition transmise récemment.\n\n'
            'Avez-vous eu l\'occasion d\'en prendre connaissance ou auriez-vous des questions particulières ?\n\n'
            'Je reste à votre disposition pour en discuter de vive voix.\n\n'
            'Bien à vous,\n{commercial}\n{entreprise}',
      ),
    ];
  }
}

class CrmEmailLog {
  final String id;
  final String enterpriseId;
  final String? opportunityId;
  final String? opportunityTitle;
  final String? customerId;
  final String customerName;
  final String toEmail;
  final String subject;
  final String body;
  final String? templateId;
  final String status; // 'sent', 'draft', 'failed'
  final DateTime sentAt;

  CrmEmailLog({
    required this.id,
    required this.enterpriseId,
    this.opportunityId,
    this.opportunityTitle,
    this.customerId,
    required this.customerName,
    required this.toEmail,
    required this.subject,
    required this.body,
    this.templateId,
    this.status = 'sent',
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'opportunityId': opportunityId,
      'opportunityTitle': opportunityTitle,
      'customerId': customerId,
      'customerName': customerName,
      'toEmail': toEmail,
      'subject': subject,
      'body': body,
      'templateId': templateId,
      'status': status,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  factory CrmEmailLog.fromMap(Map<String, dynamic> map) {
    return CrmEmailLog(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      opportunityId: map['opportunityId'],
      opportunityTitle: map['opportunityTitle'],
      customerId: map['customerId'],
      customerName: map['customerName'] ?? '',
      toEmail: map['toEmail'] ?? '',
      subject: map['subject'] ?? '',
      body: map['body'] ?? '',
      templateId: map['templateId'],
      status: map['status'] ?? 'sent',
      sentAt: map['sentAt'] != null
          ? DateTime.tryParse(map['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
