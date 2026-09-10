import 'dart:collection';

/// Result of an anti-spam validation check
class AntiSpamResult {
  final bool isAllowed;
  final int waitSeconds;
  final String message;

  const AntiSpamResult({
    required this.isAllowed,
    this.waitSeconds = 0,
    this.message = '',
  });

  static const AntiSpamResult allowed = AntiSpamResult(isAllowed: true);
}

/// Custom exception thrown when rate limits or anti-spam rules are breached
class AntiSpamException implements Exception {
  final String message;
  final int waitSeconds;

  AntiSpamException(this.message, {this.waitSeconds = 0});

  @override
  String toString() => message;
}

/// In-memory sliding-window rate limiter & anti-bot flood protection guard
class AntiSpamGuard {
  static final AntiSpamGuard _instance = AntiSpamGuard._internal();
  static AntiSpamGuard get instance => _instance;
  AntiSpamGuard._internal();

  // Configuration thresholds
  static const Duration _minMessageInterval = Duration(milliseconds: 1200); // Min 1.2s between msgs
  static const Duration _burstWindow = Duration(seconds: 10);
  static const int _maxBurstCount = 5; // Max 5 messages per 10s
  static const Duration _minuteWindow = Duration(minutes: 1);
  static const int _maxPerMinute = 20; // Max 20 messages per minute
  static const Duration _lockoutDuration = Duration(seconds: 15);
  static const int _violationsBeforeLockout = 3;

  static const Duration _minTicketInterval = Duration(seconds: 8); // Min 8s between new tickets

  // State tracking
  final Queue<DateTime> _messageTimestamps = Queue<DateTime>();
  DateTime? _lastMessageTime;
  String? _lastMessageText;
  DateTime? _lastMessageTextTime;

  DateTime? _lastTicketCreationTime;

  DateTime? _lockoutUntil;
  int _consecutiveViolations = 0;

