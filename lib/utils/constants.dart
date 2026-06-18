import 'package:flutter/material.dart';

// ─── Colors ───────────────────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF1a56db);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color accent = Color(0xFF0EA5E9);

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF6366F1);
  static const Color infoLight = Color(0xFFE0E7FF);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarText = Color(0xFFCBD5E1);
  static const Color sidebarActive = Color(0xFF1a56db);
  static const Color sidebarHover = Color(0xFF1E293B);
}

// ─── Gradients ────────────────────────────────────────────────────
class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF1a56db), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warning = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient error = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient info = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Spacing ──────────────────────────────────────────────────────
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ─── Border Radius ────────────────────────────────────────────────
class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double full = 999;
}

// ─── Shadows ──────────────────────────────────────────────────────
class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> get md => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
  static List<BoxShadow> get lg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

// ─── Enums ────────────────────────────────────────────────────────
enum DocumentStatus {
  draft,
  created,
  sent,
  accepted,
  rejected,
  converted,
  cancelled;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case created:
        return 'Cree';
      case sent:
        return 'Envoye';
      case accepted:
        return 'Accepte';
      case rejected:
        return 'Refuse';
      case converted:
        return 'Converti';
      case cancelled:
        return 'Annule';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.warning;
      case created:
        return AppColors.info;
      case sent:
        return const Color(0xFFA855F7); // Purple
      case accepted:
        return AppColors.success;
      case rejected:
        return AppColors.error;
      case converted:
        return AppColors.success;
      case cancelled:
        return AppColors.textTertiary;
    }
  }
}

enum InvoiceStatus {
  draft,
  sent,
  partial,
  paid,
  unpaid,
  overdue,
  cancelled;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case sent:
        return 'Envoyee';
      case partial:
        return 'Partiellement payee';
      case paid:
        return 'Payee';
      case unpaid:
        return 'Non paye';
      case overdue:
        return 'En retard';
      case cancelled:
        return 'Annulee';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.textTertiary;
      case sent:
        return AppColors.info;
      case partial:
        return AppColors.warning;
      case paid:
        return AppColors.success;
      case unpaid:
        return AppColors.error;
      case overdue:
        return AppColors.error;
      case cancelled:
        return AppColors.textTertiary;
    }
  }
}

enum OrderStatus {
  pending,
  confirmed,
  inProgress,
  delivered,
  cancelled;

  String get label {
    switch (this) {
      case pending:
        return 'En attente';
      case confirmed:
        return 'Confirmee';
      case inProgress:
        return 'En cours';
      case delivered:
        return 'Livree';
      case cancelled:
        return 'Annulee';
    }
  }
}

enum CustomerOrderStatus {
  draft,
  created,
  inProgress,
  delivered,
  cancelled,
  validated,
  validatedAndInvoiced;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case created:
        return 'Cree';
      case inProgress:
        return 'En cours';
      case delivered:
        return 'Livre';
      case cancelled:
        return 'Annule';
      case validatedAndInvoiced:
        return 'Validee et facturee';
      case validated:
        return 'Validee';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.textTertiary;
      case created:
        return AppColors.primary;
      case inProgress:
        return AppColors.warning;
      case delivered:
        return AppColors.success;
      case cancelled:
        return AppColors.textTertiary;
      case validatedAndInvoiced:
        return AppColors.success;
      case validated:
        return AppColors.success;
    }
  }
}

enum DeliveryNoteStatus {
  draft,
  delivered,
  invoiced,
  returned,
  cancelled;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case delivered:
        return 'Livre';
      case invoiced:
        return 'Livre et Facture';
      case returned:
        return 'Retourne';
      case cancelled:
        return 'Annule';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.textTertiary;
      case delivered:
        return AppColors.success;
      case invoiced:
        return AppColors.primary;
      case returned:
        return AppColors.warning;
      case cancelled:
        return AppColors.error;
    }
  }
}

enum ReturnNoteStatus {
  draft,
  validated,
  cancelled;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case validated:
        return 'Valide';
      case cancelled:
        return 'Annule';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.textTertiary;
      case validated:
        return AppColors.success;
      case cancelled:
        return AppColors.error;
    }
  }
}

