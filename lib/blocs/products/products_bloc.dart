import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../services/firestore_pagination_service.dart';

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
  }

  Future<void> _onLoad(LoadProducts event, Emitter<ProductsState> emit) async {
    emit(ProductsLoading());
    try {
      final products = await DatabaseHelper.instance.getProducts();
      final lowStock = await DatabaseHelper.instance.getLowStockProducts();
      emit(ProductsLoaded(
        products,
        lowStock,
        totalCount: products.length,
        hasMore: false,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
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
