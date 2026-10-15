import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../utils/file_download_helper.dart';
import '../../../services/error_handler.dart';
import '../../../widgets/app_error_widget.dart';

enum UserModuleType {
  vente,
  achat,
  stock,
  client,
  fournisseur,
  entreprise,
}

class UserDocumentsManagerScreen extends StatefulWidget {
  const UserDocumentsManagerScreen({super.key});

  @override
  State<UserDocumentsManagerScreen> createState() => _UserDocumentsManagerScreenState();
}

class _UserDocumentsManagerScreenState extends State<UserDocumentsManagerScreen> {
  // User selection
  DocumentSnapshot<Map<String, dynamic>>? _selectedUser;
  Map<String, dynamic>? _selectedUserData;
  List<DocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  Map<String, Map<String, dynamic>> _entMap = {};
  bool _isLoadingUsers = true;

  // Active module
  UserModuleType _activeModule = UserModuleType.vente;
  String _subTypeFilter = 'all'; // sub-filter for Vente / Achat / Stock

  // Data list
  bool _isLoadingData = false;
  List<Map<String, dynamic>> _rawDocuments = [];
  String? _errorMessage;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsersAndEnterprises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsersAndEnterprises() async {
    setState(() => _isLoadingUsers = true);
    try {
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('enterprises').get(),
        FirebaseFirestore.instance.collection('users').get(),
      ]);

      final entSnap = futures[0];
      final userSnap = futures[1];

      final Map<String, Map<String, dynamic>> em = {};
      for (final doc in entSnap.docs) {
        em[doc.id] = {'id': doc.id, ...doc.data()};
      }

