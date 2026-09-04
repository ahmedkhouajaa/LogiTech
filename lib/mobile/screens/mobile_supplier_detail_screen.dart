import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../screens/supplier_detail_screen.dart';

/// Mobile adapter for SupplierDetailScreen
class MobileSupplierDetailScreen extends StatelessWidget {
  final Supplier supplier;

  const MobileSupplierDetailScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return SupplierDetailScreen(supplier: supplier);
  }
}
