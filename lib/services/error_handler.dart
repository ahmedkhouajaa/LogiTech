import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// Structured error model providing human-readable context and actionable next steps.
class ErrorDetails {
  final String title;
  final String whatHappened;
  final String whatToDoNext;
  final IconData icon;

  const ErrorDetails({
    required this.title,
    required this.whatHappened,
    required this.whatToDoNext,
    this.icon = Icons.error_outline_rounded,
  });

  /// Complete message stating what happened and what to do next.
  String get fullMessage {
    final h = whatHappened.trim();
    final n = whatToDoNext.trim();
    if (h.isEmpty) return n;
    if (n.isEmpty) return h;
    final separator = (h.endsWith('.') || h.endsWith('!') || h.endsWith('?')) ? ' ' : '. ';
    return '$h$separator$n';
  }

  @override
  String toString() => fullMessage;
}

class ErrorHandler {
  /// Analyzes any error or exception and extracts structured, user-friendly details:
  /// 1. What happened (clear, human explanation — never raw exceptions or "Error 500")
  /// 2. What to do next (actionable guidance for the user)
  static ErrorDetails parseErrorDetails(dynamic e) {
    if (e == null) {
      return const ErrorDetails(
        title: "Opération interrompue",
        whatHappened: "Une anomalie inattendue a interrompu l'opération en cours.",
        whatToDoNext: "Veuillez rafraîchir l'écran ou réessayer l'action.",
        icon: Icons.info_outline_rounded,
      );
    }

    if (e is ErrorDetails) {
      return e;
    }

    String? code;
    String rawStr = e.toString();
    String message = rawStr.toLowerCase();

    // 1. Firebase Auth Exceptions
    if (e is FirebaseAuthException) {
      code = e.code.toLowerCase();
    } else if (e is FirebaseException) {
      code = e.code.toLowerCase();
    } else if (e is PlatformException) {
      code = e.code.toLowerCase();
      if (message.contains('sign_in_canceled') || message.contains('canceled') || message.contains('cancelled')) {
        code = 'sign_in_canceled';
      }
    }

    // 2. Identify by keywords in message
    if (code == null) {
      if (message.contains('sign_in_canceled') ||
          message.contains('annulé') ||
          message.contains('canceled') ||
          message.contains('cancelled') ||
          message.contains('popup_closed_by_user')) {
        code = 'sign_in_canceled';
      } else if (message.contains('500') ||
          message.contains('internal server error') ||
          message.contains('status code: 500') ||
          message.contains('erreur 500') ||
          message.contains('internal-error')) {
        code = 'server-500';
      } else if (message.contains('502') ||
          message.contains('503') ||
          message.contains('504') ||
          message.contains('bad gateway') ||
          message.contains('service unavailable')) {
        code = 'server-unavailable';
      } else if (e is TimeoutException ||
          e.runtimeType.toString().contains('SocketException') ||
          message.contains('socketexception') ||
          message.contains('failed host lookup') ||
          message.contains('connection timed out') ||
          message.contains('network-request-failed') ||
          message.contains('clientexception') ||
          message.contains('handshakeexception') ||
          message.contains('connexion')) {
        code = 'network-request-failed';
      } else if (message.contains('permission-denied') ||
          message.contains('missing or insufficient permissions') ||
          message.contains('permission denied') ||
          message.contains('droits insuffisants') ||
          message.contains('insuffisantes') ||
          message.contains('403')) {
        code = 'permission-denied';
      } else if (message.contains('token-expired') ||
          message.contains('user-token-expired') ||
          message.contains('session expired') ||
          message.contains('unauthenticated') ||
          message.contains('401')) {
        code = 'user-token-expired';
      } else if (message.contains('user-disabled') || message.contains('user_disabled') || message.contains('suspendu')) {
        code = 'user-disabled';
      } else if (message.contains('account-exists-with-different-credential') ||
          message.contains('credential-already-in-use') ||
          message.contains('email-already-in-use') ||
          message.contains('already-exists') ||
          message.contains('déjà existant') ||
          message.contains('doublon')) {
        code = 'already-exists';
      } else if (message.contains('not-found') || message.contains('introuvable') || message.contains('404')) {
        code = 'not-found';
      } else if (message.contains('formatexception') || message.contains('format invalide') || message.contains('parsing')) {
        code = 'format-exception';
      } else if (message.contains('export')) {
        code = 'export-failed';
      } else if (message.contains('import')) {
        code = 'import-failed';
      } else if (message.contains('null check operator') || message.contains('bad state') || message.contains('rangeerror')) {
        code = 'internal-client-state';
      }
    }

    // 3. Map code to rich ErrorDetails (What happened + What to do next)
    switch (code) {
      case 'server-500':
        return const ErrorDetails(
          title: "Serveur indisponible",
          whatHappened: "Le serveur distant a rencontré une difficulté technique pour traiter votre demande.",
          whatToDoNext: "Veuillez patienter quelques instants puis relancer l'opération. Si le problème persiste, signalez-le au support technique.",
          icon: Icons.cloud_off_rounded,
        );

      case 'server-unavailable':
        return const ErrorDetails(
          title: "Service momentanément interrompu",
          whatHappened: "Le service en ligne est temporairement inaccessible pour maintenance ou surcharge.",
          whatToDoNext: "Veuillez patienter 1 à 2 minutes avant de renouveler votre requête.",
          icon: Icons.dns_rounded,
        );

      case 'network-request-failed':
      case 'unavailable':
        return const ErrorDetails(
          title: "Problème de connexion réseau",
          whatHappened: "Impossible de joindre nos serveurs en ligne.",
          whatToDoNext: "Vérifiez votre connexion Internet (Wi-Fi, Ethernet ou données mobiles) et réessayez.",
          icon: Icons.wifi_off_rounded,
        );

      case 'sign_in_canceled':
      case 'canceled':
      case 'cancelled':
      case 'popup_closed_by_user':
        return const ErrorDetails(
          title: "Connexion interrompue",
          whatHappened: "La tentative de connexion a été annulée avant la fin.",
          whatToDoNext: "Cliquez à nouveau sur le bouton de connexion si vous souhaitez vous identifier.",
          icon: Icons.cancel_outlined,
        );

      case 'user-disabled':
        return const ErrorDetails(
          title: "Compte suspendu",
          whatHappened: "Ce compte utilisateur ou son entreprise a été désactivé par l'administration.",
          whatToDoNext: "Veuillez contacter le support technique ou l'administrateur principal de votre entreprise.",
          icon: Icons.block_rounded,
        );

      case 'permission-denied':
      case 'insufficient-permissions':
        return const ErrorDetails(
          title: "Autorisations insuffisantes",
          whatHappened: "Votre profil utilisateur ne possède pas les permissions requises pour cette action.",
          whatToDoNext: "Vérifiez vos droits d'accès auprès de l'administrateur de votre compte ou reconnectez-vous.",
          icon: Icons.admin_panel_settings_outlined,
        );

      case 'user-token-expired':
      case 'token-expired':
      case 'unauthenticated':
        return const ErrorDetails(
          title: "Session de travail expirée",
          whatHappened: "Votre session a expiré après une période d'inactivité ou de renouvellement de sécurité.",
          whatToDoNext: "Veuillez vous reconnecter pour poursuivre votre saisie en toute sécurité.",
          icon: Icons.lock_clock_rounded,
        );

      case 'not-found':
        return const ErrorDetails(
          title: "Donnée introuvable",
          whatHappened: "L'élément recherché n'a pas été trouvé ou a été déplacé/supprimé.",
          whatToDoNext: "Modifiez vos filtres de recherche ou actualisez la page pour recharger la liste.",
          icon: Icons.search_off_rounded,
        );

      case 'already-exists':
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return const ErrorDetails(
          title: "Élément déjà existant",
          whatHappened: "Un enregistrement avec ce numéro, ce code ou cette adresse email existe déjà dans le système.",
          whatToDoNext: "Veuillez modifier la référence ou l'adresse saisie pour éviter les doublons.",
          icon: Icons.copy_rounded,
        );

      case 'export-failed':
        return const ErrorDetails(
          title: "Échec de l'exportation",
          whatHappened: "Le document n'a pas pu être généré ou enregistré sur votre appareil.",
          whatToDoNext: "Vérifiez que le fichier n'est pas déjà ouvert dans une autre application et que vous disposez des droits d'écriture, puis relancez l'export.",
          icon: Icons.file_download_off_rounded,
        );

      case 'import-failed':
        return const ErrorDetails(
          title: "Échec de l'importation",
          whatHappened: "Le fichier importé présente des anomalies de structure ou des colonnes incompatibles.",
          whatToDoNext: "Vérifiez la conformité du modèle (colonnes obligatoires et types de données), puis réimportez le fichier.",
          icon: Icons.file_upload_outlined,
        );

      case 'format-exception':
        return const ErrorDetails(
          title: "Format non reconnu",
          whatHappened: "Le format des données saisies ou du document sélectionné est invalide.",
          whatToDoNext: "Vérifiez la syntaxe des informations saisies (nombres, dates, texte) avant de valider.",
          icon: Icons.rule_rounded,
        );

      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
      case 'wrong-password':
        return const ErrorDetails(
          title: "Identifiants incorrects",
          whatHappened: "L'identifiant ou le mot de passe renseigné est incorrect ou a expiré.",
          whatToDoNext: "Vérifiez attentivement votre saisie ou utilisez l'option 'Mot de passe oublié'.",
          icon: Icons.vpn_key_off_rounded,
        );

      case 'user-not-found':
        return const ErrorDetails(
          title: "Compte inexistant",
          whatHappened: "Aucun compte utilisateur ne correspond à l'adresse email indiquée.",
          whatToDoNext: "Vérifiez l'orthographe de l'adresse email ou créez un nouveau compte.",
          icon: Icons.person_off_rounded,
        );

      case 'weak-password':
        return const ErrorDetails(
          title: "Mot de passe trop court",
          whatHappened: "Le mot de passe choisi ne répond pas aux normes de sécurité requises.",
          whatToDoNext: "Veuillez choisir un mot de passe d'au moins 6 caractères comprenant lettres et chiffres.",
          icon: Icons.password_rounded,
        );

      case 'too-many-requests':
        return const ErrorDetails(
          title: "Trop de requêtes successives",
          whatHappened: "Le système a restreint temporairement les demandes pour prévenir tout abus.",
          whatToDoNext: "Veuillez patienter 2 à 3 minutes avant de réessayer.",
          icon: Icons.hourglass_top_rounded,
        );

      case 'deadline-exceeded':
        return const ErrorDetails(
          title: "Délai de réponse dépassé",
          whatHappened: "Le serveur a mis trop de temps à répondre à votre requête.",
          whatToDoNext: "Vérifiez votre débit réseau et relancez l'opération.",
          icon: Icons.timer_off_rounded,
        );

      case 'internal-client-state':
        return const ErrorDetails(
          title: "Traitement incomplet",
          whatHappened: "Une incohérence temporaire a empêché la finalisation du traitement.",
          whatToDoNext: "Actualisez la page ou fermez et rouvrez cette boîte de dialogue pour réessayer.",
          icon: Icons.sync_problem_rounded,
        );

      default:
        // Clean any raw technical prefixes from custom string messages
        String cleaned = _cleanRawExceptionString(rawStr);
        String nextStep = "Veuillez vérifier les informations renseignées puis réessayer. Si le problème persiste, contactez le support.";
        
        // If the cleaned message already gives guidance, don't duplicate it
        final lower = cleaned.toLowerCase();
        if (lower.contains('veuillez') || lower.contains('merci de') || lower.contains('essayez') || lower.contains('contactez')) {
          nextStep = "";
        }

        return ErrorDetails(
          title: "Opération interrompue",
          whatHappened: cleaned,
          whatToDoNext: nextStep,
          icon: Icons.error_outline_rounded,
        );
    }
  }