      setState(() {
        _entMap = em;
        _allUsers = userSnap.docs;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement utilisateurs : $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  /// Collects all enterprise IDs for selected user
  Set<String> _getTargetEnterpriseIds() {
    final ids = <String>{};
    if (_selectedUser == null) return ids;

    final data = _selectedUserData ?? {};
    final userId = _selectedUser!.id;

    final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
    if (curEnt != null && curEnt.toString().trim().isNotEmpty) {
      ids.add(curEnt.toString().trim());
    }

    final rawEnts = data['enterprises'];
    if (rawEnts is List) {
      for (final item in rawEnts) {
        if (item != null && item.toString().trim().isNotEmpty) {
          ids.add(item.toString().trim());
        }
      }
    }

    // Check ownership in _entMap
    for (final entry in _entMap.entries) {
      final entData = entry.value;
      if (entData['ownerId'] == userId || entData['userId'] == userId) {
        ids.add(entry.key);
      }
    }

    return ids;
  }

  /// Fetch documents for the selected user and module
  Future<void> _fetchModuleData() async {
    if (_selectedUser == null) return;

    final userId = _selectedUser!.id;
    final enterpriseIds = _getTargetEnterpriseIds();
    final firestore = FirebaseFirestore.instance;

    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
      _rawDocuments = [];
    });

    // Helper with 3.5s timeout
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeQuery(Query<Map<String, dynamic>> q) async {
      try {
        final snap = await q.get().timeout(const Duration(milliseconds: 3500));
        return snap.docs;
      } catch (_) {
        return const [];
      }
    }

    try {
      final List<Map<String, dynamic>> collected = [];
      final Set<String> seenIds = {};

      void addDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String collectionName, String defaultType) {
        for (final doc in docs) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            final data = Map<String, dynamic>.from(doc.data());
            data['_docId'] = doc.id;
            data['_collection'] = collectionName;
            data['_subType'] = data['document_type'] ?? data['type'] ?? defaultType;
            collected.add(data);
          }
        }
      }

      switch (_activeModule) {
        // 1. VENTE: invoices, quotes, customer_orders, delivery_notes
        case UserModuleType.vente:
          final List<String> collections = ['invoices', 'quotes', 'customer_orders', 'delivery_notes'];
          for (final col in collections) {
            for (final eid in enterpriseIds) {
              final d = await safeQuery(firestore.collection(col).where('enterprise_id', isEqualTo: eid));
              addDocs(d, col, col);
            }
            final dUid = await safeQuery(firestore.collection(col).where('userId', isEqualTo: userId));
            addDocs(dUid, col, col);
          }
          break;

        // 2. ACHAT: purchase_invoices, supplier_orders, receiving_vouchers
        case UserModuleType.achat:
          final List<String> collections = ['purchase_invoices', 'supplier_orders', 'receiving_vouchers'];
          for (final col in collections) {
            for (final eid in enterpriseIds) {
              final d = await safeQuery(firestore.collection(col).where('enterprise_id', isEqualTo: eid));
              addDocs(d, col, col);
            }
            final dUid = await safeQuery(firestore.collection(col).where('userId', isEqualTo: userId));
            addDocs(dUid, col, col);
          }
          break;

        // 3. STOCK: stock_entries, bons_sortie, stock_transfers
        case UserModuleType.stock:
          final List<String> collections = ['stock_entries', 'bons_sortie', 'stock_transfers'];
          for (final col in collections) {
            for (final eid in enterpriseIds) {
              final d = await safeQuery(firestore.collection(col).where('enterprise_id', isEqualTo: eid));
              addDocs(d, col, col);
            }
            final dUid = await safeQuery(firestore.collection(col).where('userId', isEqualTo: userId));
            addDocs(dUid, col, col);
          }
          break;

        // 4. CLIENTS: clients
        case UserModuleType.client:
          for (final eid in enterpriseIds) {
            final d = await safeQuery(firestore.collection('clients').where('enterprise_id', isEqualTo: eid));
            addDocs(d, 'clients', 'client');
          }
          final dUid = await safeQuery(firestore.collection('clients').where('userId', isEqualTo: userId));
          addDocs(dUid, 'clients', 'client');
          break;

        // 5. FOURNISSEURS: fournisseurs
        case UserModuleType.fournisseur:
          for (final eid in enterpriseIds) {
            final d = await safeQuery(firestore.collection('fournisseurs').where('enterprise_id', isEqualTo: eid));
            addDocs(d, 'fournisseurs', 'fournisseur');
          }
          final dUid = await safeQuery(firestore.collection('fournisseurs').where('userId', isEqualTo: userId));
          addDocs(dUid, 'fournisseurs', 'fournisseur');
          break;

        // 6. ENTREPRISES: enterprises
        case UserModuleType.entreprise:
          for (final eid in enterpriseIds) {
            if (_entMap.containsKey(eid)) {
              final ent = Map<String, dynamic>.from(_entMap[eid]!);
              ent['_docId'] = eid;
              ent['_collection'] = 'enterprises';
              ent['_subType'] = 'entreprise';
              if (!seenIds.contains(eid)) {
                seenIds.add(eid);
                collected.add(ent);
              }
            }
          }
          break;
      }

      // Sort by date / updated_at desc
      collected.sort((a, b) {
        final da = a['date'] ?? a['created_at'] ?? a['createdAt'] ?? '';
        final db = b['date'] ?? b['created_at'] ?? b['createdAt'] ?? '';
        return db.toString().compareTo(da.toString());
      });

      if (mounted) {
        setState(() {
          _rawDocuments = collected;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = ErrorHandler.parseError(e);
        });
      }
    }
  }

  // Filtered documents
  List<Map<String, dynamic>> get _filteredDocuments {
    final q = _searchController.text.trim().toLowerCase();

    return _rawDocuments.where((doc) {
      final isDel = doc['is_deleted'] == 1 || doc['is_deleted'] == true || doc['isDeleted'] == true;
      if (isDel) return false;

      // Sub-type filter
      if (_subTypeFilter != 'all') {
        final col = doc['_collection']?.toString();
        if (col != _subTypeFilter) return false;
      }

      // Status filter
      if (_statusFilter != 'all') {
        final status = (doc['status'] ?? doc['etat'] ?? '').toString().toLowerCase();
        if (!status.contains(_statusFilter.toLowerCase())) return false;
      }

      // Query filter
      if (q.isNotEmpty) {
        final num = (doc['number'] ?? doc['code'] ?? doc['id'] ?? doc['_docId'] ?? '').toString().toLowerCase();
        final name = (doc['name'] ?? doc['customerName'] ?? doc['supplierName'] ?? doc['clientName'] ?? doc['title'] ?? '').toString().toLowerCase();
        final desc = (doc['notes'] ?? doc['description'] ?? doc['email'] ?? doc['phone'] ?? '').toString().toLowerCase();
        final total = (doc['totalTTC'] ?? doc['total_ttc'] ?? doc['totalHT'] ?? doc['total_ht'] ?? '').toString().toLowerCase();

        if (!num.contains(q) && !name.contains(q) && !desc.contains(q) && !total.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Add a new document modal
  void _showAddDocumentDialog() {
    if (_selectedUser == null) return;

    final userId = _selectedUser!.id;
    final enterpriseIds = _getTargetEnterpriseIds();
    final defaultEid = enterpriseIds.isNotEmpty ? enterpriseIds.first : null;
    final userName = _selectedUserData?['name'] ?? _selectedUserData?['displayName'] ?? 'Utilisateur';

    // Controllers
    final refCtrl = TextEditingController(text: _generateDefaultReference());
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0.000');
    final notesCtrl = TextEditingController();
    String targetCollection = _getDefaultCollectionForModule();
    String status = 'Payée / Validée';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 600,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                          child: Icon(_getModuleIcon(_activeModule), color: const Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajouter : ${_getModuleName(_activeModule)}',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text('Pour le compte de $userName (ID: $userId)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: isSaving ? null : () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Collection sub-choice if Vente / Achat / Stock
                            if (_activeModule == UserModuleType.vente) ...[
                              const Text('Type de document de vente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: targetCollection,
                                decoration: _dialogInputDecoration(),
                                items: const [
                                  DropdownMenuItem(value: 'invoices', child: Text('Facture de Vente')),
                                  DropdownMenuItem(value: 'quotes', child: Text('Devis Client')),
                                  DropdownMenuItem(value: 'customer_orders', child: Text('Bon de Commande Client')),
                                  DropdownMenuItem(value: 'delivery_notes', child: Text('Bon de Livraison')),
                                ],
                                onChanged: (v) => setDialogState(() => targetCollection = v!),
                              ),
                              const SizedBox(height: 14),
                            ] else if (_activeModule == UserModuleType.achat) ...[
                              const Text('Type de document d\'achat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: targetCollection,
                                decoration: _dialogInputDecoration(),
                                items: const [
                                  DropdownMenuItem(value: 'purchase_invoices', child: Text('Facture d\'Achat')),
                                  DropdownMenuItem(value: 'supplier_orders', child: Text('Bon de Commande Fournisseur')),
                                  DropdownMenuItem(value: 'receiving_vouchers', child: Text('Bon de Réception')),
                                ],
                                onChanged: (v) => setDialogState(() => targetCollection = v!),
                              ),
                              const SizedBox(height: 14),
                            ] else if (_activeModule == UserModuleType.stock) ...[
                              const Text('Type d\'opération stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: targetCollection,
                                decoration: _dialogInputDecoration(),
                                items: const [
                                  DropdownMenuItem(value: 'stock_entries', child: Text('Bon d\'Entrée Stock')),
                                  DropdownMenuItem(value: 'bons_sortie', child: Text('Bon de Sortie Stock')),
                                  DropdownMenuItem(value: 'stock_transfers', child: Text('Transfert de Stock')),
                                ],
                                onChanged: (v) => setDialogState(() => targetCollection = v!),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Numéro / Référence & Nom / Client
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _dialogField(label: 'Numéro / Réf *', controller: refCtrl, hint: 'ex: FAC-2026-001'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: _dialogField(
                                    label: _activeModule == UserModuleType.client
                                        ? 'Nom Client *'
                                        : _activeModule == UserModuleType.fournisseur
                                            ? 'Nom Fournisseur *'
                                            : _activeModule == UserModuleType.entreprise
                                                ? 'Nom Entreprise *'
                                                : 'Partenaire / Client / Libellé *',
                                    controller: nameCtrl,
                                    hint: 'ex: Société ABC',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Phone & Email if client, supplier, or enterprise
                            if (_activeModule == UserModuleType.client || _activeModule == UserModuleType.fournisseur || _activeModule == UserModuleType.entreprise) ...[
                              Row(
                                children: [
                                  Expanded(child: _dialogField(label: 'Téléphone', controller: phoneCtrl, hint: 'ex: 98123456')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _dialogField(label: 'Email', controller: emailCtrl, hint: 'contact@exemple.com')),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Montant & Statut (for financial docs)
                            if (_activeModule == UserModuleType.vente || _activeModule == UserModuleType.achat) ...[
                              Row(
                                children: [
                                  Expanded(child: _dialogField(label: 'Montant Total TTC (DT)', controller: amountCtrl, keyboardType: TextInputType.number)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: status,
                                          decoration: _dialogInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'Payée / Validée', child: Text('Payée / Validée')),
                                            DropdownMenuItem(value: 'En attente', child: Text('En attente')),
                                            DropdownMenuItem(value: 'Brouillon', child: Text('Brouillon')),
                                            DropdownMenuItem(value: 'Annulée', child: Text('Annulée')),
                                          ],
                                          onChanged: (v) => setDialogState(() => status = v!),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Notes / Description
                            _dialogField(label: 'Notes / Détails complémentaires', controller: notesCtrl, hint: 'Remarques ou observations...', maxLines: 2),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(isSaving ? 'Enregistrement...' : 'Créer l\'enregistrement'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  final ref = refCtrl.text.trim();
                                  if (name.isEmpty || ref.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Veuillez renseigner le nom et le numéro/référence.'), backgroundColor: Color(0xFFEF4444)),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  try {
                                    final firestore = FirebaseFirestore.instance;
                                    final newId = firestore.collection(targetCollection).doc().id;
                                    final nowIso = DateTime.now().toIso8601String();
                                    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

                                    final payload = <String, dynamic>{
                                      'id': newId,
                                      'number': ref,
                                      'code': ref,
                                      'name': name,
                                      'title': name,
                                      'customerName': name,
                                      'supplierName': name,
                                      'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                                      'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                                      'totalTTC': amt,
                                      'totalHT': amt / 1.19,
                                      'total_ttc': amt,
                                      'status': status,
                                      'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                      'enterprise_id': defaultEid,
                                      'enterpriseId': defaultEid,
                                      'userId': userId,
                                      'firebase_uid': userId,
                                      'created_at': nowIso,
                                      'updated_at': nowIso,
                                      'is_active': 1,
                                      'is_deleted': 0,
                                    };

                                    // Save to Firestore
                                    await firestore.collection(targetCollection).doc(newId).set(payload);

                                    // Add locally
                                    payload['_docId'] = newId;
                                    payload['_collection'] = targetCollection;
                                    payload['_subType'] = targetCollection;

                                    setState(() {
                                      _rawDocuments = [payload, ..._rawDocuments];
                                    });

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Document "$ref - $name" ajouté avec succès !'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ErrorHandler.showErrorSnackBar(context, e);
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Edit an existing document modal
  void _showEditDocumentDialog(Map<String, dynamic> doc) {
    final docId = doc['_docId'] ?? doc['id'];
    final collection = doc['_collection'] ?? _getDefaultCollectionForModule();

    final refCtrl = TextEditingController(text: (doc['number'] ?? doc['code'] ?? doc['id'] ?? '').toString());
    final nameCtrl = TextEditingController(text: (doc['name'] ?? doc['customerName'] ?? doc['supplierName'] ?? doc['title'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (doc['phone'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (doc['email'] ?? '').toString());
    final amountCtrl = TextEditingController(text: (doc['totalTTC'] ?? doc['total_ttc'] ?? doc['totalHT'] ?? '0.000').toString());
    final notesCtrl = TextEditingController(text: (doc['notes'] ?? doc['description'] ?? '').toString());
    String status = (doc['status'] ?? 'Payée / Validée').toString();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 600,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modifier : ${refCtrl.text}',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text('Collection : $collection • ID: $docId', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: isSaving ? null : () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(flex: 2, child: _dialogField(label: 'Numéro / Code', controller: refCtrl)),
                                const SizedBox(width: 12),
                                Expanded(flex: 3, child: _dialogField(label: 'Nom / Libellé / Tiers', controller: nameCtrl)),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (doc.containsKey('phone') || doc.containsKey('email') || _activeModule == UserModuleType.client || _activeModule == UserModuleType.fournisseur) ...[
                              Row(
                                children: [
                                  Expanded(child: _dialogField(label: 'Téléphone', controller: phoneCtrl)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _dialogField(label: 'Email', controller: emailCtrl)),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],

                            if (doc.containsKey('totalTTC') || doc.containsKey('total_ttc') || _activeModule == UserModuleType.vente || _activeModule == UserModuleType.achat) ...[
                              Row(
                                children: [
                                  Expanded(child: _dialogField(label: 'Total (DT)', controller: amountCtrl, keyboardType: TextInputType.number)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: status,
                                          decoration: _dialogInputDecoration(),
                                          items: [
                                            DropdownMenuItem(value: status, child: Text(status)),
                                            const DropdownMenuItem(value: 'Payée / Validée', child: Text('Payée / Validée')),
                                            const DropdownMenuItem(value: 'En attente', child: Text('En attente')),
                                            const DropdownMenuItem(value: 'Brouillon', child: Text('Brouillon')),
                                            const DropdownMenuItem(value: 'Annulée', child: Text('Annulée')),
                                          ],
                                          onChanged: (v) => setDialogState(() => status = v!),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],

                            _dialogField(label: 'Notes / Détails', controller: notesCtrl, maxLines: 2),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(isSaving ? 'Mise à jour...' : 'Enregistrer Modifications'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  try {
                                    final firestore = FirebaseFirestore.instance;
                                    final nowIso = DateTime.now().toIso8601String();
                                    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

                                    final updates = <String, dynamic>{
                                      'number': refCtrl.text.trim(),
                                      'code': refCtrl.text.trim(),
                                      'name': nameCtrl.text.trim(),
                                      'title': nameCtrl.text.trim(),
                                      'customerName': nameCtrl.text.trim(),
                                      'supplierName': nameCtrl.text.trim(),
                                      'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                                      'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                                      'totalTTC': amt,
                                      'totalHT': amt / 1.19,
                                      'total_ttc': amt,
                                      'status': status,
                                      'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                      'updated_at': nowIso,
                                    };

                                    await firestore.collection(collection).doc(docId).update(updates);

                                    // Update local record
                                    setState(() {
                                      final idx = _rawDocuments.indexWhere((d) => (d['_docId'] ?? d['id']) == docId);
                                      if (idx != -1) {
                                        _rawDocuments[idx].addAll(updates);
                                      }
                                    });

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Document mis à jour avec succès !'), backgroundColor: Color(0xFF10B981)),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erreur mise à jour : $e'), backgroundColor: const Color(0xFFEF4444)),
                                      );
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Delete confirmation
  void _confirmDeleteDocument(Map<String, dynamic> doc) {
    final docId = doc['_docId'] ?? doc['id'];
    final collection = doc['_collection'] ?? _getDefaultCollectionForModule();
    final title = (doc['number'] ?? doc['code'] ?? doc['name'] ?? docId).toString();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Text('Supprimer le document', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Êtes-vous certain de vouloir supprimer définitivement "$title" ?\nCette action est irréversible dans la base Firestore ($collection).',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
                  setState(() {
                    _rawDocuments.removeWhere((d) => (d['_docId'] ?? d['id']) == docId);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Document "$title" supprimé avec succès.'), backgroundColor: const Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur suppression : $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              child: const Text('Supprimer définitivement'),
            ),
          ],
        );
      },
    );
  }

  String _getDefaultCollectionForModule() {
    switch (_activeModule) {
      case UserModuleType.vente: return 'invoices';
      case UserModuleType.achat: return 'purchase_invoices';
      case UserModuleType.stock: return 'stock_entries';
      case UserModuleType.client: return 'clients';
      case UserModuleType.fournisseur: return 'fournisseurs';
      case UserModuleType.entreprise: return 'enterprises';
    }
  }

  String _generateDefaultReference() {
    final ts = DateTime.now().millisecondsSinceEpoch % 10000;
    switch (_activeModule) {
      case UserModuleType.vente: return 'FAC-${DateTime.now().year}-$ts';
      case UserModuleType.achat: return 'ACH-${DateTime.now().year}-$ts';
      case UserModuleType.stock: return 'STK-$ts';
      case UserModuleType.client: return 'CLI-$ts';
      case UserModuleType.fournisseur: return 'FOURN-$ts';
      case UserModuleType.entreprise: return 'ENT-$ts';
    }
  }

  IconData _getModuleIcon(UserModuleType m) {
    switch (m) {
      case UserModuleType.vente: return Icons.shopping_cart_rounded;
      case UserModuleType.achat: return Icons.shopping_bag_rounded;
      case UserModuleType.stock: return Icons.warehouse_rounded;
      case UserModuleType.client: return Icons.groups_rounded;
      case UserModuleType.fournisseur: return Icons.local_shipping_rounded;
      case UserModuleType.entreprise: return Icons.apartment_rounded;
    }
  }

  String _getModuleName(UserModuleType m) {
    switch (m) {
      case UserModuleType.vente: return 'Vente (Factures / Devis)';
      case UserModuleType.achat: return 'Achat (Fournisseurs / Bons)';
      case UserModuleType.stock: return 'Stock (Entrées / Sorties)';
      case UserModuleType.client: return 'Clients';
      case UserModuleType.fournisseur: return 'Fournisseurs';
      case UserModuleType.entreprise: return 'Entreprises';
    }
  }

  void _showUserPickerModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final matching = _allUsers.where((doc) {
              final d = doc.data() ?? {};
              final name = (d['name'] ?? d['displayName'] ?? '').toString().toLowerCase();
              final email = (d['email'] ?? '').toString().toLowerCase();
              final phone = (d['phone'] ?? '').toString().toLowerCase();
              final q = filter.trim().toLowerCase();
              if (q.isEmpty) return true;
              return name.contains(q) || email.contains(q) || phone.contains(q) || doc.id.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 650,
                height: 580,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.person_search_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sélectionner un Utilisateur / Client', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('Choisissez le compte client dont vous voulez inspecter ou éditer les documents', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, email, téléphone ou ID...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                    const SizedBox(height: 14),
                    Text('${matching.length} utilisateur(s) trouvé(s)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Expanded(
                      child: matching.isEmpty
                          ? const Center(child: Text('Aucun utilisateur ne correspond à votre recherche.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
                          : ListView.separated(
                              itemCount: matching.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, i) {
                                final doc = matching[i];
                                final d = doc.data() ?? {};
                                final name = (d['name'] ?? d['displayName'] ?? 'Sans Nom').toString();
                                final email = (d['email'] ?? 'Sans Email').toString();
                                final phone = (d['phone'] ?? '').toString();
                                final isSelected = _selectedUser?.id == doc.id;

                                String entName = '';
                                final curEid = d['currentEnterpriseId'] ?? d['enterpriseId'];
                                if (curEid != null && _entMap.containsKey(curEid.toString())) {
                                  entName = _entMap[curEid.toString()]?['name'] ?? '';
                                }

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                    foregroundColor: isSelected ? Colors.white : const Color(0xFF334155),
                                    child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                  subtitle: Text(
                                    '$email ${phone.isNotEmpty ? "• $phone" : ""} ${entName.isNotEmpty ? "• 🏢 $entName" : ""}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20)
                                      : const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _selectedUser = doc;
                                      _selectedUserData = d;
                                    });
                                    _fetchModuleData();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportCsv() async {
    final list = _filteredDocuments;
    if (list.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('Numero_Code,Nom_Partenaire,Type_Collection,Date,Montant_Total,Statut');
    for (final doc in list) {
      final docNum = (doc['number'] ?? doc['code'] ?? doc['id'] ?? doc['_docId'] ?? '').toString().replaceAll(',', ' ');
      final name = (doc['name'] ?? doc['customerName'] ?? doc['supplierName'] ?? doc['clientName'] ?? doc['title'] ?? '-').toString().replaceAll(',', ' ');
      final col = (doc['_collection'] ?? '').toString().replaceAll(',', ' ');
      final rawDate = doc['date'] ?? doc['created_at'] ?? doc['createdAt'] ?? '';
      final rawAmount = (doc['totalTTC'] ?? doc['total_ttc'] ?? doc['totalHT'] ?? '').toString();
      final status = (doc['status'] ?? doc['etat'] ?? 'Valide').toString().replaceAll(',', ' ');
      buffer.writeln('$docNum,$name,$col,$rawDate,$rawAmount,$status');
    }
    final fileName = 'documents_${_activeModule.name}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    await FileDownloadHelper.saveStringFile(buffer.toString(), fileName, mimeType: 'text/csv', context: context);
  }

  Widget _dialogField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(controller: controller, keyboardType: keyboardType, maxLines: maxLines, decoration: _dialogInputDecoration(hint: hint)),
      ],
    );
  }

  InputDecoration _dialogInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocuments;
    final userName = _selectedUserData?['name'] ?? _selectedUserData?['displayName'] ?? 'Utilisateur Inconnu';
    final userEmail = _selectedUserData?['email'] ?? '';
    final curEid = _selectedUserData?['currentEnterpriseId'] ?? _selectedUserData?['enterpriseId'];
    String entName = 'Entreprise non associée';
    if (curEid != null && _entMap.containsKey(curEid.toString())) {
      entName = _entMap[curEid.toString()]?['name']?.toString() ?? curEid.toString();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Top Header
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 980;

                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Gestion des Documents & Modules Client',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sélectionnez un client et un module (Vente, Achat, Stock, Clients, Fournisseurs, Entreprises) pour inspecter, ajouter, modifier ou supprimer.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_selectedUser != null) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Nouveau Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _showAddDocumentDialog,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Actualiser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isLoadingData ? null : _fetchModuleData,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Exporter CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _exportCsv,
                      ),
                    ],
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_search_rounded, size: 16),
                      label: Text(_selectedUser == null ? 'Sélectionner Client' : 'Changer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoadingUsers ? null : _showUserPickerModal,
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleSection),
                    const SizedBox(width: 14),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // User Info Banner
            if (_selectedUser != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF2563EB),
                      child: Text(userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(userName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFBFDBFE))),
                                child: Text('ID: ${_selectedUser!.id}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('$userEmail • Entreprise : $entName', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Modules Selector Tabs (Achat, Vente, Stock, Client, Fournisseur, Entreprise)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _moduleTab(UserModuleType.vente, 'Vente', Icons.shopping_cart_rounded),
                    _moduleTab(UserModuleType.achat, 'Achat', Icons.shopping_bag_rounded),
                    _moduleTab(UserModuleType.stock, 'Stock', Icons.warehouse_rounded),
                    _moduleTab(UserModuleType.client, 'Clients', Icons.groups_rounded),
                    _moduleTab(UserModuleType.fournisseur, 'Fournisseurs', Icons.local_shipping_rounded),
                    _moduleTab(UserModuleType.entreprise, 'Entreprises', Icons.apartment_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Filtrer par référence, numéro, client, fournisseur...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 17), onPressed: () => setState(() => _searchController.clear()))
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Sub-type filter for Vente/Achat/Stock
                  if (_activeModule == UserModuleType.vente)
                    _subTypeDropdown([
                      {'value': 'all', 'label': 'Tous les documents'},
                      {'value': 'invoices', 'label': 'Factures'},
                      {'value': 'quotes', 'label': 'Devis'},
                      {'value': 'customer_orders', 'label': 'Bons de Commande'},
                      {'value': 'delivery_notes', 'label': 'Bons de Livraison'},
                    ])
                  else if (_activeModule == UserModuleType.achat)
                    _subTypeDropdown([
                      {'value': 'all', 'label': 'Tous les documents'},
                      {'value': 'purchase_invoices', 'label': 'Factures d\'achat'},
                      {'value': 'supplier_orders', 'label': 'Bons de commande'},
                      {'value': 'receiving_vouchers', 'label': 'Bons de réception'},
                    ])
                  else if (_activeModule == UserModuleType.stock)
                    _subTypeDropdown([
                      {'value': 'all', 'label': 'Toutes les opérations'},
                      {'value': 'stock_entries', 'label': 'Entrées de stock'},
                      {'value': 'bons_sortie', 'label': 'Sorties de stock'},
                      {'value': 'stock_transfers', 'label': 'Transferts'},
                    ]),
                  const SizedBox(width: 12),

                  // Status filter dropdown
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tous les statuts')),
                          DropdownMenuItem(value: 'pay', child: Text('Payée / Validée')),
                          DropdownMenuItem(value: 'attente', child: Text('En attente')),
                          DropdownMenuItem(value: 'brouillon', child: Text('Brouillon')),
                          DropdownMenuItem(value: 'annul', child: Text('Annulée')),
                        ],
                        onChanged: (v) => v != null ? setState(() => _statusFilter = v) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Results count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${filtered.length} document(s) trouvé(s)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                if (_selectedUser != null)
                  Text('Module actif : ${_getModuleName(_activeModule)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 8),

            // Content Table
            Expanded(
              child: _selectedUser == null
                  ? Center(
                      child: Container(
                        width: 460,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle), child: const Icon(Icons.folder_shared_rounded, size: 40, color: Color(0xFF2563EB))),
                            const SizedBox(height: 18),
                            const Text('Aucun client sélectionné', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 8),
                            const Text('Sélectionnez un compte client pour explorer, filtrer, créer, modifier ou supprimer ses documents.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_search_rounded, size: 18),
                              label: const Text('Sélectionner un Client'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: _isLoadingUsers ? null : _showUserPickerModal,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? AppErrorWidget(
                              message: _errorMessage!,
                              onRetry: _fetchModuleData,
                            )
                          : filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.folder_open_rounded, color: Color(0xFF94A3B8), size: 44),
                                      const SizedBox(height: 12),
                                      Text('Aucun enregistrement trouvé dans ${_getModuleName(_activeModule)} pour ce client.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 14),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add_rounded, size: 16),
                                        label: const Text('Créer le premier document'),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        onPressed: _showAddDocumentDialog,
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          headingRowHeight: 46,
                                          dataRowMinHeight: 52,
                                          dataRowMaxHeight: 56,
                                          horizontalMargin: 20,
                                          columnSpacing: 24,
                                          columns: const [
                                            DataColumn(label: Text('Numéro / Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                            DataColumn(label: Text('Nom / Partenaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                            DataColumn(label: Text('Type / Collection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                            DataColumn(label: Text('Montant Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                            DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          ],
                                          rows: filtered.map((doc) {
                                            final docRefNum = (doc['number'] ?? doc['code'] ?? doc['id'] ?? doc['_docId'] ?? '').toString();
                                            final name = (doc['name'] ?? doc['customerName'] ?? doc['supplierName'] ?? doc['clientName'] ?? doc['title'] ?? '-').toString();
                                            final col = (doc['_collection'] ?? '').toString();
                                            final rawDate = doc['date'] ?? doc['created_at'] ?? doc['createdAt'];
                                            String dateStr = '-';
                                            if (rawDate != null) {
                                              if (rawDate is Timestamp) {
                                                dateStr = DateFormat('dd/MM/yyyy').format(rawDate.toDate());
                                              } else {
                                                final d = DateTime.tryParse(rawDate.toString());
                                                if (d != null) dateStr = DateFormat('dd/MM/yyyy').format(d);
                                              }
                                            }

                                            final rawAmount = doc['totalTTC'] ?? doc['total_ttc'] ?? doc['totalHT'] ?? doc['total_ht'];
                                            String amountStr = '-';
                                            if (rawAmount != null && rawAmount is num) {
                                              amountStr = '${rawAmount.toStringAsFixed(3)} DT';
                                            }

                                            final status = (doc['status'] ?? doc['etat'] ?? 'Validé').toString();

                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(docRefNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                                                ),
                                                DataCell(
                                                  Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                                ),
                                                DataCell(
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                                    child: Text(col, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                                                  ),
                                                ),
                                                DataCell(Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                                DataCell(Text(amountStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)))),
                                                DataCell(
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: status.toLowerCase().contains('pay') || status.toLowerCase().contains('valid')
                                                          ? const Color(0xFFECFDF5)
                                                          : const Color(0xFFFFFBEB),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: status.toLowerCase().contains('pay') || status.toLowerCase().contains('valid')
                                                            ? const Color(0xFF059669)
                                                            : const Color(0xFFD97706),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                                                        tooltip: 'Modifier ce document',
                                                        onPressed: () => _showEditDocumentDialog(doc),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                                        tooltip: 'Supprimer ce document',
                                                        onPressed: () => _confirmDeleteDocument(doc),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleTab(UserModuleType m, String label, IconData icon) {
    final isSelected = _activeModule == m;
    return InkWell(
      onTap: () {
        setState(() {
          _activeModule = m;
          _subTypeFilter = 'all';
        });
        _fetchModuleData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subTypeDropdown(List<Map<String, String>> items) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _subTypeFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: items.map((it) => DropdownMenuItem(value: it['value']!, child: Text(it['label']!))).toList(),
          onChanged: (v) => v != null ? setState(() => _subTypeFilter = v) : null,
        ),
      ),
    );
  }
}
