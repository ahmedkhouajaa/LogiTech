import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/utils/anti_spam_guard.dart';

void main() {
  setUp(() {
    AntiSpamGuard.instance.reset();
  });

  group('AntiSpamGuard Unit Tests', () {
    test('Allows first message', () {
      final res = AntiSpamGuard.instance.checkMessageAllowed('Hello support');
      expect(res.isAllowed, isTrue);
    });

    test('Blocks immediate consecutive message (< 1.2s)', () {
      final res1 = AntiSpamGuard.instance.checkMessageAllowed('Hello support');
      expect(res1.isAllowed, isTrue);
      AntiSpamGuard.instance.recordMessageSent('Hello support');

      // Immediately attempt second message
      final res2 = AntiSpamGuard.instance.checkMessageAllowed('Another message');
      expect(res2.isAllowed, isFalse);
      expect(res2.message, contains('un instant'));
    });

    test('Blocks identical duplicate message in quick succession', () async {
      AntiSpamGuard.instance.checkMessageAllowed('Spam test');
      AntiSpamGuard.instance.recordMessageSent('Spam test');

      // Wait past minimum interval (1.3s)
      await Future.delayed(const Duration(milliseconds: 1300));

      // Attempt identical message
      final dupRes = AntiSpamGuard.instance.checkMessageAllowed('Spam test');
      expect(dupRes.isAllowed, isFalse);
      expect(dupRes.message, contains('identique'));
    });

    test('Allows different message after interval', () async {
      AntiSpamGuard.instance.checkMessageAllowed('First unique');
      AntiSpamGuard.instance.recordMessageSent('First unique');

      await Future.delayed(const Duration(milliseconds: 1300));

      final diffRes = AntiSpamGuard.instance.checkMessageAllowed('Second unique');
      expect(diffRes.isAllowed, isTrue);
    });

    test('Enforces ticket creation interval', () {
      final res1 = AntiSpamGuard.instance.checkTicketCreationAllowed();
      expect(res1.isAllowed, isTrue);
      AntiSpamGuard.instance.recordTicketCreated();

      final res2 = AntiSpamGuard.instance.checkTicketCreationAllowed();
      expect(res2.isAllowed, isFalse);
      expect(res2.message, contains('créer un nouveau ticket'));
    });

    test('Triggers temporary lockout after multiple consecutive violations', () {
      AntiSpamGuard.instance.recordMessageSent('Message');

      // Trigger violations
      AntiSpamGuard.instance.checkMessageAllowed('Msg 1');
      AntiSpamGuard.instance.checkMessageAllowed('Msg 2');
      AntiSpamGuard.instance.checkMessageAllowed('Msg 3');

      expect(AntiSpamGuard.instance.isLockedOut, isTrue);
      expect(AntiSpamGuard.instance.remainingLockoutSeconds, greaterThan(0));

      final blockedRes = AntiSpamGuard.instance.checkMessageAllowed('Msg 4');
      expect(blockedRes.isAllowed, isFalse);
      expect(blockedRes.message, contains('temporairement bloqués'));
    });

    test('Allows initial login attempt', () {
      final res = AntiSpamGuard.instance.checkLoginAllowed(email: 'test@example.com');
      expect(res.isAllowed, isTrue);
    });

    test('Blocks immediate consecutive login attempts (< 1.5s)', () {
      AntiSpamGuard.instance.recordLoginResult(email: 'test@example.com', success: false);
      final res = AntiSpamGuard.instance.checkLoginAllowed(email: 'test@example.com');
      expect(res.isAllowed, isFalse);
      expect(res.message, contains('un instant avant de retenter'));
    });

    test('Triggers 30s lockout after 5 failed login attempts', () {
      for (int i = 0; i < 5; i++) {
        AntiSpamGuard.instance.recordLoginResult(email: 'attacker@evil.com', success: false);
      }

      expect(AntiSpamGuard.instance.isLoginLockedOut, isTrue);
      expect(AntiSpamGuard.instance.remainingLoginLockoutSeconds, greaterThan(0));

      final res = AntiSpamGuard.instance.checkLoginAllowed(email: 'attacker@evil.com');
      expect(res.isAllowed, isFalse);
      expect(res.message, contains('Trop de tentatives de connexion échouées'));
    });

    test('Successful login resets failed attempts counter', () {
      for (int i = 0; i < 4; i++) {
        AntiSpamGuard.instance.recordLoginResult(email: 'user@example.com', success: false);
      }
      expect(AntiSpamGuard.instance.failedLoginAttempts, equals(4));

      // Successful login
      AntiSpamGuard.instance.recordLoginResult(email: 'user@example.com', success: true);
      expect(AntiSpamGuard.instance.failedLoginAttempts, equals(0));
      expect(AntiSpamGuard.instance.isLoginLockedOut, isFalse);
    });

    test('Enforces sign-up interval (< 5s)', () {
      final res1 = AntiSpamGuard.instance.checkSignUpAllowed();
      expect(res1.isAllowed, isTrue);
      AntiSpamGuard.instance.recordSignUpResult(success: true);

      final res2 = AntiSpamGuard.instance.checkSignUpAllowed();
      expect(res2.isAllowed, isFalse);
      expect(res2.message, contains('soumettre une nouvelle inscription'));
    });

    test('Blocks more than 3 sign-ups in 15 minutes', () {
      // Simulate 3 signups spaced by 6 seconds
      for (int i = 0; i < 3; i++) {
        AntiSpamGuard.instance.recordSignUpResult(success: true);
      }

      final res = AntiSpamGuard.instance.checkSignUpAllowed();
      expect(res.isAllowed, isFalse);
    });
  });
}
