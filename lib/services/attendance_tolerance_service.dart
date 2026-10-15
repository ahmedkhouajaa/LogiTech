import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'public_holiday_service.dart';

/// Service de gestion des Intervalles de Tolérance d'entrée et de sortie (Odoo Attendance)
/// Configure les plages de tolérance (ex: 10 min), les horaires standards (08:00 - 17:00),
/// et le calcul automatique des pauses (ex: 60 min).
class AttendanceToleranceService {
  static final AttendanceToleranceService instance = AttendanceToleranceService._();
  AttendanceToleranceService._();

  int entryToleranceMinutes = 10;
  int exitToleranceMinutes = 10;
  int standardStartHour = 8;
  int standardStartMinute = 0;
  int standardEndHour = 17;
  int standardEndMinute = 0;
  int breakDurationMinutes = 60; // Pause déjeuner de 1h
  bool autoApplyTolerance = true;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      entryToleranceMinutes = prefs.getInt('att_entry_tolerance_min') ?? 10;
      exitToleranceMinutes = prefs.getInt('att_exit_tolerance_min') ?? 10;
      standardStartHour = prefs.getInt('att_standard_start_h') ?? 8;
      standardStartMinute = prefs.getInt('att_standard_start_m') ?? 0;
      standardEndHour = prefs.getInt('att_standard_end_h') ?? 17;
      standardEndMinute = prefs.getInt('att_standard_end_m') ?? 0;
      breakDurationMinutes = prefs.getInt('att_break_duration_min') ?? 60;
      autoApplyTolerance = prefs.getBool('att_auto_apply_tolerance') ?? true;
    } catch (_) {}
  }

  Future<void> saveSettings({
    required int entryTolerance,
    required int exitTolerance,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int breakDuration,
    required bool autoApply,
  }) async {
    entryToleranceMinutes = entryTolerance;
    exitToleranceMinutes = exitTolerance;
    standardStartHour = startHour;
    standardStartMinute = startMinute;
    standardEndHour = endHour;
    standardEndMinute = endMinute;
    breakDurationMinutes = breakDuration;
    autoApplyTolerance = autoApply;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('att_entry_tolerance_min', entryToleranceMinutes);
      await prefs.setInt('att_exit_tolerance_min', exitToleranceMinutes);
      await prefs.setInt('att_standard_start_h', standardStartHour);
      await prefs.setInt('att_standard_start_m', standardStartMinute);
      await prefs.setInt('att_standard_end_h', standardEndHour);
      await prefs.setInt('att_standard_end_m', standardEndMinute);
      await prefs.setInt('att_break_duration_min', breakDurationMinutes);
      await prefs.setBool('att_auto_apply_tolerance', autoApplyTolerance);
    } catch (_) {}
  }

  /// Calcule l'heure de Début Théorique en fonction de l'Arrivée et de l'intervalle de tolérance
  /// Odoo Logique:
  /// - Horaire standard de début = 08:00
  /// - Tolérance d'entrée = 10 minutes (plage tolérée : 08:00 -> 08:10)
  /// - Si l'employé arrive entre 08:00:00 et 08:10:00 (ou avant 08:00:00):
  ///     Début théorique = 08:00:00 (Capture 1)
  /// - Si l'employé arrive à 08:12:00 (au-delà de la tolérance de 10 min):
  ///     Début théorique = 08:10:00 (la borne de tolérance, Capture 3)
  DateTime computeTheoreticalStart(DateTime checkIn) {
    if (!autoApplyTolerance) {
      return DateTime(checkIn.year, checkIn.month, checkIn.day, standardStartHour, standardStartMinute, 0);
    }

    final stdStart = DateTime(checkIn.year, checkIn.month, checkIn.day, standardStartHour, standardStartMinute, 0);
    final tolLimit = stdStart.add(Duration(minutes: entryToleranceMinutes));

    if (checkIn.isAfter(tolLimit)) {
      // Arrivée au-delà de la tolérance -> Début théorique calé sur la tolérance (08:10:00)
      return tolLimit;
    } else {
      // Arrivée à l'heure ou dans l'intervalle de tolérance -> Début théorique à 08:00:00
      return stdStart;
    }
  }

  /// Calcule l'heure de Fin Théorique en fonction du Départ et de la tolérance de sortie
  DateTime computeTheoreticalEnd(DateTime? checkOut, {DateTime? fallbackDate}) {
    final base = checkOut ?? fallbackDate ?? DateTime.now();
    final stdEnd = DateTime(base.year, base.month, base.day, standardEndHour, standardEndMinute, 0);

    if (checkOut == null || !autoApplyTolerance) {
      return stdEnd;
    }

    final tolLimit = stdEnd.subtract(Duration(minutes: exitToleranceMinutes));
    if (checkOut.isBefore(tolLimit)) {
      // Départ anticipé au-delà de la tolérance de sortie -> Fin théorique ajustée
      return tolLimit;
    } else {
      return stdEnd;
    }
  }

  /// Calcule les Heures Travaillées effectives déduction faite de la pause déjeuner
  /// Exemple Capture 1: 08:00 à 17:00 (9h span - 1h pause = 8h00 travaillées = 08:00)
  /// Exemple Capture 3: 08:12 à 17:00 (8h48 span - 1h pause = 7h48 travaillées = 07:48)
  double computeWorkedHours(DateTime checkIn, DateTime? checkOut) {
    if (checkOut == null) return 0.0;
    final diffSec = checkOut.difference(checkIn).inSeconds;
    if (diffSec <= 0) return 0.0;

    final totalMin = diffSec / 60.0;
    // Si la journée dépasse 6 heures (360 min), déduire la pause déjeuner (60 min)
    double netMin = totalMin;
    if (totalMin >= 360 && breakDurationMinutes > 0) {
      netMin = totalMin - breakDurationMinutes;
    }
    if (netMin < 0) netMin = 0;
    return netMin / 60.0;
  }

  /// Calcule les Heures Théoriques dues déduction faite de la pause déjeuner
  /// Sur un jour férié (Screenshots 3 & 4), les heures théoriques sont fixées à 00:00.
  double computeTheoreticalHours(DateTime theoreticalStart, DateTime? theoreticalEnd, {DateTime? checkDate}) {
    final date = checkDate ?? theoreticalStart;
    if (PublicHolidayService.instance.isHoliday(date)) {
      return 0.0;
    }
    if (theoreticalEnd == null) return 8.0;
    final diffSec = theoreticalEnd.difference(theoreticalStart).inSeconds;
    if (diffSec <= 0) return 0.0;

    final totalMin = diffSec / 60.0;
    double netMin = totalMin;
    if (totalMin >= 360 && breakDurationMinutes > 0) {
      netMin = totalMin - breakDurationMinutes;
    }
    if (netMin < 0) netMin = 0;
    return netMin / 60.0;
  }

  /// Dialogue de configuration des Intervalles de Tolérance
  static void showToleranceSettingsDialog(BuildContext context, {VoidCallback? onSaved}) {
    final s = AttendanceToleranceService.instance;
    int entryTol = s.entryToleranceMinutes;
    int exitTol = s.exitToleranceMinutes;
    int startH = s.standardStartHour;
    int startM = s.standardStartMinute;
    int endH = s.standardEndHour;
    int endM = s.standardEndMinute;
    int breakM = s.breakDurationMinutes;
    bool autoApply = s.autoApplyTolerance;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF1A56DB), size: 22),
              SizedBox(width: 8),
              Text(
                'Tolérances de pointage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paramétrez les marges de tolérance pour le calcul automatique des heures théoriques et du retard (Odoo ERP).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                // Auto apply toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFF1A56DB),
                  title: const Text('Appliquer les tolérances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Ajuste le début/fin théorique selon la marge', style: TextStyle(fontSize: 11)),
                  value: autoApply,
                  onChanged: (val) => setDlgState(() => autoApply = val),
                ),
                const Divider(),

                // Tolérance d'entrée (minutes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tolérance d\'entrée :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: entryTol,
                          isDense: true,
                          items: [0, 5, 10, 15, 20, 30].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                          onChanged: (val) => setDlgState(() => entryTol = val ?? entryTol),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tolérance de sortie (minutes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tolérance de sortie :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: exitTol,
                          isDense: true,
                          items: [0, 5, 10, 15, 20, 30].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                          onChanged: (val) => setDlgState(() => exitTol = val ?? exitTol),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pause déjeuner standard (minutes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pause déjeuner (déduite) :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: breakM,
                          isDense: true,
                          items: [0, 30, 45, 60, 90].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                          onChanged: (val) => setDlgState(() => breakM = val ?? breakM),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Horaires standards
                const Text('Horaires théoriques standards :', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(hour: startH, minute: startM),
                          );
                          if (picked != null) {
                            setDlgState(() {
                              startH = picked.hour;
                              startM = picked.minute;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Début: ${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12.5)),
                              const Icon(Icons.schedule, size: 16, color: Color(0xFF1A56DB)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(hour: endH, minute: endM),
                          );
                          if (picked != null) {
                            setDlgState(() {
                              endH = picked.hour;
                              endM = picked.minute;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fin: ${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12.5)),
                              const Icon(Icons.schedule, size: 16, color: Color(0xFF1A56DB)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await s.saveSettings(
                  entryTolerance: entryTol,
                  exitTolerance: exitTol,
                  startHour: startH,
                  startMinute: startM,
                  endHour: endH,
                  endMinute: endM,
                  breakDuration: breakM,
                  autoApply: autoApply,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (onSaved != null) onSaved();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
