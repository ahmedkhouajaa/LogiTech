import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../database/database_helper.dart';
import '../../models/project.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class ProjectsEvent extends Equatable { const ProjectsEvent(); @override List<Object?> get props => []; }
class LoadProjects extends ProjectsEvent {}
class AddProject extends ProjectsEvent { final Project project; const AddProject(this.project); @override List<Object?> get props => [project]; }
class UpdateProject extends ProjectsEvent { final Project project; const UpdateProject(this.project); @override List<Object?> get props => [project]; }
class DeleteProject extends ProjectsEvent { final String id; const DeleteProject(this.id); @override List<Object?> get props => [id]; }

abstract class ProjectsState extends Equatable { const ProjectsState(); @override List<Object?> get props => []; }
class ProjectsInitial extends ProjectsState {}
class ProjectsLoading extends ProjectsState {}
class ProjectsLoaded extends ProjectsState { final List<Project> projects; const ProjectsLoaded(this.projects); @override List<Object?> get props => [projects]; }
class ProjectsError extends ProjectsState { final String message; const ProjectsError(this.message); @override List<Object?> get props => [message]; }

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  ProjectsBloc() : super(ProjectsInitial()) {
    on<LoadProjects>(_onLoad);
    on<AddProject>(_onAdd);
    on<UpdateProject>(_onUpdate);
    on<DeleteProject>(_onDelete);
  }

  Query _buildQuery() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    Query query = FirebaseFirestore.instance.collection('projects').where('is_deleted', isEqualTo: 0);
    if (uid != null && uid.isNotEmpty) {
      query = query.where('userId', isEqualTo: uid);
    }
    if (currentEntId != null && currentEntId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: currentEntId);
    }
    return query;
  }

  List<Project> _parseSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      data['id'] = doc.id;
      data['created_at'] = data['created_at'] ?? DateTime.now().toIso8601String();
      data['updated_at'] = data['updated_at'] ?? DateTime.now().toIso8601String();
      return Project.fromMap(data);
    }).toList();
  }

  Future<void> _onLoad(LoadProjects event, Emitter<ProjectsState> emit) async {
    emit(ProjectsLoading());

    try {
      bool shownFromCache = false;
      try {
        final cacheSnapshot = await _buildQuery().get(const GetOptions(source: Source.cache));
        if (cacheSnapshot.docs.isNotEmpty && !emit.isDone) {
          final cachedProjects = _parseSnapshot(cacheSnapshot);
          cachedProjects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          emit(ProjectsLoaded(cachedProjects));
          shownFromCache = true;
        }
      } catch (_) {}

      try {
        final serverSnapshot = await _buildQuery().get(const GetOptions(source: Source.server));
        List<Project> projects = _parseSnapshot(serverSnapshot);
        
        if (projects.isEmpty) {
          final defaultProject = Project(
            id: const Uuid().v4(),
            name: 'Projet par défaut',
            description: 'Projet initial par défaut',
            startDate: DateTime.now(),
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          projects = [defaultProject];
          
          FirestoreRepository.instance
              .saveDocument('projects', defaultProject.id, defaultProject.toMap())
              .catchError((e) => print("Firestore default project auto-create error: $e"));
        }

        projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        if (!emit.isDone) {
          emit(ProjectsLoaded(projects));
        }
      } catch (e) {
        if (!shownFromCache && !emit.isDone) {
          emit(ProjectsLoaded(const []));
        }
      }
    } catch (e) {
      if (!emit.isDone) emit(ProjectsLoaded(const []));
    }
  }

  Future<void> _onAdd(AddProject event, Emitter<ProjectsState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final project = (event.project.enterpriseId == null || event.project.enterpriseId!.isEmpty)
        ? Project(
            id: event.project.id,
            name: event.project.name,
            description: event.project.description,
            customerId: event.project.customerId,
            customerName: event.project.customerName,
            startDate: event.project.startDate,
            endDate: event.project.endDate,
            budget: event.project.budget,
            spent: event.project.spent,
            status: event.project.status,
            progress: event.project.progress,
            notes: event.project.notes,
            firebaseUid: event.project.firebaseUid,
            enterpriseId: currentEntId,
            isDeleted: event.project.isDeleted,
            createdAt: event.project.createdAt,
            updatedAt: event.project.updatedAt,
          )
        : event.project;

    final currentState = state;
    if (currentState is ProjectsLoaded) {
      final currentList = List<Project>.from(currentState.projects);
      currentList.insert(0, project);
      emit(ProjectsLoaded(currentList));
    }

    try {
      await FirestoreRepository.instance.saveDocument('projects', project.id, project.toMap());
    } catch (e) {
      print("Failed to save project: $e");
    }
  }

  Future<void> _onUpdate(UpdateProject event, Emitter<ProjectsState> emit) async {
    final currentState = state;
    if (currentState is ProjectsLoaded) {
      final currentList = List<Project>.from(currentState.projects);
      final idx = currentList.indexWhere((p) => p.id == event.project.id);
      if (idx != -1) {
        currentList[idx] = event.project;
      } else {
        currentList.insert(0, event.project);
      }
      emit(ProjectsLoaded(currentList));
    }

    try {
      await FirestoreRepository.instance.saveDocument('projects', event.project.id, event.project.toMap());
    } catch (e) {
      print("Failed to update project: $e");
    }
  }

  Future<void> _onDelete(DeleteProject event, Emitter<ProjectsState> emit) async {
    final currentState = state;
    if (currentState is ProjectsLoaded) {
      final currentList = List<Project>.from(currentState.projects)..removeWhere((p) => p.id == event.id);
      emit(ProjectsLoaded(currentList));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('projects', event.id);
    } catch (e) {
      print("Failed to delete project: $e");
    }
  }
}