  /// Cleans out raw developer/library prefixes (e.g., 'Exception:', 'Error 500', 'PlatformException(...)')
  static String _cleanRawExceptionString(String input) {
    String text = input.trim();

    // Strip common technical prefixes
    final prefixes = [
      RegExp(r'^Exception:\s*', caseSensitive: false),
      RegExp(r'^Error:\s*', caseSensitive: false),
      RegExp(r'^Erreur\s*:\s*', caseSensitive: false),
      RegExp(r'^PlatformException\([^)]*\)\s*', caseSensitive: false),
      RegExp(r'^ClientException:\s*', caseSensitive: false),
      RegExp(r'^FormatException:\s*', caseSensitive: false),
      RegExp(r'^FirebaseException:\s*', caseSensitive: false),
      RegExp(r'^\[[^\]]+\]\s*'), // e.g. [cloud_firestore/permission-denied]
    ];

    for (final prefix in prefixes) {
      text = text.replaceFirst(prefix, '').trim();
    }

    // Replace technical Error 500 references
    if (text.toLowerCase().contains('error 500') || text.toLowerCase().contains('code: 500')) {
      return "Le serveur a rencontré un dysfonctionnement temporaire lors de l'exécution";
    }

    // If text became empty or only punctuation
    if (text.isEmpty || text == '.' || text == ':') {
      return "Une anomalie s'est produite lors de la validation des données";
    }

    // Capitalize first letter
    return text.substring(0, 1).toUpperCase() + text.substring(1);
  }

  /// Legacy helper returning the full friendly message (What happened + What to do next).
  static String parseError(dynamic e) {
    return parseErrorDetails(e).fullMessage;
  }

  /// Show a standardized red SnackBar for form-level or inline errors
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    final details = parseErrorDetails(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(details.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details.fullMessage,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.amberAccent,
                onPressed: onRetry,
              )
            : null,
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show a friendly modal dialog with clear 'What happened' and 'What to do next' sections
  static Future<void> showRetryableErrorDialog({
    required BuildContext context,
    String? title,
    required dynamic error,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;
    final details = parseErrorDetails(error);
    final displayTitle = title ?? details.title;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(details.icon, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details.whatHappened,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
            ),
            if (details.whatToDoNext.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Que faire maintenant :",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            details.whatToDoNext,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Fermer', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (onRetry != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRetry();
              },
              label: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }
}
