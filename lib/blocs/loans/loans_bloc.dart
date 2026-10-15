import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/employee_loan.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import '../../services/error_handler.dart';
import 'loans_event.dart';
import 'loans_state.dart';

class LoansBloc extends Bloc<LoansEvent, LoansState> {
  LoansBloc() : super(LoansInitial()) {
    on<LoadLoans>(_onLoadLoans);
    on<AddLoan>(_onAddLoan);
    on<UpdateLoan>(_onUpdateLoan);
    on<DeleteLoan>(_onDeleteLoan);
    on<PayLoanRepayment>(_onPayLoanRepayment);
    on<UnlinkLoanRepayment>(_onUnlinkLoanRepayment);
  }

  Future<void> _onLoadLoans(LoadLoans event, Emitter<LoansState> emit) async {
    final currentList = state is LoansLoaded ? (state as LoansLoaded).loans : <EmployeeLoan>[];
    if (currentList.isEmpty) {
      emit(LoansLoading());
    }

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('employee_loans');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      final loans = <EmployeeLoan>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['isDeleted'] == true;
        if (isDeleted) continue;

        try {
          final l = EmployeeLoan.fromMap(data);
          if (event.employeeId != null && event.employeeId!.isNotEmpty) {
            if (l.employeeId != event.employeeId) continue;
          }
          if (event.status != null && event.status!.isNotEmpty && event.status != 'all') {
            if (l.status.toLowerCase() != event.status!.toLowerCase()) continue;
          }
          if (event.searchQuery != null && event.searchQuery!.trim().isNotEmpty) {
            final q = event.searchQuery!.trim().toLowerCase();
            final matches = l.name.toLowerCase().contains(q) ||
                l.employeeName.toLowerCase().contains(q) ||
                l.reference.toLowerCase().contains(q);
            if (!matches) continue;
          }
          loans.add(l);
        } catch (_) {}
      }

      loans.sort((a, b) => b.date.compareTo(a.date));
      emit(LoansLoaded(loans, totalCount: loans.length));
    } catch (e) {
      emit(LoansError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddLoan(AddLoan event, Emitter<LoansState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final loan = event.loan.copyWith(
      enterpriseId: (event.loan.enterpriseId != null && event.loan.enterpriseId!.isNotEmpty)
          ? event.loan.enterpriseId
          : currentEntId,
    );

    final currentState = state;
    if (currentState is LoansLoaded) {
      final list = List<EmployeeLoan>.from(currentState.loans);
      list.removeWhere((l) => l.id == loan.id);
      list.insert(0, loan);
      list.sort((a, b) => b.date.compareTo(a.date));
      emit(currentState.copyWith(loans: list, totalCount: list.length));
    } else {
      emit(LoansLoaded([loan], totalCount: 1));
    }

    try {
      await FirestoreRepository.instance.saveDocument('employee_loans', loan.id, loan.toMap());
    } catch (e) {
      if (currentState is LoansLoaded) {
        emit(currentState);
      }
      emit(LoansError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateLoan(UpdateLoan event, Emitter<LoansState> emit) async {
    final currentState = state;
    if (currentState is LoansLoaded) {
      final list = List<EmployeeLoan>.from(currentState.loans);
      final idx = list.indexWhere((l) => l.id == event.loan.id);
      if (idx != -1) {
        list[idx] = event.loan;
        emit(currentState.copyWith(loans: list));
      }
    }

    try {
      await FirestoreRepository.instance.saveDocument('employee_loans', event.loan.id, event.loan.toMap());
    } catch (e) {
      if (currentState is LoansLoaded) {
        emit(currentState);
      }
      emit(LoansError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteLoan(DeleteLoan event, Emitter<LoansState> emit) async {
    final currentState = state;
    if (currentState is LoansLoaded) {
      final list = List<EmployeeLoan>.from(currentState.loans);
      list.removeWhere((l) => l.id == event.id);
      emit(currentState.copyWith(loans: list, totalCount: list.length));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('employee_loans', event.id);
    } catch (e) {
      if (currentState is LoansLoaded) {
        emit(currentState);
      }
      emit(LoansError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onPayLoanRepayment(PayLoanRepayment event, Emitter<LoansState> emit) async {
    final currentState = state;
    if (currentState is LoansLoaded) {
      final list = List<EmployeeLoan>.from(currentState.loans);
      final idx = list.indexWhere((l) => l.id == event.loanId);
      if (idx != -1) {
        final loan = list[idx];
        final updatedRepayments = loan.repayments.map((r) {
          if (r.id == event.repaymentId) {
            return r.copyWith(
              status: 'paid',
              payslipId: event.payslipId,
              payslipReference: event.payslipReference,
            );
          }
          return r;
        }).toList();

        // Calculate remaining amount
        double totalPaid = 0.0;
        for (final r in updatedRepayments) {
          if (r.status == 'paid') {
            totalPaid += r.amount;
          }
        }
        final double remaining = (loan.amount - totalPaid).clamp(0.0, double.infinity);
        final String status = remaining <= 0.0 ? 'paid' : loan.status;

        final updatedLoan = loan.copyWith(
          repayments: updatedRepayments,
          remainingAmount: remaining,
          status: status,
          updatedAt: DateTime.now(),
        );

        list[idx] = updatedLoan;
        emit(currentState.copyWith(loans: list));

        try {
          await FirestoreRepository.instance.saveDocument('employee_loans', updatedLoan.id, updatedLoan.toMap());
        } catch (_) {}
      }
    }
  }

  Future<void> _onUnlinkLoanRepayment(UnlinkLoanRepayment event, Emitter<LoansState> emit) async {
    final currentState = state;
    if (currentState is LoansLoaded) {
      final list = List<EmployeeLoan>.from(currentState.loans);
      final idx = list.indexWhere((l) => l.id == event.loanId);
      if (idx != -1) {
        final loan = list[idx];
        final updatedRepayments = loan.repayments.map((r) {
          if (r.id == event.repaymentId) {
            return r.copyWith(
              status: 'draft',
              payslipId: null,
              payslipReference: null,
            );
          }
          return r;
        }).toList();

        double totalPaid = 0.0;
        for (final r in updatedRepayments) {
          if (r.status == 'paid') {
            totalPaid += r.amount;
          }
        }
        final double remaining = (loan.amount - totalPaid).clamp(0.0, double.infinity);
        final String status = loan.status == 'paid' ? 'confirmed' : loan.status;

        final updatedLoan = loan.copyWith(
          repayments: updatedRepayments,
          remainingAmount: remaining,
          status: status,
          updatedAt: DateTime.now(),
        );

        list[idx] = updatedLoan;
        emit(currentState.copyWith(loans: list));

        try {
          await FirestoreRepository.instance.saveDocument('employee_loans', updatedLoan.id, updatedLoan.toMap());
        } catch (_) {}
      }
    }
  }
}
