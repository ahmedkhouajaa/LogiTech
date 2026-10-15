import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/product.dart';
import '../../../utils/file_download_helper.dart';
import '../../../services/error_handler.dart';
import '../../../widgets/app_error_widget.dart';

class UserArticlesScreen extends StatefulWidget {
  const UserArticlesScreen({super.key});

  @override
  State<UserArticlesScreen> createState() => _UserArticlesScreenState();
}

class _UserArticlesScreenState extends State<UserArticlesScreen> {
  // User selection state
  DocumentSnapshot<Map<String, dynamic>>? _selectedUser;
  Map<String, dynamic>? _selectedUserData;
  List<DocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  Map<String, Map<String, dynamic>> _entMap = {};
  bool _isLoadingUsers = true;

  // Search user controller & filter
  final TextEditingController _userSearchController = TextEditingController();

  // Articles state
  bool _isLoadingArticles = false;
  List<Product> _userArticles = [];
  String? _articlesErrorMessage;

  // Article filters
  final TextEditingController _articleFilterController = TextEditingController();
  String _stockStatusFilter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  String _selectedCategory = 'all';
  bool _includeDeleted = false;

  @override
  void initState() {
    super.initState();
    _loadUsersAndEnterprises();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _articleFilterController.dispose();
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
          SnackBar(
            content: Text('Erreur chargement utilisateurs : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Finds and loads all articles belonging to the selected user / enterprises
  Future<void> _fetchArticlesForUser(DocumentSnapshot<Map<String, dynamic>> userDoc) async {
    final userId = userDoc.id;
    final data = userDoc.data() ?? {};

    setState(() {
      _selectedUser = userDoc;
      _selectedUserData = data;
      _isLoadingArticles = true;
      _articlesErrorMessage = null;
      _userArticles = [];
      _selectedCategory = 'all';
    });

    try {
      // 1. Collect all enterprise IDs associated with this user
      final targetEnterpriseIds = <String>{};

      final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
      if (curEnt != null && curEnt.toString().trim().isNotEmpty) {
        targetEnterpriseIds.add(curEnt.toString().trim());
      }

      final rawEnts = data['enterprises'];
      if (rawEnts is List) {
        for (final item in rawEnts) {
          if (item != null && item.toString().trim().isNotEmpty) {
            targetEnterpriseIds.add(item.toString().trim());
          }
        }
      }

      // Check if user is owner of any enterprise in the directory
      for (final entry in _entMap.entries) {
        final entData = entry.value;
        if (entData['ownerId'] == userId || entData['userId'] == userId) {
          targetEnterpriseIds.add(entry.key);
        }
      }

      final Map<String, Product> articleMap = {};
      final firestore = FirebaseFirestore.instance;

      // Safe query helper with 3.5s timeout to guarantee zero stalling
      Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeQuery(Query<Map<String, dynamic>> q) async {
        try {
          final snap = await q.get().timeout(const Duration(milliseconds: 3500));
          return snap.docs;
        } catch (_) {
          return const [];
        }
      }

      final List<Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>> queryFutures = [];

      // 1. Primary: Query articles by enterprise_id (standard and fastest)
      for (final eid in targetEnterpriseIds) {
        queryFutures.add(safeQuery(firestore.collection('articles').where('enterprise_id', isEqualTo: eid)));
      }

      // 2. Query articles by user id / firebase_uid
      queryFutures.add(safeQuery(firestore.collection('articles').where('firebase_uid', isEqualTo: userId)));
      queryFutures.add(safeQuery(firestore.collection('articles').where('userId', isEqualTo: userId)));

      // Execute all concurrently with timeouts
      final queryResults = await Future.wait(queryFutures);

      for (final docList in queryResults) {
        for (final doc in docList) {
          if (!articleMap.containsKey(doc.id)) {
            final docData = Map<String, dynamic>.from(doc.data());
            docData['id'] = doc.id;
            try {
              final prod = Product.fromMap(docData);
              articleMap[doc.id] = prod;
            } catch (err) {
              // Fallback safe manual parse
              final prod = Product(
                id: doc.id,
                code: (docData['code'] ?? '').toString(),
                name: (docData['name'] ?? 'Sans Nom').toString(),
                reference: docData['reference']?.toString(),
                description: docData['description']?.toString(),
                category: docData['category']?.toString(),
                purchasePrice: (docData['purchase_price'] ?? docData['purchasePrice'] ?? 0.0).toDouble(),
                sellingPrice: (docData['selling_price'] ?? docData['sellingPrice'] ?? 0.0).toDouble(),
                stockQty: (docData['stock_qty'] ?? docData['stockQty'] ?? 0.0).toDouble(),
                enterpriseId: (docData['enterprise_id'] ?? docData['enterpriseId'])?.toString(),
                firebaseUid: (docData['firebase_uid'] ?? docData['userId'])?.toString(),
                isDeleted: docData['is_deleted'] == 1 || docData['is_deleted'] == true,
              );
              articleMap[doc.id] = prod;
            }
          }
        }
      }

      final list = articleMap.values.toList();
      // Sort alphabetically by name
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _userArticles = list;
          _isLoadingArticles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingArticles = false;
          _articlesErrorMessage = ErrorHandler.parseError(e);
        });
      }
    }
  }

