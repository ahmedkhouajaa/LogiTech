import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/public_holiday.dart';
import 'enterprise_service.dart';
import 'firestore_repository.dart';

/// Service de gestion des Jours Fériés Odoo ERP (Screenshots 1 à 5)
class PublicHolidayService extends ChangeNotifier {
  static final PublicHolidayService instance = PublicHolidayService._();
  PublicHolidayService._();

  final List<PublicHoliday> _holidays = [];
  bool _initialized = false;

  List<PublicHoliday> get holidays => List.unmodifiable(_holidays.where((h) => !h.isDeleted));

  /// Initialise la liste des jours fériés depuis le cache local puis Firestore
  Future<void> init() async {
    if (_initialized && _holidays.isNotEmpty) return;

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      final entName = EnterpriseService.instance.currentEnterprise?.name ?? 'My Company (San Francisco)';

      // 1. Charger depuis le cache SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_public_holidays');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List list = jsonDecode(cachedJson);
          _holidays.clear();
          for (final item in list) {
            _holidays.add(PublicHoliday.fromMap(Map<String, dynamic>.from(item as Map)));
          }
        } catch (_) {}
      }

      // 2. Si vide, pré-remplir avec les jours fériés conformes aux captures (Screenshots 1, 2, 3, 4, 5)
      if (_holidays.isEmpty) {
        _holidays.addAll([
          PublicHoliday(
            id: 'holiday_public_time_off_2024',
            name: 'Public Time Off',
            dateFrom: DateTime(2024, 2, 13, 6, 0, 0),
            dateTo: DateTime(2024, 2, 13, 18, 0, 0),
            workingHoursSchedule: 'Standard 40 hours/week',
            company: entName,
            enterpriseId: currentEntId,
          ),
          PublicHoliday(
            id: 'holiday_revolution_2024',
            name: 'revolution',
            dateFrom: DateTime(2024, 12, 17, 8, 0, 0),
            dateTo: DateTime(2024, 12, 17, 23, 59, 59),
            workingHoursSchedule: 'Standard 40 hours/week',
            company: entName,
            enterpriseId: currentEntId,
          ),
          PublicHoliday(
            id: 'holiday_jour_de_l_an_2025',
            name: 'Jour de l\'An',
            dateFrom: DateTime(2025, 1, 1, 0, 0, 0),
            dateTo: DateTime(2025, 1, 1, 23, 59, 59),
            workingHoursSchedule: 'Standard 40 hours/week',
            company: entName,
            enterpriseId: currentEntId,
          ),
          PublicHoliday(
            id: 'holiday_fete_du_travail_2025',
            name: 'Fête du Travail',
            dateFrom: DateTime(2025, 5, 1, 0, 0, 0),
            dateTo: DateTime(2025, 5, 1, 23, 59, 59),
            workingHoursSchedule: 'Standard 40 hours/week',
            company: entName,
            enterpriseId: currentEntId,
          ),
        ]);
        await _saveLocalCache();
      }

      // 3. Charger depuis Firestore en arrière-plan
      _loadFromFirestore();
      _initialized = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadFromFirestore() async {
    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('public_holidays');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        final List<PublicHoliday> remote = [];
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['id'] = doc.id;
          final isDel = data['is_deleted'] == 1 || data['is_deleted'] == true;
          if (!isDel) {
            remote.add(PublicHoliday.fromMap(data));
          }
        }
        if (remote.isNotEmpty) {
          _holidays.clear();
          _holidays.addAll(remote);
          await _saveLocalCache();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _holidays.map((h) => h.toMap()).toList();
      await prefs.setString('cached_public_holidays', jsonEncode(list));
    } catch (_) {}
  }

  /// Récupère le jour férié correspondant à une date précise
  PublicHoliday? getHolidayForDate(DateTime date) {
    for (final h in holidays) {
      if (h.isDateMatching(date)) {
        return h;
      }
    }
    return null;
  }

  /// Indique si la date donnée est un jour férié
  bool isHoliday(DateTime date) {
    return getHolidayForDate(date) != null;
  }

  /// Retourne les jours fériés pour une année donnée (filtre "Période: 2024", "Période: 2025")
  List<PublicHoliday> getHolidaysForYear(int year) {
    return holidays.where((h) => h.year == year).toList();
  }

  /// Retourne les jours fériés inclus dans une plage de dates
  List<PublicHoliday> getHolidaysForPeriod(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return holidays.where((h) {
      final hStart = DateTime(h.dateFrom.year, h.dateFrom.month, h.dateFrom.day);
      final hEnd = DateTime(h.dateTo.year, h.dateTo.month, h.dateTo.day, 23, 59, 59);
      return !hEnd.isBefore(s) && !hStart.isAfter(e);
    }).toList();
  }

  /// Sauvegarde ou met à jour un jour férié
  Future<PublicHoliday> saveHoliday(PublicHoliday holiday) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final item = holiday.copyWith(
      enterpriseId: (holiday.enterpriseId != null && holiday.enterpriseId!.isNotEmpty)
          ? holiday.enterpriseId
          : currentEntId,
      updatedAt: DateTime.now(),
    );

    final idx = _holidays.indexWhere((h) => h.id == item.id);
    if (idx != -1) {
      _holidays[idx] = item;
    } else {
      _holidays.add(item);
    }

    await _saveLocalCache();
    notifyListeners();

    try {
      await FirestoreRepository.instance.saveDocument('public_holidays', item.id, item.toMap());
    } catch (_) {}

    return item;
  }

  /// Supprime un jour férié (soft delete)
  Future<void> deleteHoliday(String id) async {
    final idx = _holidays.indexWhere((h) => h.id == id);
    if (idx != -1) {
      final deleted = _holidays[idx].copyWith(isDeleted: true, updatedAt: DateTime.now());
      _holidays[idx] = deleted;
      await _saveLocalCache();
      notifyListeners();

      try {
        await FirestoreRepository.instance.saveDocument('public_holidays', id, deleted.toMap());
      } catch (_) {}
    }
  }
}
