import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/product.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();
  @override
  List<Object?> get props => [];
}
class LoadProducts extends ProductsEvent {}
class AddProduct extends ProductsEvent {
  final Product product;
  const AddProduct(this.product);
  @override
  List<Object?> get props => [product];
}
class UpdateProduct extends ProductsEvent {
  final Product product;
  const UpdateProduct(this.product);
  @override
  List<Object?> get props => [product];
}
class DeleteProduct extends ProductsEvent {
  final String id;
  const DeleteProduct(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class ProductsState extends Equatable {
  const ProductsState();
  @override
  List<Object?> get props => [];
}
class ProductsInitial extends ProductsState {}
class ProductsLoading extends ProductsState {}
class ProductsLoaded extends ProductsState {
  final List<Product> products;
  final List<Product> lowStockProducts;
  const ProductsLoaded(this.products, this.lowStockProducts);
  @override
  List<Object?> get props => [products, lowStockProducts];
}
class ProductsError extends ProductsState {
  final String message;
  const ProductsError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc() : super(ProductsInitial()) {
    on<LoadProducts>(_onLoad);
    on<AddProduct>(_onAdd);
    on<UpdateProduct>(_onUpdate);
    on<DeleteProduct>(_onDelete);
  }

  Future<void> _onLoad(LoadProducts event, Emitter<ProductsState> emit) async {
    emit(ProductsLoading());
    try {
      final products = await DatabaseHelper.instance.getProducts();
      final lowStock = await DatabaseHelper.instance.getLowStockProducts();
      emit(ProductsLoaded(products, lowStock));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  Future<void> _onAdd(AddProduct event, Emitter<ProductsState> emit) async {
    try {
      await DatabaseHelper.instance.insertProduct(event.product);
      add(LoadProducts());
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateProduct event, Emitter<ProductsState> emit) async {
    try {
      await DatabaseHelper.instance.updateProduct(event.product);
      add(LoadProducts());
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteProduct event, Emitter<ProductsState> emit) async {
    try {
      await DatabaseHelper.instance.deleteProduct(event.id);
      add(LoadProducts());
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}
