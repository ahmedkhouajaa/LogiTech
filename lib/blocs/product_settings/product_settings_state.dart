import 'package:equatable/equatable.dart';
import '../../models/product_family.dart';
import '../../models/product_category.dart';

abstract class ProductSettingsState extends Equatable {
  const ProductSettingsState();

  @override
  List<Object?> get props => [];
}

class ProductSettingsInitial extends ProductSettingsState {}

class ProductSettingsLoading extends ProductSettingsState {}

class ProductSettingsLoaded extends ProductSettingsState {
  final List<ProductFamily> families;
  final List<ProductCategory> categories;
  final List<ProductBrand> brands;
  final DateTime timestamp;

  // Computed property to get only root families (no parentId)
  List<ProductFamily> get rootFamilies => families.where((f) => f.parentId == null).toList();

  ProductSettingsLoaded({
    required this.families,
    this.categories = const [],
    this.brands = const [],
  }) : timestamp = DateTime.now();

  List<ProductFamily> getSubFamilies(String familyId) {
    return families.where((f) => f.parentId == familyId).toList();
  }

  List<ProductBrand> getBrandsForCategory(String categoryNameOrId) {
    return brands.where((b) => b.categoryId == categoryNameOrId).toList();
  }

  @override
  List<Object> get props => [timestamp, families.length, categories.length, brands.length];
}

class ProductSettingsError extends ProductSettingsState {
  final String message;
  const ProductSettingsError(this.message);

  @override
  List<Object> get props => [message];
}
