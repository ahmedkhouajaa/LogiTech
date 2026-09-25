import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../models/check_traite.dart';
import '../../models/payment_model.dart';
import '../../models/treasury_transaction.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

// Events
abstract class ChecksTraitesEvent extends Equatable {
  const ChecksTraitesEvent();
  @override
  List<Object?> get props => [];
}

class LoadChecksTraites extends ChecksTraitesEvent {}

class CreateCheckTraite extends ChecksTraitesEvent {
  final CheckTraite document;
  const CreateCheckTraite(this.document);
  @override
  List<Object?> get props => [document];
}

class UpdateCheckTraiteStatus extends ChecksTraitesEvent {
  final String id;
  final String status;
  final String? paymentId;
  final DateTime? dateDepot;
  const UpdateCheckTraiteStatus(this.id, this.status, {this.paymentId, this.dateDepot});
  @override
  List<Object?> get props => [id, status, paymentId, dateDepot];
}

class DepositCheckTraite extends ChecksTraitesEvent {
  final CheckTraite check;
  const DepositCheckTraite(this.check);
  @override
  List<Object?> get props => [check];
}

class RejectCheckTraite extends ChecksTraitesEvent {
  final CheckTraite check;
  const RejectCheckTraite(this.check);
  @override
  List<Object?> get props => [check];
}

