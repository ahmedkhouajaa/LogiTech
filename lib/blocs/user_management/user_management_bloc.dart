import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/user_management_service.dart';
import '../../services/enterprise_service.dart';
import '../../models/user_management_model.dart';
import '../../models/enterprise.dart';
import 'user_management_event.dart';
import 'user_management_state.dart';

class UserManagementBloc extends Bloc<UserManagementEvent, UserManagementState> {
  final UserManagementService _service;

  List<EnterpriseUserModel> _cachedUsers = [];
  List<Enterprise> _cachedOwnedEnterprises = [];
  bool _cachedIsAdmin = true;

  UserManagementBloc({UserManagementService? service})
      : _service = service ?? UserManagementService.instance,
        super(UserManagementInitial()) {
    on<LoadEnterpriseUsers>(_onLoadEnterpriseUsers);
    on<VerifyUserEmailEvent>(_onVerifyUserEmail);
    on<ResetEmailVerificationEvent>(_onResetEmailVerification);
    on<AddEnterpriseUserEvent>(_onAddEnterpriseUser);
    on<UpdateEnterpriseUserEvent>(_onUpdateEnterpriseUser);
    on<RemoveEnterpriseUserEvent>(_onRemoveEnterpriseUser);
  }

  Future<void> _onLoadEnterpriseUsers(
    LoadEnterpriseUsers event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(UserManagementLoading());
    try {
      final currentEnterpriseId = event.enterpriseId ?? EnterpriseService.instance.currentEnterpriseId;
      if (currentEnterpriseId == null || currentEnterpriseId.isEmpty) {
        emit(const UserManagementLoaded(
          users: [],
          filteredUsers: [],
          ownedEnterprises: [],
          isCurrentUserAdmin: false,
        ));
        return;
      }

      _cachedIsAdmin = await _service.isCurrentUserAdmin(currentEnterpriseId);
      _cachedUsers = await _service.getUsersForEnterprise(currentEnterpriseId);
      _cachedOwnedEnterprises = await _service.getOwnedEnterprises();

      final filtered = _applyFilters(
        _cachedUsers,
        searchQuery: event.searchQuery,
        roleFilter: event.roleFilter,
      );

      emit(UserManagementLoaded(
        users: _cachedUsers,
        filteredUsers: filtered,
        ownedEnterprises: _cachedOwnedEnterprises,
        isCurrentUserAdmin: _cachedIsAdmin,
        searchQuery: event.searchQuery,
        roleFilter: event.roleFilter,
      ));
    } catch (e) {
      emit(UserManagementError('Erreur lors du chargement des utilisateurs: $e'));
    }
  }

  List<EnterpriseUserModel> _applyFilters(
    List<EnterpriseUserModel> users, {
    String? searchQuery,
    String? roleFilter,
  }) {
    return users.where((user) {
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchName = user.name.toLowerCase().contains(query);
        final matchEmail = user.email.toLowerCase().contains(query);
        final matchPhone = (user.phone ?? '').toLowerCase().contains(query);
        if (!matchName && !matchEmail && !matchPhone) return false;
      }

      if (roleFilter != null && roleFilter != 'Tous' && roleFilter.isNotEmpty) {
        final r = roleFilter.toLowerCase();
        if (r == 'admin' || r == 'administrateur') {
          if (!user.isAdmin) return false;
        } else if (r == 'collaborateur' || r == 'utilisateur' || r == 'collaborator') {
          if (user.isAdmin) return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _onVerifyUserEmail(
    VerifyUserEmailEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(EmailVerificationInProgress());
    try {
      final result = await _service.verifyUserEmail(event.email, event.currentEnterpriseId);
      if (result.isValid && result.userData != null) {
        final data = result.userData!;
        emit(EmailVerificationSuccess(
          uid: data['uid'] ?? '',
          email: data['email'] ?? event.email,
          name: data['name'] ?? '',
          phone: data['phone'],
          existingEnterprises: data['existingEnterprises'] != null
              ? List<String>.from(data['existingEnterprises'])
              : [],
        ));
      } else {
        emit(EmailVerificationFailure(result.errorMessage ?? 'Adresse email non valide.'));
      }
    } catch (e) {
      emit(EmailVerificationFailure('Erreur de vérification: $e'));
    }
  }

  void _onResetEmailVerification(
    ResetEmailVerificationEvent event,
    Emitter<UserManagementState> emit,
  ) {
    emit(UserManagementLoaded(
      users: _cachedUsers,
      filteredUsers: _cachedUsers,
      ownedEnterprises: _cachedOwnedEnterprises,
      isCurrentUserAdmin: _cachedIsAdmin,
    ));
  }

  Future<void> _onAddEnterpriseUser(
    AddEnterpriseUserEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(const UserOperationInProgress(message: 'Création du compte et ajout à l\'entreprise...'));
    try {
      await _service.createAndAddUserToEnterprises(
        email: event.email,
        name: event.name,
        phone: event.phone,
        password: event.password,
        sendInvitationEmail: event.sendInvitationEmail,
        role: event.role,
        selectedEnterpriseIds: event.selectedEnterpriseIds,
        permissions: event.permissions,
      );

      emit(const UserOperationSuccess('Utilisateur créé et ajouté avec succès !'));
      add(LoadEnterpriseUsers(enterpriseId: event.currentEnterpriseId));
    } catch (e) {
      emit(UserOperationFailure('Échec de l\'ajout de l\'utilisateur: $e'));
    }
  }

  Future<void> _onUpdateEnterpriseUser(
    UpdateEnterpriseUserEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(const UserOperationInProgress(message: 'Mise à jour des permissions...'));
    try {
      await _service.updateUserInEnterprise(
        targetUid: event.targetUid,
        currentEnterpriseId: event.currentEnterpriseId,
        name: event.name,
        phone: event.phone,
        role: event.role,
        selectedEnterpriseIds: event.selectedEnterpriseIds,
        permissions: event.permissions,
      );

      emit(const UserOperationSuccess('Permissions mises à jour avec succès !'));
      add(LoadEnterpriseUsers(enterpriseId: event.currentEnterpriseId));
    } catch (e) {
      emit(UserOperationFailure('Échec de la mise à jour: $e'));
    }
  }

  Future<void> _onRemoveEnterpriseUser(
    RemoveEnterpriseUserEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(const UserOperationInProgress(message: 'Retrait de l\'utilisateur...'));
    try {
      await _service.removeUserFromEnterprise(event.enterpriseId, event.targetUid);
      emit(const UserOperationSuccess('Utilisateur retiré de l\'entreprise.'));
      add(LoadEnterpriseUsers(enterpriseId: event.enterpriseId));
    } catch (e) {
      emit(UserOperationFailure('Échec du retrait de l\'utilisateur: $e'));
    }
  }
}
