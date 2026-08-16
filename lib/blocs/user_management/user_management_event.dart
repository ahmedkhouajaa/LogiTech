import 'package:equatable/equatable.dart';
import '../../models/user_management_model.dart';

abstract class UserManagementEvent extends Equatable {
  const UserManagementEvent();
  @override
  List<Object?> get props => [];
}

/// Load list of users for the current enterprise
class LoadEnterpriseUsers extends UserManagementEvent {
  final String? enterpriseId;
  final String? searchQuery;
  final String? roleFilter;

  const LoadEnterpriseUsers({
    this.enterpriseId,
    this.searchQuery,
    this.roleFilter,
  });

  @override
  List<Object?> get props => [enterpriseId, searchQuery, roleFilter];
}

/// Step 1: Verify user email before proceeding to configure access
class VerifyUserEmailEvent extends UserManagementEvent {
  final String email;
  final String currentEnterpriseId;

  const VerifyUserEmailEvent({
    required this.email,
    required this.currentEnterpriseId,
  });

  @override
  List<Object?> get props => [email, currentEnterpriseId];
}

/// Reset the email verification state when navigating back
class ResetEmailVerificationEvent extends UserManagementEvent {}

/// Step 2: Add verified user to selected enterprises
class AddEnterpriseUserEvent extends UserManagementEvent {
  final String email;
  final String name;
  final String? phone;
  final String? password;
  final bool sendInvitationEmail;
  final String role;
  final List<String> selectedEnterpriseIds;
  final Map<String, UserResourcePermission> permissions;
  final String currentEnterpriseId;

  const AddEnterpriseUserEvent({
    required this.email,
    required this.name,
    this.phone,
    this.password,
    this.sendInvitationEmail = true,
    required this.role,
    required this.selectedEnterpriseIds,
    required this.permissions,
    required this.currentEnterpriseId,
  });

  @override
  List<Object?> get props => [
        email,
        name,
        phone,
        password,
        sendInvitationEmail,
        role,
        selectedEnterpriseIds,
        permissions,
        currentEnterpriseId,
      ];
}

/// Update an existing user's role, permissions, and enterprise assignments
class UpdateEnterpriseUserEvent extends UserManagementEvent {
  final String targetUid;
  final String name;
  final String? phone;
  final String role;
  final List<String> selectedEnterpriseIds;
  final Map<String, UserResourcePermission> permissions;
  final String currentEnterpriseId;

  const UpdateEnterpriseUserEvent({
    required this.targetUid,
    required this.name,
    this.phone,
    required this.role,
    required this.selectedEnterpriseIds,
    required this.permissions,
    required this.currentEnterpriseId,
  });

  @override
  List<Object?> get props => [
        targetUid,
        name,
        phone,
        role,
        selectedEnterpriseIds,
        permissions,
        currentEnterpriseId,
      ];
}

/// Remove user from the current enterprise
class RemoveEnterpriseUserEvent extends UserManagementEvent {
  final String enterpriseId;
  final String targetUid;

  const RemoveEnterpriseUserEvent({
    required this.enterpriseId,
    required this.targetUid,
  });

  @override
  List<Object?> get props => [enterpriseId, targetUid];
}
