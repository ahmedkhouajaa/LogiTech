import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/support_ticket.dart';
import '../services/enterprise_service.dart';
import '../services/permission_service.dart';

/// Service to handle Support Tickets & Chat messaging with Cloud Firestore sync
class SupportService {
  static final SupportService instance = SupportService._();
  SupportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local fallback storage for offline use or quick UI updates
  final List<SupportTicket> _localTickets = [];
  final Map<String, List<SupportMessage>> _localMessages = {};

  /// Get current user ID
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

  /// Get current user name
  String get _currentUserName => PermissionService.instance.userName;

  /// Get current user email
  String get _currentUserEmail => PermissionService.instance.userEmail;

  /// Get current user initial (e.g. 'H', 'A', etc.)
  String get _currentUserInitial => PermissionService.instance.userInitial;

  /// Get current enterprise ID
  String get _currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId ?? '';

  /// Stream of user tickets
  Stream<List<SupportTicket>> getTicketsStream() {
    try {
      final uid = _currentUserId;

      return _firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) => SupportTicket.fromMap(doc.data(), doc.id)).toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        // Sync local cache
        _localTickets.clear();
        _localTickets.addAll(list);
        return list;
      }).handleError((error) {
        debugPrint('[SupportService] Error streaming tickets: $error');
        return _localTickets;
      });
    } catch (e) {
      debugPrint('[SupportService] Stream error fallback: $e');
      return Stream.value(_localTickets);
    }
  }

  final Map<String, StreamController<List<SupportMessage>>> _messageControllers = {};

  /// Stream of chat messages for a specific ticket
  Stream<List<SupportMessage>> getMessagesStream(String ticketId) {
    if (!_messageControllers.containsKey(ticketId) || _messageControllers[ticketId]!.isClosed) {
      _messageControllers[ticketId] = StreamController<List<SupportMessage>>.broadcast();

      _firestore
          .collection('support_tickets')
          .doc(ticketId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .listen(
        (snapshot) {
          final list = snapshot.docs.map((doc) => SupportMessage.fromMap(doc.data(), doc.id)).toList();
          _localMessages[ticketId] = list;
          if (_messageControllers.containsKey(ticketId) && !_messageControllers[ticketId]!.isClosed) {
            _messageControllers[ticketId]!.add(List.from(list));
          }
        },
        onError: (error) {
          debugPrint('[SupportService] Error streaming messages: $error');
          if (_messageControllers.containsKey(ticketId) && !_messageControllers[ticketId]!.isClosed) {
            _messageControllers[ticketId]!.add(List.from(_localMessages[ticketId] ?? []));
          }
        },
      );
    }

    // Instantly push cached local messages
    Future.microtask(() {
      if (_messageControllers.containsKey(ticketId) && !_messageControllers[ticketId]!.isClosed) {
        _messageControllers[ticketId]!.add(List.from(_localMessages[ticketId] ?? []));
      }
    });

    return _messageControllers[ticketId]!.stream;
  }

  /// Create a new support ticket and send initial message
  Future<SupportTicket> createTicket({
    required String subject,
    required String initialMessage,
  }) async {
    final now = DateTime.now();
    final docRef = _firestore.collection('support_tickets').doc();

    final ticket = SupportTicket(
      id: docRef.id,
      userId: _currentUserId,
      userName: _currentUserName,
      userEmail: _currentUserEmail,
      enterpriseId: _currentEnterpriseId,
      subject: subject,
      status: 'open',
      lastMessage: initialMessage,
      createdAt: now,
      updatedAt: now,
    );

    final message = SupportMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ticketId: docRef.id,
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderInitial: _currentUserInitial,
      isFromUser: true,
      text: initialMessage,
      status: 'sent',
      createdAt: now,
    );

    // Save to local cache & notify stream immediately
    _localTickets.insert(0, ticket);
    _localMessages[docRef.id] = [message];
    if (_messageControllers.containsKey(docRef.id) && !_messageControllers[docRef.id]!.isClosed) {
      _messageControllers[docRef.id]!.add([message]);
    }

    // Save to Firestore
    try {
      await docRef.set(ticket.toMap());
      await docRef.collection('messages').doc(message.id).set(message.toMap());
    } catch (e) {
      debugPrint('[SupportService] Firestore createTicket error: $e');
    }

    // Simulate automated read status transition
    _scheduleAutomatedReadStatus(docRef.id, message.id);

    return ticket;
  }

  /// Send a new message inside a ticket chat
  Future<void> sendMessage({
    required String ticketId,
    required String text,
  }) async {
    final now = DateTime.now();
    final msgId = now.millisecondsSinceEpoch.toString();

    final message = SupportMessage(
      id: msgId,
      ticketId: ticketId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderInitial: _currentUserInitial,
      isFromUser: true,
      text: text,
      status: 'sent', // Initially sent (empty circle badge)
      createdAt: now,
    );

    // Add to local cache & push to stream immediately
    final list = _localMessages[ticketId] ?? [];
    list.add(message);
    _localMessages[ticketId] = list;

    if (_messageControllers.containsKey(ticketId) && !_messageControllers[ticketId]!.isClosed) {
      _messageControllers[ticketId]!.add(List.from(list));
    }

    // Save to Firestore
    try {
      final ticketRef = _firestore.collection('support_tickets').doc(ticketId);
      await ticketRef.collection('messages').doc(msgId).set(message.toMap());
      await ticketRef.update({
        'lastMessage': text,
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      debugPrint('[SupportService] Firestore sendMessage error: $e');
    }

    // Simulate status update from 'sent' -> 'read' (checkmark in circle badge)
    _scheduleAutomatedReadStatus(ticketId, msgId);
  }

  /// Simulate status transition from 'sent' to 'read' for demonstration/real-time feel
  void _scheduleAutomatedReadStatus(String ticketId, String messageId) {
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final msgRef = _firestore
            .collection('support_tickets')
            .doc(ticketId)
            .collection('messages')
            .doc(messageId);
        await msgRef.update({'status': 'read'});
      } catch (_) {}

      // Update local memory if present
      final list = _localMessages[ticketId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final old = list[idx];
          list[idx] = SupportMessage(
            id: old.id,
            ticketId: old.ticketId,
            senderId: old.senderId,
            senderName: old.senderName,
            senderInitial: old.senderInitial,
            isFromUser: old.isFromUser,
            text: old.text,
            status: 'read',
            createdAt: old.createdAt,
          );
          if (_messageControllers.containsKey(ticketId) && !_messageControllers[ticketId]!.isClosed) {
            _messageControllers[ticketId]!.add(List.from(list));
          }
        }
      }
    });
  }
}
