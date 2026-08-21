import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/document_template.dart';
import 'package:business_manager_pro/services/error_handler.dart';

// ─── Events ───────────────────────────────────────────────────────

abstract class DocumentTemplatesEvent extends Equatable {
  const DocumentTemplatesEvent();
  @override
  List<Object?> get props => [];
}

class LoadDocumentTemplates extends DocumentTemplatesEvent {}

class AddDocumentTemplate extends DocumentTemplatesEvent {
  final DocumentTemplate template;
  const AddDocumentTemplate(this.template);
  @override
  List<Object?> get props => [template];
}

class UpdateDocumentTemplate extends DocumentTemplatesEvent {
  final DocumentTemplate template;
  const UpdateDocumentTemplate(this.template);
  @override
  List<Object?> get props => [template];
}

class DeleteDocumentTemplate extends DocumentTemplatesEvent {
  final String id;
  const DeleteDocumentTemplate(this.id);
  @override
  List<Object?> get props => [id];
}

class DuplicateDocumentTemplate extends DocumentTemplatesEvent {
  final DocumentTemplate template;
  const DuplicateDocumentTemplate(this.template);
  @override
  List<Object?> get props => [template];
}

class SetDefaultDocumentTemplate extends DocumentTemplatesEvent {
  final String id;
  final String documentType;
  const SetDefaultDocumentTemplate(this.id, this.documentType);
  @override
  List<Object?> get props => [id, documentType];
}

// ─── States ───────────────────────────────────────────────────────

abstract class DocumentTemplatesState extends Equatable {
  const DocumentTemplatesState();
  @override
  List<Object?> get props => [];
}

class DocumentTemplatesInitial extends DocumentTemplatesState {}

class DocumentTemplatesLoading extends DocumentTemplatesState {}

class DocumentTemplatesLoaded extends DocumentTemplatesState {
  final List<DocumentTemplate> templates;
  const DocumentTemplatesLoaded(this.templates);
  @override
  List<Object?> get props => [templates];
}

class DocumentTemplatesError extends DocumentTemplatesState {
  final String message;
  const DocumentTemplatesError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────

class DocumentTemplatesBloc
    extends Bloc<DocumentTemplatesEvent, DocumentTemplatesState> {
  DocumentTemplatesBloc() : super(DocumentTemplatesInitial()) {
    on<LoadDocumentTemplates>(_onLoad);
    on<AddDocumentTemplate>(_onAdd);
    on<UpdateDocumentTemplate>(_onUpdate);
    on<DeleteDocumentTemplate>(_onDelete);
    on<DuplicateDocumentTemplate>(_onDuplicate);
    on<SetDefaultDocumentTemplate>(_onSetDefault);
  }

  Future<void> _onLoad(
      LoadDocumentTemplates event, Emitter<DocumentTemplatesState> emit) async {
    emit(DocumentTemplatesLoading());
    try {
      final templates = await DatabaseHelper.instance.getDocumentTemplates();
      emit(DocumentTemplatesLoaded(templates));
    } catch (e) {
      emit(DocumentTemplatesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAdd(
      AddDocumentTemplate event, Emitter<DocumentTemplatesState> emit) async {
    try {
      await DatabaseHelper.instance.insertDocumentTemplate(event.template);
      add(LoadDocumentTemplates());
    } catch (e) {
      emit(DocumentTemplatesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(
      UpdateDocumentTemplate event, Emitter<DocumentTemplatesState> emit) async {
    try {
      await DatabaseHelper.instance.updateDocumentTemplate(event.template);
      add(LoadDocumentTemplates());
    } catch (e) {
      emit(DocumentTemplatesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(
      DeleteDocumentTemplate event, Emitter<DocumentTemplatesState> emit) async {
    try {
      if (state is DocumentTemplatesLoaded) {
        final currentTemplates = (state as DocumentTemplatesLoaded).templates;
        final target = currentTemplates.where((t) => t.id == event.id).firstOrNull;
        if (target != null && target.isDefault) {
          emit(const DocumentTemplatesError('Le modèle par défaut ne peut pas être supprimé.'));
          add(LoadDocumentTemplates());
          return;
        }
      }
      await DatabaseHelper.instance.deleteDocumentTemplate(event.id);
      add(LoadDocumentTemplates());
    } catch (e) {
      emit(DocumentTemplatesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDuplicate(DuplicateDocumentTemplate event,
      Emitter<DocumentTemplatesState> emit) async {
    try {
      final newId = DatabaseHelper.instance.newId;
      final duplicate = event.template.copyWith(
        id: newId,
        name: '${event.template.name} (copie)',
        isDefault: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertDocumentTemplate(duplicate);
      add(LoadDocumentTemplates());
    } catch (e) {
      emit(DocumentTemplatesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onSetDefault(SetDefaultDocumentTemplate event,
      Emitter<DocumentTemplatesState> emit) async {
    try {
      await DatabaseHelper.instance
          .setDefaultTemplate(event.id, event.documentType);
      add(LoadDocumentTemplates());
    } catch (e) {
      emit(DocumentTemplatesError(ErrorHandler.parseError(e)));
    }
  }
}
