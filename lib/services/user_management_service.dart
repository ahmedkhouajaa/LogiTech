import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/enterprise.dart';
import '../models/user_management_model.dart';
import 'enterprise_service.dart';
import '../utils/firestore_safe_helper.dart';
import 'auth_service.dart';
import 'permission_service.dart';

class EmailVerificationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? userData;

  EmailVerificationResult({
    required this.isValid,
    this.errorMessage,
    this.userData,
  });

  factory EmailVerificationResult.alreadyHasAccount() => EmailVerificationResult(
        isValid: false,
        errorMessage: 'Cet utilisateur a déjà un compte. Veuillez utiliser une autre adresse email.',
      );

  factory EmailVerificationResult.error(String msg) => EmailVerificationResult(
        isValid: false,
        errorMessage: msg,
      );

  factory EmailVerificationResult.available(String cleanEmail) => EmailVerificationResult(
        isValid: true,
        userData: {
          'email': cleanEmail,
          'name': cleanEmail.split('@').first,
        },
      );
}

class UserManagementService {
  static final UserManagementService instance = UserManagementService._();
  UserManagementService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  /// Check if the currently logged in user is an administrator of the given enterprise
  Future<bool> isCurrentUserAdmin(String enterpriseId) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      final data = await FirestoreSafeHelper.getDocData(
        _firestore.collection('enterprises'),
        enterpriseId,
      );
      if (data == null) return false;

      final ownerId = data['owner_id']?.toString() ?? data['userId']?.toString();
      if (ownerId == uid) return true;

