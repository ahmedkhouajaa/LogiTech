import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enterprise_service.dart';
import '../secrets.dart';

class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? dataCard;

  AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.dataCard,
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic>? serializedCard;
    if (dataCard != null) {
      int? colorVal;
      final rawColor = dataCard!['color'];
      if (rawColor is Color) {
        colorVal = rawColor.toARGB32();
      } else if (rawColor is int) {
        colorVal = rawColor;
      }
      serializedCard = {
        'title': dataCard!['title']?.toString() ?? '',
        'badge': dataCard!['badge']?.toString() ?? '',
        'value': dataCard!['value']?.toString() ?? '',
        if (colorVal != null) 'color': colorVal,
      };
    }

    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      if (serializedCard != null) 'dataCard': serializedCard,
    };
  }

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? card;
    if (map['dataCard'] != null && map['dataCard'] is Map) {
      final cardMap = Map<String, dynamic>.from(map['dataCard'] as Map);
      Color cardColor = Colors.blue;
      final rawColor = cardMap['color'];
      if (rawColor is int) {
        cardColor = Color(rawColor);
      } else if (rawColor is num) {
        cardColor = Color(rawColor.toInt());
      }
      card = {
        'title': cardMap['title']?.toString() ?? '',
        'badge': cardMap['badge']?.toString() ?? '',
        'value': cardMap['value']?.toString() ?? '',
        'color': cardColor,
      };
    }

    return AiChatMessage(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text']?.toString() ?? '',
      isUser: map['isUser'] == true,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dataCard: card,
    );
  }
}

class AiChatService {
  AiChatService._privateConstructor() {
    _messages.add(_defaultWelcomeMessage());
    initialize();
  }
  static final AiChatService instance = AiChatService._privateConstructor();

  final List<AiChatMessage> _messages = [];
  final StreamController<List<AiChatMessage>> _messagesController =
      StreamController<List<AiChatMessage>>.broadcast();

  Stream<List<AiChatMessage>> get messagesStream => _messagesController.stream;
  List<AiChatMessage> get currentMessages => List.unmodifiable(_messages);

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  bool _isInitialized = false;

  // Optional Gemini API Key (defaults to Secrets.geminiApiKey if defined)
  String? _geminiApiKey;
  String? get effectiveApiKey =>
      (_geminiApiKey != null && _geminiApiKey!.isNotEmpty)
          ? _geminiApiKey
          : (Secrets.geminiApiKey.isNotEmpty ? Secrets.geminiApiKey : null);

  set geminiApiKey(String? key) => _geminiApiKey = key;

  // Supported enterprise collection keys with aliases
  static const List<Map<String, dynamic>> _allCollectionsMap = [
    {'key': 'quotes', 'altKeys': ['devis'], 'label': 'Devis'},
    {'key': 'invoices', 'altKeys': ['factures', 'facture_ventes', 'factures_ventes'], 'label': 'Factures de Vente'},
    {'key': 'delivery_notes', 'altKeys': ['bl', 'bons_livraison'], 'label': 'Bons de Livraison'},
    {'key': 'customer_orders', 'altKeys': ['commandes_clients', 'orders'], 'label': 'Commandes Clients'},
    {'key': 'purchase_invoices', 'altKeys': ['achats', 'factures_achat', 'facture_achats', 'purchase_invoice'], 'label': 'Factures d\'Achat'},
    {'key': 'supplier_orders', 'altKeys': ['commandes_fournisseurs'], 'label': 'Commandes Fournisseurs'},
    {'key': 'receiving_vouchers', 'altKeys': ['bons_reception', 'br'], 'label': 'Bons de Réception'},
    {'key': 'credit_notes', 'altKeys': ['avoirs', 'avoirs_clients'], 'label': 'Avoirs Clients'},
    {'key': 'supplier_credit_notes', 'altKeys': ['avoirs_fournisseurs'], 'label': 'Avoirs Fournisseurs'},
    {'key': 'return_notes', 'altKeys': ['retours_clients'], 'label': 'Bons de Retour Client'},
    {'key': 'supplier_returns', 'altKeys': ['retours_fournisseurs'], 'label': 'Retours Fournisseurs'},
    {'key': 'stock_withdrawals', 'altKeys': ['bons_sortie', 'bons_prelevement', 'sorties_stock'], 'label': 'Bons de Sortie Stock'},
    {'key': 'stock_entries', 'altKeys': ['entrees_stock'], 'label': 'Bons d\'Entrée Stock'},
    {'key': 'stock_transfers', 'altKeys': ['transferts_stock'], 'label': 'Transferts de Stock'},
    {'key': 'inventory_sheets', 'altKeys': ['inventaires'], 'label': 'Fiches d\'Inventaire'},
    {'key': 'clients', 'altKeys': ['customers'], 'label': 'Clients'},
    {'key': 'fournisseurs', 'altKeys': ['suppliers'], 'label': 'Fournisseurs'},
    {'key': 'articles', 'altKeys': ['products', 'produits'], 'label': 'Articles & Produits'},
    {'key': 'treasury_accounts', 'altKeys': ['comptes_tresorerie', 'accounts'], 'label': 'Comptes de Trésorerie'},
    {'key': 'paiements', 'altKeys': ['payments'], 'label': 'Paiements'},
    {'key': 'checks_traites', 'altKeys': ['cheques', 'traites'], 'label': 'Chèques & Traites'},
    {'key': 'projects', 'altKeys': ['projets'], 'label': 'Projets'},
    {'key': 'retenue_source_vente', 'altKeys': ['rs_vente'], 'label': 'Retenues à la Source Vente'},
    {'key': 'retenue_source_achat', 'altKeys': ['rs_achat'], 'label': 'Retenues à la Source Achat'},
  ];

