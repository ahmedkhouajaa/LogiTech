import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LicenseExtensionScreen extends StatefulWidget {
  const LicenseExtensionScreen({super.key});

  @override
  State<LicenseExtensionScreen> createState() => _LicenseExtensionScreenState();
}

class _LicenseExtensionScreenState extends State<LicenseExtensionScreen> {
  String? _selectedUserId;
  String? _selectedEnterpriseId; // 'ALL' or specific enterpriseId
  String _selectedPlan = 'keep_current';

  // Duration modes: 'exact' (fixer le nombre exact de jours restants), 'add' (ajouter des jours), 'calendar' (date précise)
  String _durationMode = 'exact';

  final TextEditingController _exactDaysController = TextEditingController(text: '11');
  final TextEditingController _addDaysController = TextEditingController(text: '30');
  DateTime? _selectedCalendarDate;

  final TextEditingController _reasonController = TextEditingController(text: 'Mise à jour de la licence / accord commercial.');
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedCalendarDate = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _exactDaysController.dispose();
    _addDaysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _applyExtension({
    int? addDays,
    int? exactDays,
    DateTime? exactDate,
    required List<Map<String, dynamic>> userEnterprises,
    required String userName,
  }) async {
    if (_selectedUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez d\'abord sélectionner un client.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
      return;
    }

    if (_selectedEnterpriseId == null || userEnterprises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner au moins une entreprise à configurer.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez préciser le motif de l\'opération.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final firestore = FirebaseFirestore.instance;
      final dateFormat = DateFormat('dd/MM/yyyy');

      // Determine target enterprises (either 'ALL' or a single enterprise)
      final List<Map<String, dynamic>> targets = _selectedEnterpriseId == 'ALL'
          ? userEnterprises
          : userEnterprises.where((e) => e['id'] == _selectedEnterpriseId).toList();

      DateTime maxNewEndDate = DateTime.now();

      for (final ent in targets) {
        final entId = ent['id'] as String;
        final entRef = firestore.collection('enterprises').doc(entId);
        final currentEndTimestamp = ent['trialEndDate'] as Timestamp?;
        final currentEnd = currentEndTimestamp?.toDate() ?? DateTime.now();

        DateTime newEnd;
        String actionType;

        if (exactDays != null) {
          // Mode: Set exact number of remaining days from now
          newEnd = DateTime.now().add(Duration(days: exactDays));
          actionType = 'LICENSE_SET_EXACT_DAYS';
        } else if (exactDate != null) {
          // Mode: Set exact calendar date
          newEnd = exactDate;
          actionType = 'LICENSE_SET_CALENDAR_DATE';
        } else {
          // Mode: Add incremental days to current end date
          final int days = addDays ?? 30;
          final baseDate = currentEnd.isAfter(DateTime.now()) ? currentEnd : DateTime.now();
          newEnd = baseDate.add(Duration(days: days));
          actionType = 'LICENSE_EXTEND_ADD_DAYS';
        }

        if (newEnd.isAfter(maxNewEndDate)) {
          maxNewEndDate = newEnd;
        }

        // Determine plan and upgraded status
        String targetPlan;
        bool targetIsUpgraded;

        if (_selectedPlan == 'keep_current') {
          targetPlan = (ent['plan'] ?? (ent['isUpgraded'] == true ? 'annual' : 'trial')).toString().toLowerCase();
          targetIsUpgraded = ent['isUpgraded'] == true && targetPlan != 'trial';
        } else if (_selectedPlan == 'trial') {
          targetPlan = 'trial';
          targetIsUpgraded = false;
        } else {
          targetPlan = _selectedPlan;
          targetIsUpgraded = true;
        }

        batch.update(entRef, {
          'trialEndDate': Timestamp.fromDate(newEnd),
          'isUpgraded': targetIsUpgraded,
          'isVip': targetPlan == 'vip',
          'plan': targetPlan,
          'subscriptionPlan': targetPlan,
          'subscriptionTier': targetPlan,
          'lastExtendedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Audit log entry for each enterprise
        final auditRef = firestore.collection('audit_logs').doc();
        batch.set(auditRef, {
          'action': actionType,
          'targetUserId': _selectedUserId,
          'targetUserName': userName,
          'targetEnterpriseId': entId,
          'targetCompanyName': ent['name'] ?? 'Entreprise',
          'daysAdded': addDays,
          'exactDaysSet': exactDays,
          'previousEndDate': Timestamp.fromDate(currentEnd),
          'newEndDate': Timestamp.fromDate(newEnd),
          'plan': targetPlan,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Also update client user document
      final userRef = firestore.collection('users').doc(_selectedUserId);
      final bool userIsUpgraded = _selectedPlan == 'keep_current'
          ? targets.any((e) => e['isUpgraded'] == true && e['plan'] != 'trial')
          : (_selectedPlan != 'trial');

      final String userPlan = _selectedPlan == 'keep_current'
          ? (targets.firstOrNull?['plan'] ?? 'trial').toString().toLowerCase()
          : _selectedPlan;

      batch.update(userRef, {
        'isUpgraded': userIsUpgraded,
        'isVip': userPlan == 'vip',
        'plan': userPlan,
        'subscriptionPlan': userPlan,
        'subscriptionTier': userPlan,
        'trialEndDate': Timestamp.fromDate(maxNewEndDate),
        'lastExtendedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      setState(() => _isProcessing = false);

      if (mounted) {
        final daysRemaining = maxNewEndDate.difference(DateTime.now()).inDays;
        final bool isVipPlan = userPlan == 'vip' || targets.any((t) => t['plan'] == 'vip');

        final String message;
        if (isVipPlan) {
          message = targets.length > 1
              ? '⭐ Statut Abonnement VIP accordé avec succès aux ${targets.length} entreprises de "$userName" !'
              : '⭐ Statut Abonnement VIP accordé avec succès pour "${targets.first['name']}" !';
        } else {
          message = targets.length > 1
              ? 'Licences mises à jour pour les ${targets.length} entreprises de "$userName" : expire le ${dateFormat.format(maxNewEndDate)} ($daysRemaining jour(s) restants) !'
              : 'Licence mise à jour pour "${targets.first['name']}" : expire le ${dateFormat.format(maxNewEndDate)} ($daysRemaining jour(s) restants) !';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
        builder: (context, entSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              final allEnterprises = entSnapshot.data?.docs ?? [];
              final allUsers = userSnapshot.data?.docs ?? [];

              // Map enterpriseId -> enterpriseData
              final Map<String, Map<String, dynamic>> entMap = {};
              for (final doc in allEnterprises) {
                entMap[doc.id] = {'id': doc.id, ...doc.data()};
              }

              // Filter users to Primary Clients / Account Owners
              final clientUsers = allUsers.where((u) {
                final d = u.data();
                final role = (d['role'] ?? '').toString().toLowerCase();
                final isCollaborator = role == 'collaborator';
                return !isCollaborator || d['isOwner'] == true;
              }).toList();

              // Helper to compute enterprises owned by a specific user
              List<Map<String, dynamic>> getUserEnterprises(String uid, String email) {
                final list = <Map<String, dynamic>>[];
                for (final ent in allEnterprises) {
                  final ed = ent.data();
                  if (ed['ownerId'] == uid || ed['ownerEmail'] == email) {
                    list.add({'id': ent.id, ...ed});
                  }
                }
                final uDoc = allUsers.where((doc) => doc.id == uid).firstOrNull;
                if (uDoc != null) {
                  final entList = uDoc.data()['enterprises'];
                  if (entList is List) {
                    for (final item in entList) {
                      final String? eid = item is Map ? (item['id'] as String?) : (item is String ? item : null);
                      if (eid != null && eid.isNotEmpty && !list.any((e) => e['id'] == eid)) {
                        if (entMap.containsKey(eid)) {
                          list.add(entMap[eid]!);
                        }
                      }
                    }
                  }
                }
                return list;
              }

              // Selected user and their enterprises
              final selectedUserDoc = _selectedUserId != null
                  ? allUsers.where((u) => u.id == _selectedUserId).firstOrNull
                  : null;
              final selectedUserData = selectedUserDoc?.data() ?? {};
              final selectedUserName = selectedUserData['name'] ?? selectedUserData['displayName'] ?? 'Client';
              final selectedUserEmail = selectedUserData['email'] ?? '';
              final selectedUserEnterprises = _selectedUserId != null
                  ? getUserEnterprises(_selectedUserId!, selectedUserEmail)
                  : <Map<String, dynamic>>[];

              // Ensure valid _selectedEnterpriseId
              if (selectedUserEnterprises.isNotEmpty && _selectedEnterpriseId == null) {
                _selectedEnterpriseId = selectedUserEnterprises.length > 1 ? 'ALL' : selectedUserEnterprises.first['id'];
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Extension & Ajustement Précis des Licences',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Fixez le nombre exact de jours, ajoutez des bonus ou choisissez une date d\'expiration calendaire.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── Step 1: Select Client & Associated Enterprise ───
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '1. Sélectionner le Client (Compte Utilisateur)',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Choisissez le client propriétaire. Ses entreprises apparaîtront automatiquement ci-dessous.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 14),

                            // User / Client Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _selectedUserId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: 'Sélectionner un compte client...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF2563EB)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: clientUsers.map((userDoc) {
                                final d = userDoc.data();
                                final name = d['name'] ?? d['displayName'] ?? 'Client sans nom';
                                final email = d['email'] ?? 'Sans email';
                                final ents = getUserEnterprises(userDoc.id, email);
                                final isBanned = d['isBanned'] == true || d['status'] == 'banned';

                                return DropdownMenuItem<String>(
                                  value: userDoc.id,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: isBanned ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                        child: Icon(
                                          isBanned ? Icons.block_rounded : Icons.person_rounded,
                                          size: 14,
                                          color: isBanned ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '$name ($email)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isBanned ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${ents.length} entr.',
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (uid) {
                                setState(() {
                                  _selectedUserId = uid;
                                  if (uid != null) {
                                    final uDoc = allUsers.where((u) => u.id == uid).firstOrNull;
                                    final uEmail = uDoc?.data()['email'] ?? '';
                                    final userEnts = getUserEnterprises(uid, uEmail);
                                    if (userEnts.isNotEmpty) {
                                      _selectedEnterpriseId = userEnts.length > 1 ? 'ALL' : userEnts.first['id'];
                                    } else {
                                      _selectedEnterpriseId = null;
                                    }
                                  } else {
                                    _selectedEnterpriseId = null;
                                  }
                                });
                              },
                            ),

                            // ─── Step 1.b: Target Enterprise Selector ───
                            if (_selectedUserId != null) ...[
                              const SizedBox(height: 18),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 16),

                              if (selectedUserEnterprises.isEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Ce client n\'a pas encore créé d\'entreprise. Une entreprise doit être créée pour appliquer une licence.',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    const Icon(Icons.business_rounded, size: 16, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Entreprise(s) cible(s) à configurer :',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${selectedUserEnterprises.length} entreprise(s) associée(s)',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                DropdownButtonFormField<String>(
                                  initialValue: _selectedEnterpriseId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                  ),
                                  items: [
                                    if (selectedUserEnterprises.length > 1)
                                      DropdownMenuItem<String>(
                                        value: 'ALL',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.all_inclusive_rounded, size: 16, color: Color(0xFF059669)),
                                            const SizedBox(width: 8),
                                            Text(
                                              '⭐ Toutes les entreprises du client (${selectedUserEnterprises.length} entreprises)',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ...selectedUserEnterprises.map((ent) {
                                      final name = ent['name'] ?? 'Entreprise sans nom';
                                      final tax = ent['taxNumber'] ?? 'N/A';
                                      final isUp = ent['isUpgraded'] == true;
                                      final plan = ent['plan'] ?? (isUp ? 'Annuel' : 'Essai');

                                      return DropdownMenuItem<String>(
                                        value: ent['id'] as String,
                                        child: Text(
                                          '$name (Matricule: $tax) • Plan actuel: $plan',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedEnterpriseId = val);
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Summary Preview of targeted enterprises
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _selectedEnterpriseId == 'ALL' ? Icons.playlist_add_check_rounded : Icons.info_outline_rounded,
                                            size: 16,
                                            color: const Color(0xFF2563EB),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedEnterpriseId == 'ALL'
                                                ? 'État actuel des ${selectedUserEnterprises.length} entreprises du client :'
                                                : 'Détail de l\'entreprise sélectionnée :',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: selectedUserEnterprises.map((ent) {
                                          final isTargeted = _selectedEnterpriseId == 'ALL' || _selectedEnterpriseId == ent['id'];
                                          final name = ent['name'] ?? 'Entreprise';
                                          final isUp = ent['isUpgraded'] == true;
                                          final trialEnd = (ent['trialEndDate'] as Timestamp?)?.toDate();
                                          final daysLeft = trialEnd != null ? trialEnd.difference(DateTime.now()).inDays : 0;
                                          final isExpired = daysLeft < 0;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isTargeted ? Colors.white : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isTargeted ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                                width: isTargeted ? 1.5 : 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.business_rounded,
                                                  size: 14,
                                                  color: isTargeted ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: isTargeted ? FontWeight.bold : FontWeight.w500,
                                                    color: isTargeted ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: ent['plan'] == 'vip'
                                                        ? const Color(0xFFFEF3C7)
                                                        : (isExpired
                                                            ? const Color(0xFFFEE2E2)
                                                            : (isUp ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7))),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Text(
                                                    ent['plan'] == 'vip'
                                                        ? '⭐ VIP'
                                                        : (isExpired
                                                            ? 'Expirée'
                                                            : (trialEnd != null ? '$daysLeft j restants' : (isUp ? 'Abonné' : 'Essai'))),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: ent['plan'] == 'vip'
                                                          ? const Color(0xFFB45309)
                                                          : (isExpired
                                                              ? const Color(0xFFDC2626)
                                                              : (isUp ? const Color(0xFF059669) : const Color(0xFFD97706))),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ─── Step 2: Define Duration & Plan ───
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('2. Définir la Durée & la Formule Cible', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 14),

                            // Plan selection
                            const Text('Formule d\'abonnement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPlan,
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'keep_current', child: Text('Conserver le plan actuel (Essai ou Abonné)')),
                                DropdownMenuItem(value: 'vip', child: Text('⭐ Abonnement VIP (Accès Privilégié / Permanent)')),
                                DropdownMenuItem(value: 'trial', child: Text('Période d\'Essai (Prolongation Gratuite / Bonus)')),
                                DropdownMenuItem(value: 'monthly', child: Text('Plan Mensuel (Standard)')),
                                DropdownMenuItem(value: 'annual', child: Text('Plan Annuel (Recommandé)')),
                                DropdownMenuItem(value: 'enterprise', child: Text('Plan Entreprise (Grand Compte)')),
                              ],
                              onChanged: (v) => v != null ? setState(() => _selectedPlan = v) : null,
                            ),
                            const SizedBox(height: 16),

                            // VIP Quick Activation Banner Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Accorder le statut Abonnement VIP',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Configure la formule sur "VIP" avec 10 ans de validité. Dans l\'interface du client, le bandeau affichera immédiatement "Abonnement VIP" au lieu du décompte standard.',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _isProcessing || _selectedUserId == null
                                        ? null
                                        : () {
                                            setState(() => _selectedPlan = 'vip');
                                            _applyExtension(
                                              exactDays: 3650, // 10 ans de licence VIP
                                              userEnterprises: selectedUserEnterprises,
                                              userName: selectedUserName,
                                            );
                                          },
                                    icon: const Icon(Icons.verified_rounded, size: 16),
                                    label: const Text(
                                      'Confirmer VIP',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ─── Duration Mode Selector (Tabs) ───
                            const Text('Méthode d\'ajustement de la durée', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  _modeTab(
                                    id: 'exact',
                                    label: 'Fixer le nombre exact de jours',
                                    icon: Icons.pin_rounded,
                                  ),
                                  _modeTab(
                                    id: 'add',
                                    label: 'Ajouter des jours (+X)',
                                    icon: Icons.add_circle_outline_rounded,
                                  ),
                                  _modeTab(
                                    id: 'calendar',
                                    label: 'Date d\'expiration exacte (Calendrier)',
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // ─── Mode 1: Exact Remaining Days ───
                            if (_durationMode == 'exact') ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Fixer la durée restante exacte (à partir d\'aujourd\'hui) :',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Quick Chips for exact days
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _exactChip(7),
                                        _exactChip(11),
                                        _exactChip(14),
                                        _exactChip(30),
                                        _exactChip(90),
                                        _exactChip(365),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _exactDaysController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Nombre exact de jours restants',
                                              hintText: 'Ex: 11',
                                              suffixText: 'jours restants',
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: _isProcessing
                                              ? null
                                              : () {
                                                  final d = int.tryParse(_exactDaysController.text.trim()) ?? 0;
                                                  if (d > 0) {
                                                    _applyExtension(
                                                      exactDays: d,
                                                      userEnterprises: selectedUserEnterprises,
                                                      userName: selectedUserName,
                                                    );
                                                  }
                                                },
                                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                                          label: Text('Fixer à ${_exactDaysController.text.trim()} j restants'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Builder(
                                      builder: (_) {
                                        final d = int.tryParse(_exactDaysController.text.trim()) ?? 0;
                                        final targetDate = DateTime.now().add(Duration(days: d));
                                        return Text(
                                          'ℹ️ L\'abonnement/essai expirera exactement le ${dateFormat.format(targetDate)}.',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ─── Mode 2: Incremental Days (+X) ───
                            if (_durationMode == 'add') ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.add_circle_rounded, size: 16, color: Color(0xFF059669)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Ajouter des jours bonus à la date de fin actuelle (+ jours) :',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _quickButton('+5 Jours Bonus', 5, Icons.card_giftcard_rounded, selectedUserEnterprises, selectedUserName),
                                        _quickButton('+30 Jours (Mensuel)', 30, Icons.date_range_rounded, selectedUserEnterprises, selectedUserName),
                                        _quickButton('+90 Jours (Trimestre)', 90, Icons.calendar_month_rounded, selectedUserEnterprises, selectedUserName),
                                        _quickButton('+365 Jours (Annuel)', 365, Icons.verified_rounded, selectedUserEnterprises, selectedUserName),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _addDaysController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Nombre de jours à ajouter',
                                              hintText: 'Ex: 15',
                                              suffixText: 'jours à ajouter',
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: _isProcessing
                                              ? null
                                              : () {
                                                  final d = int.tryParse(_addDaysController.text.trim()) ?? 0;
                                                  if (d > 0) {
                                                    _applyExtension(
                                                      addDays: d,
                                                      userEnterprises: selectedUserEnterprises,
                                                      userName: selectedUserName,
                                                    );
                                                  }
                                                },
                                          icon: const Icon(Icons.add_rounded, size: 18),
                                          label: Text('Ajouter +${_addDaysController.text.trim()} jours'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ─── Mode 3: Calendar Date Picker ───
                            if (_durationMode == 'calendar') ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF7C3AED)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sélectionner la date d\'expiration exacte dans le calendrier :',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: _selectedCalendarDate ?? DateTime.now().add(const Duration(days: 30)),
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                              );
                                              if (picked != null) {
                                                setState(() => _selectedCalendarDate = picked);
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF7C3AED)),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _selectedCalendarDate != null
                                                        ? dateFormat.format(_selectedCalendarDate!)
                                                        : 'Choisir une date...',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                                  ),
                                                  const Spacer(),
                                                  if (_selectedCalendarDate != null)
                                                    Text(
                                                      '(${_selectedCalendarDate!.difference(DateTime.now()).inDays} jours restants)',
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF7C3AED),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: _isProcessing || _selectedCalendarDate == null
                                              ? null
                                              : () {
                                                  _applyExtension(
                                                    exactDate: _selectedCalendarDate!,
                                                    userEnterprises: selectedUserEnterprises,
                                                    userName: selectedUserName,
                                                  );
                                                },
                                          icon: const Icon(Icons.event_available_rounded, size: 18),
                                          label: const Text('Appliquer cette Date'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),

                            // Reason for Operation
                            const Text('Motif de l\'opération (Audit Log obligatoire)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _reasonController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Précisez la raison de la modification...',
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _modeTab({required String id, required String label, required IconData icon}) {
    final isSelected = _durationMode == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _durationMode = id),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exactChip(int days) {
    final isSelected = _exactDaysController.text.trim() == days.toString();
    return ActionChip(
      label: Text('$days jours restants'),
      backgroundColor: isSelected ? const Color(0xFF2563EB) : Colors.white,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
      ),
      onPressed: () {
        setState(() {
          _exactDaysController.text = days.toString();
        });
      },
    );
  }

  Widget _quickButton(String label, int days, IconData icon, List<Map<String, dynamic>> enterprises, String userName) {
    return ElevatedButton.icon(
      onPressed: _isProcessing
          ? null
          : () => _applyExtension(
                addDays: days,
                userEnterprises: enterprises,
                userName: userName,
              ),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: days == 365 ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
        foregroundColor: days == 365 ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
