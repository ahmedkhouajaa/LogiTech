import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/auth_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/permission_service.dart';
import 'package:business_manager_pro/services/error_handler.dart';

// ─── Events ──────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  const AuthSignUpRequested(this.email, this.password, this.name);
  @override
  List<Object?> get props => [email, password, name];
}

class AuthGoogleSignInRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class AuthOfflineModeRequested extends AuthEvent {}

class AuthSessionExpiredEvent extends AuthEvent {
  final String reason;
  const AuthSessionExpiredEvent({this.reason = 'Votre session a expiré. Veuillez vous reconnecter.'});
  @override
  List<Object?> get props => [reason];
}

class AuthAccountDeactivatedEvent extends AuthEvent {
  final String reason;
  const AuthAccountDeactivatedEvent({this.reason = "Votre compte a été désactivé. Contactez l'administrateur."});
  @override
  List<Object?> get props => [reason];
}

// ─── States ──────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final bool isOffline;
  const AuthAuthenticated({this.isOffline = false});
  @override
  List<Object?> get props => [isOffline];
}

class AuthUnauthenticated extends AuthState {}

class AuthSignUpSuccess extends AuthState {
  final String email;
  const AuthSignUpSuccess(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthError extends AuthState {
  final String message;
  final bool isCancellation;
  const AuthError(this.message, {this.isCancellation = false});
  @override
  List<Object?> get props => [message, isCancellation];
}

class AuthSessionExpired extends AuthState {
  final String message;
  const AuthSessionExpired(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthAccountDeactivated extends AuthState {
  final String reason;
  const AuthAccountDeactivated(this.reason);
  @override
  List<Object?> get props => [reason];
}

// ─── BLoC ────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription? _tokenSub;
  StreamSubscription? _deactivationSub;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthOfflineModeRequested>(_onAuthOfflineModeRequested);
    on<AuthSessionExpiredEvent>(_onAuthSessionExpired);
    on<AuthAccountDeactivatedEvent>(_onAuthAccountDeactivated);

    // Listen to token changes for revocation / expiration (Scenarios 15, 18)
    _tokenSub = _authService.idTokenChanges.listen((user) {
      if (user == null && state is AuthAuthenticated && !_authService.isOfflineMode) {
        add(const AuthSessionExpiredEvent(reason: 'Votre session a été fermée ou révoquée.'));
      }
    });

    // Listen to real-time deactivation triggers
    _deactivationSub = _authService.onAccountDeactivated.listen((reason) {
      add(AuthAccountDeactivatedEvent(reason: reason));
    });
  }

  @override
  Future<void> close() {
    _tokenSub?.cancel();
    _deactivationSub?.cancel();
    return super.close();
  }

  void _onAuthAccountDeactivated(AuthAccountDeactivatedEvent event, Emitter<AuthState> emit) {
    emit(AuthAccountDeactivated(event.reason));
  }

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    await _authService.initialize();
    if (_authService.isAuthenticated) {
      await EnterpriseService.instance.loadEnterprisesFromFirestore();
      await PermissionService.instance.loadPermissions();
      emit(AuthAuthenticated(isOffline: _authService.isOfflineMode));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    // Scenario 11: Debounce simultaneous clicks
    if (state is AuthLoading) return;

    emit(AuthLoading());
    try {
      final success = await _authService.login(event.email, event.password);
      if (success) {
        await EnterpriseService.instance.loadEnterprisesFromFirestore();
        await PermissionService.instance.loadPermissions();
        emit(AuthAuthenticated(isOffline: _authService.isOfflineMode));
      } else {
        emit(const AuthError('Identifiants incorrects'));
      }
    } catch (e) {
      emit(AuthError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAuthSignUpRequested(AuthSignUpRequested event, Emitter<AuthState> emit) async {
    if (state is AuthLoading) return;

    emit(AuthLoading());
    try {
      final success = await _authService.signUpWithEmail(event.email, event.password, event.name);
      if (success) {
        emit(AuthSignUpSuccess(event.email));
      } else {
        emit(const AuthError('Erreur lors de l\'inscription'));
      }
    } catch (e) {
      emit(AuthError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAuthGoogleSignInRequested(AuthGoogleSignInRequested event, Emitter<AuthState> emit) async {
    // Scenario 11: Debounce / prevent multiple simultaneous clicks
    if (state is AuthLoading) return;

    emit(AuthLoading());
    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        await EnterpriseService.instance.loadEnterprisesFromFirestore();
        await PermissionService.instance.loadPermissions();
        emit(AuthAuthenticated(isOffline: _authService.isOfflineMode));
      } else {
        emit(const AuthError('Erreur lors de la connexion Google'));
      }
    } catch (e) {
      final message = ErrorHandler.parseError(e);
      final isCancel = message.contains('annulée par l\'utilisateur') ||
          message.toLowerCase().contains('user_cancelled');
      emit(AuthError(message, isCancellation: isCancel));
    }
  }

  Future<void> _onAuthLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authService.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthOfflineModeRequested(AuthOfflineModeRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authService.enableOfflineMode();
    emit(const AuthAuthenticated(isOffline: true));
  }

  void _onAuthSessionExpired(AuthSessionExpiredEvent event, Emitter<AuthState> emit) {
    emit(AuthSessionExpired(event.reason));
  }
}
