import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/overtime_rate.dart';
import 'enterprise_service.dart';
import 'firestore_repository.dart';

/// Service de gestion des Taux d'Heures Supplémentaires Odoo ERP (Screenshots 1 à 5)
class OvertimeRateService {
  static final OvertimeRateService instance = OvertimeRateService._();
  OvertimeRateService._();

  static const Color _odooPurple = Color(0xFF1A56DB);

  final List<OvertimeRate> _rates = [];
  bool _initialized = false;

  List<OvertimeRate> get rates => List.unmodifiable(_rates.where((r) => !r.isDeleted));

  /// Initialise la liste des taux d'heures supplémentaires
  Future<void> init() async {
    if (_initialized && _rates.isNotEmpty) return;

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      final entName = EnterpriseService.instance.currentEnterprise?.name ?? 'My Company';

      // 1. Charger depuis le cache local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_overtime_rates');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List list = jsonDecode(cachedJson);
          _rates.clear();
          for (final item in list) {
            _rates.add(OvertimeRate.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        } catch (_) {}
      }

      // 2. Si vide, pré-remplir avec les taux standards Odoo (Screenshot 1, 2, 3, 4, 5)
      if (_rates.isEmpty) {
        _rates.addAll([
          OvertimeRate(
            id: 'rate_1_25',
            name: 'x 1.25',
            rate: 1.25,
            company: entName,
            enterpriseId: currentEntId,
          ),
          OvertimeRate(
            id: 'rate_1_5',
            name: 'x 1.5',
            rate: 1.50,
            company: entName,
            enterpriseId: currentEntId,
          ),
          OvertimeRate(
            id: 'rate_1_75',
            name: 'x 1.75',
            rate: 1.75,
            company: entName,
            enterpriseId: currentEntId,
          ),
          OvertimeRate(
            id: 'rate_2_0',
            name: '2',
            rate: 2.00,
            company: entName,
            enterpriseId: currentEntId,
          ),
          OvertimeRate(
            id: 'rate_x_2',
            name: 'X2',
            rate: 2.00,
            company: entName,
            enterpriseId: currentEntId,
          ),
        ]);
        await _saveLocalCache();
      }

      // 3. Charger depuis Firestore en arrière-plan
      _loadFromFirestore();
      _initialized = true;
    } catch (_) {}
  }

  Future<void> _loadFromFirestore() async {
    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('overtime_rates');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        final List<OvertimeRate> remote = [];
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['id'] = doc.id;
          final isDel = data['is_deleted'] == 1 || data['is_deleted'] == true;
          if (!isDel) {
            remote.add(OvertimeRate.fromMap(data));
          }
        }
        if (remote.isNotEmpty) {
          _rates.clear();
          _rates.addAll(remote);
          await _saveLocalCache();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _rates.map((r) => r.toMap()).toList();
      await prefs.setString('cached_overtime_rates', jsonEncode(list));
    } catch (_) {}
  }

  /// Sauvegarde ou met à jour un taux d'heures supplémentaires
  Future<OvertimeRate> saveRate(OvertimeRate rate) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final item = rate.copyWith(
      enterpriseId: (rate.enterpriseId != null && rate.enterpriseId!.isNotEmpty) ? rate.enterpriseId : currentEntId,
      updatedAt: DateTime.now(),
    );

    final idx = _rates.indexWhere((r) => r.id == item.id);
    if (idx != -1) {
      _rates[idx] = item;
    } else {
      _rates.add(item);
    }

    await _saveLocalCache();

    try {
      await FirestoreRepository.instance.saveDocument('overtime_rates', item.id, item.toMap());
    } catch (_) {}

    return item;
  }

  /// Dialogue modal Odoo "Créer Taux Heures Supplémentaires" (Screenshot 2)
  static Future<OvertimeRate?> showCreateRateDialog(
    BuildContext context, {
    String? initialName,
    double? initialRate,
  }) async {
    final entName = EnterpriseService.instance.currentEnterprise?.name ?? 'My Company';
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final rateCtrl = TextEditingController(text: initialRate != null ? initialRate.toStringAsFixed(2).replaceAll('.', ',') : '0,00');

    return showDialog<OvertimeRate>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: "Créer Taux Heures Supplémentaires" + [X] (Screenshot 2)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Créer Taux Heures Supplémentaires',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Form Fields (Screenshot 2: Nom, Société, Taux)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Nom & Société
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 70,
                                      child: Text(
                                        'Nom',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: nameCtrl,
                                        autofocus: true,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                        decoration: const InputDecoration(
                                          hintText: 'ex: X2, x 1.5',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                          border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 70,
                                      child: Text(
                                        'Société',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                                        ),
                                        child: Text(
                                          entName,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right side: Taux
                          Expanded(
                            flex: 5,
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 60,
                                  child: Text(
                                    'Taux',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: rateCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    decoration: const InputDecoration(
                                      hintText: '0,00',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom Actions: [Enregistrer & Fermer] (purple) & [Ignorer] (Screenshot 2)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _odooPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez saisir un nom pour le taux')),
                            );
                            return;
                          }

                          final parsedRate = double.tryParse(rateCtrl.text.replaceAll(',', '.').trim()) ?? 1.0;
                          final newRate = OvertimeRate(
                            id: const Uuid().v4(),
                            name: name,
                            rate: parsedRate,
                            company: entName,
                          );

                          await OvertimeRateService.instance.saveRate(newRate);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop(newRate);
                          }
                        },
                        child: const Text('Enregistrer & Fermer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Ignorer', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Vue Détaillée d'un Taux d'Heures Supplémentaires accessible via le "Lien interne" (Screenshot 5)
  static Future<void> showRateDetailsDialog(
    BuildContext context,
    OvertimeRate rate, {
    String? returnBreadcrumbTitle,
    VoidCallback? onUpdated,
  }) async {
    final nameCtrl = TextEditingController(text: rate.name);
    final rateCtrl = TextEditingController(text: rate.formattedRate);
    final companyName = rate.company.isNotEmpty ? rate.company : (EnterpriseService.instance.currentEnterprise?.name ?? 'My Company');

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFFF8FAFC),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar (Screenshot 5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // [Nouveau] button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _odooPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await OvertimeRateService.showCreateRateDialog(context);
                              if (onUpdated != null) onUpdated();
                            },
                            child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 16),
                          // Breadcrumbs: Présences / 09:58 : (08:01-19:00) / x 1.5 ⚙ (Screenshot 5)
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Présences',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ),
                          const Text(' / ', style: TextStyle(color: Colors.grey)),
                          if (returnBreadcrumbTitle != null && returnBreadcrumbTitle.isNotEmpty) ...[
                            Tooltip(
                              message: 'Back to "$returnBreadcrumbTitle"',
                              child: InkWell(
                                onTap: () => Navigator.of(ctx).pop(),
                                child: Text(
                                  returnBreadcrumbTitle,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                            const Text(' / ', style: TextStyle(color: Colors.grey)),
                          ],
                          Text(
                            rate.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('1 / 1', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Main Content Card (Screenshot 5)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Nom, Société (Screenshot 5)
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 80,
                                        child: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: nameCtrl,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 80,
                                        child: Text('Société', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                          decoration: const BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                                          ),
                                          child: Text(
                                            companyName,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 40),
                            // Right Column: Taux (Screenshot 5)
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 60,
                                    child: Text('Taux', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: rateCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _odooPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.save_outlined, size: 16),
                              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () async {
                                final updated = rate.copyWith(
                                  name: nameCtrl.text.trim(),
                                  rate: double.tryParse(rateCtrl.text.replaceAll(',', '.').trim()) ?? rate.rate,
                                );
                                await OvertimeRateService.instance.saveRate(updated);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                if (onUpdated != null) onUpdated();
                              },
                            ),
                          ],
                        ),
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
  }
}
