import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../tenant_xray_screen.dart';

class AllClientsScreen extends StatefulWidget {
  const AllClientsScreen({super.key});

  @override
  State<AllClientsScreen> createState() => _AllClientsScreenState();
}

class _AllClientsScreenState extends State<AllClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _accountTypeFilter = 'owners'; // 'owners' (default), 'all', 'collaborators'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBanUserDialog(
    BuildContext context,
    String userId,
    String userName,
    String userEmail,
    List<Map<String, dynamic>> userEnterprises,
    List<Map<String, dynamic>> collaborators,
    bool isCurrentlyBanned,
  ) {
    final reasonController = TextEditingController(
      text: isCurrentlyBanned ? 'Réactivation suite à régularisation.' : 'Non-respect des conditions d\'utilisation / Défaut de paiement.',
    );

    final enterpriseNames = userEnterprises.map((e) => e['name'] ?? 'Entreprise').join(', ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrentlyBanned ? 'Réactiver le client' : 'Bannir / Suspendre le client'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentlyBanned
                    ? 'Voulez-vous réactiver le compte de "$userName" ($userEmail) ?\nSes ${userEnterprises.length} entreprise(s) ($enterpriseNames) et tous ses collaborateurs seront également réactivés.'
                    : 'Attention : Bannir "$userName" ($userEmail) bloquera immédiatement sa connexion et suspendra TOUTES ses ${userEnterprises.length} entreprise(s) ($enterpriseNames) ainsi que ses ${collaborators.length} collaborateur(s) invité(s).',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Motif de l\'action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyBanned ? const Color(0xFF059669) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final firestore = FirebaseFirestore.instance;
              final batch = firestore.batch();

              // 1. Update Client / Owner document
              final userRef = firestore.collection('users').doc(userId);
              batch.update(userRef, {
                'isBanned': !isCurrentlyBanned,
                'isDisabled': !isCurrentlyBanned,
                'status': !isCurrentlyBanned ? 'banned' : 'active',
                'banReason': !isCurrentlyBanned ? reasonController.text.trim() : null,
                'bannedAt': !isCurrentlyBanned ? FieldValue.serverTimestamp() : null,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // 2. Update all client's enterprises
              for (final ent in userEnterprises) {
                final entId = ent['id'] as String?;
                if (entId != null && entId.isNotEmpty) {
                  final entRef = firestore.collection('enterprises').doc(entId);
                  batch.update(entRef, {
                    'isBanned': !isCurrentlyBanned,
                    'status': !isCurrentlyBanned ? 'banned' : 'active',
                    'banReason': !isCurrentlyBanned ? reasonController.text.trim() : null,
                    'bannedAt': !isCurrentlyBanned ? FieldValue.serverTimestamp() : null,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
              }

              // 3. Update all collaborators attached to these enterprises
              for (final col in collaborators) {
                final colId = col['id'] as String?;
                if (colId != null && colId.isNotEmpty && colId != userId) {
                  final colRef = firestore.collection('users').doc(colId);
                  batch.update(colRef, {
                    'isBanned': !isCurrentlyBanned,
                    'isDisabled': !isCurrentlyBanned,
                    'status': !isCurrentlyBanned ? 'banned' : 'active',
                    'banReason': !isCurrentlyBanned ? 'Entreprise parente suspendue' : null,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
              }

              // 4. Log Audit
              final auditRef = firestore.collection('audit_logs').doc();
              batch.set(auditRef, {
                'action': !isCurrentlyBanned ? 'BAN_CLIENT_AND_ALL_ENTERPRISES' : 'UNBAN_CLIENT_AND_ALL_ENTERPRISES',
                'targetUserId': userId,
                'targetUserName': userName,
                'targetUserEmail': userEmail,
                'enterprisesCount': userEnterprises.length,
                'enterprises': enterpriseNames,
                'collaboratorsCount': collaborators.length,
                'reason': reasonController.text.trim(),
                'timestamp': FieldValue.serverTimestamp(),
              });

              await batch.commit();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isCurrentlyBanned ? 'Client, entreprises et collaborateurs réactivés avec succès !' : 'Client et toutes ses entreprises bannis.'),
                    backgroundColor: isCurrentlyBanned ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: Text(isCurrentlyBanned ? 'Confirmer la Réactivation' : 'Confirmer le Bannissement'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, String userId, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: data['name'] ?? data['displayName'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    String role = data['role'] ?? 'admin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier les informations du compte client'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nom complet / Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Téléphone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Rôle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Propriétaire / Administrateur')),
                      DropdownMenuItem(value: 'collaborator', child: Text('Collaborateur')),
                      DropdownMenuItem(value: 'viewer', child: Text('Lecteur seul')),
                    ],
                    onChanged: (v) => setDialogState(() => role = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'role': role,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compte client mis à jour !'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendPasswordReset(BuildContext context, String email) async {
    if (email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email de réinitialisation envoyé à $email !'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  void _openXRayForUser(BuildContext context, List<Map<String, dynamic>> enterprises) {
    if (enterprises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune entreprise rattachée à ce compte.'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    if (enterprises.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: enterprises.first['id']!)),
      );
      return;
    }

    // Multiple enterprises dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner une entreprise à inspecter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: enterprises.map((ent) {
            final name = ent['name'] ?? 'Entreprise';
            final id = ent['id'] ?? '';
            final plan = (ent['plan'] ?? 'Essai').toString().toUpperCase();

            return ListTile(
              leading: const Icon(Icons.business_rounded, color: Color(0xFF2563EB)),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text('ID: $id • Formule: $plan', style: const TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: id)),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Title Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Annuaire de Tous les Clients (Comptes Principaux)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gestion des comptes clients souscripteurs, de leurs entreprises associées et de leurs collaborateurs.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search Bar & Filter Controls
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom client, email, téléphone, entreprise...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Account Type Filter (Owners vs All vs Collaborators)
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _accountTypeFilter,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'owners', child: Text('Comptes Clients (Propriétaires)')),
                        DropdownMenuItem(value: 'all', child: Text('Tous les comptes')),
                        DropdownMenuItem(value: 'collaborators', child: Text('Collaborateurs invités')),
                      ],
                      onChanged: (v) => v != null ? setState(() => _accountTypeFilter = v) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Status Filter Dropdown
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous les statuts')),
                        DropdownMenuItem(value: 'active', child: Text('Actifs')),
                        DropdownMenuItem(value: 'banned', child: Text('Bannis / Suspendus')),
                      ],
                      onChanged: (v) => v != null ? setState(() => _statusFilter = v) : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Real-time Stream joining Users & Enterprises
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
                builder: (context, enterpriseSnapshot) {
                  final allEnterprises = enterpriseSnapshot.data?.docs ?? [];

                  // Map enterpriseId -> enterpriseData
                  final Map<String, Map<String, dynamic>> entMap = {};
                  for (final doc in allEnterprises) {
                    entMap[doc.id] = {'id': doc.id, ...doc.data()};
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final userDocs = userSnapshot.data?.docs ?? [];
                      final query = _searchController.text.trim().toLowerCase();

                      // Map each user to their owned enterprises & memberships
                      final filteredUsers = userDocs.where((doc) {
                        final data = doc.data();
                        final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                        final email = (data['email'] ?? '').toString().toLowerCase();
                        final phone = (data['phone'] ?? '').toString().toLowerCase();
                        final id = doc.id.toLowerCase();
                        final role = (data['role'] ?? '').toString().toLowerCase();
                        final isOwner = data['isOwner'] == true;

                        final isBanned = data['isBanned'] == true ||
                            data['isDisabled'] == true ||
                            data['status'] == 'banned' ||
                            data['status'] == 'disabled' ||
                            data['isActive'] == false;

                        // Identify whether this user is an Enterprise Owner / Primary Account
                        bool ownsEnterprises = false;
                        for (final ent in allEnterprises) {
                          if (ent.data()['ownerId'] == doc.id) {
                            ownsEnterprises = true;
                            break;
                          }
                        }
                        final isPrimaryClient = isOwner || ownsEnterprises || (role == 'admin');

                        // Account Type filtering
                        if (_accountTypeFilter == 'owners' && !isPrimaryClient) return false;
                        if (_accountTypeFilter == 'collaborators' && isPrimaryClient) return false;

                        // Status filtering
                        if (_statusFilter == 'active' && isBanned) return false;
                        if (_statusFilter == 'banned' && !isBanned) return false;

                        // Search matching
                        if (query.isNotEmpty) {
                          final userEntIds = <String>{};
                          final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
                          if (curEnt != null && curEnt.toString().isNotEmpty) userEntIds.add(curEnt.toString());
                          final entList = data['enterprises'];
                          if (entList is List) {
                            for (final e in entList) {
                              if (e != null && e.toString().isNotEmpty) userEntIds.add(e.toString());
                            }
                          }
                          for (final ent in allEnterprises) {
                            if (ent.data()['ownerId'] == doc.id) userEntIds.add(ent.id);
                          }

                          bool matchesEnterprise = false;
                          for (final eid in userEntIds) {
                            final entData = entMap[eid];
                            if (entData != null) {
                              final entName = (entData['name'] ?? '').toString().toLowerCase();
                              if (entName.contains(query)) {
                                matchesEnterprise = true;
                                break;
                              }
                            }
                          }

                          final matches = name.contains(query) || email.contains(query) || phone.contains(query) || id.contains(query) || matchesEnterprise;
                          if (!matches) return false;
                        }

                        return true;
                      }).toList();

                      if (filteredUsers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.person_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 12),
                              Text('Aucun client ne correspond aux critères', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final userDoc = filteredUsers[index];
                          final data = userDoc.data();
                          final userId = userDoc.id;
                          final name = data['name'] ?? data['displayName'] ?? (data['email'] != null ? data['email'].toString().split('@').first : 'Client sans nom');
                          final email = data['email'] ?? 'N/A';
                          final phone = data['phone'] ?? 'N/A';
                          final role = (data['role'] ?? 'ADMIN').toString().toUpperCase();
                          final isOwner = data['isOwner'] == true;

                          final isBanned = data['isBanned'] == true ||
                              data['isDisabled'] == true ||
                              data['status'] == 'banned' ||
                              data['status'] == 'disabled' ||
                              data['isActive'] == false;

                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                          // Resolve user's enterprises (strictly owned or main workspace)
                          final userEntIds = <String>{};
                          for (final ent in allEnterprises) {
                            if (ent.data()['ownerId'] == userId) {
                              userEntIds.add(ent.id);
                            }
                          }
                          // Fallback to enterprises array if no direct ownerId match
                          if (userEntIds.isEmpty) {
                            final entList = data['enterprises'];
                            if (entList is List) {
                              for (final e in entList) {
                                if (e != null && e.toString().isNotEmpty) userEntIds.add(e.toString());
                              }
                            }
                            final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
                            if (curEnt != null && curEnt.toString().isNotEmpty) userEntIds.add(curEnt.toString());
                          }

                          final userEnterprises = userEntIds
                              .map((eid) => entMap[eid] ?? {'id': eid, 'name': 'Entreprise ($eid)'})
                              .toList();

                          // Find collaborators attached to these enterprises
                          final collaborators = userDocs.where((ud) {
                            if (ud.id == userId) return false;
                            final uData = ud.data();
                            final curE = uData['currentEnterpriseId'] ?? uData['enterpriseId'];
                            final eList = uData['enterprises'];
                            return userEntIds.contains(curE) || (eList is List && eList.any((e) => userEntIds.contains(e)));
                          }).map((ud) => {'id': ud.id, ...ud.data()}).toList();

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isBanned ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    width: 4.5,
                                    color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: isBanned ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                                child: Icon(
                                                  isBanned ? Icons.block_rounded : Icons.person_rounded,
                                                  color: isBanned ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A))),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isBanned ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            isBanned ? 'BANNI / SUSPENDU' : 'CLIENT ACTIF',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: isBanned ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                                          child: Text(
                                                            isOwner ? 'PROPRIÉTAIRE' : role,
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'ID : $userId • Email : $email • Tél : $phone ${createdAt != null ? "• Inscrit le : ${dateFormat.format(createdAt)}" : ""}',
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Envoyer réinitialisation mot de passe',
                                                    icon: const Icon(Icons.key_rounded, color: Color(0xFFF59E0B), size: 19),
                                                    onPressed: () => _sendPasswordReset(context, email),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  OutlinedButton.icon(
                                                    onPressed: () => _showEditUserDialog(context, userId, data),
                                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                                    label: const Text('Modifier'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: const Color(0xFF334155),
                                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    tooltip: isBanned ? 'Réactiver le client et toutes ses entreprises' : 'Bannir le client et toutes ses entreprises',
                                                    icon: Icon(
                                                      isBanned ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                                                      color: isBanned ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                      size: 20,
                                                    ),
                                                    onPressed: () => _showBanUserDialog(
                                                      context,
                                                      userId,
                                                      name,
                                                      email,
                                                      userEnterprises,
                                                      collaborators,
                                                      isBanned,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _openXRayForUser(context, userEnterprises),
                                                    icon: const Icon(Icons.manage_search_rounded, size: 16),
                                                    label: Text(userEnterprises.length > 1 ? 'Inspecter (${userEnterprises.length})' : 'Inspecter (X-Ray)'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF2563EB),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          // Enterprises Chips for this user
                                          if (userEnterprises.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                            const SizedBox(height: 8),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.business_rounded, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Entreprises du client (${userEnterprises.length}) :',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: userEnterprises.map((ent) {
                                                      final entName = ent['name'] ?? 'Entreprise';
                                                      final isUp = ent['isUpgraded'] == true;
                                                      final entPlan = (ent['plan'] ?? (isUp ? 'Annuel' : 'Essai')).toString();
                                                      final entBanned = ent['isBanned'] == true || ent['status'] == 'banned';

                                                      return InkWell(
                                                        onTap: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: ent['id']!)),
                                                          );
                                                        },
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: entBanned
                                                                ? const Color(0xFFFEE2E2)
                                                                : const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(
                                                              color: entBanned
                                                                  ? const Color(0xFFFECDD3)
                                                                  : const Color(0xFFE2E8F0),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                entName,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: entBanned ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '($entPlan)',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: entBanned ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],

                                          // Collaborators sub-line if any
                                          if (collaborators.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.people_alt_outlined, size: 13, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${collaborators.length} Collaborateur(s) rattaché(s) : ',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    collaborators.map((c) => '${c['name'] ?? c['email']}').join(', '),
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