class DeleteCheckTraite extends ChecksTraitesEvent {
  final String id;
  const DeleteCheckTraite(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class ChecksTraitesState extends Equatable {
  const ChecksTraitesState();
  @override
  List<Object?> get props => [];
}

class ChecksTraitesInitial extends ChecksTraitesState {}
class ChecksTraitesLoading extends ChecksTraitesState {}

class ChecksTraitesLoaded extends ChecksTraitesState {
  final List<CheckTraite> documents;
  const ChecksTraitesLoaded(this.documents);
  @override
  List<Object?> get props => [documents];
}

class ChecksTraitesError extends ChecksTraitesState {
  final String message;
  const ChecksTraitesError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class ChecksTraitesBloc extends Bloc<ChecksTraitesEvent, ChecksTraitesState> {
  final DatabaseHelper databaseHelper;

  ChecksTraitesBloc({required this.databaseHelper}) : super(ChecksTraitesInitial()) {
    on<LoadChecksTraites>(_onLoadDocuments);
    on<CreateCheckTraite>(_onCreateDocument);
    on<UpdateCheckTraiteStatus>(_onUpdateStatus);
    on<DepositCheckTraite>(_onDepositCheck);
    on<RejectCheckTraite>(_onRejectCheck);
    on<DeleteCheckTraite>(_onDeleteDocument);
  }

  Future<void> _onLoadDocuments(LoadChecksTraites event, Emitter<ChecksTraitesState> emit) async {
    emit(ChecksTraitesLoading());
    try {
      final documents = await databaseHelper.getChecksTraites();
      emit(ChecksTraitesLoaded(documents));

      // Auto-heal any previously deposited checks whose linked document isn't marked paid
      for (final check in documents) {
        if (check.status.toLowerCase().replaceAll('é', 'e') == 'depose') {
          _ensureDocumentMarkedPaid(check);
        }
      }
    } catch (e) {
      emit(ChecksTraitesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onCreateDocument(CreateCheckTraite event, Emitter<ChecksTraitesState> emit) async {
    try {
      await databaseHelper.insertCheckTraite(event.document);
      add(LoadChecksTraites());
    } catch (e) {
      emit(ChecksTraitesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateStatus(UpdateCheckTraiteStatus event, Emitter<ChecksTraitesState> emit) async {
    try {
      await databaseHelper.updateCheckTraiteStatus(
        event.id,
        event.status,
        paymentId: event.paymentId,
        dateDepot: event.dateDepot,
      );
      add(LoadChecksTraites());
    } catch (e) {
      emit(ChecksTraitesError(ErrorHandler.parseError(e)));
    }
  }

  String _resolveCollection(String? docType, String entityType) {
    if (docType == 'facture_vente' || docType == 'invoice') return 'invoices';
    if (docType == 'bon_livraison' || docType == 'delivery_note') return 'delivery_notes';
    if (docType == 'facture_achat' || docType == 'purchase_invoice') return 'purchase_invoices';
    if (docType == 'bon_reception' || docType == 'receiving_voucher') return 'receiving_vouchers';
    return entityType == 'fournisseur' ? 'purchase_invoices' : 'invoices';
  }

  Future<void> _onDepositCheck(DepositCheckTraite event, Emitter<ChecksTraitesState> emit) async {
    try {
      final check = event.check;
      final now = DateTime.now();

      // 1. Resolve linked document (by documentId or documentRef)
      DocumentReference? targetDocRef;
      Map<String, dynamic>? docData;
      String targetCollection = _resolveCollection(check.documentType, check.entityType);

      if (check.documentId != null && check.documentId!.isNotEmpty) {
        final candidateRef = FirebaseFirestore.instance.collection(targetCollection).doc(check.documentId);
        final snap = await candidateRef.get();
        if (snap.exists) {
          targetDocRef = candidateRef;
          docData = snap.data();
        }
      }

      // Robust fallback: search by document number across collections
      if (targetDocRef == null && check.documentRef != null && check.documentRef!.isNotEmpty) {
        final collectionsToSearch = {
          targetCollection,
          'invoices',
          'delivery_notes',
          'purchase_invoices',
          'receiving_vouchers',
        };

        for (final col in collectionsToSearch) {
          final querySnap = await FirebaseFirestore.instance
              .collection(col)
              .where('number', isEqualTo: check.documentRef)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            targetDocRef = querySnap.docs.first.reference;
            docData = querySnap.docs.first.data();
            targetCollection = col;
            break;
          }
        }
      }

      // 2. Update linked document status and amountPaid
      if (targetDocRef != null && docData != null) {
        final currentPaid = double.tryParse(docData['amount_paid']?.toString() ?? '0') ?? 0.0;
        final totalTTC = double.tryParse(docData['total_ttc']?.toString() ?? '0') ?? 0.0;
        final timbre = double.tryParse(docData['timbre_fiscal']?.toString() ?? '0') ?? 0.0;
        final totalDue = totalTTC + timbre;

        final computedPaid = currentPaid + check.amount;
        final newAmountPaid = (totalDue > 0 && computedPaid < totalDue) ? totalDue : computedPaid;
        final newStatus = targetCollection == 'receiving_vouchers' ? 'payee' : 'paid';

        await targetDocRef.set({
          'amount_paid': newAmountPaid,
          'status': newStatus,
          'custom_status': newStatus,
          'updated_at': now.toIso8601String(),
        }, SetOptions(merge: true));
      }

      // 3. Resolve treasury account (fallback to default or first account)
      String? accountId = check.compteTresorerieId;
      if (accountId == null || accountId.isEmpty) {
        try {
          final accsSnap = await FirebaseFirestore.instance.collection('treasury_accounts').limit(1).get();
          if (accsSnap.docs.isNotEmpty) {
            accountId = accsSnap.docs.first.id;
          }
        } catch (_) {}
      }

      // 4. Create Payment record in payments collection
      String? paymentId;
      try {
        final paymentNumber = 'PAI-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');
        final payment = Payment(
          id: const Uuid().v4(),
          paymentNumber: paymentNumber,
          direction: check.isClient ? 'encaissement' : 'decaissement',
          contactId: check.partyId ?? '',
          contactType: check.isClient ? 'customer' : 'supplier',
          contactName: check.partyName,
          amount: check.amount,
          method: check.type,
          accountId: accountId,
          reference: check.reference,
          paymentDate: now,
          notes: 'Dépôt ${check.type == 'traite' ? 'Traite' : 'Chèque'} N° ${check.reference}${check.documentRef != null ? ' (Doc: ${check.documentRef})' : ''}',
          status: 'paid',
          relatedInvoiceId: targetDocRef?.id ?? check.documentId,
          createdAt: now,
          updatedAt: now,
        );
        await FirestoreRepository.instance.savePayment(payment);
        paymentId = payment.id;
      } catch (e) {
        debugPrint('[ChecksTraitesBloc] Error creating payment: $e');
      }

      // 5. Update check status to 'déposé'
      await databaseHelper.updateCheckTraiteStatus(
        check.id,
        'déposé',
        paymentId: paymentId,
        dateDepot: now,
      );

      // 6. Create TreasuryTransaction + update TreasuryAccount balance
      if (accountId != null && accountId.isNotEmpty) {
        final isClient = check.isClient;
        final txType = isClient ? 'income' : 'expense';
        final seq = await databaseHelper.getNextTreasuryTransactionSequence();
        final txNumber = 'TR-${now.year}-${seq.toString().padLeft(6, '0')}';

        final tx = TreasuryTransaction(
          id: const Uuid().v4(),
          transactionNumber: txNumber,
          accountId: accountId,
          amount: check.amount,
          type: txType,
          category: isClient ? 'Encaissement Chèque/Traite' : 'Décaissement Chèque/Traite',
          dateTransaction: now,
          description: 'Dépôt ${check.type == 'traite' ? 'Traite' : 'Chèque'} N° ${check.reference} (${check.partyName})${check.documentRef != null ? ' - Doc: ${check.documentRef}' : ''}',
          paymentId: paymentId,
          createdAt: now,
          updatedAt: now,
        );
        await FirestoreRepository.instance.saveDocument('treasury_transactions', tx.id, tx.toMap());

        // Update account balance
        final accRef = FirebaseFirestore.instance.collection('treasury_accounts').doc(accountId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snap = await transaction.get(accRef);
          if (snap.exists) {
            final curBal = double.tryParse(snap.data()?['balance']?.toString() ?? '0') ?? 0.0;
            final newBal = txType == 'income' ? curBal + check.amount : curBal - check.amount;
            transaction.update(accRef, {'balance': newBal, 'updated_at': now.toIso8601String()});
          }
        });
      }

      add(LoadChecksTraites());
    } catch (e) {
      debugPrint('[ChecksTraitesBloc] Deposit error: $e');
      emit(ChecksTraitesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onRejectCheck(RejectCheckTraite event, Emitter<ChecksTraitesState> emit) async {
    try {
      final check = event.check;
      final now = DateTime.now();
      final wasDeposited = check.status.toLowerCase().replaceAll('é', 'e') == 'depose';

      // 1. Update check status to 'rejeté'
      await databaseHelper.updateCheckTraiteStatus(check.id, 'rejeté');

      // 2. Resolve linked document (by documentId or documentRef)
      DocumentReference? targetDocRef;
      Map<String, dynamic>? docData;
      String targetCollection = _resolveCollection(check.documentType, check.entityType);

      if (check.documentId != null && check.documentId!.isNotEmpty) {
        final candidateRef = FirebaseFirestore.instance.collection(targetCollection).doc(check.documentId);
        final snap = await candidateRef.get();
        if (snap.exists) {
          targetDocRef = candidateRef;
          docData = snap.data();
        }
      }

      if (targetDocRef == null && check.documentRef != null && check.documentRef!.isNotEmpty) {
        final collectionsToSearch = {
          targetCollection,
          'invoices',
          'delivery_notes',
          'purchase_invoices',
          'receiving_vouchers',
        };

        for (final col in collectionsToSearch) {
          final querySnap = await FirebaseFirestore.instance
              .collection(col)
              .where('number', isEqualTo: check.documentRef)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            targetDocRef = querySnap.docs.first.reference;
            docData = querySnap.docs.first.data();
            break;
          }
        }
      }

      if (targetDocRef != null && docData != null) {
        final currentPaid = double.tryParse(docData['amount_paid']?.toString() ?? '0') ?? 0.0;
        final newAmountPaid = wasDeposited ? (currentPaid - check.amount).clamp(0.0, double.infinity) : currentPaid;

        await targetDocRef.set({
          'amount_paid': newAmountPaid,
          'status': 'impayee',
          'custom_status': 'impayee',
          'updated_at': now.toIso8601String(),
        }, SetOptions(merge: true));
      }

      // 3. If was deposited, reverse TreasuryTransaction + reverse TreasuryAccount balance
      String? accountId = check.compteTresorerieId;
      if (accountId == null || accountId.isEmpty) {
        try {
          final accsSnap = await FirebaseFirestore.instance.collection('treasury_accounts').limit(1).get();
          if (accsSnap.docs.isNotEmpty) {
            accountId = accsSnap.docs.first.id;
          }
        } catch (_) {}
      }

      if (wasDeposited && accountId != null && accountId.isNotEmpty) {
        final isClient = check.isClient;
        final revType = isClient ? 'expense' : 'income'; // Reversal
        final seq = await databaseHelper.getNextTreasuryTransactionSequence();
        final txNumber = 'TR-${now.year}-${seq.toString().padLeft(6, '0')}';

        final tx = TreasuryTransaction(
          id: const Uuid().v4(),
          transactionNumber: txNumber,
          accountId: accountId,
          amount: check.amount,
          type: revType,
          category: 'Rejet Chèque/Traite',
          dateTransaction: now,
          description: 'Annulation (Rejet) ${check.type == 'traite' ? 'Traite' : 'Chèque'} N° ${check.reference}${check.documentRef != null ? ' - Doc: ${check.documentRef}' : ''}',
          createdAt: now,
          updatedAt: now,
        );
        await FirestoreRepository.instance.saveDocument('treasury_transactions', tx.id, tx.toMap());

        final accRef = FirebaseFirestore.instance.collection('treasury_accounts').doc(accountId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snap = await transaction.get(accRef);
          if (snap.exists) {
            final curBal = double.tryParse(snap.data()?['balance']?.toString() ?? '0') ?? 0.0;
            final newBal = revType == 'income' ? curBal + check.amount : curBal - check.amount;
            transaction.update(accRef, {'balance': newBal, 'updated_at': now.toIso8601String()});
          }
        });
      }

      add(LoadChecksTraites());
    } catch (e) {
      debugPrint('[ChecksTraitesBloc] Reject error: $e');
      emit(ChecksTraitesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteDocument(DeleteCheckTraite event, Emitter<ChecksTraitesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('checks_traites', event.id);
      await databaseHelper.deleteCheckTraite(event.id);
      add(LoadChecksTraites());
    } catch (e) {
      emit(ChecksTraitesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _ensureDocumentMarkedPaid(CheckTraite check) async {
    try {
      DocumentReference? targetDocRef;
      Map<String, dynamic>? docData;
      String targetCollection = _resolveCollection(check.documentType, check.entityType);

      if (check.documentId != null && check.documentId!.isNotEmpty) {
        final candidateRef = FirebaseFirestore.instance.collection(targetCollection).doc(check.documentId);
        final snap = await candidateRef.get();
        if (snap.exists) {
          targetDocRef = candidateRef;
          docData = snap.data();
        }
      }

      if (targetDocRef == null && check.documentRef != null && check.documentRef!.isNotEmpty) {
        final collectionsToSearch = {
          targetCollection,
          'invoices',
          'delivery_notes',
          'purchase_invoices',
          'receiving_vouchers',
        };
        for (final col in collectionsToSearch) {
          final querySnap = await FirebaseFirestore.instance
              .collection(col)
              .where('number', isEqualTo: check.documentRef)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            targetDocRef = querySnap.docs.first.reference;
            docData = querySnap.docs.first.data();
            targetCollection = col;
            break;
          }
        }
      }

      if (targetDocRef != null && docData != null) {
        final currentStatus = (docData['status']?.toString() ?? '').toLowerCase();
        if (currentStatus != 'paid' && currentStatus != 'payee') {
          final totalTTC = double.tryParse(docData['total_ttc']?.toString() ?? '0') ?? 0.0;
          final timbre = double.tryParse(docData['timbre_fiscal']?.toString() ?? '0') ?? 0.0;
          final totalDue = totalTTC + timbre;
          final currentPaid = double.tryParse(docData['amount_paid']?.toString() ?? '0') ?? 0.0;
          final newAmountPaid = (totalDue > 0 && currentPaid < totalDue) ? totalDue : currentPaid;
          final newStatus = targetCollection == 'receiving_vouchers' ? 'payee' : 'paid';

          await targetDocRef.set({
            'amount_paid': newAmountPaid,
            'status': newStatus,
            'custom_status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('[ChecksTraitesBloc] _ensureDocumentMarkedPaid error: $e');
    }
  }
}
