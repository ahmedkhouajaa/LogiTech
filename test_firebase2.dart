import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('retenue_source_vente').limit(1).get();
  print("DEBUG FIREBASE COLLECTION: retenue_source_vente docs count = ${snapshot.docs.length}");
  
  final snapshot2 = await FirebaseFirestore.instance.collection('payments').where('method', isEqualTo: 'retenue_source').where('direction', isEqualTo: 'encaissement').limit(1).get();
  print("DEBUG FIREBASE COLLECTION: payments (retenue ventes) docs count = ${snapshot2.docs.length}");
}
