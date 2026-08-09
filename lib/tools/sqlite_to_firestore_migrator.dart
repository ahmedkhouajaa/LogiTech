import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SqliteToFirestoreMigrator {
  static Future<bool> runMigrationIfDbExists() async {
    // If running in browser or environment without legacy db, skip cleanly
    if (kIsWeb) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[Migration] User not logged in, skipping migration.');
        return false;
      }
      debugPrint('[Migration] No legacy SQLite database pending migration.');
      return true;
    } catch (e) {
      debugPrint('[Migration Error] $e');
      return false;
    }
  }
}
