import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../models/payslip.dart';
import '../../models/payslip_batch.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import '../../services/error_handler.dart';
import 'payroll_event.dart';
import 'payroll_state.dart';

class PayrollBloc extends Bloc<PayrollEvent, PayrollState> {
  static const _monthsList = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  PayrollBloc() : super(PayrollInitial()) {
    on<LoadPayslips>(_onLoadPayslips);
    on<GenerateMonthlyPayslips>(_onGenerateMonthlyPayslips);
    on<AddPayslip>(_onAddPayslip);
    on<UpdatePayslipStatus>(_onUpdatePayslipStatus);
    on<DeletePayslip>(_onDeletePayslip);
    on<AddPayslipBatch>(_onAddPayslipBatch);
    on<UpdatePayslipBatch>(_onUpdatePayslipBatch);
    on<DeletePayslipBatch>(_onDeletePayslipBatch);
    on<GenerateBatchPayslips>(_onGenerateBatchPayslips);
  }

  Future<void> _onLoadPayslips(LoadPayslips event, Emitter<PayrollState> emit) async {
    final currentList = state is PayrollLoaded ? (state as PayrollLoaded).payslips : <Payslip>[];
    if (currentList.isEmpty) {
      emit(PayrollLoading());
    }

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('payslips');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      final list = <Payslip>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['isDeleted'] == true;
        if (isDeleted) continue;

        try {
          final p = Payslip.fromMap(data);
          list.add(p);
        } catch (_) {}
      }

      list.sort((a, b) {
        final cmpYear = b.periodYear.compareTo(a.periodYear);
        if (cmpYear != 0) return cmpYear;
        return b.periodMonth.compareTo(a.periodMonth);
      });

