import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_family.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import 'product_settings_event.dart';
import 'product_settings_state.dart';

class ProductSettingsBloc extends Bloc<ProductSettingsEvent, ProductSettingsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<ProductFamily> _families = [];

  ProductSettingsBloc() : super(ProductSettingsInitial()) {
    on<LoadFamilies>(_onLoadFamilies);
    on<AddFamily>(_onAddFamily);
    on<UpdateFamily>(_onUpdateFamily);
    on<DeleteFamily>(_onDeleteFamily);
    on<AddSubFamily>(_onAddSubFamily);
    on<DeleteSubFamily>(_onDeleteSubFamily);
  }

  Future<void> _onLoadFamilies(LoadFamilies event, Emitter<ProductSettingsState> emit) async {
    if (_families.isEmpty && state is! ProductSettingsLoaded) {
      emit(ProductSettingsLoading());
    }
    try {
      final snap = await _firestore.collection('product_families').get();
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      
      final remoteFamilies = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return ProductFamily.fromMap(data);
      }).where((f) {
        final docSnap = snap.docs.firstWhere((d) => d.id == f.id);
        final map = docSnap.data();
        final entId = map['enterprise_id'] ?? map['enterpriseId'];
        if (currentEntId != null && currentEntId.isNotEmpty && entId != null) {
          return entId == currentEntId;
        }
        return true;
      }).toList();
      
      for (var rf in remoteFamilies) {
        if (!_families.any((f) => f.id == rf.id)) {
          _families.add(rf);
        }
      }
      
      _families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      emit(ProductSettingsLoaded(families: List.from(_families)));
    } catch (e) {
      print("Error loading product families: $e");
      emit(ProductSettingsLoaded(families: List.from(_families)));
    }
  }

  Future<void> _onAddFamily(AddFamily event, Emitter<ProductSettingsState> emit) async {
    print("DEBUG BLOC: _onAddFamily called for '${event.family.name}'");
    if (!_families.any((f) => f.id == event.family.id)) {
      _families.add(event.family);
    }
    print("DEBUG BLOC: emitting ProductSettingsLoaded with ${_families.length} families");
    emit(ProductSettingsLoaded(families: List.from(_families)));

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.family.id, event.family.toMap());
      print("DEBUG BLOC: saved to Firestore successfully");
    } catch (e) {
      print("Error adding family to Firestore: $e");
    }
  }

  Future<void> _onUpdateFamily(UpdateFamily event, Emitter<ProductSettingsState> emit) async {
    final index = _families.indexWhere((f) => f.id == event.family.id);
    if (index != -1) {
      _families[index] = event.family;
    }
    emit(ProductSettingsLoaded(families: List.from(_families)));

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.family.id, event.family.toMap());
    } catch (e) {
      print("Error updating family in Firestore: $e");
    }
  }

  Future<void> _onDeleteFamily(DeleteFamily event, Emitter<ProductSettingsState> emit) async {
    _families.removeWhere((f) => f.id == event.id || f.parentId == event.id);
    emit(ProductSettingsLoaded(families: List.from(_families)));

    try {
      await _firestore.collection('product_families').doc(event.id).delete();
      final subSnap = await _firestore.collection('product_families').where('parent_id', isEqualTo: event.id).get();
      for (var doc in subSnap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print("Error deleting family from Firestore: $e");
    }
  }

  Future<void> _onAddSubFamily(AddSubFamily event, Emitter<ProductSettingsState> emit) async {
    if (!_families.any((f) => f.id == event.subFamily.id)) {
      _families.add(event.subFamily);
    }
    emit(ProductSettingsLoaded(families: List.from(_families)));

    try {
      await FirestoreRepository.instance.saveDocument('product_families', event.subFamily.id, event.subFamily.toMap());
    } catch (e) {
      print("Error adding sub-family to Firestore: $e");
    }
  }

  Future<void> _onDeleteSubFamily(DeleteSubFamily event, Emitter<ProductSettingsState> emit) async {
    _families.removeWhere((f) => f.id == event.id);
    emit(ProductSettingsLoaded(families: List.from(_families)));

    try {
      await _firestore.collection('product_families').doc(event.id).delete();
    } catch (e) {
      print("Error deleting sub-family from Firestore: $e");
    }
  }
}
