import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/enterprise.dart';
import '../../services/enterprise_service.dart';

// ─── Events ──────────────────────────────────────────────────────────

abstract class EnterpriseEvent extends Equatable {
  const EnterpriseEvent();
  @override
  List<Object?> get props => [];
}

/// Load enterprise list from Firestore (or cache).
class LoadEnterprises extends EnterpriseEvent {}

/// Switch to a different enterprise.
class SwitchEnterprise extends EnterpriseEvent {
  final String enterpriseId;
  const SwitchEnterprise(this.enterpriseId);
  @override
  List<Object?> get props => [enterpriseId];
}

/// Create a new enterprise with company settings.
class CreateEnterprise extends EnterpriseEvent {
  final String name;
  final String? description;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxId;
  final String? rcNumber;
  final String? address;
  final String? rib;

  const CreateEnterprise(
    this.name, {
    this.description,
    this.phone,
    this.email,
    this.website,
    this.taxId,
    this.rcNumber,
    this.address,
    this.rib,
  });

  @override
  List<Object?> get props => [
        name,
        description,
        phone,
        email,
        website,
        taxId,
        rcNumber,
        address,
        rib,
      ];
}

// ─── States ──────────────────────────────────────────────────────────

abstract class EnterpriseState extends Equatable {
  const EnterpriseState();
  @override
  List<Object?> get props => [];
}

class EnterpriseInitial extends EnterpriseState {}

class EnterpriseLoading extends EnterpriseState {}

class EnterpriseLoaded extends EnterpriseState {
  final List<Enterprise> enterprises;
  final String? currentEnterpriseId;

  const EnterpriseLoaded({
    required this.enterprises,
    this.currentEnterpriseId,
  });

  @override
  List<Object?> get props => [enterprises, currentEnterpriseId];
}

class EnterpriseSwitching extends EnterpriseState {}

class EnterpriseError extends EnterpriseState {
  final String message;
  const EnterpriseError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────

class EnterpriseBloc extends Bloc<EnterpriseEvent, EnterpriseState> {
  final EnterpriseService _service;

  EnterpriseBloc({EnterpriseService? service})
      : _service = service ?? EnterpriseService.instance,
        super(EnterpriseInitial()) {
    on<LoadEnterprises>(_onLoadEnterprises);
    on<SwitchEnterprise>(_onSwitchEnterprise);
    on<CreateEnterprise>(_onCreateEnterprise);
  }

  Future<void> _onLoadEnterprises(
    LoadEnterprises event,
    Emitter<EnterpriseState> emit,
  ) async {
    emit(EnterpriseLoading());
    try {
      final enterprises = await _service.loadEnterprisesFromFirestore();
      emit(EnterpriseLoaded(
        enterprises: enterprises,
        currentEnterpriseId: _service.currentEnterpriseId,
      ));
    } catch (e) {
      emit(EnterpriseError(e.toString()));
    }
  }

  Future<void> _onSwitchEnterprise(
    SwitchEnterprise event,
    Emitter<EnterpriseState> emit,
  ) async {
    emit(EnterpriseSwitching());
    try {
      await _service.setCurrentEnterprise(event.enterpriseId);
      emit(EnterpriseLoaded(
        enterprises: _service.enterprises,
        currentEnterpriseId: event.enterpriseId,
      ));
    } catch (e) {
      emit(EnterpriseError(e.toString()));
    }
  }

  Future<void> _onCreateEnterprise(
    CreateEnterprise event,
    Emitter<EnterpriseState> emit,
  ) async {
    emit(EnterpriseLoading());
    try {
      final enterprise = await _service.createEnterprise(
        event.name,
        description: event.description,
        phone: event.phone,
        email: event.email,
        website: event.website,
        taxId: event.taxId,
        rcNumber: event.rcNumber,
        address: event.address,
        rib: event.rib,
      );
      emit(EnterpriseLoaded(
        enterprises: _service.enterprises,
        currentEnterpriseId: enterprise.id,
      ));
    } catch (e) {
      emit(EnterpriseError(e.toString()));
    }
  }
}