enum StockWithdrawalStatus {
  draft,
  validated,
  cancelled;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case validated:
        return 'Valide';
      case cancelled:
        return 'Annule';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.textTertiary;
      case validated:
        return AppColors.success;
      case cancelled:
        return AppColors.error;
    }
  }
}

enum MovementType {
  entry,
  exit,
  transfer,
  adjustment;

  String get label {
    switch (this) {
      case entry:
        return 'Entree';
      case exit:
        return 'Sortie';
      case transfer:
        return 'Transfert';
      case adjustment:
        return 'Ajustement';
    }
  }
}

enum PaymentMethod {
  cash,
  check,
  transfer,
  card,
  traite;

  String get label {
    switch (this) {
      case cash:
        return 'Especes';
      case check:
        return 'Cheque';
      case transfer:
        return 'Virement';
      case card:
        return 'Carte';
      case traite:
        return 'Traite';
    }
  }
}

enum CheckTraiteType {
  checkReceived,
  checkIssued,
  traiteReceived,
  traiteIssued;

  String get label {
    switch (this) {
      case checkReceived:
        return 'Cheque recu';
      case checkIssued:
        return 'Cheque emis';
      case traiteReceived:
        return 'Traite recue';
      case traiteIssued:
        return 'Traite emise';
    }
  }
}

enum CheckTraiteStatus {
  pending,
  deposited,
  cashed,
  returned,
  cancelled;

  String get label {
    switch (this) {
      case pending:
        return 'En attente';
      case deposited:
        return 'Depose';
      case cashed:
        return 'Encaisse';
      case returned:
        return 'Retourne';
      case cancelled:
        return 'Annule';
    }
  }
}

enum ProjectStatus {
  planning,
  active,
  completed,
  onHold,
  cancelled;

  String get label {
    switch (this) {
      case planning:
        return 'Planification';
      case active:
        return 'Actif';
      case completed:
        return 'Termine';
      case onHold:
        return 'En pause';
      case cancelled:
        return 'Annule';
    }
  }
}

enum TransactionType {
  income,
  expense;

  String get label {
    switch (this) {
      case income:
        return 'Recette';
      case expense:
        return 'Depense';
    }
  }
}
enum SupplierOrderStatus {
  draft,
  sent,
  validated,
  partiallyReceived,
  received,
  cancelled;

  String get label {
    switch (this) {
      case draft:
        return 'Brouillon';
      case sent:
        return 'Envoye';
      case validated:
        return 'Valide';
      case partiallyReceived:
        return 'Partiellement recu';
      case received:
        return 'Recu';
      case cancelled:
        return 'Annule';
    }
  }

  Color get color {
    switch (this) {
      case draft:
        return AppColors.textTertiary;
      case sent:
        return AppColors.info;
      case validated:
        return AppColors.success;
      case partiallyReceived:
        return AppColors.warning;
      case received:
        return AppColors.primary;
      case cancelled:
        return AppColors.error;
    }
  }
}

enum SyncOperation {
  insert,
  update,
  delete;
}

// ─── Default TVA Rates (Algeria) ──────────────────────────────────
class TvaRates {
  static const double normal = 19.0;
  static const double reduced = 13.0;
  static const double reduced2 = 9.0;
  static const double reduced3 = 7.0;
  static const double exempt = 0.0;
  static const List<double> all = [19.0, 13.0, 9.0, 7.0, 0.0];
}

// ─── Document Number Prefixes ─────────────────────────────────────
class DocPrefix {
  static const String invoice = 'FAC';
  static const String quote = 'DEV';
  static const String deliveryNote = 'BL';
  static const String creditNote = 'AV';
  static const String purchaseInvoice = 'FA';
  static const String exitVoucher = 'BS';
  static const String returnVoucher = 'BR';
  static const String stockEntry = 'BE';
  static const String stockWithdrawal = 'BP';
  static const String stockTransfer = 'BT';
  static const String inventorySheet = 'FI';
  static const String customerOrder = 'CC';
  static const String supplierOrder = 'CF';
  static const String receivingVoucher = 'BRec';
  static const String supplierCreditNote = 'AVF';
  static const String supplierReturn = 'BRF';
  static const String paymentIn = 'PAI';
  static const String paymentOut = 'DEB';
}
