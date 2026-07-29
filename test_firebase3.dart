import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('payments')
    .where('method', isEqualTo: 'retenue_source')
    .where('direction', isEqualTo: 'encaissement')
    .limit(1).get();
    
  if (snapshot.docs.isNotEmpty) {
    print("DEBUG DOC: ${snapshot.docs.first.data()}");
  } else {
    print("DEBUG DOC: NO DOCUMENTS FOUND");
  }
}
