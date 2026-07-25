import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager_pro/firebase_options.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('==== DIRECTORIES ====');
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    print('App Doc Dir: \${appDocDir.path}');
  } catch(e) { print('Doc Dir Error'); }

  try {
    final appSupportDir = await getApplicationSupportDirectory();
    print('App Support Dir: \${appSupportDir.path}');
  } catch(e) { print('Support Dir Error'); }

  try {
    final tempDir = await getTemporaryDirectory();
    print('Temp Dir: \${tempDir.path}');
  } catch(e) { print('Temp Dir Error'); }

  print('==== TESTING FIRESTORE STREAM ====');
  try {
    final snapshot = await FirebaseFirestore.instance.collection('suppliers').limit(1).snapshots().first;
    print('SUCCESS! Got \${snapshot.docs.length} docs.');
  } catch (e, stack) {
    print('ERROR: \$e');
    print(stack);
  }
  print('==== END ====');
  exit(0);
}
