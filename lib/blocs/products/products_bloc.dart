import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/product.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../database/database_helper.dart';
import 'package:business_manager_pro/services/error_handler.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();
  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductsEvent {}

class LoadFirstProducts extends ProductsEvent {
  final String? searchQuery;
  final String stockFilter;
  final int pageSize;

  const LoadFirstProducts({
    this.searchQuery,
    this.stockFilter = 'Tous',
    this.pageSize = 10,
  });

  @override
  List<Object?> get props => [searchQuery, stockFilter, pageSize];
}

class LoadNextProducts extends ProductsEvent {
  final String? searchQuery;
  final String stockFilter;
  final int pageSize;

  const LoadNextProducts({
    this.searchQuery,
    this.stockFilter = 'Tous',
    this.pageSize = 10,
  });

  @override
  List<Object?> get props => [searchQuery, stockFilter, pageSize];
}

class ResetProductsPagination extends ProductsEvent {
  final String? searchQuery;
  final String stockFilter;

  const ResetProductsPagination({this.searchQuery, this.stockFilter = 'Tous'});

  @override
  List<Object?> get props => [searchQuery, stockFilter];
}

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

class BulkDeleteProducts extends ProductsEvent {
  final List<String> ids;
  const BulkDeleteProducts(this.ids);
  @override
  List<Object?> get props => [ids];
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
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String activeStockFilter;
  final String searchQuery;

  const ProductsLoaded(
    this.products,
    this.lowStockProducts, {
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.activeStockFilter = 'Tous',
    this.searchQuery = '',
  });

  ProductsLoaded copyWith({
    List<Product>? products,
    List<Product>? lowStockProducts,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? activeStockFilter,
    String? searchQuery,
  }) {
    return ProductsLoaded(
      products ?? this.products,
      lowStockProducts ?? this.lowStockProducts,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activeStockFilter: activeStockFilter ?? this.activeStockFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        products,
        lowStockProducts,
        totalCount,
        hasMore,
        isLoadingMore,
        activeStockFilter,
        searchQuery,
      ];
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
    on<LoadFirstProducts>(_onLoadFirst);
    on<LoadNextProducts>(_onLoadNext);
    on<ResetProductsPagination>(_onResetPagination);
    on<AddProduct>(_onAdd);
    on<UpdateProduct>(_onUpdate);
    on<DeleteProduct>(_onDelete);
    on<BulkDeleteProducts>(_onBulkDelete);
  }

  Future<void> _onLoad(LoadProducts event, Emitter<ProductsState> emit) async {
    add(const LoadFirstProducts());
  }

