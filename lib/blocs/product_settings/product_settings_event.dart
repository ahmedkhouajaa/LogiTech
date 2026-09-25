import 'package:equatable/equatable.dart';
import '../../models/product_family.dart';
import '../../models/product_category.dart';

abstract class ProductSettingsEvent extends Equatable {
  const ProductSettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadFamilies extends ProductSettingsEvent {}

class AddFamily extends ProductSettingsEvent {
  final ProductFamily family;
  const AddFamily(this.family);

  @override
  List<Object> get props => [family];
}

class UpdateFamily extends ProductSettingsEvent {
  final ProductFamily family;
  const UpdateFamily(this.family);

  @override
  List<Object> get props => [family];
}

class DeleteFamily extends ProductSettingsEvent {
  final String id;
  const DeleteFamily(this.id);

  @override
  List<Object> get props => [id];
}

class AddSubFamily extends ProductSettingsEvent {
  final ProductFamily subFamily;
  const AddSubFamily(this.subFamily);

  @override
  List<Object> get props => [subFamily];
}

class UpdateSubFamily extends ProductSettingsEvent {
  final ProductFamily subFamily;
  const UpdateSubFamily(this.subFamily);

  @override
  List<Object> get props => [subFamily];
}

class DeleteSubFamily extends ProductSettingsEvent {
  final String id;
  const DeleteSubFamily(this.id);

  @override
  List<Object> get props => [id];
}

class AddCategory extends ProductSettingsEvent {
  final ProductCategory category;
  const AddCategory(this.category);

  @override
  List<Object> get props => [category];
}

class UpdateCategory extends ProductSettingsEvent {
  final ProductCategory category;
  final String? oldName;
  const UpdateCategory(this.category, {this.oldName});

  @override
  List<Object?> get props => [category, oldName];
}

class DeleteCategory extends ProductSettingsEvent {
  final String id;
  const DeleteCategory(this.id);

  @override
  List<Object> get props => [id];
}

class AddBrand extends ProductSettingsEvent {
  final ProductBrand brand;
  const AddBrand(this.brand);

  @override
  List<Object> get props => [brand];
}

class UpdateBrand extends ProductSettingsEvent {
  final ProductBrand brand;
  const UpdateBrand(this.brand);

  @override
  List<Object> get props => [brand];
}

class DeleteBrand extends ProductSettingsEvent {
  final String id;
  const DeleteBrand(this.id);

  @override
  List<Object> get props => [id];
}
