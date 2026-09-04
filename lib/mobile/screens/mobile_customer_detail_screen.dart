import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../screens/customer_detail_screen.dart';

/// Mobile adapter for CustomerDetailScreen
class MobileCustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const MobileCustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return CustomerDetailScreen(customer: customer);
  }
}
