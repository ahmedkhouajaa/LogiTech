import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../screens/article_detail_screen.dart';

/// Mobile adapter for ArticleDetailScreen
class MobileProductDetailScreen extends StatelessWidget {
  final Product product;

  const MobileProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return ArticleDetailScreen(product: product);
  }
}
