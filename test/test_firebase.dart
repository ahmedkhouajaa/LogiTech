import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager_pro/firebase_options.dart';

void main() {
  test('Check payments collection', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final snapshot = await FirebaseFirestore.instance.collection('payments').get();
    print('DEBUG_PAYMENTS_COUNT: ${snapshot.docs.length}');
    for (var doc in snapshot.docs) {
      print('DOC: ${doc.data()}');
    }
  });
}
