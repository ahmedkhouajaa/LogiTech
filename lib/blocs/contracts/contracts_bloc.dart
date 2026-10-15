import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/employee_contract.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import '../../services/error_handler.dart';
import 'contracts_event.dart';
import 'contracts_state.dart';

class ContractsBloc extends Bloc<ContractsEvent, ContractsState> {
  ContractsBloc() : super(ContractsInitial()) {
    on<LoadContracts>(_onLoadContracts);
    on<AddContract>(_onAddContract);
    on<UpdateContract>(_onUpdateContract);
    on<DeleteContract>(_onDeleteContract);
  }

  Future<void> _onLoadContracts(LoadContracts event, Emitter<ContractsState> emit) async {
    final currentList = state is ContractsLoaded ? (state as ContractsLoaded).contracts : <EmployeeContract>[];
    if (currentList.isEmpty) {
      emit(ContractsLoading());
    }

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('employee_contracts');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      final contracts = <EmployeeContract>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['isDeleted'] == true;
        if (isDeleted) continue;

        try {
          final c = EmployeeContract.fromMap(data);
          if (event.employeeId != null && event.employeeId!.isNotEmpty) {
            if (c.employeeId != event.employeeId) continue;
          }
          if (event.status != null && event.status!.isNotEmpty) {
            if (c.status != event.status) continue;
          }
          if (event.searchQuery != null && event.searchQuery!.trim().isNotEmpty) {
            final q = event.searchQuery!.trim().toLowerCase();
            final matches = c.reference.toLowerCase().contains(q) ||
                c.employeeName.toLowerCase().contains(q) ||
                c.jobTitle.toLowerCase().contains(q) ||
                c.department.toLowerCase().contains(q);
            if (!matches) continue;
          }
          contracts.add(c);
        } catch (_) {}
      }

      contracts.sort((a, b) => b.startDate.compareTo(a.startDate));
      emit(ContractsLoaded(contracts, totalCount: contracts.length));
    } catch (e) {
      emit(ContractsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddContract(AddContract event, Emitter<ContractsState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final contract = event.contract.copyWith(
      enterpriseId: (event.contract.enterpriseId != null && event.contract.enterpriseId!.isNotEmpty)
          ? event.contract.enterpriseId
          : currentEntId,
    );

    final currentState = state;
    if (currentState is ContractsLoaded) {
      final list = List<EmployeeContract>.from(currentState.contracts);
      list.removeWhere((c) => c.id == contract.id);
      list.add(contract);
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      emit(currentState.copyWith(contracts: list, totalCount: list.length));
    } else {
      emit(ContractsLoaded([contract], totalCount: 1));
    }

    try {
      await FirestoreRepository.instance.saveDocument('employee_contracts', contract.id, contract.toMap());
    } catch (e) {
      if (currentState is ContractsLoaded) {
        emit(currentState);
      }
      emit(ContractsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateContract(UpdateContract event, Emitter<ContractsState> emit) async {
    final currentState = state;
    if (currentState is ContractsLoaded) {
      final list = List<EmployeeContract>.from(currentState.contracts);
      final idx = list.indexWhere((c) => c.id == event.contract.id);
      if (idx != -1) {
        list[idx] = event.contract;
      } else {
        list.add(event.contract);
      }
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      emit(currentState.copyWith(contracts: list));
    }

    try {
      await FirestoreRepository.instance.saveDocument('employee_contracts', event.contract.id, event.contract.toMap());
    } catch (e) {
      emit(ContractsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteContract(DeleteContract event, Emitter<ContractsState> emit) async {
    final currentState = state;
    if (currentState is ContractsLoaded) {
      final list = List<EmployeeContract>.from(currentState.contracts);
      list.removeWhere((c) => c.id == event.id);
      emit(currentState.copyWith(contracts: list, totalCount: list.length));
    }

    try {
      await FirestoreRepository.instance.saveDocument('employee_contracts', event.id, {
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      emit(ContractsError(ErrorHandler.parseError(e)));
    }
  }
}
