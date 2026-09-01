import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String enterpriseId;
  final String subject;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.enterpriseId,
    required this.subject,
    this.status = 'open',
    this.lastMessage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map, String docId) {
    return SupportTicket(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      subject: map['subject'] ?? 'Sans sujet',
      status: map['status'] ?? 'open',
      lastMessage: map['lastMessage'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'enterpriseId': enterpriseId,
      'subject': subject,
      'status': status,
      'lastMessage': lastMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolu';
      case 'closed':
        return 'Fermé';
      case 'open':
      default:
        return 'Ouvert';
    }
  }
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String senderInitial;
  final bool isFromUser;
  final String text;
  final String status; // 'sent', 'read'
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.senderInitial,
    required this.isFromUser,
    required this.text,
    this.status = 'sent',
    required this.createdAt,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map, String docId) {
    return SupportMessage(
      id: docId,
      ticketId: map['ticketId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderInitial: map['senderInitial'] ?? 'U',
      isFromUser: map['isFromUser'] ?? true,
      text: map['text'] ?? '',
      status: map['status'] ?? 'sent',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'senderId': senderId,
      'senderName': senderName,
      'senderInitial': senderInitial,
      'isFromUser': isFromUser,
      'text': text,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
