import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_family.dart';
import '../../models/product_category.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import 'product_settings_event.dart';
import 'product_settings_state.dart';

class ProductSettingsBloc extends Bloc<ProductSettingsEvent, ProductSettingsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<ProductFamily> _families = [];
  final List<ProductCategory> _categories = [];
  final List<ProductBrand> _brands = [];

  ProductSettingsBloc() : super(ProductSettingsInitial()) {
    on<LoadFamilies>(_onLoadFamilies);
    on<AddFamily>(_onAddFamily);
    on<UpdateFamily>(_onUpdateFamily);
    on<DeleteFamily>(_onDeleteFamily);
    on<AddSubFamily>(_onAddSubFamily);
    on<UpdateSubFamily>(_onUpdateSubFamily);
    on<DeleteSubFamily>(_onDeleteSubFamily);
    on<AddCategory>(_onAddCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<AddBrand>(_onAddBrand);
    on<UpdateBrand>(_onUpdateBrand);
    on<DeleteBrand>(_onDeleteBrand);
  }

  void _emitLoaded(Emitter<ProductSettingsState> emit) {
    emit(ProductSettingsLoaded(
      families: List.from(_families),
      categories: List.from(_categories),
      brands: List.from(_brands),
    ));
  }

  Future<void> _onLoadFamilies(LoadFamilies event, Emitter<ProductSettingsState> emit) async {
    if (_families.isEmpty && _categories.isEmpty && state is! ProductSettingsLoaded) {
      emit(ProductSettingsLoading());
    }
    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;

      // 1. Load Families
      final snapFamilies = await _firestore.collection('product_families').get();
      final remoteFamilies = snapFamilies.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return ProductFamily.fromMap(data);
      }).where((f) {
        final docSnap = snapFamilies.docs.firstWhere((d) => d.id == f.id);
        final map = docSnap.data();
        final isDel = map['is_deleted'] == 1 || map['is_deleted'] == true;
        if (isDel) return false;
        final entId = map['enterprise_id'] ?? map['enterpriseId'];
        if (currentEntId != null && currentEntId.isNotEmpty && entId != null) {
          return entId == currentEntId;
        }
        return true;
      }).toList();

      _families.clear();
      _families.addAll(remoteFamilies);
      _families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // 2. Load Categories
      try {
        final snapCats = await _firestore.collection('product_categories').get();
        final remoteCats = snapCats.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return ProductCategory.fromMap(data);
        }).where((c) {
          final docSnap = snapCats.docs.firstWhere((d) => d.id == c.id);
          final map = docSnap.data();
          final isDel = map['is_deleted'] == 1 || map['is_deleted'] == true;
          if (isDel) return false;
          final entId = map['enterprise_id'] ?? map['enterpriseId'];
          if (currentEntId != null && currentEntId.isNotEmpty && entId != null) {
            return entId == currentEntId;
          }
          return true;
        }).toList();

        _categories.clear();
        _categories.addAll(remoteCats);
      } catch (e) {
        print("Error fetching product_categories: $e");
      }

      // Seed default static categories if not yet present
      for (final catName in kDefaultCategories) {
        if (!_categories.any((c) => c.name.toLowerCase() == catName.toLowerCase())) {
          _categories.add(ProductCategory(
            id: 'cat_${catName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
            name: catName,
          ));
        }
      }
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // 3. Load Brands
      try {
        final snapBrands = await _firestore.collection('product_brands').get();
        final remoteBrands = snapBrands.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return ProductBrand.fromMap(data);
        }).where((b) {
          final docSnap = snapBrands.docs.firstWhere((d) => d.id == b.id);
          final map = docSnap.data();
          final isDel = map['is_deleted'] == 1 || map['is_deleted'] == true;
          if (isDel) return false;
          final entId = map['enterprise_id'] ?? map['enterpriseId'];
          if (currentEntId != null && currentEntId.isNotEmpty && entId != null) {
            return entId == currentEntId;
          }
          return true;
        }).toList();

        _brands.clear();
        _brands.addAll(remoteBrands);
      } catch (e) {
        print("Error fetching product_brands: $e");
      }

      // Seed default static brands per category
      kDefaultCategoryBrands.forEach((catName, brandList) {
        for (final bName in brandList) {
          if (!_brands.any((b) => b.categoryId?.toLowerCase() == catName.toLowerCase() && b.name.toLowerCase() == bName.toLowerCase())) {
            _brands.add(ProductBrand(
              id: 'brand_${catName.toLowerCase()}_${bName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
              name: bName,
              categoryId: catName,
            ));
          }
        }
      });
      _brands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _emitLoaded(emit);
    } catch (e) {
      print("Error loading product settings: $e");
      emit(ProductSettingsError(e.toString()));
    }
  }

  Future<void> _onAddFamily(AddFamily event, Emitter<ProductSettingsState> emit) async {
    if (!_families.any((f) => f.id == event.family.id)) {
      _families.add(event.family);
      _families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.family.id, event.family.toMap());
    } catch (e) {
      print("Error adding family to Firestore: $e");
    }
  }

  Future<void> _onUpdateFamily(UpdateFamily event, Emitter<ProductSettingsState> emit) async {
    final index = _families.indexWhere((f) => f.id == event.family.id);
    if (index != -1) {
      _families[index] = event.family;
      _families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.family.id, event.family.toMap());
    } catch (e) {
      print("Error updating family in Firestore: $e");
    }
  }

  Future<void> _onDeleteFamily(DeleteFamily event, Emitter<ProductSettingsState> emit) async {
    _families.removeWhere((f) => f.id == event.id || f.parentId == event.id);
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.softDeleteDocument('product_families', event.id);
      final subSnap = await _firestore.collection('product_families').where('parent_id', isEqualTo: event.id).get();
      for (var doc in subSnap.docs) {
        await FirestoreRepository.instance.softDeleteDocument('product_families', doc.id);
      }
    } catch (e) {
      print("Error deleting family from Firestore: $e");
    }
  }

  Future<void> _onAddSubFamily(AddSubFamily event, Emitter<ProductSettingsState> emit) async {
    if (!_families.any((f) => f.id == event.subFamily.id)) {
      _families.add(event.subFamily);
      _families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.subFamily.id, event.subFamily.toMap());
    } catch (e) {
      print("Error adding sub-family to Firestore: $e");
    }
  }

  Future<void> _onUpdateSubFamily(UpdateSubFamily event, Emitter<ProductSettingsState> emit) async {
    final index = _families.indexWhere((f) => f.id == event.subFamily.id);
    if (index != -1) {
      _families[index] = event.subFamily;
      _families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.subFamily.id, event.subFamily.toMap());
    } catch (e) {
      print("Error updating sub-family in Firestore: $e");
    }
  }

  Future<void> _onDeleteSubFamily(DeleteSubFamily event, Emitter<ProductSettingsState> emit) async {
    _families.removeWhere((f) => f.id == event.id);
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.softDeleteDocument('product_families', event.id);
    } catch (e) {
      print("Error deleting sub-family from Firestore: $e");
    }
  }

  Future<void> _onAddCategory(AddCategory event, Emitter<ProductSettingsState> emit) async {
    if (!_categories.any((c) => c.name.toLowerCase() == event.category.name.toLowerCase())) {
      _categories.add(event.category);
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_categories', event.category.id, event.category.toMap());
    } catch (e) {
      print("Error adding category to Firestore: $e");
    }
  }

  Future<void> _onUpdateCategory(UpdateCategory event, Emitter<ProductSettingsState> emit) async {
    final index = _categories.indexWhere((c) => c.id == event.category.id);
    final oldName = event.oldName ?? (index != -1 ? _categories[index].name : null);
    if (index != -1) {
      _categories[index] = event.category;
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      _categories.add(event.category);
    }

    if (oldName != null && oldName.toLowerCase() != event.category.name.toLowerCase()) {
      for (int i = 0; i < _brands.length; i++) {
        if (_brands[i].categoryId?.toLowerCase() == oldName.toLowerCase()) {
          final updatedBrand = ProductBrand(
            id: _brands[i].id,
            name: _brands[i].name,
            categoryId: event.category.name,
            createdAt: _brands[i].createdAt,
          );
          _brands[i] = updatedBrand;
          try {
            await FirestoreRepository.instance.saveDocument('product_brands', updatedBrand.id, updatedBrand.toMap());
          } catch (e) {
            print("Error updating brand category in Firestore: $e");
          }
        }
      }
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_categories', event.category.id, event.category.toMap());
    } catch (e) {
      print("Error updating category in Firestore: $e");
    }
  }

  Future<void> _onDeleteCategory(DeleteCategory event, Emitter<ProductSettingsState> emit) async {
    final cat = _categories.firstWhere((c) => c.id == event.id, orElse: () => ProductCategory(id: event.id, name: ''));
    _categories.removeWhere((c) => c.id == event.id);
    _brands.removeWhere((b) => b.categoryId == event.id || (cat.name.isNotEmpty && b.categoryId == cat.name));
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.softDeleteDocument('product_categories', event.id);
      final brandsSnap = await _firestore.collection('product_brands').where('category_id', isEqualTo: event.id).get();
      for (var doc in brandsSnap.docs) {
        await FirestoreRepository.instance.softDeleteDocument('product_brands', doc.id);
      }
      if (cat.name.isNotEmpty) {
        final brandsByNameSnap = await _firestore.collection('product_brands').where('category_id', isEqualTo: cat.name).get();
        for (var doc in brandsByNameSnap.docs) {
          await FirestoreRepository.instance.softDeleteDocument('product_brands', doc.id);
        }
      }
    } catch (e) {
      print("Error deleting category from Firestore: $e");
    }
  }

  Future<void> _onAddBrand(AddBrand event, Emitter<ProductSettingsState> emit) async {
    if (!_brands.any((b) => b.name.toLowerCase() == event.brand.name.toLowerCase() && b.categoryId == event.brand.categoryId)) {
      _brands.add(event.brand);
      _brands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_brands', event.brand.id, event.brand.toMap());
    } catch (e) {
      print("Error adding brand to Firestore: $e");
    }
  }

  Future<void> _onUpdateBrand(UpdateBrand event, Emitter<ProductSettingsState> emit) async {
    final index = _brands.indexWhere((b) => b.id == event.brand.id);
    if (index != -1) {
      _brands[index] = event.brand;
      _brands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      _brands.add(event.brand);
    }
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.saveDocument('product_brands', event.brand.id, event.brand.toMap());
    } catch (e) {
      print("Error updating brand in Firestore: $e");
    }
  }

  Future<void> _onDeleteBrand(DeleteBrand event, Emitter<ProductSettingsState> emit) async {
    _brands.removeWhere((b) => b.id == event.id);
    _emitLoaded(emit);

    try {
      await FirestoreRepository.instance.softDeleteDocument('product_brands', event.id);
    } catch (e) {
      print("Error deleting brand from Firestore: $e");
    }
  }
}