      final members = data['members'];
      if (members is List) {
        for (final m in members) {
          if (m is Map && m['uid'] == uid) {
            final role = m['role']?.toString().toLowerCase() ?? '';
            return role == 'admin' || role == 'administrateur';
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get all enterprises owned / managed by the current user
  Future<List<Enterprise>> getOwnedEnterprises() async {
    final uid = currentUid;
    if (uid == null) return [];

    try {
      // First check cached/loaded enterprises in EnterpriseService
      final allUserEnterprises = EnterpriseService.instance.enterprises;
      if (allUserEnterprises.isNotEmpty) {
        return allUserEnterprises.where((e) {
          if (e.ownerId == uid) return true;
          return e.members.any((m) => m.uid == uid && (m.role.toLowerCase() == 'admin' || m.role.toLowerCase() == 'administrateur'));
        }).toList();
      }

      // Query from Firestore if cache is empty
      final userData = await FirestoreSafeHelper.getDocData(
        _firestore.collection('users'),
        uid,
      );
      List<String> enterpriseIds = [];
      if (userData != null && userData['enterprises'] != null) {
        enterpriseIds = List<String>.from(userData['enterprises']);
      }

      final List<Enterprise> result = [];
      for (final eid in enterpriseIds) {
        final entData = await FirestoreSafeHelper.getDocData(
          _firestore.collection('enterprises'),
          eid,
        );
        if (entData != null) {
          final ent = Enterprise.fromMap({...entData, 'id': eid});
          if (ent.ownerId == uid || ent.members.any((m) => m.uid == uid && (m.role.toLowerCase() == 'admin' || m.role.toLowerCase() == 'administrateur'))) {
            result.add(ent);
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error getting owned enterprises: $e');
      return EnterpriseService.instance.enterprises;
    }
  }

  /// Get list of all users who have access to the current enterprise
  Future<List<EnterpriseUserModel>> getUsersForEnterprise(String enterpriseId) async {
    try {
      final entData = await FirestoreSafeHelper.getDocData(
        _firestore.collection('enterprises'),
        enterpriseId,
      );
      if (entData == null) return [];

      final ownerId = entData['owner_id']?.toString() ?? entData['userId']?.toString() ?? '';
      final rawMembers = entData['members'];

      List<Map<String, dynamic>> memberList = [];
      if (rawMembers is List) {
        for (final m in rawMembers) {
          if (m is Map) {
            memberList.add(Map<String, dynamic>.from(m));
          }
        }
      }

      // Ensure owner is included in the list
      final ownerExistsInMembers = memberList.any((m) => m['uid'] == ownerId);
      if (ownerId.isNotEmpty && !ownerExistsInMembers) {
        memberList.insert(0, {
          'uid': ownerId,
          'role': 'admin',
          'isOwner': true,
          'addedAt': null,
        });
      }

      final List<EnterpriseUserModel> users = [];

      for (final member in memberList) {
        final uid = member['uid']?.toString() ?? '';
        if (uid.isEmpty) continue;

        final role = member['role']?.toString() ?? 'collaborator';
        final isOwner = uid == ownerId || member['isOwner'] == true;

        Map<String, UserResourcePermission> permissions = {};
        if (member['permissions'] is Map) {
          final rawPerms = member['permissions'] as Map;
          rawPerms.forEach((k, v) {
            if (v is Map) {
              permissions[k] = UserResourcePermission.fromMap(Map<String, dynamic>.from(v));
            }
          });
        } else {
          permissions = role.toLowerCase() == 'admin'
              ? UserPermissionResources.getAdminDefaultPermissions()
              : UserPermissionResources.getCollaboratorDefaultPermissions();
        }

        // Fetch user profile from users collection
        try {
          final uData = await FirestoreSafeHelper.getDocData(
            _firestore.collection('users'),
            uid,
          ) ?? <String, dynamic>{};
          final userEnterprises = uData['enterprises'] != null ? List<String>.from(uData['enterprises']) : [enterpriseId];

          String? extractField(List<String> keys, List<Map<String, dynamic>?> maps) {
            for (final m in maps) {
              if (m == null) continue;
              for (final k in keys) {
                final v = m[k]?.toString().trim();
                if (v != null && v.isNotEmpty && v != 'null') {
                  return v;
                }
              }
            }
            return null;
          }

          final name = extractField(
            ['name', 'displayName', 'display_name', 'fullName', 'full_name', 'username'],
            [uData, member],
          ) ?? (isOwner ? 'Propriétaire' : 'Utilisateur');

          final email = extractField(
            ['email', 'userEmail', 'user_email', 'mail'],
            [uData, member],
          ) ?? (uid == FirebaseAuth.instance.currentUser?.uid ? (FirebaseAuth.instance.currentUser?.email ?? '') : '');

          String? phone = extractField(
            ['phone', 'phoneNumber', 'phone_number', 'telephone', 'tel', 'mobile', 'contactPhone', 'contact_phone'],
            [uData, member, if (isOwner) entData],
          );

          if ((phone == null || phone.isEmpty) && uid == FirebaseAuth.instance.currentUser?.uid) {
            final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
            if (authPhone != null && authPhone.isNotEmpty) {
              phone = authPhone;
            }
          }

          users.add(EnterpriseUserModel(
            uid: uid,
            name: name,
            email: email,
            phone: phone,
            role: role,
            enterprises: userEnterprises,
            permissions: permissions,
            isOwner: isOwner,
            addedBy: member['addedBy']?.toString(),
            addedAt: member['addedAt'] != null
                ? (member['addedAt'] is Timestamp
                    ? (member['addedAt'] as Timestamp).toDate()
                    : DateTime.tryParse(member['addedAt'].toString()))
                : null,
            isActive: uData['isActive'] != false,
          ));
        } catch (e) {
          debugPrint('Error fetching user profile for $uid: $e');
        }
      }

      return users;
    } catch (e) {
      debugPrint('Error getUsersForEnterprise: $e');
      return [];
    }
  }

  /// Step 1: Verify email does NOT exist (must be a new user account)
  Future<EmailVerificationResult> verifyUserEmail(String email, String currentEnterpriseId) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return EmailVerificationResult.error('Veuillez saisir une adresse email valide.');
    }

    try {
      // 1. Check if user already exists in Firestore users collection
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        return EmailVerificationResult.alreadyHasAccount();
      }

      // 2. Check if email is already in any enterprise members list
      final entData = await FirestoreSafeHelper.getDocData(
        _firestore.collection('enterprises'),
        currentEnterpriseId,
      );
      if (entData != null) {
        final members = entData['members'];
        if (members is List) {
          for (final m in members) {
            if (m is Map && m['email'] != null && m['email'].toString().toLowerCase() == cleanEmail) {
              return EmailVerificationResult.alreadyHasAccount();
            }
          }
        }
      }

      // Email is available for creating a new user
      return EmailVerificationResult.available(cleanEmail);
    } catch (e) {
      debugPrint('Error during email verification: $e');
      return EmailVerificationResult.error('Erreur lors de la vérification : $e');
    }
  }

  /// Step 2 Confirmation: Create brand new user account in Firebase Auth and add to enterprises
  Future<void> createAndAddUserToEnterprises({
    required String email,
    required String name,
    String? phone,
    String? password,
    bool sendInvitationEmail = true,
    required String role,
    required List<String> selectedEnterpriseIds,
    required Map<String, UserResourcePermission> permissions,
  }) async {
    final isAdminRole = role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrateur';
    if (isAdminRole && !PermissionService.instance.isOwner) {
      throw 'Seul le propriétaire de l\'entreprise peut attribuer le rôle Administrateur.';
    }

    final adminUid = currentUid ?? 'admin';
    final now = DateTime.now();
    final cleanEmail = email.trim().toLowerCase();
    final effectivePassword = (password != null && password.trim().isNotEmpty)
        ? password.trim()
        : 'TempPass_${DateTime.now().millisecondsSinceEpoch}!';

    String newUid = '';

    // 1. Create user in Firebase Authentication via secondary FirebaseApp to avoid signing out the current admin
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'UserCreationApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final userCred = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
        email: cleanEmail,
        password: effectivePassword,
      );

      final newUser = userCred.user;
      if (newUser == null) {
        throw 'Échec de la création du compte utilisateur dans Firebase Auth.';
      }
      newUid = newUser.uid;

      try {
        await newUser.updateDisplayName(name);
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'Cet utilisateur a déjà un compte. Veuillez utiliser une autre adresse email.';
      } else if (e.code == 'weak-password') {
        throw 'Le mot de passe est trop faible. Veuillez choisir au moins 6 caractères.';
      } else {
        throw 'Erreur Firebase Auth: ${e.message ?? e.code}';
      }
    } finally {
      await tempApp.delete();
    }

    // 2. Send password setup / invitation email if requested
    if (sendInvitationEmail) {
      try {
        await AuthService.instance.sendPasswordResetEmail(cleanEmail);
      } catch (e) {
        debugPrint('Invitation email error: $e');
      }
    }

    final permissionsMap = permissions.map((k, v) => MapEntry(k, v.toMap()));
    final memberData = {
      'uid': newUid,
      'email': cleanEmail,
      'name': name,
      if (phone != null && phone.isNotEmpty) ...{
        'phone': phone,
        'phoneNumber': phone,
        'phone_number': phone,
      },
      'role': role,
      'permissions': permissionsMap,
      'addedBy': adminUid,
      'addedAt': now.toIso8601String(),
    };

    // 3. Create document in Firestore users collection
    final enterpriseRolesMap = <String, dynamic>{};
    for (final eid in selectedEnterpriseIds) {
      enterpriseRolesMap[eid] = {
        'role': role,
        'permissions': permissionsMap,
        'addedBy': adminUid,
        'addedAt': now.toIso8601String(),
      };
    }

    await _firestore.collection('users').doc(newUid).set({
      'uid': newUid,
      'email': cleanEmail,
      'name': name,
      'role': role,
      if (phone != null && phone.isNotEmpty) ...{
        'phone': phone,
        'phoneNumber': phone,
        'phone_number': phone,
      },
      'enterprises': selectedEnterpriseIds,
      'enterpriseRoles': enterpriseRolesMap,
      'currentEnterpriseId': selectedEnterpriseIds.isNotEmpty ? selectedEnterpriseIds.first : null,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': null,
    }, SetOptions(merge: true));

    // 4. Update each selected enterprise document
    for (final eid in selectedEnterpriseIds) {
      final enterpriseRef = _firestore.collection('enterprises').doc(eid);
      final enterpriseDoc = await enterpriseRef.get();

      if (enterpriseDoc.exists) {
        final currentMembers = List<Map<String, dynamic>>.from(
          (enterpriseDoc.data()?['members'] as List? ?? []).map((m) => Map<String, dynamic>.from(m)),
        );

        currentMembers.removeWhere((m) => m['uid'] == newUid || (m['email'] != null && m['email'].toString().toLowerCase() == cleanEmail));
        currentMembers.add(memberData);

        await enterpriseRef.set({
          'members': currentMembers,
          'updated_at': now.toIso8601String(),
        }, SetOptions(merge: true));
      }
    }
  }

  /// Update existing user role, permissions, and enterprises
  Future<void> updateUserInEnterprise({
    required String targetUid,
    required String currentEnterpriseId,
    required String name,
    String? phone,
    required String role,
    required List<String> selectedEnterpriseIds,
    required Map<String, UserResourcePermission> permissions,
  }) async {
    final adminUid = currentUid ?? 'admin';
    final now = DateTime.now();

    // Security hierarchy check:
    // 1. Owner cannot be modified by ANY user
    final entData = await FirestoreSafeHelper.getDocData(
      _firestore.collection('enterprises'),
      currentEnterpriseId,
    );
    final ownerId = entData?['owner_id']?.toString() ?? entData?['userId']?.toString() ?? '';
    if (ownerId.isNotEmpty && ownerId == targetUid) {
      throw 'Impossible de modifier le profil du propriétaire de l\'entreprise.';
    }

    // 2. Only Owner can manage an Admin or assign the Admin role
    if (!PermissionService.instance.isOwner) {
      final isAdminRole = role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrateur';
      if (isAdminRole) {
        throw 'Seul le propriétaire de l\'entreprise peut attribuer le rôle Administrateur.';
      }

      final members = entData?['members'];
      if (members is List) {
        for (final m in members) {
          if (m is Map && m['uid'] == targetUid) {
            final mRole = m['role']?.toString().toLowerCase() ?? '';
            if (mRole == 'admin' || mRole == 'administrateur' || m['isOwner'] == true) {
              throw 'Seul le propriétaire de l\'entreprise peut gérer un administrateur.';
            }
          }
        }
      }
    }

    final permissionsMap = permissions.map((k, v) => MapEntry(k, v.toMap()));

    // 1. Update user profile document in users collection
    final userRef = _firestore.collection('users').doc(targetUid);
    final userDoc = await userRef.get();

    List<String> currentEnterprises = [];
    if (userDoc.exists && userDoc.data()?['enterprises'] != null) {
      currentEnterprises = List<String>.from(userDoc.data()!['enterprises']);
    }

    for (final eid in selectedEnterpriseIds) {
      if (!currentEnterprises.contains(eid)) {
        currentEnterprises.add(eid);
      }
    }

    final enterpriseRolesUpdate = <String, dynamic>{};
    for (final eid in selectedEnterpriseIds) {
      enterpriseRolesUpdate[eid] = {
        'role': role,
        'permissions': permissionsMap,
        'addedBy': adminUid,
        'addedAt': now.toIso8601String(),
      };
    }

    await userRef.set({
      'name': name,
      'role': role,
      if (phone != null && phone.isNotEmpty) ...{
        'phone': phone,
        'phoneNumber': phone,
        'phone_number': phone,
      },
      'enterprises': currentEnterprises,
      'enterpriseRoles': enterpriseRolesUpdate,
      'updated_at': now.toIso8601String(),
    }, SetOptions(merge: true));

    // 2. Update enterprise documents
    for (final eid in selectedEnterpriseIds) {
      final enterpriseRef = _firestore.collection('enterprises').doc(eid);
      final enterpriseDoc = await enterpriseRef.get();

      if (enterpriseDoc.exists) {
        final currentMembers = List<Map<String, dynamic>>.from(
          (enterpriseDoc.data()?['members'] as List? ?? []).map((m) => Map<String, dynamic>.from(m)),
        );

        final email = userDoc.exists ? (userDoc.data()?['email']?.toString() ?? '') : '';

        currentMembers.removeWhere((m) => m['uid'] == targetUid);
        currentMembers.add({
          'uid': targetUid,
          'email': email,
          'name': name,
          if (phone != null && phone.isNotEmpty) ...{
            'phone': phone,
            'phoneNumber': phone,
            'phone_number': phone,
          },
          'role': role,
          'permissions': permissionsMap,
          'addedBy': adminUid,
          'addedAt': now.toIso8601String(),
        });

        await enterpriseRef.set({
          'members': currentMembers,
          'updated_at': now.toIso8601String(),
        }, SetOptions(merge: true));
      }
    }

    if (targetUid == currentUid) {
      await PermissionService.instance.loadPermissions();
    }
  }

  /// Remove user from a specific enterprise
  Future<void> removeUserFromEnterprise(String enterpriseId, String targetUid) async {
    final now = DateTime.now();

    // Security hierarchy check:
    // 1. Owner cannot be removed by ANY user
    final entData = await FirestoreSafeHelper.getDocData(
      _firestore.collection('enterprises'),
      enterpriseId,
    );
    final ownerId = entData?['owner_id']?.toString() ?? entData?['userId']?.toString() ?? '';
    if (ownerId.isNotEmpty && ownerId == targetUid) {
      throw 'Impossible de retirer le propriétaire de l\'entreprise.';
    }

    // 2. Only Owner can remove an Admin
    if (!PermissionService.instance.isOwner) {
      final members = entData?['members'];
      if (members is List) {
        for (final m in members) {
          if (m is Map && m['uid'] == targetUid) {
            final mRole = m['role']?.toString().toLowerCase() ?? '';
            if (mRole == 'admin' || mRole == 'administrateur' || m['isOwner'] == true) {
              throw 'Seul le propriétaire de l\'entreprise peut retirer un administrateur.';
            }
          }
        }
      }
    }

    // 1. Remove from enterprise document members list
    final enterpriseRef = _firestore.collection('enterprises').doc(enterpriseId);
    final enterpriseDoc = await enterpriseRef.get();

    if (enterpriseDoc.exists) {
      final currentMembers = List<Map<String, dynamic>>.from(
        (enterpriseDoc.data()?['members'] as List? ?? []).map((m) => Map<String, dynamic>.from(m)),
      );

      currentMembers.removeWhere((m) => m['uid'] == targetUid);

      await enterpriseRef.set({
        'members': currentMembers,
        'updated_at': now.toIso8601String(),
      }, SetOptions(merge: true));
    }

    // 2. Remove enterprise from user's enterprises array
    final userRef = _firestore.collection('users').doc(targetUid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      List<String> currentEnterprises = [];
      if (userDoc.data()?['enterprises'] != null) {
        currentEnterprises = List<String>.from(userDoc.data()!['enterprises']);
      }
      currentEnterprises.remove(enterpriseId);

      await userRef.set({
        'enterprises': currentEnterprises,
        'enterpriseRoles': {
          enterpriseId: FieldValue.delete(),
        },
        'updated_at': now.toIso8601String(),
      }, SetOptions(merge: true));
    }
  }
}
