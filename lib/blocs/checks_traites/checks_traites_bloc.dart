import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/check_traite.dart';
import '../../database/database_helper.dart';

// Events
abstract class ChecksTraitesEvent extends Equatable {
  const ChecksTraitesEvent();
  @override
  List<Object?> get props => [];
}

class LoadChecksTraites extends ChecksTraitesEvent {}

class CreateCheckTraite extends ChecksTraitesEvent {
  final CheckTraite document;
  const CreateCheckTraite(this.document);
  @override
  List<Object?> get props => [document];
}

class UpdateCheckTraiteStatus extends ChecksTraitesEvent {
  final String id;
  final String status;
  final String? paymentId;
  const UpdateCheckTraiteStatus(this.id, this.status, {this.paymentId});
  @override
  List<Object?> get props => [id, status, paymentId];
}

class DeleteCheckTraite extends ChecksTraitesEvent {
  final String id;
  const DeleteCheckTraite(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class ChecksTraitesState extends Equatable {
  const ChecksTraitesState();
  @override
  List<Object?> get props => [];
}

class ChecksTraitesInitial extends ChecksTraitesState {}
class ChecksTraitesLoading extends ChecksTraitesState {}

class ChecksTraitesLoaded extends ChecksTraitesState {
  final List<CheckTraite> documents;
  const ChecksTraitesLoaded(this.documents);
  @override
  List<Object?> get props => [documents];
}

class ChecksTraitesError extends ChecksTraitesState {
  final String message;
  const ChecksTraitesError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class ChecksTraitesBloc extends Bloc<ChecksTraitesEvent, ChecksTraitesState> {
  final DatabaseHelper databaseHelper;

  ChecksTraitesBloc({required this.databaseHelper}) : super(ChecksTraitesInitial()) {
    on<LoadChecksTraites>(_onLoadDocuments);
    on<CreateCheckTraite>(_onCreateDocument);
    on<UpdateCheckTraiteStatus>(_onUpdateStatus);
    on<DeleteCheckTraite>(_onDeleteDocument);
  }

  Future<void> _onLoadDocuments(LoadChecksTraites event, Emitter<ChecksTraitesState> emit) async {
    emit(ChecksTraitesLoading());
    try {
      final documents = await databaseHelper.getChecksTraites();
      emit(ChecksTraitesLoaded(documents));
    } catch (e) {
      emit(ChecksTraitesError(e.toString()));
    }
  }

  Future<void> _onCreateDocument(CreateCheckTraite event, Emitter<ChecksTraitesState> emit) async {
    try {
      await databaseHelper.insertCheckTraite(event.document);
      add(LoadChecksTraites());
    } catch (e) {
      emit(ChecksTraitesError(e.toString()));
    }
  }

  Future<void> _onUpdateStatus(UpdateCheckTraiteStatus event, Emitter<ChecksTraitesState> emit) async {
    try {
      await databaseHelper.updateCheckTraiteStatus(event.id, event.status, paymentId: event.paymentId);
      add(LoadChecksTraites());
    } catch (e) {
      emit(ChecksTraitesError(e.toString()));
    }
  }

  Future<void> _onDeleteDocument(DeleteCheckTraite event, Emitter<ChecksTraitesState> emit) async {
    try {
      await databaseHelper.deleteCheckTraite(event.id);
      add(LoadChecksTraites());
    } catch (e) {
      emit(ChecksTraitesError(e.toString()));
    }
  }
}
