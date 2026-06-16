import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class QuoteItemWidget extends StatelessWidget {
  final QuoteItem item;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const QuoteItemWidget({
    Key? key,
    required this.item,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(item.productName ?? '-')),
        Expanded(flex: 2, child: Text(item.quantity.toString())),
        Expanded(flex: 2, child: Text(formatCurrency(item.unitPrice))),
        Expanded(flex: 2, child: Text('\${item.tvaRate}%')),
        Expanded(flex: 2, child: Text(formatCurrency(item.computedTotalHT))),
        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete, size: 18, color: AppColors.error), onPressed: onDelete),
      ],
    );
  }
}
