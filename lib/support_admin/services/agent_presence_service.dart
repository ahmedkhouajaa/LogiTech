import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Real-time agent presence and heartbeat tracking service
class AgentPresenceService {
  static final AgentPresenceService instance = AgentPresenceService._();
  AgentPresenceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _heartbeatTimer;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  /// Starts a 30-second heartbeat to maintain online status
  void startPresenceHeartbeat() {
    _heartbeatTimer?.cancel();
    _updatePresence(true);

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updatePresence(true);
    });
  }

  /// Stops heartbeat and flags offline
  void stopPresence() {
    _heartbeatTimer?.cancel();
    _updatePresence(false);
  }

  Future<void> _updatePresence(bool isOnline) async {
    if (_uid.isEmpty) return;

    try {
      await _firestore.collection('support_agents_presence').doc(_uid).set({
        'agentId': _uid,
        'email': _email,
        'isOnline': isOnline,
        'lastHeartbeat': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AgentPresenceService] Error updating presence: $e');
    }
  }

  /// Stream of all active online support agents
  Stream<List<Map<String, dynamic>>> getActiveAgentsStream() {
    return _firestore
        .collection('support_agents_presence')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }
}
