import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class ErrorHandler {
  /// Parse an arbitrary error object and return a user-friendly French message.
  static String parseError(dynamic e) {
    if (e == null) {
      return "Une erreur inattendue s'est produite. Veuillez réessayer.";
    }

    if (e is String) {
      return e;
    }

    String? code;
    String message = e.toString().toLowerCase();

    if (e is FirebaseAuthException) {
      code = e.code.toLowerCase();
    } else if (e is FirebaseException) {
      code = e.code.toLowerCase();
    } else if (e is PlatformException) {
      code = e.code.toLowerCase();
      if (message.contains('sign_in_canceled') || message.contains('canceled') || message.contains('cancelled')) {
        code = 'sign_in_canceled';
      }
    } else if (e is SocketException || e is TimeoutException) {
      return "Aucune connexion Internet ou le serveur ne répond pas. Veuillez vérifier votre connexion et réessayer.";
    }

    // Check message keywords
    if (code == null) {
      if (message.contains('sign_in_canceled') || message.contains('annulé') || message.contains('canceled') || message.contains('cancelled') || message.contains('popup_closed_by_user')) {
        code = 'sign_in_canceled';
      } else if (message.contains('user-disabled') || message.contains('user_disabled')) {
        code = 'user-disabled';
      } else if (message.contains('account-exists-with-different-credential') || message.contains('credential-already-in-use') || message.contains('email-already-in-use')) {
        code = 'account-exists-with-different-credential';
      } else if (message.contains('network') || message.contains('socket') || message.contains('connection timed out')) {
        code = 'network-request-failed';
      } else if (message.contains('token-expired') || message.contains('user-token-expired') || message.contains('session expired')) {
        code = 'user-token-expired';
      }
    }

    switch (code) {
      case 'sign_in_canceled':
      case 'canceled':
      case 'cancelled':
      case 'popup_closed_by_user':
        return "Connexion Google annulée.";
      case 'user-disabled':
        return "Ce compte utilisateur a été désactivé. Veuillez contacter le support technique.";
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return "Cette adresse email est déjà associée à un autre mode de connexion (Email/Mot de passe). Veuillez vous connecter avec vos identifiants habituels.";
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
      case 'wrong-password':
        return "Identifiants de connexion invalides ou expirés. Veuillez réessayer.";
      case 'user-not-found':
        return "Aucun compte n'a été trouvé avec cette adresse email.";
      case 'operation-not-allowed':
        return "La méthode de connexion demandée n'est pas activée.";
      case 'user-token-expired':
      case 'token-expired':
      case 'unauthenticated':
        return "Votre session a expiré. Veuillez vous reconnecter pour continuer.";
      case 'unavailable':
      case 'network-request-failed':
        return "Impossible de se connecter aux serveurs. Veuillez vérifier votre connexion Internet.";
      case 'permission-denied':
        return "Accès refusé. Vous n'avez pas les autorisations nécessaires pour cette opération.";
      case 'not-found':
        return "Les données demandées sont introuvables.";
      case 'already-exists':
        return "Cet élément existe déjà.";
      case 'failed-precondition':
        return "Impossible d'effectuer cette opération dans l'état actuel.";
      case 'invalid-email':
        return "Veuillez saisir une adresse email valide.";
      case 'weak-password':
        return "Le mot de passe doit contenir au moins 6 caractères.";
      case 'expired-action-code':
        return "Le lien de réinitialisation a expiré. Veuillez faire une nouvelle demande.";
      case 'invalid-action-code':
        return "Le lien de réinitialisation est invalide. Veuillez faire une nouvelle demande.";
      case 'too-many-requests':
        return "Trop de tentatives. Veuillez réessayer dans quelques minutes.";
      case 'deadline-exceeded':
        return "La requête a mis trop de temps à répondre. Veuillez réessayer.";
      case 'insufficient-permissions':
        return "Autorisations insuffisantes. Veuillez autoriser l'accès à votre profil et votre adresse email.";
      default:
        return "Une erreur est survenue lors de l'opération. Veuillez réessayer.";
    }
  }

  /// Show a standardized red SnackBar for form-level or inline errors
  static void showErrorSnackBar(BuildContext context, dynamic error, {Duration duration = const Duration(seconds: 5)}) {
    if (!context.mounted) return;
    final String friendlyMessage = parseError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(friendlyMessage, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show a friendly modal dialog with a retry callback
  static Future<void> showRetryableErrorDialog({
    required BuildContext context,
    required String title,
    required dynamic error,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;
    final String friendlyMessage = parseError(error);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          friendlyMessage,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Fermer', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (onRetry != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRetry();
              },
              child: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }
}

