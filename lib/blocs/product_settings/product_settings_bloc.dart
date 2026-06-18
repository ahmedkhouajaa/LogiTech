import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import 'product_settings_event.dart';
import 'product_settings_state.dart';

class ProductSettingsBloc extends Bloc<ProductSettingsEvent, ProductSettingsState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  ProductSettingsBloc() : super(ProductSettingsInitial()) {
    on<LoadFamilies>(_onLoadFamilies);
    on<AddFamily>(_onAddFamily);
    on<UpdateFamily>(_onUpdateFamily);
    on<DeleteFamily>(_onDeleteFamily);
    on<AddSubFamily>(_onAddSubFamily);
    on<DeleteSubFamily>(_onDeleteSubFamily);
  }

  Future<void> _onLoadFamilies(LoadFamilies event, Emitter<ProductSettingsState> emit) async {
    emit(ProductSettingsLoading());
    try {
      final families = await _dbHelper.getProductFamilies();
      emit(ProductSettingsLoaded(families: families));
    } catch (e) {
      emit(ProductSettingsError(e.toString()));
    }
  }

  Future<void> _onAddFamily(AddFamily event, Emitter<ProductSettingsState> emit) async {
    try {
      await _dbHelper.insertProductFamily(event.family);
      add(LoadFamilies());
    } catch (e) {
      emit(ProductSettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateFamily(UpdateFamily event, Emitter<ProductSettingsState> emit) async {
    try {
      await _dbHelper.updateProductFamily(event.family);
      add(LoadFamilies());
    } catch (e) {
      emit(ProductSettingsError(e.toString()));
    }
  }

  Future<void> _onDeleteFamily(DeleteFamily event, Emitter<ProductSettingsState> emit) async {
    try {
      await _dbHelper.deleteProductFamily(event.id);
      add(LoadFamilies());
    } catch (e) {
      emit(ProductSettingsError(e.toString()));
    }
  }

  Future<void> _onAddSubFamily(AddSubFamily event, Emitter<ProductSettingsState> emit) async {
    try {
      await _dbHelper.insertProductFamily(event.subFamily);
      add(LoadFamilies());
    } catch (e) {
      emit(ProductSettingsError(e.toString()));
    }
  }

  Future<void> _onDeleteSubFamily(DeleteSubFamily event, Emitter<ProductSettingsState> emit) async {
    try {
      await _dbHelper.deleteProductFamily(event.id);
      add(LoadFamilies());
    } catch (e) {
      emit(ProductSettingsError(e.toString()));
    }
  }
}