  String _getStorageKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return 'logitech_ai_chat_history_$uid';
    }
    return 'logitech_ai_chat_history_default';
  }

  static AiChatMessage _defaultWelcomeMessage() {
    return AiChatMessage(
      id: 'welcome',
      text:
          "Bonjour ! Je suis votre Assistant IA LogiTech. 🤖\nComment puis-je vous aider aujourd'hui ? Vous pouvez me saluer, me poser des questions sur votre entreprise (devis, factures, achats, livraisons, stock, trésorerie), ou me demander des conseils de gestion.",
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final key = _getStorageKey();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final loaded = decoded
            .map((e) => AiChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (loaded.isNotEmpty) {
          _messages.clear();
          _messages.addAll(loaded);
          _isInitialized = true;
          _notify();
          return;
        }
      }
    } catch (e) {
      debugPrint("Error loading AI chat history: $e");
    }

    if (_messages.isEmpty) {
      _messages.add(_defaultWelcomeMessage());
    }
    _isInitialized = true;
    _notify();
  }

  Future<void> _saveMessagesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _messages.length > 100
          ? _messages.sublist(_messages.length - 100)
          : _messages;
      final encoded = jsonEncode(toSave.map((m) => m.toMap()).toList());
      await prefs.setString(_getStorageKey(), encoded);
    } catch (e) {
      debugPrint("Error saving AI chat history: $e");
    }
  }

  void _notify() {
    _messagesController.add(List.unmodifiable(_messages));
  }

  /// Determines if a prompt requires live Firestore database fetching
  bool _requiresDatabaseFetch(String prompt) {
    final lower = prompt.toLowerCase().trim();

    // Check conversational / small talk first
    if (_isGreeting(lower) || _isSocialOrThanks(lower) || _isIdentityOrHelp(lower) || _isConceptualOrGuidance(lower)) {
      return false;
    }

    final dataKeywords = [
      'combien', 'quel est', 'quelle est', 'quels sont', 'montant', 'solde',
      'total', 'donne moi', 'donne-moi', 'liste', 'etat', 'état', 'situation',
      'impaye', 'impayé', 'impayes', 'impayés', 'en cours', 'enregistré',
      'devis', 'facture', 'achat', 'bl', 'livraison', 'stock', 'article',
      'client', 'fournisseur', 'tresorerie', 'trésorerie', 'caisse', 'banque',
      'paiement', 'retenue', 'rs', 'avoir', 'commande', 'sortie', 'entree',
      'chèque', 'cheque', 'traite', 'produit',
    ];

    for (final kw in dataKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  bool _isGreeting(String text) {
    final words = text.replaceAll(RegExp(r'[^\w\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final greetingWords = {
      'slm', 'salam', 'salem', 'slam', 'aslama', 'assalam', 'assalamou',
      'bonjour', 'salut', 'coucou', 'bonsoir', 'hello', 'hi', 'hey',
      'ahla', 'marhaba', 'ahlan', 'sbah', 'sbah lkhir', 'sbe7',
    };

    if (words.length <= 4) {
      for (final w in words) {
        if (greetingWords.contains(w)) return true;
      }
    }
    return false;
  }

  bool _isSocialOrThanks(String text) {
    final lower = text.trim();
    final socialKeywords = [
      'merci', 'chokran', 'choukrane', 'cimer', 'sahha', 'saha', 'thanks', 'thank you',
      'ca va', 'ça va', 'cv', 'labas', 'kifak', 'how are you', 'tu vas bien',
      'au revoir', 'bye', 'bslama', 'a bientot', 'à bientôt', 'bonne journée', 'bonne soiree', 'bonne nuit'
    ];
    for (final s in socialKeywords) {
      if (lower == s || lower.startsWith('$s ') || lower.endsWith(' $s')) return true;
    }
    return false;
  }

  bool _isIdentityOrHelp(String text) {
    final lower = text.trim();
    final helpKeywords = [
      'qui es tu', 'qui es-tu', 'qui t\'es', 'qui etes vous', 'qui êtes-vous',
      'c\'est quoi ton role', 'c\'est quoi ton rôle', 'tu fais quoi', 'tu sers a quoi', 'tu sers à quoi',
      'que peux tu faire', 'que peux-tu faire', 'que sais tu faire', 'que sais-tu faire',
      'aide moi', 'aide-moi', 'help', 'capacites', 'capacités', 'fonctionnalités',
    ];
    for (final h in helpKeywords) {
      if (lower.contains(h)) return true;
    }
    return false;
  }

  bool _isConceptualOrGuidance(String text) {
    final lower = text.trim();
    final guidanceTriggers = [
      'c\'est quoi', 'qu\'est ce que', 'qu\'est-ce que', 'definition', 'définition',
      'difference entre', 'différence entre', 'comment faire', 'comment creer', 'comment créer',
      'comment ajouter', 'pourquoi', 'conseil', 'conseils', 'optimiser', 'explication'
    ];
    for (final g in guidanceTriggers) {
      if (lower.contains(g)) return true;
    }
    return false;
  }

  /// Queries all enterprise collections across root and nested Firestore scopes
  Future<Map<String, List<Map<String, dynamic>>>> _fetchCompleteDatabaseSnapshot(String? entId) async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Future<List<Map<String, dynamic>>> fetchSingleCollection(String collectionName) async {
      final List<Map<String, dynamic>> results = [];
      try {
        Query rootQuery = db.collection(collectionName);
        final snapshotFutures = <Future<QuerySnapshot>>[];

        if (entId != null && entId.isNotEmpty) {
          snapshotFutures.add(rootQuery.where('enterprise_id', isEqualTo: entId).get().timeout(const Duration(seconds: 4)));
        }
        if (uid != null && uid.isNotEmpty) {
          snapshotFutures.add(rootQuery.where('userId', isEqualTo: uid).get().timeout(const Duration(seconds: 4)));
          snapshotFutures.add(rootQuery.where('firebase_uid', isEqualTo: uid).get().timeout(const Duration(seconds: 4)));
        }
        snapshotFutures.add(rootQuery.limit(200).get().timeout(const Duration(seconds: 4)));

        for (final fut in snapshotFutures) {
          try {
            final snap = await fut;
            for (final doc in snap.docs) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              final docEnt = data['enterprise_id'] ?? data['enterpriseId'];
              final docUid = data['userId'] ?? data['firebase_uid'];

              final matchEnt = entId == null || entId.isEmpty || docEnt == null || docEnt == entId;
              final matchUid = uid == null || uid.isEmpty || docUid == null || docUid == uid;

              if (matchEnt && matchUid && !results.any((e) => e['id'] == doc.id)) {
                results.add(data);
              }
            }
          } catch (_) {}
        }

        if (entId != null && entId.isNotEmpty) {
          try {
            final subSnap = await db
                .collection('enterprises')
                .doc(entId)
                .collection(collectionName)
                .get()
                .timeout(const Duration(seconds: 4));
            for (final doc in subSnap.docs) {
              final data = doc.data();
              data['id'] = doc.id;
              if (!results.any((e) => e['id'] == doc.id)) {
                results.add(data);
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      return results.where((item) => item['is_deleted'] != 1 && item['is_deleted'] != true).toList();
    }

    final Map<String, List<Map<String, dynamic>>> fullSnapshot = {};

    for (final colConfig in _allCollectionsMap) {
      final primaryKey = colConfig['key'] as String;
      final altKeys = (colConfig['altKeys'] as List<String>?) ?? [];

      final List<Map<String, dynamic>> combined = [];
      final primaryItems = await fetchSingleCollection(primaryKey);
      combined.addAll(primaryItems);

      for (final alt in altKeys) {
        final altItems = await fetchSingleCollection(alt);
        for (final item in altItems) {
          if (!combined.any((e) => e['id'] == item['id'])) {
            combined.add(item);
          }
        }
      }

      fullSnapshot[primaryKey] = combined;
    }

    return fullSnapshot;
  }

  Future<void> sendMessage(String userText, BuildContext context) async {
    final cleanPrompt = userText.trim();
    if (cleanPrompt.isEmpty || _isProcessing) return;

    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: cleanPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isProcessing = true;
    _notify();
    _saveMessagesToPrefs();

    final apiKey = effectiveApiKey;
    final bool needsData = _requiresDatabaseFetch(cleanPrompt);

    Map<String, List<Map<String, dynamic>>> dbSnapshot = {};
    if (needsData || (apiKey != null && apiKey.isNotEmpty)) {
      final entId = EnterpriseService.instance.currentEnterpriseId;
      try {
        dbSnapshot = await _fetchCompleteDatabaseSnapshot(entId);
      } catch (_) {}
    }

    String aiText = "";
    Map<String, dynamic>? dataCard;

    // 1. If Gemini API Key is configured, use real Gemini LLM
    if (apiKey != null && apiKey.isNotEmpty) {
      aiText = await _callGeminiApi(cleanPrompt, dbSnapshot, apiKey);
    }

    // 2. If no Gemini API key or offline, use our Advanced Conversational NLP Engine
    if (aiText.isEmpty) {
      final result = _processIntelligentResponse(cleanPrompt, dbSnapshot);
      aiText = result['text'] as String;
      dataCard = result['card'] as Map<String, dynamic>?;
    }

    final aiMsg = AiChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: aiText,
      isUser: false,
      timestamp: DateTime.now(),
      dataCard: dataCard,
    );

    _messages.add(aiMsg);
    _isProcessing = false;
    _notify();
    _saveMessagesToPrefs();
  }

  /// Calls Google Gemini REST API with enterprise DB snapshot
  Future<String> _callGeminiApi(String prompt, Map<String, List<Map<String, dynamic>>> dbContext, String apiKey) async {
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$apiKey');

      final systemInstruction =
          "Tu es LogiTech AI, un assistant virtuel intelligent, courtois et très professionnel pour l'application ERP/CRM LogiTech. "
          "Tu comprends parfaitement le français, l'arabe, le dialecte maghrébin/tunisien (slm, chokran, cv, labas), et l'anglais. "
          "Si l'utilisateur te salue (slm, salam, bonjour, salut), réponds poliment et chaleureusement sans réciter de données. "
          "Si l'utilisateur pose une question de gestion ou générale, réponds de façon intelligente et experte. "
          "Si l'utilisateur demande des chiffres de son entreprise, utilise les données Firestore en temps réel suivantes (en devise TND) : ${jsonEncode(dbContext)}. "
          "Réponds de façon directe, claire, humaine et élégante, sans mentionner de code technique ni de requêtes.";

      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "$systemInstruction\n\nQuestion de l'utilisateur : $prompt"}
            ]
          }
        ]
      });

      request.write(payload);
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null && text.toString().isNotEmpty) {
          return text.toString().trim();
        }
      }
    } catch (_) {}
    return "";
  }

  /// Advanced Conversational NLP Engine that understands intent, tone, business concepts and enterprise data
  Map<String, dynamic> _processIntelligentResponse(String prompt, Map<String, List<Map<String, dynamic>>> db) {
    final lower = prompt.toLowerCase().trim();

    // ─────────────────────────────────────────────────────────────
    // CATEGORY 1: GREETINGS & SOCIAL POLITE CONVERSATION
    // ─────────────────────────────────────────────────────────────
    if (_isGreeting(lower)) {
      if (lower.contains('slm') || lower.contains('salam') || lower.contains('salem') || lower.contains('slam') || lower.contains('assalam')) {
        return {
          'text': "Wa alaykoum assalam ! Comment puis-je vous aider aujourd'hui dans la gestion de votre entreprise ?",
          'card': null,
        };
      }
      if (lower.contains('bonsoir')) {
        return {
          'text': "Bonsoir ! Que puis-je vérifier ou calculer pour vous ce soir ?",
          'card': null,
        };
      }
      return {
        'text': "Bonjour ! Comment puis-je vous aider aujourd'hui ? Vous pouvez me poser des questions sur vos devis, factures, trésorerie, stocks ou clients.",
        'card': null,
      };
    }

    if (lower.contains('ca va') || lower.contains('ça va') || lower.contains('cv') || lower.contains('labas') || lower.contains('kifak') || lower.contains('how are you')) {
      return {
        'text': "Tout va très bien, merci ! Prêt à vous assister pour piloter votre entreprise. Que souhaitez-vous consulter aujourd'hui ?",
        'card': null,
      };
    }

    if (lower.contains('merci') || lower.contains('chokran') || lower.contains('cimer') || lower.contains('sahha') || lower.contains('thanks')) {
      return {
        'text': "Avec grand plaisir ! N'hésitez pas si vous avez d'autres questions ou besoins sur LogiTech.",
        'card': null,
      };
    }

    if (lower.contains('au revoir') || lower.contains('bye') || lower.contains('bslama') || lower.contains('a bientot') || lower.contains('bonne journee') || lower.contains('bonne soirée')) {
      return {
        'text': "Au revoir et très bonne journée ! Je reste disponible à tout moment.",
        'card': null,
      };
    }

    // ─────────────────────────────────────────────────────────────
    // CATEGORY 2: IDENTITY & CAPABILITIES
    // ─────────────────────────────────────────────────────────────
    if (_isIdentityOrHelp(lower)) {
      return {
        'text': "Je suis **LogiTech AI**, votre assistant virtuel intelligent. 🤖\n\n"
            "Voici ce que je peux faire pour vous :\n"
            "• **Consulter vos chiffres en direct (TND)** : devis, factures de vente & d'achat, bons de livraison, bons de sortie, commandes, stocks, trésorerie, avoirs, clients, fournisseurs et RS.\n"
            "• **Conseils & Explications** : comprendre la différence entre documents, optimiser votre trésorerie, vous guider dans l'application.\n"
            "• **Simplicité** : posez-moi vos questions naturellement en français ou en arabe !",
        'card': null,
      };
    }

    // ─────────────────────────────────────────────────────────────
    // CATEGORY 3: CONCEPTUAL & BUSINESS GUIDANCE QUESTIONS
    // ─────────────────────────────────────────────────────────────
    if (lower.contains('difference') && (lower.contains('devis') || lower.contains('facture'))) {
      return {
        'text': "💡 **Différence entre Devis et Facture** :\n\n"
            "• **Le Devis** est une proposition commerciale préalable sans valeur comptable obligatoire. Il précise les prix et conditions avant accord du client.\n"
            "• **La Facture** est un document légal, comptable et fiscal obligatoire émis après réalisation de la prestation ou livraison des marchandises. Elle constate une créance et engage le paiement.",
        'card': null,
      };
    }

    if ((lower.contains('c\'est quoi') || lower.contains('definition') || lower.contains('pourquoi')) && (lower.contains('rs') || lower.contains('retenue'))) {
      return {
        'text': "📑 **Qu'est-ce que la Retenue à la Source (RS) ?**\n\n"
            "La Retenue à la Source est un prélèvement fiscal obligatoire déduit directement par l'acheteur lors du paiement d'une facture de service, honoraires ou sous-traitance. "
            "L'acheteur verse ce montant à la recette des finances et remet un certificat de retenue au fournisseur.",
        'card': null,
      };
    }

    if ((lower.contains('c\'est quoi') || lower.contains('definition') || lower.contains('a quoi sert')) && (lower.contains('livraison') || lower.contains('bl'))) {
      return {
        'text': "🚚 **À quoi sert le Bon de Livraison (BL) ?**\n\n"
            "Le Bon de Livraison prouve la remise physique effective des marchandises au client. Signé par le destinataire avec cachet ou date, il atteste de la conformité des articles avant la facturation.",
        'card': null,
      };
    }

    if (lower.contains('comment faire') || lower.contains('comment creer') || lower.contains('comment créer')) {
      if (lower.contains('facture')) {
        return {
          'text': "Pour créer une facture dans **LogiTech** :\n1. Ouvrez le menu latéral > **Factures de Vente**.\n2. Appuyez sur le bouton **'+'** en bas à droite.\n3. Choisissez votre client, ajoutez les articles et appliquez la TVA/remise.\n4. Enregistrez et imprimez/partagez en PDF.",
          'card': null,
        };
      }
      if (lower.contains('devis')) {
        return {
          'text': "Pour créer un devis dans **LogiTech** :\n1. Ouvrez le menu latéral > **Devis**.\n2. Appuyez sur le bouton **'+'**.\n3. Remplissez les informations client et vos lignes de produits.\n4. Une fois validé par votre client, vous pourrez le convertir directement en facture d'un simple clic !",
          'card': null,
        };
      }
      if (lower.contains('client')) {
        return {
          'text': "Pour ajouter un client dans **LogiTech** :\n1. Ouvrez le menu latéral > **Clients**.\n2. Appuyez sur le bouton **'+'**.\n3. Saisissez la raison sociale, téléphone, adresse et matricule fiscal, puis validez.",
          'card': null,
        };
      }
    }

    if (lower.contains('optimiser') && (lower.contains('tresorerie') || lower.contains('trésorerie'))) {
      return {
        'text': "💼 **Conseils pour optimiser votre Trésorerie** :\n\n"
            "1. **Relancez les factures impayées** régulièrement pour réduire le délai de paiement client.\n"
            "2. **Négociez des délais avec vos fournisseurs** pour préserver votre BFR (Besoin en Fonds de Roulement).\n"
            "3. **Contrôlez vos stocks** pour éviter d'immobiliser de l'argent dans des produits à faible rotation.\n"
            "4. **Suivez quotidiennement** vos encaissements et décaissements sur LogiTech.",
        'card': null,
      };
    }

    // ─────────────────────────────────────────────────────────────
    // CATEGORY 4: ENTERPRISE LIVE DATA QUERIES (TND)
    // ─────────────────────────────────────────────────────────────

    // 1. Factures d'Achat (Purchase Invoices)
    if (lower.contains('achat') || lower.contains('achats') || lower.contains('facture d\'achat') || lower.contains('facture achat') || lower.contains('factures d\'achat') || lower.contains('factures achat')) {
      final list = db['purchase_invoices'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${list.length} factures d'achat** enregistrées pour un total de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Factures d\'Achat', 'badge': '${list.length} Achats', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.deepOrange}
      };
    }

    // 2. Retenues à la Source (RS Achat & RS Vente)
    if (lower.contains('retenue') || lower.contains('rs')) {
      final rsVenteList = db['retenue_source_vente'] ?? [];
      final rsAchatList = db['retenue_source_achat'] ?? [];
      final isAchat = lower.contains('achat');
      final isVente = lower.contains('vente');

      if (isAchat) {
        double totalRs = 0;
        for (var r in rsAchatList) {
          totalRs += ((r['montant'] ?? r['amount'] ?? r['total'] ?? 0) as num).toDouble();
        }
        return {
          'text': "Vous avez **${rsAchatList.length} retenues à la source (RS Achat)** pour un total de **${totalRs.toStringAsFixed(2)} TND**.",
          'card': {'title': 'RS Achat', 'badge': '${rsAchatList.length} RS', 'value': '${totalRs.toStringAsFixed(2)} TND', 'color': Colors.deepOrange}
        };
      }

      if (isVente) {
        double totalRs = 0;
        for (var r in rsVenteList) {
          totalRs += ((r['montant'] ?? r['amount'] ?? r['total'] ?? 0) as num).toDouble();
        }
        return {
          'text': "Vous avez **${rsVenteList.length} retenues à la source (RS Vente)** pour un total de **${totalRs.toStringAsFixed(2)} TND**.",
          'card': {'title': 'RS Vente', 'badge': '${rsVenteList.length} RS', 'value': '${totalRs.toStringAsFixed(2)} TND', 'color': Colors.blueAccent}
        };
      }

      double totalRsVente = 0;
      for (var r in rsVenteList) {
        totalRsVente += ((r['montant'] ?? r['amount'] ?? r['total'] ?? 0) as num).toDouble();
      }
      double totalRsAchat = 0;
      for (var r in rsAchatList) {
        totalRsAchat += ((r['montant'] ?? r['amount'] ?? r['total'] ?? 0) as num).toDouble();
      }

      return {
        'text': "Vous avez **${rsVenteList.length} RS Vente** (${totalRsVente.toStringAsFixed(2)} TND) et **${rsAchatList.length} RS Achat** (${totalRsAchat.toStringAsFixed(2)} TND).",
        'card': {'title': 'Retenues à la Source', 'badge': '${rsVenteList.length + rsAchatList.length} RS', 'value': '${(totalRsVente + totalRsAchat).toStringAsFixed(2)} TND', 'color': Colors.teal}
      };
    }

    // 3. Historique des Paiements (Payments History)
    if (lower.contains('paiement') || lower.contains('historique de paiement') || lower.contains('encaissement') || lower.contains('décaissement') || lower.contains('paiements')) {
      final payments = db['paiements'] ?? db['payments'] ?? [];
      double totalAmount = 0;
      for (var p in payments) {
        totalAmount += ((p['amount'] ?? p['montant'] ?? p['total'] ?? 0) as num).toDouble();
      }
      return {
        'text': "Vous avez un historique de **${payments.length} paiements** enregistrés pour un montant total de **${totalAmount.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Historique Paiements', 'badge': '${payments.length} Paiements', 'value': '${totalAmount.toStringAsFixed(2)} TND', 'color': Colors.green}
      };
    }

    // 4. Devis (Quotes)
    if (lower.contains('devis') || lower.contains('proposition')) {
      final list = db['quotes'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      final String countText = list.length == 1 ? "1 devis" : "${list.length} devis";
      return {
        'text': "Vous avez actuellement **$countText** pour un montant total de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Devis', 'badge': '${list.length} Devis', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.indigo}
      };
    }

    // 5. Factures de Vente (Invoices)
    if (lower.contains('facture de vente') || lower.contains('factures de vente') || lower.contains('facture') || lower.contains('impay')) {
      final list = db['invoices'] ?? [];
      double total = 0;
      double paid = 0;
      int unpaidCount = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        final p = (item['amountPaid'] ?? item['paid'] ?? item['montant_paye'] ?? 0) as num;
        total += ttc.toDouble();
        paid += p.toDouble();
        if (ttc > p) unpaidCount++;
      }
      final due = total - paid;
      return {
        'text': "Vous avez **${list.length} factures de vente** ($unpaidCount impayées) pour un montant total de **${total.toStringAsFixed(2)} TND** et un reste à encaisser de **${due.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Factures Vente', 'badge': '$unpaidCount Impayées', 'value': '${due.toStringAsFixed(2)} TND', 'color': Colors.amber}
      };
    }

    // 6. Bons de Livraison & Bons de Sortie (Delivery Notes / Stock Withdrawals)
    if (lower.contains('sortie') || lower.contains('bon de sortie') || lower.contains('livraison') || lower.contains('bl')) {
      final listDelivery = db['delivery_notes'] ?? [];
      final listWithdrawals = db['stock_withdrawals'] ?? [];

      if (lower.contains('sortie')) {
        return {
          'text': "Vous avez **${listWithdrawals.length} bons de sortie** enregistrés dans le système.",
          'card': {'title': 'Bons de Sortie', 'badge': '${listWithdrawals.length} Sorties', 'value': '${listWithdrawals.length} Doc(s)', 'color': Colors.deepPurple}
        };
      }

      double total = 0;
      for (var item in listDelivery) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${listDelivery.length} bons de livraison** (${total.toStringAsFixed(2)} TND) et **${listWithdrawals.length} bons de sortie de stock**.",
        'card': {'title': 'Bons de Livraison', 'badge': '${listDelivery.length} BL', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.teal}
      };
    }

    // 7. Commandes Clients (Customer Orders)
    if (lower.contains('commande client') || lower.contains('bc client') || (lower.contains('commande') && !lower.contains('fournisseur'))) {
      final list = db['customer_orders'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${list.length} commandes clients** enregistrées pour une valeur totale de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Commandes Clients', 'badge': '${list.length} Commandes', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.blue}
      };
    }

    // 8. Commandes Fournisseurs (Supplier Orders)
    if (lower.contains('commande fournisseur') || lower.contains('bc fournisseur')) {
      final list = db['supplier_orders'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${list.length} commandes fournisseurs** préparées pour un montant total de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Commandes Fournisseur', 'badge': '${list.length} Commandes', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.orange}
      };
    }

    // 9. Bons de Réception (Receiving Vouchers)
    if (lower.contains('réception') || lower.contains('reception') || lower.contains('br') || lower.contains('bon de réception')) {
      final list = db['receiving_vouchers'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${list.length} bons de réception** enregistrés pour un total de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Bons de Réception', 'badge': '${list.length} BR', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.brown}
      };
    }

    // 10. Avoirs Clients (Credit Notes)
    if (lower.contains('avoir client') || (lower.contains('avoir') && !lower.contains('fournisseur'))) {
      final list = db['credit_notes'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${list.length} avoirs clients** d'une valeur totale de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Avoirs Clients', 'badge': '${list.length} Avoirs', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.redAccent}
      };
    }

    // 11. Avoirs Fournisseurs (Supplier Credit Notes)
    if (lower.contains('avoir fournisseur') || lower.contains('avoirs fournisseurs')) {
      final list = db['supplier_credit_notes'] ?? [];
      double total = 0;
      for (var item in list) {
        final ttc = (item['totalTtc'] ?? item['totalTTC'] ?? item['total'] ?? item['total_ttc'] ?? 0) as num;
        total += ttc.toDouble();
      }
      return {
        'text': "Vous avez **${list.length} avoirs fournisseurs** pour un total de **${total.toStringAsFixed(2)} TND**.",
        'card': {'title': 'Avoirs Fournisseurs', 'badge': '${list.length} Avoirs', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.pink}
      };
    }

    // 12. Stock - Entrées & Transferts
    if (lower.contains('entrée stock') || lower.contains('entree stock') || lower.contains('bon d\'entrée')) {
      final list = db['stock_entries'] ?? [];
      return {
        'text': "Vous avez **${list.length} bons d'entrée de stock** enregistrés.",
        'card': {'title': 'Entrées Stock', 'badge': '${list.length} Entrées', 'value': '${list.length} Documents', 'color': Colors.lightGreen}
      };
    }
    if (lower.contains('transfert') || lower.contains('transfert de stock')) {
      final list = db['stock_transfers'] ?? [];
      return {
        'text': "Vous avez **${list.length} transferts de stock inter-dépôts** enregistrés.",
        'card': {'title': 'Transferts Stock', 'badge': '${list.length} Transferts', 'value': '${list.length} Documents', 'color': Colors.cyan}
      };
    }

    // 13. Clients / Fournisseurs / Tiers
    if (lower.contains('client') || lower.contains('tiers')) {
      final list = db['clients'] ?? db['customers'] ?? [];
      return {
        'text': "Vous avez **${list.length} clients** enregistrés dans votre base de données.",
        'card': {'title': 'Clients', 'badge': '${list.length} Clients', 'value': '${list.length} Tiers', 'color': Colors.blue}
      };
    }
    if (lower.contains('fournisseur')) {
      final list = db['fournisseurs'] ?? db['suppliers'] ?? [];
      return {
        'text': "Vous avez **${list.length} fournisseurs** enregistrés.",
        'card': {'title': 'Fournisseurs', 'badge': '${list.length} Fournisseurs', 'value': '${list.length} Tiers', 'color': Colors.orange}
      };
    }

    // 14. Articles / Stock Catalogue
    if (lower.contains('article') || lower.contains('produit') || lower.contains('stock') || lower.contains('catalogue')) {
      final list = db['articles'] ?? db['products'] ?? [];
      int lowStockCount = 0;
      for (var p in list) {
        final stock = (p['stockQuantity'] ?? p['stock'] ?? p['quantity'] ?? 0) as num;
        final minStock = (p['minStockQuantity'] ?? p['minStock'] ?? 5) as num;
        if (stock <= minStock) lowStockCount++;
      }
      return {
        'text': "Vous avez **${list.length} articles** enregistrés dans votre catalogue, dont **$lowStockCount en alerte de stock bas**.",
        'card': {'title': 'Catalogue Stock', 'badge': '$lowStockCount Alertes', 'value': '${list.length} Articles', 'color': Colors.purple}
      };
    }

    // 15. Trésorerie / Comptes / Chèques & Traites
    if (lower.contains('trésorerie') || lower.contains('tresor') || lower.contains('solde') || lower.contains('banque') || lower.contains('caisse')) {
      final list = db['treasury_accounts'] ?? [];
      double total = 0;
      for (var t in list) {
        final bal = (t['balance'] ?? t['solde'] ?? 0) as num;
        total += bal.toDouble();
      }
      return {
        'text': "Le solde total de votre trésorerie est de **${total.toStringAsFixed(2)} TND** réparti sur **${list.length} comptes**.",
        'card': {'title': 'Trésorerie', 'badge': '${list.length} Comptes', 'value': '${total.toStringAsFixed(2)} TND', 'color': Colors.green}
      };
    }

    // ─────────────────────────────────────────────────────────────
    // CATEGORY 5: SMART GENERAL BUSINESS FALLBACK
    // ─────────────────────────────────────────────────────────────
    return {
      'text': "J'ai bien reçu votre message : \"$prompt\".\n\n"
          "Comment puis-je vous orienter au mieux ? Vous pouvez me demander :\n"
          "• Les chiffres réels de vos **devis, factures (vente/achat), BL, stocks ou trésorerie**\n"
          "• Des conseils sur la **gestion d'entreprise, facturation ou comptabilité**\n"
          "• Comment effectuer une action dans l'application LogiTech.",
      'card': null,
    };
  }

  Future<void> clearHistory() async {
    _messages.clear();
    _messages.add(_defaultWelcomeMessage());
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getStorageKey());
    } catch (e) {
      debugPrint("Error clearing AI chat history: $e");
    }
  }
}
