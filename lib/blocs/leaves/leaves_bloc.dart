import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/leave_request.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import '../../services/error_handler.dart';
import 'leaves_event.dart';
import 'leaves_state.dart';

class LeavesBloc extends Bloc<LeavesEvent, LeavesState> {
  LeavesBloc() : super(LeavesInitial()) {
    on<LoadLeaves>(_onLoadLeaves);
    on<AddLeaveRequest>(_onAddLeaveRequest);
    on<UpdateLeaveRequest>(_onUpdateLeaveRequest);
    on<UpdateLeaveStatus>(_onUpdateLeaveStatus);
    on<DeleteLeaveRequest>(_onDeleteLeaveRequest);
  }

  Future<void> _onLoadLeaves(LoadLeaves event, Emitter<LeavesState> emit) async {
    final currentList = state is LeavesLoaded ? (state as LeavesLoaded).leaves : <LeaveRequest>[];
    if (currentList.isEmpty) {
      emit(LeavesLoading());
    }

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('leave_requests');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      final leaves = <LeaveRequest>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['isDeleted'] == true;
        if (isDeleted) continue;

        try {
          final lr = LeaveRequest.fromMap(data);
          leaves.add(lr);
        } catch (e) {
          // Skip corrupt records
        }
      }

      leaves.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(LeavesLoaded(leaves));
    } catch (e) {
      emit(LeavesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddLeaveRequest(AddLeaveRequest event, Emitter<LeavesState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final item = event.leaveRequest.copyWith(
      enterpriseId: (event.leaveRequest.enterpriseId != null && event.leaveRequest.enterpriseId!.isNotEmpty)
          ? event.leaveRequest.enterpriseId
          : currentEntId,
    );

    final currentState = state;
    if (currentState is LeavesLoaded) {
      final list = List<LeaveRequest>.from(currentState.leaves);
      list.removeWhere((l) => l.id == item.id);
      list.insert(0, item);
      emit(currentState.copyWith(leaves: list));
    } else {
      emit(LeavesLoaded([item]));
    }

    try {
      await FirestoreRepository.instance.saveDocument('leave_requests', item.id, item.toMap());
    } catch (e) {
      if (currentState is LeavesLoaded) {
        emit(currentState);
      }
      emit(LeavesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateLeaveRequest(UpdateLeaveRequest event, Emitter<LeavesState> emit) async {
    final item = event.leaveRequest.copyWith(updatedAt: DateTime.now());
    final currentState = state;
    if (currentState is LeavesLoaded) {
      final list = currentState.leaves.map((l) => l.id == item.id ? item : l).toList();
      emit(currentState.copyWith(leaves: list));
    }

    try {
      await FirestoreRepository.instance.saveDocument('leave_requests', item.id, item.toMap());
    } catch (e) {
      if (currentState is LeavesLoaded) {
        emit(currentState);
      }
      emit(LeavesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateLeaveStatus(UpdateLeaveStatus event, Emitter<LeavesState> emit) async {
    final currentState = state;
    if (currentState is LeavesLoaded) {
      final list = currentState.leaves.map((l) {
        if (l.id == event.id) {
          return l.copyWith(
            status: event.newStatus,
            rejectionReason: event.rejectionReason,
            approvedBy: event.approvedBy,
            updatedAt: DateTime.now(),
          );
        }
        return l;
      }).toList();
      emit(currentState.copyWith(leaves: list));
    }

    try {
      await FirestoreRepository.instance.updateDocument('leave_requests', event.id, {
        'status': event.newStatus,
        'rejection_reason': event.rejectionReason,
        'approved_by': event.approvedBy,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (currentState is LeavesLoaded) {
        emit(currentState);
      }
      emit(LeavesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteLeaveRequest(DeleteLeaveRequest event, Emitter<LeavesState> emit) async {
    final currentState = state;
    if (currentState is LeavesLoaded) {
      final list = currentState.leaves.where((l) => l.id != event.id).toList();
      emit(currentState.copyWith(leaves: list));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('leave_requests', event.id);
    } catch (e) {
      if (currentState is LeavesLoaded) {
        emit(currentState);
      }
      emit(LeavesError(ErrorHandler.parseError(e)));
    }
  }
}
