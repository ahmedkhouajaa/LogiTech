import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/products/products_bloc.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import 'create_article_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header & Action Bar
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Text('Articles', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz_rounded, size: 16),
                label: const Text('Actions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _navigateToCreate(context, null),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, référence ou descr',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
              )
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Data Table
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoading) return const Center(child: CircularProgressIndicator());
              if (state is ProductsError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is ProductsLoaded) {
                final filtered = _search.isEmpty ? state.products
                    : state.products.where((p) => 
                        p.name.toLowerCase().contains(_search) || 
                        p.code.toLowerCase().contains(_search) || 
                        (p.reference?.toLowerCase().contains(_search) ?? false)
                      ).toList();
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Product>(
                      columns: const ['Nom', 'Prix de Vente', 'Prix d\'Achat', 'Type'],
                      rows: filtered,
                      emptyMessage: 'Aucun article trouvé',
                      cellBuilder: (p) {
                        final tvaMultiplier = 1 + (p.tvaRate / 100);
                        final sellTtc = p.sellingPrice * tvaMultiplier;
                        final purchTtc = p.purchasePrice * tvaMultiplier;
                        
                        return [
                          DataCell(Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  if (p.reference?.isNotEmpty == true)
                                    Text(p.reference!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          )),
                          DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TTC: ${formatCurrency(sellTtc)}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                              Text('HT: ${formatCurrency(p.sellingPrice)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          )),
                          DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TTC: ${formatCurrency(purchTtc)}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                              Text('HT: ${formatCurrency(p.purchasePrice)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              p.productType.capitalize(),
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)
                            ),
                          )),
                        ];
                      },
                      onEdit: (p) => _navigateToCreate(context, p),
                      onDelete: (p) => context.read<ProductsBloc>().add(DeleteProduct(p.id)),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _navigateToCreate(BuildContext context, Product? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProductsBloc>(),
          child: CreateArticleScreen(existing: existing),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
