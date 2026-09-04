import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tenant_xray_screen.dart';

class TenantSearchScreen extends StatefulWidget {
  const TenantSearchScreen({super.key});

  @override
  State<TenantSearchScreen> createState() => _TenantSearchScreenState();
}

class _TenantSearchScreenState extends State<TenantSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<DocumentSnapshot<Map<String, dynamic>>> _results = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('enterprises')
          .limit(50)
          .get();

      final q = query.toLowerCase();
      final filtered = snap.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final tax = (data['taxNumber'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || tax.contains(q) || phone.contains(q) || email.contains(q) || doc.id.toLowerCase().contains(q);
      }).toList();

      setState(() {
        _results = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
            const Text(
              'Recherche & Inspection Entreprises (Tenants)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recherchez et inspectez n\'importe quel tenant pour visualiser ses métriques, utilisateurs et historique de facturation.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom d\'entreprise, matricule fiscal, email, téléphone ou ID...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                suffixIcon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
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
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text(_searchController.text.isEmpty ? 'Saisissez un terme pour rechercher' : 'Aucune entreprise trouvée', style: const TextStyle(color: Color(0xFF64748B))))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data = _results[index].data() ?? {};
                        final entId = _results[index].id;
                        final isUpgraded = data['isUpgraded'] == true;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.business_rounded, color: Color(0xFF2563EB))),
                            title: Text(data['name'] ?? 'Entreprise sans nom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('ID : $entId • Matricule : ${data['taxNumber'] ?? "N/A"} • Tél : ${data['phone'] ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                            trailing: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: entId)),
                                );
                              },
                              icon: const Icon(Icons.visibility_rounded, size: 16),
                              label: const Text('Inspecter (X-Ray)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isUpgraded ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                              ),
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
