import 'package:equatable/equatable.dart';
import '../../models/product_family.dart';

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

class DeleteSubFamily extends ProductSettingsEvent {
  final String id;
  const DeleteSubFamily(this.id);

  @override
  List<Object> get props => [id];
}