      // Load payslip batches
      Query batchQuery = FirebaseFirestore.instance.collection('payslip_batches');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        batchQuery = batchQuery.where('enterprise_id', isEqualTo: currentEntId);
      }
      final batchSnapshot = await batchQuery.get();
      final batchList = <PayslipBatch>[];

      for (final doc in batchSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDel = data['is_deleted'] == 1 || data['is_deleted'] == true;
        if (isDel) continue;

        try {
          batchList.add(PayslipBatch.fromMap(data));
        } catch (_) {}
      }
      batchList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      emit(PayrollLoaded(list, batches: batchList));
    } catch (e) {
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onGenerateMonthlyPayslips(GenerateMonthlyPayslips event, Emitter<PayrollState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final currentState = state;
    final existingList = currentState is PayrollLoaded ? List<Payslip>.from(currentState.payslips) : <Payslip>[];
    final existingBatches = currentState is PayrollLoaded ? List<PayslipBatch>.from(currentState.batches) : <PayslipBatch>[];

    final newPayslips = <Payslip>[];

    for (final emp in event.activeEmployees) {
      final alreadyExists = existingList.any(
        (p) => p.employeeId == emp.id && p.periodMonth == event.month && p.periodYear == event.year,
      );

      if (!alreadyExists) {
        final transport = 50.0;
        final gross = emp.baseSalary + transport;
        final cnss = gross * 0.0918;
        final net = gross - cnss;

        final p = Payslip(
          id: const Uuid().v4(),
          employeeId: emp.id,
          employeeName: emp.fullName,
          employeeCin: emp.cin,
          employeeCnss: emp.cnssNumber,
          employeeJobTitle: emp.jobTitle,
          periodMonth: event.month,
          periodYear: event.year,
          baseSalary: emp.baseSalary,
          primes: 0.0,
          transportAllowance: transport,
          grossSalary: gross,
          cnssDeduction: cnss,
          taxDeduction: 0.0,
          otherDeductions: 0.0,
          netSalary: net,
          paymentStatus: 'draft',
          paymentMethod: emp.paymentMethod,
          enterpriseId: currentEntId,
        );

        newPayslips.add(p);
      }
    }

    if (newPayslips.isEmpty) return;

    final updated = [...newPayslips, ...existingList];
    emit(PayrollLoaded(updated, batches: existingBatches));

    for (final p in newPayslips) {
      try {
        await FirestoreRepository.instance.saveDocument('payslips', p.id, p.toMap());
      } catch (_) {}
    }
  }

  Future<void> _onAddPayslip(AddPayslip event, Emitter<PayrollState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final item = event.payslip.copyWith(
      enterpriseId: (event.payslip.enterpriseId != null && event.payslip.enterpriseId!.isNotEmpty)
          ? event.payslip.enterpriseId
          : currentEntId,
    );

    final currentState = state;
    if (currentState is PayrollLoaded) {
      final list = List<Payslip>.from(currentState.payslips);
      list.removeWhere((p) => p.id == item.id);
      list.insert(0, item);
      emit(currentState.copyWith(payslips: list));
    } else {
      emit(PayrollLoaded([item]));
    }

    try {
      await FirestoreRepository.instance.saveDocument('payslips', item.id, item.toMap());
    } catch (e) {
      if (currentState is PayrollLoaded) {
        emit(currentState);
      }
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdatePayslipStatus(UpdatePayslipStatus event, Emitter<PayrollState> emit) async {
    final currentState = state;
    if (currentState is PayrollLoaded) {
      final list = currentState.payslips.map((p) {
        if (p.id == event.id) {
          return p.copyWith(
            paymentStatus: event.newStatus,
            paymentDate: event.paymentDate ?? (event.newStatus == 'paid' ? DateTime.now() : null),
            updatedAt: DateTime.now(),
          );
        }
        return p;
      }).toList();
      emit(currentState.copyWith(payslips: list));
    }

    try {
      await FirestoreRepository.instance.updateDocument('payslips', event.id, {
        'payment_status': event.newStatus,
        'payment_date': (event.paymentDate ?? (event.newStatus == 'paid' ? DateTime.now() : null))?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (currentState is PayrollLoaded) {
        emit(currentState);
      }
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeletePayslip(DeletePayslip event, Emitter<PayrollState> emit) async {
    final currentState = state;
    if (currentState is PayrollLoaded) {
      final list = currentState.payslips.where((p) => p.id != event.id).toList();
      emit(currentState.copyWith(payslips: list));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('payslips', event.id);
    } catch (e) {
      if (currentState is PayrollLoaded) {
        emit(currentState);
      }
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  // ---------------------------------------------------------------------------
  // BATCH PAYSLIPS HANDLERS (Lots de bulletins de paie)
  // ---------------------------------------------------------------------------

  Future<void> _onAddPayslipBatch(AddPayslipBatch event, Emitter<PayrollState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final item = event.batch.copyWith(
      enterpriseId: (event.batch.enterpriseId != null && event.batch.enterpriseId!.isNotEmpty)
          ? event.batch.enterpriseId
          : currentEntId,
    );

    final currentState = state;
    if (currentState is PayrollLoaded) {
      final list = List<PayslipBatch>.from(currentState.batches);
      list.removeWhere((b) => b.id == item.id);
      list.insert(0, item);
      emit(currentState.copyWith(batches: list));
    } else {
      emit(PayrollLoaded(const [], batches: [item]));
    }

    try {
      await FirestoreRepository.instance.saveDocument('payslip_batches', item.id, item.toMap());
    } catch (e) {
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdatePayslipBatch(UpdatePayslipBatch event, Emitter<PayrollState> emit) async {
    final currentState = state;
    if (currentState is PayrollLoaded) {
      final list = currentState.batches.map((b) => b.id == event.batch.id ? event.batch : b).toList();
      emit(currentState.copyWith(batches: list));
    }

    try {
      await FirestoreRepository.instance.saveDocument('payslip_batches', event.batch.id, event.batch.toMap());
    } catch (e) {
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeletePayslipBatch(DeletePayslipBatch event, Emitter<PayrollState> emit) async {
    final currentState = state;
    if (currentState is PayrollLoaded) {
      final list = currentState.batches.where((b) => b.id != event.batchId).toList();
      emit(currentState.copyWith(batches: list));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('payslip_batches', event.batchId);
    } catch (e) {
      emit(PayrollError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onGenerateBatchPayslips(GenerateBatchPayslips event, Emitter<PayrollState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final currentState = state;
    final existingPayslips = currentState is PayrollLoaded ? List<Payslip>.from(currentState.payslips) : <Payslip>[];
    final existingBatches = currentState is PayrollLoaded ? List<PayslipBatch>.from(currentState.batches) : <PayslipBatch>[];

    final newPayslips = <Payslip>[];
    final newPayslipIds = <String>[];

    int counter = existingPayslips.length + 1;

    for (final emp in event.selectedEmployees) {
      final refStr = 'SLIP/${counter.toString().padLeft(3, '0')}';
      counter++;

      final transport = 50.0;
      final gross = emp.baseSalary + transport;
      final cnss = gross * 0.0918;
      final net = gross - cnss;

      final p = Payslip(
        id: const Uuid().v4(),
        reference: refStr,
        payslipName: 'Bulletin de paie de ${emp.fullName} pour ${_monthsList[event.batch.periodMonth - 1].toLowerCase()}-${event.batch.periodYear}',
        employeeId: emp.id,
        employeeName: emp.fullName,
        employeeCin: emp.cin,
        employeeCnss: emp.cnssNumber,
        employeeJobTitle: emp.jobTitle,
        periodMonth: event.batch.periodMonth,
        periodYear: event.batch.periodYear,
        workedDays: 22.0,
        workedHours: 176.0,
        baseSalary: emp.baseSalary,
        primes: 0.0,
        transportAllowance: transport,
        grossSalary: gross,
        cnssDeduction: cnss,
        taxDeduction: 0.0,
        otherDeductions: 0.0,
        netSalary: net,
        paymentStatus: 'draft',
        batchNumber: event.batch.name,
        salaryJournal: event.batch.salaryJournal,
        isCreditNote: event.batch.isCreditNote,
        paymentMethod: emp.paymentMethod,
        enterpriseId: currentEntId,
      );

      newPayslips.add(p);
      newPayslipIds.add(p.id);
    }

    final updatedBatch = event.batch.copyWith(
      payslipIds: [...event.batch.payslipIds, ...newPayslipIds],
      updatedAt: DateTime.now(),
    );

    final batchIndex = existingBatches.indexWhere((b) => b.id == updatedBatch.id);
    if (batchIndex >= 0) {
      existingBatches[batchIndex] = updatedBatch;
    } else {
      existingBatches.insert(0, updatedBatch);
    }

    final updatedPayslips = [...newPayslips, ...existingPayslips];
    emit(PayrollLoaded(updatedPayslips, batches: existingBatches));

    try {
      await FirestoreRepository.instance.saveDocument('payslip_batches', updatedBatch.id, updatedBatch.toMap());
    } catch (_) {}

    for (final p in newPayslips) {
      try {
        await FirestoreRepository.instance.saveDocument('payslips', p.id, p.toMap());
      } catch (_) {}
    }
  }
}