  /// Check if user is currently in lockout penalty
  bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      _consecutiveViolations = 0;
      return false;
    }
    return true;
  }

  /// Remaining lockout time in seconds
  int get remainingLockoutSeconds {
    if (!isLockedOut || _lockoutUntil == null) return 0;
    final diff = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Validates whether a message is permitted to be sent
  AntiSpamResult checkMessageAllowed(String text) {
    final now = DateTime.now();

    // 1. Check Lockout Penalty
    if (isLockedOut) {
      final remaining = remainingLockoutSeconds;
      return AntiSpamResult(
        isAllowed: false,
        waitSeconds: remaining,
        message: 'Envois temporairement bloqués pour cause de spam. Patientez $remaining seconde(s).',
      );
    }

    // 2. Minimum interval between consecutive messages (Debounce/Flood protection)
    if (_lastMessageTime != null) {
      final elapsed = now.difference(_lastMessageTime!);
      if (elapsed < _minMessageInterval) {
        final waitSec = ((_minMessageInterval - elapsed).inMilliseconds / 1000).ceil();
        _recordViolation();
        return AntiSpamResult(
          isAllowed: false,
          waitSeconds: waitSec > 0 ? waitSec : 1,
          message: 'Veuillez patienter un instant avant d\'envoyer un autre message.',
        );
      }
    }

    // 3. Duplicate message spam detection (same exact text within 4 seconds)
    final trimmed = text.trim();
    if (trimmed.isNotEmpty && trimmed == _lastMessageText && _lastMessageTextTime != null) {
      final textElapsed = now.difference(_lastMessageTextTime!);
      if (textElapsed < const Duration(seconds: 4)) {
        _recordViolation();
        return const AntiSpamResult(
          isAllowed: false,
          waitSeconds: 2,
          message: 'Message identique détecté. Évitez les envois répétitifs.',
        );
      }
    }

    // 4. Sliding Window: Clean expired timestamps
    _cleanupExpiredTimestamps(now);

    // 5. Burst rate check (Max 5 msgs in 10 seconds)
    final recentBurstCount = _messageTimestamps.where((t) => now.difference(t) <= _burstWindow).length;
    if (recentBurstCount >= _maxBurstCount) {
      _recordViolation();
      final oldestInBurst = _messageTimestamps.where((t) => now.difference(t) <= _burstWindow).first;
      final waitSec = _burstWindow.inSeconds - now.difference(oldestInBurst).inSeconds;
      return AntiSpamResult(
        isAllowed: false,
        waitSeconds: waitSec > 0 ? waitSec : 2,
        message: 'Trop de messages rapides. Veuillez patienter $waitSec seconde(s).',
      );
    }

    // 6. Minute rate check (Max 20 msgs in 1 minute)
    if (_messageTimestamps.length >= _maxPerMinute) {
      _recordViolation();
      final waitSec = 60 - now.difference(_messageTimestamps.first).inSeconds;
      return AntiSpamResult(
        isAllowed: false,
        waitSeconds: waitSec > 0 ? waitSec : 5,
        message: 'Limite de messages par minute atteinte. Veuillez patienter un moment.',
      );
    }

    return AntiSpamResult.allowed;
  }

  /// Records a successfully sent message to update rate tracking
  void recordMessageSent(String text) {
    final now = DateTime.now();
    _lastMessageTime = now;
    _lastMessageText = text.trim();
    _lastMessageTextTime = now;
    _messageTimestamps.addLast(now);
    _cleanupExpiredTimestamps(now);

    // Progressive cooldown on success: decrement violation counter
    if (_consecutiveViolations > 0) {
      _consecutiveViolations--;
    }
  }

  /// Validates whether a new ticket creation is permitted
  AntiSpamResult checkTicketCreationAllowed() {
    final now = DateTime.now();

    if (_lastTicketCreationTime != null) {
      final elapsed = now.difference(_lastTicketCreationTime!);
      if (elapsed < _minTicketInterval) {
        final waitSec = _minTicketInterval.inSeconds - elapsed.inSeconds;
        return AntiSpamResult(
          isAllowed: false,
          waitSeconds: waitSec > 0 ? waitSec : 1,
          message: 'Veuillez patienter $waitSec seconde(s) avant de créer un nouveau ticket.',
        );
      }
    }

    return AntiSpamResult.allowed;
  }

  /// Records ticket creation
  void recordTicketCreated() {
    _lastTicketCreationTime = DateTime.now();
  }

  // ─── Authentication Rate Limiting & Anti-Brute Force ─────────────────

  static const Duration _minLoginInterval = Duration(milliseconds: 1500); // Min 1.5s between login attempts
  static const Duration _minSignUpInterval = Duration(seconds: 5);        // Min 5s between signups
  static const Duration _signUpWindow = Duration(minutes: 15);            // 15-minute registration window
  static const int _maxSignUpsInWindow = 3;                               // Max 3 registrations per 15 min

  DateTime? _lastLoginAttemptTime;
  int _failedLoginAttempts = 0;
  DateTime? _loginLockoutUntil;

  DateTime? _lastSignUpAttemptTime;
  final Queue<DateTime> _signUpTimestamps = Queue<DateTime>();

  /// Number of consecutive failed login attempts
  int get failedLoginAttempts => _failedLoginAttempts;

  /// Check if user is currently locked out from logging in
  bool get isLoginLockedOut {
    if (_loginLockoutUntil == null) return false;
    if (DateTime.now().isAfter(_loginLockoutUntil!)) {
      _loginLockoutUntil = null;
      return false;
    }
    return true;
  }

  /// Remaining login lockout in seconds
  int get remainingLoginLockoutSeconds {
    if (!isLoginLockedOut || _loginLockoutUntil == null) return 0;
    final diff = _loginLockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Validates whether a login attempt is permitted
  AntiSpamResult checkLoginAllowed({String? email}) {
    final now = DateTime.now();

    // 1. Check if currently in lockout penalty
    if (_loginLockoutUntil != null) {
      if (now.isBefore(_loginLockoutUntil!)) {
        final remaining = _loginLockoutUntil!.difference(now).inSeconds;
        final waitSec = remaining > 0 ? remaining : 1;
        return AntiSpamResult(
          isAllowed: false,
          waitSeconds: waitSec,
          message: 'Trop de tentatives de connexion échouées. Veuillez patienter $waitSec seconde(s) avant de réessayer.',
        );
      } else {
        _loginLockoutUntil = null;
        _failedLoginAttempts = 4; // Keep in high-risk zone
      }
    }

    // 2. Minimum interval between consecutive attempts
    if (_lastLoginAttemptTime != null) {
      final elapsed = now.difference(_lastLoginAttemptTime!);
      if (elapsed < _minLoginInterval) {
        final waitSec = ((_minLoginInterval - elapsed).inMilliseconds / 1000).ceil();
        return AntiSpamResult(
          isAllowed: false,
          waitSeconds: waitSec > 0 ? waitSec : 1,
          message: 'Veuillez patienter un instant avant de retenter la connexion.',
        );
      }
    }

    return AntiSpamResult.allowed;
  }

  /// Records the result of a login attempt
  void recordLoginResult({String? email, required bool success}) {
    final now = DateTime.now();
    _lastLoginAttemptTime = now;

    if (success) {
      // Clear penalties on successful login
      _failedLoginAttempts = 0;
      _loginLockoutUntil = null;
    } else {
      _failedLoginAttempts++;
      if (_failedLoginAttempts >= 10) {
        // 10+ failed attempts: 5-minute lockout
        _loginLockoutUntil = now.add(const Duration(minutes: 5));
      } else if (_failedLoginAttempts >= 8) {
        // 8-9 failed attempts: 60-second lockout
        _loginLockoutUntil = now.add(const Duration(seconds: 60));
      } else if (_failedLoginAttempts >= 5) {
        // 5-7 failed attempts: 30-second lockout
        _loginLockoutUntil = now.add(const Duration(seconds: 30));
      }
    }
  }

  /// Validates whether a sign-up attempt is permitted
  AntiSpamResult checkSignUpAllowed() {
    final now = DateTime.now();

    // 1. Minimum interval between sign-up clicks
    if (_lastSignUpAttemptTime != null) {
      final elapsed = now.difference(_lastSignUpAttemptTime!);
      if (elapsed < _minSignUpInterval) {
        final waitSec = _minSignUpInterval.inSeconds - elapsed.inSeconds;
        return AntiSpamResult(
          isAllowed: false,
          waitSeconds: waitSec > 0 ? waitSec : 2,
          message: 'Veuillez patienter $waitSec seconde(s) avant de soumettre une nouvelle inscription.',
        );
      }
    }

    // 2. Sliding window check: Max 3 registrations in 15 minutes
    while (_signUpTimestamps.isNotEmpty && now.difference(_signUpTimestamps.first) > _signUpWindow) {
      _signUpTimestamps.removeFirst();
    }

    if (_signUpTimestamps.length >= _maxSignUpsInWindow) {
      final oldest = _signUpTimestamps.first;
      final waitSec = _signUpWindow.inSeconds - now.difference(oldest).inSeconds;
      final waitMin = (waitSec / 60).ceil();
      return AntiSpamResult(
        isAllowed: false,
        waitSeconds: waitSec > 0 ? waitSec : 60,
        message: 'Limite d\'inscriptions atteinte. Veuillez patienter $waitMin minute(s) avant de créer un autre compte.',
      );
    }

    return AntiSpamResult.allowed;
  }

  /// Records the result of a sign-up attempt
  void recordSignUpResult({required bool success}) {
    final now = DateTime.now();
    _lastSignUpAttemptTime = now;
    if (success) {
      _signUpTimestamps.addLast(now);
    }
  }

  void _recordViolation() {
    _consecutiveViolations++;
    if (_consecutiveViolations >= _violationsBeforeLockout) {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
      _consecutiveViolations = 0;
    }
  }

  void _cleanupExpiredTimestamps(DateTime now) {
    while (_messageTimestamps.isNotEmpty && now.difference(_messageTimestamps.first) > _minuteWindow) {
      _messageTimestamps.removeFirst();
    }
  }

  /// Reset all state (useful for tests or logout)
  void reset() {
    _messageTimestamps.clear();
    _lastMessageTime = null;
    _lastMessageText = null;
    _lastMessageTextTime = null;
    _lastTicketCreationTime = null;
    _lockoutUntil = null;
    _consecutiveViolations = 0;

    _lastLoginAttemptTime = null;
    _failedLoginAttempts = 0;
    _loginLockoutUntil = null;

    _lastSignUpAttemptTime = null;
    _signUpTimestamps.clear();
  }
}
