import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    String message = e.toString();

    if (e is FirebaseException) {
      code = e.code;
    } else if (e is PlatformException) {
      code = e.code;
      // Sometimes Firestore codes are embedded in the message
      if (message.contains('unavailable') || message.contains('UNAVAILABLE')) {
        code = 'unavailable';
      } else if (message.contains('permission-denied') || message.contains('PERMISSION_DENIED')) {
        code = 'permission-denied';
      } else if (message.contains('not-found') || message.contains('NOT_FOUND')) {
        code = 'not-found';
      }
    } else if (e is SocketException || e is TimeoutException) {
      return "Impossible de se connecter au serveur. Veuillez vérifier votre connexion Internet.";
    }

    // Try to extract Firestore-like code from generic string if not natively caught
    if (code == null && message.contains('unavailable')) {
      code = 'unavailable';
    }

    switch (code) {
      case 'unavailable':
      case 'network-request-failed':
        return "Le service est temporairement indisponible. Veuillez vérifier votre connexion Internet.";
      case 'permission-denied':
        return "Vous n'avez pas les autorisations nécessaires pour effectuer cette action.";
      case 'not-found':
        return "Les données demandées sont introuvables.";
      case 'already-exists':
        return "Cet élément existe déjà.";
      case 'failed-precondition':
        return "Impossible d'effectuer cette opération. Veuillez réessayer.";
      case 'unauthenticated':
        return "Votre session a expiré. Veuillez vous reconnecter.";
      case 'deadline-exceeded':
        return "La requête a mis trop de temps à répondre. Veuillez réessayer.";
      default:
        // Generic fallback for unmapped errors
        return "Une erreur inattendue s'est produite. Veuillez réessayer.";
    }
  }

  /// Show a standardized red SnackBar for form-level or inline errors
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    if (!context.mounted) return;
    final String friendlyMessage = parseError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(friendlyMessage)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
