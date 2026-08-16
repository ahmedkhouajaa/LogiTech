import 'package:equatable/equatable.dart';
import '../../models/user_management_model.dart';
import '../../models/enterprise.dart';

abstract class UserManagementState extends Equatable {
  const UserManagementState();
  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {}

class UserManagementLoading extends UserManagementState {}

class UserManagementLoaded extends UserManagementState {
  final List<EnterpriseUserModel> users;
  final List<EnterpriseUserModel> filteredUsers;
  final List<Enterprise> ownedEnterprises;
  final bool isCurrentUserAdmin;
  final String? searchQuery;
  final String? roleFilter;

  const UserManagementLoaded({
    required this.users,
    required this.filteredUsers,
    this.ownedEnterprises = const [],
    this.isCurrentUserAdmin = true,
    this.searchQuery,
    this.roleFilter,
  });

  int get totalUsersCount => filteredUsers.length;

  @override
  List<Object?> get props => [
        users,
        filteredUsers,
        ownedEnterprises,
        isCurrentUserAdmin,
        searchQuery,
        roleFilter,
      ];
}

class UserManagementError extends UserManagementState {
  final String message;
  const UserManagementError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Step 1 Email Verification States ──────────────────────────────────────────

class EmailVerificationInProgress extends UserManagementState {}

class EmailVerificationSuccess extends UserManagementState {
  final String uid;
  final String email;
  final String name;
  final String? phone;
  final List<String> existingEnterprises;

  const EmailVerificationSuccess({
    required this.uid,
    required this.email,
    required this.name,
    this.phone,
    this.existingEnterprises = const [],
  });

  @override
  List<Object?> get props => [uid, email, name, phone, existingEnterprises];
}

class EmailVerificationFailure extends UserManagementState {
  final String message;
  const EmailVerificationFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Step 2 / Mutation States ──────────────────────────────────────────────────

class UserOperationInProgress extends UserManagementState {
  final String message;
  const UserOperationInProgress({this.message = 'Traitement en cours...'});
  @override
  List<Object?> get props => [message];
}

class UserOperationSuccess extends UserManagementState {
  final String message;
  const UserOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class UserOperationFailure extends UserManagementState {
  final String message;
  const UserOperationFailure(this.message);
  @override
  List<Object?> get props => [message];
}
