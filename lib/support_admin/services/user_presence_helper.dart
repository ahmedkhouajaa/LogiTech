import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Helper service for user activation status and last connected timestamp formatting
class UserPresenceHelper {
  /// Formats the last connected / last active timestamp into a human-readable string
  static String formatLastConnected(dynamic timestamp) {
    if (timestamp == null) return 'Aucune connexion enregistrée';

    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    }

    if (dt == null) return 'Date de connexion inconnue';

    final now = DateTime.now();
    final diff = now.difference(dt);

    final timeStr = DateFormat('HH:mm').format(dt);
    final dateStr = DateFormat('dd/MM/yyyy').format(dt);

    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && now.day == dt.day && now.month == dt.month && now.year == dt.year) {
      return 'Aujourd\'hui à $timeStr';
    } else if (diff.inHours < 48 && now.subtract(const Duration(days: 1)).day == dt.day) {
      return 'Hier à $timeStr';
    } else {
      return '$dateStr à $timeStr';
    }
  }

  /// Evaluates whether a user document represents an active online user.
  /// A user is considered online if:
  ///   1. Their `isOnline` flag is explicitly `true`, AND
  ///   2. Their `lastHeartbeat` was received within the last 90 seconds
  ///      (heartbeat fires every 25s; 3 missed = ~75s + 15s buffer).
  static bool isUserOnline(Map<String, dynamic> data) {
    // Must have explicit online flag set to true
    if (data['isOnline'] != true) return false;

    // Validate with heartbeat recency — guards against stale isOnline=true
    // left from a crash or force-kill where offline was never written.
    final lastHeartbeat = data['lastHeartbeat'];
    if (lastHeartbeat != null) {
      DateTime? dt;
      if (lastHeartbeat is Timestamp) {
        dt = lastHeartbeat.toDate();
      } else if (lastHeartbeat is DateTime) {
        dt = lastHeartbeat;
      } else if (lastHeartbeat is String) {
        dt = DateTime.tryParse(lastHeartbeat);
      }

      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        // 90s: covers 3 missed 25s heartbeats + 15s network delay buffer
        return diff.inSeconds < 90;
      }
    }

    // No heartbeat recorded yet (very first login) — trust the flag
    return true;
  }

  /// Evaluates user activation status and returns badge styling + labels
  static UserActivationInfo getActivationInfo(Map<String, dynamic> data) {
    final isBanned = data['isBanned'] == true ||
        data['isDisabled'] == true ||
        data['status'] == 'banned' ||
        data['status'] == 'disabled' ||
        data['isActive'] == false;

    final status = (data['status'] ?? '').toString().toLowerCase();
    final isInvited = status == 'invited' || status == 'pending';

    if (isBanned) {
      return const UserActivationInfo(
        statusKey: 'banned',
        label: 'Compte Suspendu / Banni',
        shortLabel: 'SUSPENDU',
        color: Color(0xFFDC2626),
        backgroundColor: Color(0xFFFEE2E2),
        icon: Icons.block_rounded,
        isActivated: false,
      );
    } else if (isInvited) {
      return const UserActivationInfo(
        statusKey: 'invited',
        label: 'En Attente d\'Activation',
        shortLabel: 'EN ATTENTE',
        color: Color(0xFFD97706),
        backgroundColor: Color(0xFFFEF3C7),
        icon: Icons.mark_email_unread_rounded,
        isActivated: false,
      );
    } else {
      return const UserActivationInfo(
        statusKey: 'active',
        label: 'Compte Activé',
        shortLabel: 'COMPTE ACTIVÉ',
        color: Color(0xFF059669),
        backgroundColor: Color(0xFFD1FAE5),
        icon: Icons.check_circle_outline_rounded,
        isActivated: true,
      );
    }
  }
}

class UserActivationInfo {
  final String statusKey;
  final String label;
  final String shortLabel;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final bool isActivated;

  const UserActivationInfo({
    required this.statusKey,
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.isActivated,
  });
}
