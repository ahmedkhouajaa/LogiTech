import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/project.dart';

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

  Future<void> _onLoad(LoadProjects event, Emitter<ProjectsState> emit) async {
    emit(ProjectsLoading());
    try { emit(ProjectsLoaded(await DatabaseHelper.instance.getProjects())); } catch (e) { emit(ProjectsError(e.toString())); }
  }
  Future<void> _onAdd(AddProject event, Emitter<ProjectsState> emit) async {
    try { await DatabaseHelper.instance.insertProject(event.project); add(LoadProjects()); } catch (e) { emit(ProjectsError(e.toString())); }
  }
  Future<void> _onUpdate(UpdateProject event, Emitter<ProjectsState> emit) async {
    try { await DatabaseHelper.instance.updateProject(event.project); add(LoadProjects()); } catch (e) { emit(ProjectsError(e.toString())); }
  }
  Future<void> _onDelete(DeleteProject event, Emitter<ProjectsState> emit) async {
    try { await DatabaseHelper.instance.softDelete('projects', event.id); add(LoadProjects()); } catch (e) { emit(ProjectsError(e.toString())); }
  }
}
