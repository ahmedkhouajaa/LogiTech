import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/enterprise.dart';
import '../../services/enterprise_service.dart';
import 'package:business_manager_pro/services/error_handler.dart';

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

/// Update existing enterprise details/settings.
class UpdateEnterprise extends EnterpriseEvent {
  final Enterprise enterprise;
  const UpdateEnterprise(this.enterprise);
  @override
  List<Object?> get props => [enterprise];
}

/// Internal event fired when Firestore notifies of new/updated enterprises in real time.
class EnterprisesUpdated extends EnterpriseEvent {
  final List<Enterprise> enterprises;
  final String? currentEnterpriseId;

  const EnterprisesUpdated({
    required this.enterprises,
    this.currentEnterpriseId,
  });

  @override
  List<Object?> get props => [enterprises, currentEnterpriseId];
}

/// Reset enterprise bloc to initial state (e.g. on user logout).
class ResetEnterprises extends EnterpriseEvent {}

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
  StreamSubscription<List<Enterprise>>? _enterprisesSub;
  StreamSubscription<String?>? _currentIdSub;

  EnterpriseBloc({EnterpriseService? service})
      : _service = service ?? EnterpriseService.instance,
        super(EnterpriseInitial()) {
    on<LoadEnterprises>(_onLoadEnterprises);
    on<SwitchEnterprise>(_onSwitchEnterprise);
    on<CreateEnterprise>(_onCreateEnterprise);
    on<UpdateEnterprise>(_onUpdateEnterprise);
    on<EnterprisesUpdated>(_onEnterprisesUpdated);
    on<ResetEnterprises>((event, emit) => emit(EnterpriseInitial()));

    // Reactively update BLoC whenever EnterpriseService streams a refreshed enterprise list
    _enterprisesSub = _service.enterprisesStream.listen((enterprises) {
      add(EnterprisesUpdated(
        enterprises: List<Enterprise>.from(enterprises),
        currentEnterpriseId: _service.currentEnterpriseId,
      ));
    });

    // Reactively update BLoC whenever EnterpriseService switches the active enterprise ID
    _currentIdSub = _service.enterpriseStream.listen((currentId) {
      add(EnterprisesUpdated(
        enterprises: List<Enterprise>.from(_service.enterprises),
        currentEnterpriseId: currentId,
      ));
    });
  }

  @override
  Future<void> close() {
    _enterprisesSub?.cancel();
    _currentIdSub?.cancel();
    return super.close();
  }

  void _onEnterprisesUpdated(
    EnterprisesUpdated event,
    Emitter<EnterpriseState> emit,
  ) {
    if (event.enterprises.isEmpty && (state is EnterpriseInitial || state is EnterpriseLoading)) {
      return;
    }
    emit(EnterpriseLoaded(
      enterprises: List<Enterprise>.from(event.enterprises),
      currentEnterpriseId: event.currentEnterpriseId ?? _service.currentEnterpriseId,
    ));
  }

  Future<void> _onLoadEnterprises(
    LoadEnterprises event,
    Emitter<EnterpriseState> emit,
  ) async {
    emit(EnterpriseLoading());
    try {
      final enterprises = await _service.loadEnterprisesFromFirestore();
      emit(EnterpriseLoaded(
        enterprises: List<Enterprise>.from(enterprises),
        currentEnterpriseId: _service.currentEnterpriseId,
      ));
    } catch (e) {
      emit(EnterpriseError(ErrorHandler.parseError(e)));
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
        enterprises: List<Enterprise>.from(_service.enterprises),
        currentEnterpriseId: event.enterpriseId,
      ));
    } catch (e) {
      emit(EnterpriseError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onCreateEnterprise(
    CreateEnterprise event,
    Emitter<EnterpriseState> emit,
  ) async {
    if (state is EnterpriseLoading) return;
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
        enterprises: List<Enterprise>.from(_service.enterprises),
        currentEnterpriseId: enterprise.id,
      ));
    } catch (e) {
      emit(EnterpriseError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateEnterprise(
    UpdateEnterprise event,
    Emitter<EnterpriseState> emit,
  ) async {
    emit(EnterpriseLoading());
    try {
      final updated = await _service.updateEnterprise(event.enterprise);
      emit(EnterpriseLoaded(
        enterprises: List<Enterprise>.from(_service.enterprises),
        currentEnterpriseId: updated.id,
      ));
    } catch (e) {
      emit(EnterpriseError(ErrorHandler.parseError(e)));
    }
  }
}