  // Filtered list based on search, stock status, category and deletion
  List<Product> get _filteredArticles {
    final q = _articleFilterController.text.trim().toLowerCase();

    return _userArticles.where((article) {
      if (!_includeDeleted && article.isDeleted) return false;

      // Stock status filter
      if (_stockStatusFilter == 'in_stock' && article.stockQty <= 0) return false;
      if (_stockStatusFilter == 'out_of_stock' && article.stockQty > 0) return false;
      if (_stockStatusFilter == 'low_stock' && !article.isLowStock) return false;

      // Category filter
      if (_selectedCategory != 'all' && (article.category ?? '') != _selectedCategory) {
        return false;
      }

      // Filter by name or reference (or code / barcode)
      if (q.isNotEmpty) {
        final matchesName = article.name.toLowerCase().contains(q);
        final matchesRef = (article.reference?.toLowerCase().contains(q)) ?? false;
        final matchesCode = article.code.toLowerCase().contains(q);
        final matchesBarcode = (article.barcode?.toLowerCase().contains(q)) ?? false;

        if (!matchesName && !matchesRef && !matchesCode && !matchesBarcode) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Unique categories list for dropdown filter
  List<String> get _categories {
    final set = <String>{};
    for (final a in _userArticles) {
      if (a.category != null && a.category!.trim().isNotEmpty) {
        set.add(a.category!.trim());
      }
    }
    final list = set.toList()..sort();
    return ['all', ...list];
  }

  // Export articles to CSV
  Future<void> _exportArticlesCsv() async {
    final list = _filteredArticles;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun article à exporter.')),
      );
      return;
    }

    final userName = _selectedUserData?['name'] ?? _selectedUserData?['displayName'] ?? 'utilisateur';
    final buffer = StringBuffer();
    buffer.writeln('Code,Reference,Nom Article,Categorie,Type,Stock,Prix Achat (HT),Prix Vente (HT),TVA (%),Code Barre');

    for (final a in list) {
      final code = (a.code).replaceAll(',', ' ');
      final ref = (a.reference ?? '').replaceAll(',', ' ');
      final name = (a.name).replaceAll(',', ' ');
      final cat = (a.category ?? '').replaceAll(',', ' ');
      final type = (a.productType).replaceAll(',', ' ');
      final stock = a.stockQty.toStringAsFixed(2);
      final buy = a.purchasePrice.toStringAsFixed(3);
      final sell = a.sellingPrice.toStringAsFixed(3);
      final tva = a.tvaRate.toStringAsFixed(1);
      final barcode = (a.barcode ?? '').replaceAll(',', ' ');

      buffer.writeln('$code,$ref,$name,$cat,$type,$stock,$buy,$sell,$tva,$barcode');
    }

    final safeName = userName.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'articles_user_${safeName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    await FileDownloadHelper.saveStringFile(
      buffer.toString(),
      fileName,
      mimeType: 'text/csv',
      context: context,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier exporté avec succès : $fileName'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // Dialog to Add a New Article directly for the selected user
  void _showCreateArticleDialog() {
    if (_selectedUser == null) return;

    final userId = _selectedUser!.id;
    final curEid = _selectedUserData?['currentEnterpriseId'] ?? _selectedUserData?['enterpriseId'];
    final userName = _selectedUserData?['name'] ?? _selectedUserData?['displayName'] ?? 'Utilisateur';

    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'ART-${DateTime.now().millisecondsSinceEpoch % 100000}');
    final refCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final purchCtrl = TextEditingController(text: '0.000');
    final sellCtrl = TextEditingController(text: '0.000');
    final stockCtrl = TextEditingController(text: '0');
    final barcodeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    String productType = 'produit';
    String destination = 'Vente et Achat';
    String unit = 'Piece';
    double tvaRate = 19.0;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 720,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ajouter un Nouvel Article pour ce Client',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Compte : $userName (ID: $userId)',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Scrollable form fields
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Nom & Code
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _dialogField(
                                    label: 'Nom de l\'article *',
                                    controller: nameCtrl,
                                    hint: 'ex: Ordinateur Portable HP 15',
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 2,
                                  child: _dialogField(
                                    label: 'Code Article *',
                                    controller: codeCtrl,
                                    hint: 'ex: ART-1234',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 2: Référence & Catégorie
                            Row(
                              children: [
                                Expanded(
                                  child: _dialogField(
                                    label: 'Référence (Optionnelle)',
                                    controller: refCtrl,
                                    hint: 'ex: REF-HP-15S',
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _dialogField(
                                    label: 'Catégorie',
                                    controller: catCtrl,
                                    hint: 'ex: Informatique, Bureautique...',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 3: Type, Destination, Unité
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Type de produit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: productType,
                                        decoration: _dialogInputDecoration(),
                                        items: const [
                                          DropdownMenuItem(value: 'produit', child: Text('Produit standard')),
                                          DropdownMenuItem(value: 'service', child: Text('Service / Prestation')),
                                          DropdownMenuItem(value: 'consommable', child: Text('Consommable')),
                                          DropdownMenuItem(value: 'immobilisation', child: Text('Immobilisation')),
                                        ],
                                        onChanged: (v) => setDialogState(() => productType = v!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Destination', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: destination,
                                        decoration: _dialogInputDecoration(),
                                        items: const [
                                          DropdownMenuItem(value: 'Vente et Achat', child: Text('Vente et Achat')),
                                          DropdownMenuItem(value: 'Vente', child: Text('Vente uniquement')),
                                          DropdownMenuItem(value: 'Achat', child: Text('Achat uniquement')),
                                        ],
                                        onChanged: (v) => setDialogState(() => destination = v!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Unité', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: unit,
                                        decoration: _dialogInputDecoration(),
                                        items: const [
                                          DropdownMenuItem(value: 'Piece', child: Text('Pièce (pcs)')),
                                          DropdownMenuItem(value: 'Kilogramme', child: Text('Kilogramme (kg)')),
                                          DropdownMenuItem(value: 'Litre', child: Text('Litre (L)')),
                                          DropdownMenuItem(value: 'Metre', child: Text('Mètre (m)')),
                                          DropdownMenuItem(value: 'Boite', child: Text('Boîte (bte)')),
                                          DropdownMenuItem(value: 'Carton', child: Text('Carton (ctn)')),
                                          DropdownMenuItem(value: 'Forfait', child: Text('Forfait (forf)')),
                                        ],
                                        onChanged: (v) => setDialogState(() => unit = v!),
                                      ),  
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 4: Prix d'Achat, Prix de Vente, Taux TVA, Stock initial
                            Row(
                              children: [
                                Expanded(
                                  child: _dialogField(
                                    label: 'Prix Achat HT (DT)',
                                    controller: purchCtrl,
                                    hint: '0.000',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _dialogField(
                                    label: 'Prix Vente HT (DT)',
                                    controller: sellCtrl,
                                    hint: '0.000',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Taux TVA (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<double>(
                                        initialValue: tvaRate,
                                        decoration: _dialogInputDecoration(),
                                        items: const [
                                          DropdownMenuItem(value: 0.0, child: Text('0% (Exonéré)')),
                                          DropdownMenuItem(value: 7.0, child: Text('7%')),
                                          DropdownMenuItem(value: 13.0, child: Text('13%')),
                                          DropdownMenuItem(value: 19.0, child: Text('19% (Standard)')),
                                        ],
                                        onChanged: (v) => setDialogState(() => tvaRate = v!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _dialogField(
                                    label: 'Stock Initial',
                                    controller: stockCtrl,
                                    hint: '0',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 5: Code-barres & Description
                            _dialogField(
                              label: 'Code-barres (EAN / Barcode)',
                              controller: barcodeCtrl,
                              hint: 'ex: 6191234567890',
                            ),
                            const SizedBox(height: 14),
                            _dialogField(
                              label: 'Description détaillée (Optionnelle)',
                              controller: descCtrl,
                              hint: 'Spécifications techniques, remarques...',
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(isSaving ? 'Enregistrement...' : 'Enregistrer l\'Article'),
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
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Le nom de l\'article est obligatoire.'),
                                        backgroundColor: Color(0xFFEF4444),
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  try {
                                    final newId = FirebaseFirestore.instance.collection('articles').doc().id;
                                    final nowIso = DateTime.now().toIso8601String();
                                    final entIdStr = curEid?.toString().trim();

                                    final payload = {
                                      'id': newId,
                                      'code': codeCtrl.text.trim().isNotEmpty
                                          ? codeCtrl.text.trim()
                                          : 'ART-${DateTime.now().millisecondsSinceEpoch % 100000}',
                                      'name': name,
                                      'reference': refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                                      'category': catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : 'Général',
                                      'product_type': productType,
                                      'destination': destination,
                                      'unit': unit,
                                      'purchase_price': double.tryParse(purchCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                      'selling_price': double.tryParse(sellCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                      'usual_discount': 0.0,
                                      'tva_rate': tvaRate,
                                      'stock_qty': double.tryParse(stockCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                      'min_stock_qty': 0.0,
                                      'barcode': barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                                      'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                                      'is_active': 1,
                                      'is_deleted': 0,
                                      'enterprise_id': entIdStr,
                                      'firebase_uid': userId,
                                      'userId': userId,
                                      'created_at': nowIso,
                                      'updated_at': nowIso,
                                    };

                                    // 1. Save directly into Firestore 'articles'
                                    await FirebaseFirestore.instance.collection('articles').doc(newId).set(payload);

                                    // 2. Add locally for instantaneous UI update
                                    final newProd = Product.fromMap(payload);
                                    setState(() {
                                      _userArticles = [newProd, ..._userArticles];
                                    });

                                    if (dialogCtx.mounted) {
                                      Navigator.of(dialogCtx).pop();
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Article "$name" créé avec succès pour $userName !'),
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
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: _dialogInputDecoration(hint: hint),
        ),
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_search_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sélectionner un Utilisateur / Client',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Choisissez le compte client dont vous voulez inspecter ou gérer les articles',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, email, téléphone ou ID...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${matching.length} utilisateur(s) trouvé(s)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: matching.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun utilisateur ne correspond à votre recherche.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: matching.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, i) {
                                final doc = matching[i];
                                final d = doc.data() ?? {};
                                final name = (d['name'] ?? d['displayName'] ?? 'Sans Nom').toString();
                                final email = (d['email'] ?? 'Sans Email').toString();
                                final phone = (d['phone'] ?? '').toString();
                                final role = (d['role'] ?? 'Client').toString();
                                final isSelected = _selectedUser?.id == doc.id;

                                // Find enterprise name
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
                                    child: Text(
                                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        email + (phone.isNotEmpty ? ' • $phone' : ''),
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                      if (entName.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '🏢 Entreprise : $entName',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20)
                                      : const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _fetchArticlesForUser(doc);
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

  void _showArticleDetailsDialog(Product article) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Code : ${article.code} ${article.reference != null ? "• Réf : ${article.reference}" : ""}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),
                _detailRow('Nom de l\'article', article.name),
                _detailRow('Code', article.code),
                _detailRow('Référence', article.reference ?? 'Non spécifiée'),
                _detailRow('Catégorie', article.category ?? 'Général'),
                _detailRow('Type de produit', article.productType),
                _detailRow('Destination', article.destination),
                _detailRow('Unité', article.unit),
                _detailRow('Quantité en stock', '${article.stockQty} ${article.unit}'),
                _detailRow('Prix d\'Achat', '${article.purchasePrice.toStringAsFixed(3)} DT'),
                _detailRow('Prix de Vente', '${article.sellingPrice.toStringAsFixed(3)} DT'),
                _detailRow('Taux TVA', '${article.tvaRate}%'),
                _detailRow('Code-barres', article.barcode ?? 'Aucun'),
                if (article.description != null && article.description!.isNotEmpty)
                  _detailRow('Description', article.description!),
                _detailRow('Statut', article.isActive ? 'Actif' : 'Inactif'),
                if (article.enterpriseId != null)
                  _detailRow('Enterprise ID', article.enterpriseId!),
                if (article.firebaseUid != null)
                  _detailRow('User/UID', article.firebaseUid!),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredArticles;

    // Metrics
    int totalCount = _userArticles.length;
    int inStockCount = _userArticles.where((a) => a.stockQty > 0).length;
    int outOfStockCount = _userArticles.where((a) => a.stockQty <= 0).length;
    double stockValue = _userArticles.fold(0.0, (acc, a) => acc + (a.stockQty * a.purchasePrice));

    // Current selected user details
    final userName = _selectedUserData?['name'] ?? _selectedUserData?['displayName'] ?? 'Utilisateur Inconnu';
    final userEmail = _selectedUserData?['email'] ?? 'Sans email';
    final userPhone = _selectedUserData?['phone'] ?? '';
    final curEid = _selectedUserData?['currentEnterpriseId'] ?? _selectedUserData?['enterpriseId'];
    String entName = 'Entreprise non associée';
    if (curEid != null) {
      final entData = _entMap[curEid.toString()];
      if (entData != null && entData['name'] != null) {
        entName = entData['name'].toString();
      } else {
        entName = curEid.toString();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Top Header without any overflow
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 980;

                final titleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Articles par Utilisateur (Article User)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sélectionnez un compte utilisateur/client pour inspecter, ajouter et filtrer l\'ensemble de ses articles.',
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
                      // + ADD ARTICLE BUTTON
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Ajouter un Article'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _showCreateArticleDialog,
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
                        onPressed: _isLoadingArticles ? null : () => _fetchArticlesForUser(_selectedUser!),
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
                        onPressed: _exportArticlesCsv,
                      ),
                    ],
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_search_rounded, size: 16),
                      label: Text(_selectedUser == null ? 'Sélectionner Utilisateur' : 'Changer'),
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
                      titleWidget,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleWidget),
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
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF2563EB),
                      child: Text(
                        userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  'ID: ${_selectedUser!.id}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$userEmail ${userPhone.isNotEmpty ? "• $userPhone" : ""} • Entreprise : $entName',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                      label: const Text('Changer', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _showUserPickerModal,
                    ),
                  ],
                ),
              ),

            // If No User Selected State
            if (_selectedUser == null)
              Expanded(
                child: Center(
                  child: Container(
                    width: 480,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Aucun utilisateur sélectionné',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Veuillez choisir un utilisateur/client dans la base de données pour afficher et gérer l\'ensemble de ses articles.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_search_rounded, size: 18),
                          label: const Text('Sélectionner un Utilisateur'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isLoadingUsers ? null : _showUserPickerModal,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Metrics Row
              Row(
                children: [
                  _metricCard('Total Articles', totalCount.toString(), Icons.inventory_2_outlined, const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _metricCard('En Stock', inStockCount.toString(), Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _metricCard('En Rupture', outOfStockCount.toString(), Icons.remove_circle_outline_rounded, const Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  _metricCard('Valeur Stock (Achat)', '${stockValue.toStringAsFixed(2)} DT', Icons.monetization_on_outlined, const Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Controls (NAME OR REFERENCE SEARCH)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Main Search Bar: by name or reference
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _articleFilterController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Filtrer par nom ou référence (ex: PC portable, REF-001)...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                            suffixIcon: _articleFilterController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 17, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      _articleFilterController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Stock Status Filter
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
                          value: _stockStatusFilter,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tous les stocks')),
                            DropdownMenuItem(value: 'in_stock', child: Text('En stock (>0)')),
                            DropdownMenuItem(value: 'out_of_stock', child: Text('Rupture (=0)')),
                            DropdownMenuItem(value: 'low_stock', child: Text('Stock faible')),
                          ],
                          onChanged: (v) => v != null ? setState(() => _stockStatusFilter = v) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Category Filter Dropdown
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
                          value: _selectedCategory,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat == 'all' ? 'Toutes catégories' : cat),
                            );
                          }).toList(),
                          onChanged: (v) => v != null ? setState(() => _selectedCategory = v) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Results Count Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} article(s) trouvé(s) pour cet utilisateur',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _includeDeleted,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (v) => setState(() => _includeDeleted = v ?? false),
                      ),
                      const Text(
                        'Afficher les articles archivés/supprimés',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Articles Table / List
              Expanded(
                child: _isLoadingArticles
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Chargement des articles du client...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    : _articlesErrorMessage != null
                        ? AppErrorWidget(
                            message: _articlesErrorMessage!,
                            onRetry: () => _fetchArticlesForUser(_selectedUser!),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      _userArticles.isEmpty
                                          ? 'Aucun article trouvé pour ce compte client.'
                                          : 'Aucun article ne correspond à votre filtre de nom ou référence.',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    if (_userArticles.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add_rounded, size: 18),
                                        label: const Text('Créer le premier article'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: _showCreateArticleDialog,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
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
                                          DataColumn(label: Text('Code / Réf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Nom de l\'article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Catégorie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Prix Vente (HT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Prix Achat (HT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('TVA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                        ],
                                        rows: filtered.map((article) {
                                          final isOutOfStock = article.stockQty <= 0;
                                          final isLowStock = article.isLowStock;

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      article.code,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                                    ),
                                                    if (article.reference != null && article.reference!.isNotEmpty)
                                                      Text(
                                                        'Réf: ${article.reference}',
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  article.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    article.category ?? 'Général',
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  article.productType,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock
                                                        ? const Color(0xFFFEF2F2)
                                                        : isLowStock
                                                            ? const Color(0xFFFFFBEB)
                                                            : const Color(0xFFECFDF5),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${article.stockQty} ${article.unit}',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isOutOfStock
                                                          ? const Color(0xFFDC2626)
                                                          : isLowStock
                                                              ? const Color(0xFFD97706)
                                                              : const Color(0xFF059669),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  '${article.sellingPrice.toStringAsFixed(3)} DT',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  '${article.purchasePrice.toStringAsFixed(3)} DT',
                                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  '${article.tvaRate}%',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                              DataCell(
                                                IconButton(
                                                  icon: const Icon(Icons.visibility_rounded, color: Color(0xFF2563EB), size: 19),
                                                  tooltip: 'Voir détails complets',
                                                  onPressed: () => _showArticleDetailsDialog(article),
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
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
