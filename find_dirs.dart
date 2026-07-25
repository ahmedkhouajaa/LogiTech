import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  print('App Doc Dir: ${appDocDir.path}');
  final appSupportDir = await getApplicationSupportDirectory();
  print('App Support Dir: ${appSupportDir.path}');
  final tempDir = await getTemporaryDirectory();
  print('Temp Dir: ${tempDir.path}');
}
