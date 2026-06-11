import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/supplier.dart';

abstract class SuppliersEvent extends Equatable {
  const SuppliersEvent();
  @override
  List<Object?> get props => [];
}
class LoadSuppliers extends SuppliersEvent {}
class AddSupplier extends SuppliersEvent {
  final Supplier supplier;
  const AddSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}
class UpdateSupplier extends SuppliersEvent {
  final Supplier supplier;
  const UpdateSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}
class DeleteSupplier extends SuppliersEvent {
  final String id;
  const DeleteSupplier(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class SuppliersState extends Equatable {
  const SuppliersState();
  @override
  List<Object?> get props => [];
}
class SuppliersInitial extends SuppliersState {}
class SuppliersLoading extends SuppliersState {}
class SuppliersLoaded extends SuppliersState {
  final List<Supplier> suppliers;
  const SuppliersLoaded(this.suppliers);
  @override
  List<Object?> get props => [suppliers];
}
class SuppliersError extends SuppliersState {
  final String message;
  const SuppliersError(this.message);
  @override
  List<Object?> get props => [message];
}

class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  SuppliersBloc() : super(SuppliersInitial()) {
    on<LoadSuppliers>(_onLoad);
    on<AddSupplier>(_onAdd);
    on<UpdateSupplier>(_onUpdate);
    on<DeleteSupplier>(_onDelete);
  }

  Future<void> _onLoad(LoadSuppliers event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      final suppliers = await DatabaseHelper.instance.getSuppliers();
      emit(SuppliersLoaded(suppliers));
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onAdd(AddSupplier event, Emitter<SuppliersState> emit) async {
    try {
      await DatabaseHelper.instance.insertSupplier(event.supplier);
      add(LoadSuppliers());
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateSupplier event, Emitter<SuppliersState> emit) async {
    try {
      await DatabaseHelper.instance.updateSupplier(event.supplier);
      add(LoadSuppliers());
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteSupplier event, Emitter<SuppliersState> emit) async {
    try {
      await DatabaseHelper.instance.deleteSupplier(event.id);
      add(LoadSuppliers());
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }
}