  Future<void> _onLoadFirst(
    LoadFirstProducts event,
    Emitter<ProductsState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      final count = await FirestorePaginationService.instance.getProductsCount(
        searchQuery: event.searchQuery,
        stockFilter: event.stockFilter,
      );

      final items = await FirestorePaginationService.instance.getFirstProducts(
        pageSize: event.pageSize,
        searchQuery: event.searchQuery,
        stockFilter: event.stockFilter,
      );

      final lowStock = items.where((p) => p.isLowStock).toList();

      emit(ProductsLoaded(
        items,
        lowStock,
        totalCount: count,
        hasMore: items.length == event.pageSize,
        isLoadingMore: false,
        activeStockFilter: event.stockFilter,
        searchQuery: event.searchQuery ?? '',
      ));
    } catch (e) {
      emit(const ProductsError("Erreur lors du chargement des articles"));
    }
  }

  Future<void> _onLoadNext(
    LoadNextProducts event,
    Emitter<ProductsState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProductsLoaded && currentState.hasMore && !currentState.isLoadingMore) {
      emit(currentState.copyWith(isLoadingMore: true));
      try {
        final newItems = await FirestorePaginationService.instance.getNextProducts(
          pageSize: event.pageSize,
          searchQuery: event.searchQuery,
          stockFilter: event.stockFilter,
        );

        final updatedList = [...currentState.products, ...newItems];

        emit(currentState.copyWith(
          products: updatedList,
          hasMore: newItems.length == event.pageSize,
          isLoadingMore: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> _onResetPagination(
    ResetProductsPagination event,
    Emitter<ProductsState> emit,
  ) async {
    FirestorePaginationService.instance.resetProductsPagination();
    add(LoadFirstProducts(
      searchQuery: event.searchQuery,
      stockFilter: event.stockFilter,
    ));
  }

  Future<void> _onAdd(AddProduct event, Emitter<ProductsState> emit) async {
    if (!PermissionService.instance.canCreate(UserPermissionResources.productsList)) {
      emit(const ProductsError('Permission refusée : Vous n\'avez pas le droit d\'ajouter un article.'));
      return;
    }
    try {
      await FirestoreRepository.instance.saveProduct(event.product);
      add(const LoadFirstProducts());
    } catch (e) {
      emit(ProductsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(UpdateProduct event, Emitter<ProductsState> emit) async {
    if (!PermissionService.instance.canUpdate(UserPermissionResources.productsList)) {
      emit(const ProductsError('Permission refusée : Vous n\'avez pas le droit de modifier un article.'));
      return;
    }
    try {
      await FirestoreRepository.instance.saveProduct(event.product);
      add(const LoadFirstProducts());
    } catch (e) {
      emit(ProductsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(DeleteProduct event, Emitter<ProductsState> emit) async {
    if (!PermissionService.instance.canDelete(UserPermissionResources.productsList)) {
      emit(const ProductsError('Permission refusée : Vous n\'avez pas le droit de supprimer un article.'));
      return;
    }

    // 1. Optimistically remove from state immediately
    final currentState = state;
    if (currentState is ProductsLoaded) {
      final updatedProducts = currentState.products.where((p) => p.id != event.id).toList();
      final newCount = (currentState.totalCount > 0 ? currentState.totalCount - 1 : updatedProducts.length);
      emit(ProductsLoaded(
        updatedProducts,
        currentState.lowStockProducts.where((p) => p.id != event.id).toList(),
        totalCount: newCount,
        hasMore: currentState.hasMore,
        isLoadingMore: currentState.isLoadingMore,
        activeStockFilter: currentState.activeStockFilter,
        searchQuery: currentState.searchQuery,
      ));
    }

    if (event.id.trim().isNotEmpty) {
      try {
        await FirestoreRepository.instance.deleteDocument('articles', event.id);
        await DatabaseHelper.instance.deleteProduct(event.id);
      } catch (e) {
        print("Error deleting product in Firestore: $e");
      }
    }
  }

  Future<void> _onBulkDelete(BulkDeleteProducts event, Emitter<ProductsState> emit) async {
    if (!PermissionService.instance.canDelete(UserPermissionResources.productsList)) {
      emit(const ProductsError('Permission refusée : Vous n\'avez pas le droit de supprimer des articles.'));
      return;
    }

    final idsSet = event.ids.where((id) => id.trim().isNotEmpty).toSet();

    // 1. Optimistically remove from state immediately
    final currentState = state;
    if (currentState is ProductsLoaded) {
      final updatedProducts = currentState.products.where((p) => !idsSet.contains(p.id)).toList();
      final newCount = (currentState.totalCount >= event.ids.length ? currentState.totalCount - event.ids.length : updatedProducts.length);
      emit(ProductsLoaded(
        updatedProducts,
        currentState.lowStockProducts.where((p) => !idsSet.contains(p.id)).toList(),
        totalCount: newCount,
        hasMore: currentState.hasMore,
        isLoadingMore: currentState.isLoadingMore,
        activeStockFilter: currentState.activeStockFilter,
        searchQuery: currentState.searchQuery,
      ));
    }

    try {
      final validIds = event.ids.where((id) => id.trim().isNotEmpty).toList();
      if (validIds.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in validIds) {
          batch.delete(FirebaseFirestore.instance.collection('articles').doc(id));
        }
        await batch.commit();

        for (final id in validIds) {
          await DatabaseHelper.instance.deleteProduct(id);
        }
      }
    } catch (e) {
      print("Error in bulk deleting products: $e");
    }
  }
}
