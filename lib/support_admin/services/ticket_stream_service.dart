import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The 6 Ticket Drawer Menu Filter options
enum TicketMenuFilter {
  queue,        // 1. File d'attente -> No filter (shows all tickets)
  myTickets,    // 2. Mes Tickets -> where assignedAgentId == currentAgentUid
  urgent,       // 3. Tickets Urgents -> where priority in ['urgent', 'high']
  unassigned,   // 4. Non Assignés -> where assignedAgentId == null
  escalated,    // 5. Tickets Escaladés -> where status == 'escalated'
  all,          // 6. Tous les Tickets -> No filter (same as File d'attente)
}

/// Real-time ticket query & management service for Support Agents & SuperAdmin
class TicketStreamService {
  static final TicketStreamService instance = TicketStreamService._();
  TicketStreamService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get currentAgentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get currentAgentEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  /// Stream of filtered tickets in real-time (Cloud-first, zero local SQLite cache)
  Stream<List<Map<String, dynamic>>> getFilteredTicketsStream({
    TicketMenuFilter menuFilter = TicketMenuFilter.queue,
    String status = 'all',
    String priority = 'all',
    bool onlyMyTickets = false,
    String searchQuery = '',
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('support_tickets');

    // Server-side query optimization where supported
    if (menuFilter == TicketMenuFilter.myTickets || onlyMyTickets) {
      if (currentAgentUid.isNotEmpty) {
        query = query.where('assignedAgentId', isEqualTo: currentAgentUid);
      }
    } else if (menuFilter == TicketMenuFilter.escalated) {
      query = query.where('status', isEqualTo: 'escalated');
    }

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // 1. Apply Menu filter logic
      switch (menuFilter) {
        case TicketMenuFilter.queue:
        case TicketMenuFilter.all:
          // No filter (shows all tickets)
          break;
        case TicketMenuFilter.myTickets:
          // where assignedAgentId == currentAgentUid
          if (currentAgentUid.isNotEmpty) {
            list = list.where((t) => t['assignedAgentId'] == currentAgentUid).toList();
          }
          break;
        case TicketMenuFilter.urgent:
          // where priority in ['urgent', 'high']
          list = list.where((t) {
            final p = (t['priority'] ?? '').toString().toLowerCase();
            return p == 'urgent' || p == 'high';
          }).toList();
          break;
        case TicketMenuFilter.unassigned:
          // where assignedAgentId == null (or empty/omitted)
          list = list.where((t) {
            final a = t['assignedAgentId'];
            return a == null || a.toString().trim().isEmpty;
          }).toList();
          break;
        case TicketMenuFilter.escalated:
          // where status == 'escalated'
          list = list.where((t) => (t['status'] ?? '').toString().toLowerCase() == 'escalated').toList();
          break;
      }

      // 2. Local interactive dashboard filters (Status pill & Priority dropdown)
      if (status != 'all') {
        list = list.where((t) => (t['status'] ?? '').toString().toLowerCase() == status.toLowerCase()).toList();
      }
      if (priority != 'all') {
        list = list.where((t) => (t['priority'] ?? '').toString().toLowerCase() == priority.toLowerCase()).toList();
      }
      if (onlyMyTickets && currentAgentUid.isNotEmpty) {
        list = list.where((t) => t['assignedAgentId'] == currentAgentUid).toList();
      }

      // 3. Client-side search filtering
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        list = list.where((t) {
          final subject = (t['subject'] ?? '').toString().toLowerCase();
          final user = (t['userName'] ?? '').toString().toLowerCase();
          final email = (t['userEmail'] ?? '').toString().toLowerCase();
          final enterprise = (t['enterpriseName'] ?? '').toString().toLowerCase();
          final id = (t['id'] ?? '').toString().toLowerCase();
          return subject.contains(q) || user.contains(q) || email.contains(q) || enterprise.contains(q) || id.contains(q);
        }).toList();
      }

      // 4. Sort by latest update descending
      list.sort((a, b) {
        final aDate = (a['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      return list;
    }).handleError((error) {
      debugPrint('[TicketStreamService] Stream error: $error');
      return <Map<String, dynamic>>[];
    });
  }

  /// Paginated fetch for large ticket volumes
  Future<List<Map<String, dynamic>>> fetchTicketsPage({
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('support_tickets')
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snap = await query.get();
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Assign ticket to an agent
  Future<void> assignTicket({
    required String ticketId,
    required String agentUid,
    required String agentEmail,
  }) async {
    final batch = _firestore.batch();
    final ticketRef = _firestore.collection('support_tickets').doc(ticketId);

    batch.update(ticketRef, {
      'assignedAgentId': agentUid,
      'assignedAgentEmail': agentEmail,
      'status': 'in_progress',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write audit log
    final auditRef = _firestore.collection('audit_logs').doc();
    batch.set(auditRef, {
      'agentId': currentAgentUid,
      'agentEmail': currentAgentEmail,
      'action': 'ASSIGN_TICKET',
      'targetTicketId': ticketId,
      'assignedTo': agentEmail,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Update ticket status with optional resolution note
  Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
    String? resolutionNote,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'resolved' || status == 'closed') {
      data['resolvedAt'] = FieldValue.serverTimestamp();
      data['resolvedBy'] = currentAgentEmail;
      if (resolutionNote != null && resolutionNote.isNotEmpty) {
        data['resolutionNote'] = resolutionNote;
      }
    }

    await _firestore.collection('support_tickets').doc(ticketId).update(data);
  }
}
