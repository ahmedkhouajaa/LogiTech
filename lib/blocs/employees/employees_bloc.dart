import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/employee.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import '../../services/error_handler.dart';
import 'employees_event.dart';
import 'employees_state.dart';

class EmployeesBloc extends Bloc<EmployeesEvent, EmployeesState> {
  EmployeesBloc() : super(EmployeesInitial()) {
    on<LoadEmployees>(_onLoadEmployees);
    on<AddEmployee>(_onAddEmployee);
    on<UpdateEmployee>(_onUpdateEmployee);
    on<DeleteEmployee>(_onDeleteEmployee);
  }

  Future<void> _onLoadEmployees(LoadEmployees event, Emitter<EmployeesState> emit) async {
    final currentList = state is EmployeesLoaded ? (state as EmployeesLoaded).employees : <Employee>[];
    if (currentList.isEmpty) {
      emit(EmployeesLoading());
    }

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('employees');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      final employees = <Employee>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['isDeleted'] == true;
        if (isDeleted) continue;

        try {
          final emp = Employee.fromMap(data);
          employees.add(emp);
        } catch (e) {
          // Skip corrupt records
        }
      }

      employees.sort((a, b) => a.code.compareTo(b.code));
      emit(EmployeesLoaded(employees, totalCount: employees.length));
    } catch (e) {
      emit(EmployeesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddEmployee(AddEmployee event, Emitter<EmployeesState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final emp = event.employee.copyWith(
      enterpriseId: (event.employee.enterpriseId != null && event.employee.enterpriseId!.isNotEmpty)
          ? event.employee.enterpriseId
          : currentEntId,
    );

    final currentState = state;
    if (currentState is EmployeesLoaded) {
      final list = List<Employee>.from(currentState.employees);
      list.removeWhere((e) => e.id == emp.id);
      list.add(emp);
      list.sort((a, b) => a.code.compareTo(b.code));
      emit(currentState.copyWith(employees: list, totalCount: list.length));
    } else {
      emit(EmployeesLoaded([emp], totalCount: 1));
    }

    try {
      await FirestoreRepository.instance.saveDocument('employees', emp.id, emp.toMap());
    } catch (e) {
      if (currentState is EmployeesLoaded) {
        emit(currentState);
      }
      emit(EmployeesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateEmployee(UpdateEmployee event, Emitter<EmployeesState> emit) async {
    final currentState = state;
    if (currentState is EmployeesLoaded) {
      final list = List<Employee>.from(currentState.employees);
      final idx = list.indexWhere((e) => e.id == event.employee.id);
      if (idx != -1) {
        list[idx] = event.employee;
      } else {
        list.add(event.employee);
      }
      list.sort((a, b) => a.code.compareTo(b.code));
      emit(currentState.copyWith(employees: list));
    }

    try {
      await FirestoreRepository.instance.saveDocument('employees', event.employee.id, event.employee.toMap());
    } catch (e) {
      if (currentState is EmployeesLoaded) {
        emit(currentState);
      }
      emit(EmployeesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteEmployee(DeleteEmployee event, Emitter<EmployeesState> emit) async {
    final currentState = state;
    if (currentState is EmployeesLoaded) {
      final list = currentState.employees.where((e) => e.id != event.id).toList();
      emit(currentState.copyWith(employees: list, totalCount: list.length));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('employees', event.id);
    } catch (e) {
      if (currentState is EmployeesLoaded) {
        emit(currentState);
      }
      emit(EmployeesError(ErrorHandler.parseError(e)));
    }
  }
}
