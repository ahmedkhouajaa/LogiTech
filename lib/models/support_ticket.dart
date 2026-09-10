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
  final String? imageUrl;
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
    this.imageUrl,
    this.status = 'sent',
    required this.createdAt,
  });

  SupportMessage copyWith({
    String? id,
    String? ticketId,
    String? senderId,
    String? senderName,
    String? senderInitial,
    bool? isFromUser,
    String? text,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderInitial: senderInitial ?? this.senderInitial,
      isFromUser: isFromUser ?? this.isFromUser,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SupportMessage.fromMap(Map<String, dynamic> map, String docId) {
    // Robustly determine if sender is user or support:
    // If isFromSupport is true or isFromUser is false, it's from support.
    final bool isSupport = map['isFromSupport'] == true || map['isFromUser'] == false;
    final bool isUser = !isSupport;

    final String text = (map['text'] ?? map['content'] ?? '').toString();
    final String senderName = (map['senderName'] ?? '').toString();
    final String? imageUrl = (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty)
        ? map['imageUrl'].toString()
        : null;

    String initial = (map['senderInitial'] ?? '').toString().trim();
    if (initial.isEmpty) {
      if (senderName.isNotEmpty) {
        initial = senderName[0].toUpperCase();
      } else {
        initial = isUser ? 'U' : 'S';
      }
    }

    return SupportMessage(
      id: docId,
      ticketId: (map['ticketId'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      senderName: senderName.isNotEmpty ? senderName : (isUser ? 'Client' : 'Support LogiTech'),
      senderInitial: initial,
      isFromUser: isUser,
      text: text,
      imageUrl: imageUrl,
      status: (map['status'] ?? 'sent').toString(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'ticketId': ticketId,
      'senderId': senderId,
      'senderName': senderName,
      'senderInitial': senderInitial,
      'isFromUser': isFromUser,
      'isFromSupport': !isFromUser,
      'text': text,
      'content': text.isNotEmpty ? text : (imageUrl != null ? '📷 Image jointe' : ''),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      map['imageUrl'] = imageUrl;
    }
    return map;
  }
}
