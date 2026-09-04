import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../tenant_xray_screen.dart';
import '../../../utils/file_download_helper.dart';

class ClientSearchScreen extends StatefulWidget {
  const ClientSearchScreen({super.key});

  @override
  State<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends State<ClientSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<DocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  Map<String, Map<String, dynamic>> _entMap = {};
  List<DocumentSnapshot<Map<String, dynamic>>> _results = [];
  bool _isLoading = false;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final entSnap = await FirebaseFirestore.instance.collection('enterprises').get();
      final userSnap = await FirebaseFirestore.instance.collection('users').get();

      final Map<String, Map<String, dynamic>> em = {};
      for (final d in entSnap.docs) {
        em[d.id] = {'id': d.id, ...d.data()};
      }

      setState(() {
        _entMap = em;
        _allUsers = userSnap.docs;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();

    final filtered = _allUsers.where((doc) {
      final data = doc.data() ?? {};
      final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final id = doc.id.toLowerCase();
      final isBanned = data['isBanned'] == true ||
          data['isDisabled'] == true ||
          data['status'] == 'banned' ||
          data['status'] == 'disabled' ||
          data['isActive'] == false;

      // Find user enterprises
      final userEntIds = <String>{};
      final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
      if (curEnt != null && curEnt.toString().isNotEmpty) userEntIds.add(curEnt.toString());
      final entList = data['enterprises'];
      if (entList is List) {
        for (final e in entList) {
          if (e != null && e.toString().isNotEmpty) userEntIds.add(e.toString());
        }
      }

      if (q.isNotEmpty) {
        bool matchesEnt = false;
        for (final eid in userEntIds) {
          final entData = _entMap[eid];
          if (entData != null) {
            final entName = (entData['name'] ?? '').toString().toLowerCase();
            final tax = (entData['taxNumber'] ?? '').toString().toLowerCase();
            if (entName.contains(q) || tax.contains(q)) {
              matchesEnt = true;
              break;
            }
          }
        }

        final matches = name.contains(q) || phone.contains(q) || email.contains(q) || id.contains(q) || matchesEnt;
        if (!matches) return false;
      }

      if (_selectedStatus == 'active' && isBanned) return false;
      if (_selectedStatus == 'banned' && !isBanned) return false;

      return true;
    }).toList();

    setState(() {
      _results = filtered;
    });
  }

  Future<void> _exportSearchResults() async {
    if (_results.isEmpty) return;

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('ID Client,Nom Contact,Email,Telephone,Statut,Entreprises Gerees');

    for (final doc in _results) {
      final data = doc.data() ?? {};
      final name = (data['name'] ?? data['displayName'] ?? '').toString().replaceAll('"', '""');
      final email = (data['email'] ?? '').toString().replaceAll('"', '""');
      final phone = (data['phone'] ?? '').toString().replaceAll('"', '""');
      final isBanned = data['isBanned'] == true || data['status'] == 'banned' || data['isActive'] == false;
      final status = isBanned ? 'Banni' : 'Actif';

      final userEntIds = <String>{};
      final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
      if (curEnt != null && curEnt.toString().isNotEmpty) userEntIds.add(curEnt.toString());
      final entList = data['enterprises'];
      if (entList is List) {
        for (final e in entList) {
          if (e != null && e.toString().isNotEmpty) userEntIds.add(e.toString());
        }
      }

      final entNames = userEntIds.map((id) => _entMap[id]?['name'] ?? id).join(' | ').replaceAll('"', '""');

      csvBuffer.writeln('"${doc.id}","$name","$email","$phone","$status","$entNames"');
    }

    final fileName = 'resultats_recherche_clients_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    if (!mounted) return;
    await FileDownloadHelper.saveStringFile(
      csvBuffer.toString(),
      fileName,
      mimeType: 'text/csv',
      context: context,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export réussi (${_results.length} résultats) : $fileName'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Rechercher un Client',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recherche multi-critères instantanée sur les comptes clients et l\'ensemble de leurs entreprises.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _results.isNotEmpty ? _exportSearchResults : null,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Exporter Résultats (CSV)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom client, email, téléphone, matricule ou nom d\'entreprise...',
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

                // Status Filter
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
                      value: _selectedStatus,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous les statuts')),
                        DropdownMenuItem(value: 'active', child: Text('Actifs')),
                        DropdownMenuItem(value: 'banned', child: Text('Bannis / Suspendus')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStatus = v);
                          _applyFilter();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results count
            Text(
              '${_results.length} client(s) trouvé(s)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 12),
                              Text('Aucun résultat trouvé', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = _results[index];
                            final data = doc.data() ?? {};
                            final name = data['name'] ?? data['displayName'] ?? 'Client sans nom';
                            final email = data['email'] ?? 'N/A';
                            final phone = data['phone'] ?? 'N/A';
                            final isBanned = data['isBanned'] == true ||
                                data['isDisabled'] == true ||
                                data['status'] == 'banned' ||
                                data['status'] == 'disabled' ||
                                data['isActive'] == false;

                            // Resolve user enterprises
                            final userEntIds = <String>{};
                            final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
                            if (curEnt != null && curEnt.toString().isNotEmpty) userEntIds.add(curEnt.toString());
                            final entList = data['enterprises'];
                            if (entList is List) {
                              for (final e in entList) {
                                if (e != null && e.toString().isNotEmpty) userEntIds.add(e.toString());
                              }
                            }

                            final userEnterprises = userEntIds
                                .map((eid) => _entMap[eid] ?? {'id': eid, 'name': 'Entreprise ($eid)'})
                                .toList();

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
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isBanned ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                          child: Icon(
                                            isBanned ? Icons.block_rounded : Icons.person_rounded,
                                            color: isBanned ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isBanned ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      isBanned ? 'BANNI' : 'ACTIF',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isBanned ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text('ID Client: ${doc.id} • Email: $email • Tél: $phone', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        if (userEnterprises.isNotEmpty)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: userEnterprises.first['id']!)),
                                              );
                                            },
                                            icon: const Icon(Icons.manage_search_rounded, size: 16),
                                            label: Text('Inspecter (${userEnterprises.length})'),
                                          ),
                                      ],
                                    ),
                                    if (userEnterprises.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: userEnterprises.map((ent) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                            child: Text('🏢 ${ent['name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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
