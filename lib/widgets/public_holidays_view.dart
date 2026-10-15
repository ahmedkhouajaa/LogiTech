import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/public_holiday.dart';
import '../services/enterprise_service.dart';
import '../services/public_holiday_service.dart';
import 'odoo_datetime_picker_dialog.dart';

/// Vue complète des Jours Fériés conforme à Odoo ERP (Screenshots 1 & 2)
/// Permet la consultation, le filtrage par période (2024, 2025...), la recherche,
/// la création inline avec [Nouveau] ➔ [Enregistrer] / [Ignorer], et la modification.
class PublicHolidaysView extends StatefulWidget {
  final bool isDialog;
  const PublicHolidaysView({super.key, this.isDialog = false});

  static Future<void> showAsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
          child: const PublicHolidaysView(isDialog: true),
        ),
      ),
    );
  }

  @override
  State<PublicHolidaysView> createState() => _PublicHolidaysViewState();
}

class _PublicHolidaysViewState extends State<PublicHolidaysView> {
  static const Color _odooPurple = Color(0xFF1A56DB);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _selectedPeriodYear = 2024; // Conforme Screenshot 1: Période: 2024
  final Set<String> _selectedIds = {};

  // Mode création / édition inline (Screenshot 2)
  bool _isCreatingInline = false;
  String? _editingHolidayId;

  final TextEditingController _nameCtrl = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  String _workingHoursSchedule = 'Standard 40 hours/week';

  final List<String> _schedulePresets = [
    'Standard 40 hours/week',
    'Standard 35 hours/week',
    'Standard 38 hours/week',
    'Temps partiel (20h/week)',
    'Personnalisé',
  ];

  @override
  void initState() {
    super.initState();
    PublicHolidayService.instance.addListener(_onServiceChanged);
    _initInlineValues();
  }

  @override
  void dispose() {
    PublicHolidayService.instance.removeListener(_onServiceChanged);
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _initInlineValues() {
    final now = DateTime.now();
    final year = _selectedPeriodYear ?? now.year;
    _startDate = DateTime(year, 12, 20, 8, 0, 0); // Conforme Screenshot 2: 20/12/2024 08:00:00
    _endDate = DateTime(year, 12, 20, 17, 0, 0); // Conforme Screenshot 2: 20/12/2024 17:00:00
    _nameCtrl.text = '';
    _workingHoursSchedule = 'Standard 40 hours/week';
  }

  void _startCreatingInline() {
    setState(() {
      _isCreatingInline = true;
      _editingHolidayId = null;
      _initInlineValues();
    });
  }

  void _startEditing(PublicHoliday holiday) {
    setState(() {
      _isCreatingInline = true;
      _editingHolidayId = holiday.id;
      _nameCtrl.text = holiday.name;
      _startDate = holiday.dateFrom;
      _endDate = holiday.dateTo;
      _workingHoursSchedule = holiday.workingHoursSchedule;
    });
  }

  void _cancelInline() {
    setState(() {
      _isCreatingInline = false;
      _editingHolidayId = null;
    });
  }

  Future<void> _saveInline() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner un nom pour le jour férié')),
      );
      return;
    }

    final entName = EnterpriseService.instance.currentEnterprise?.name ?? 'My Company (San Francisco)';
    final holiday = PublicHoliday(
      id: _editingHolidayId ?? const Uuid().v4(),
      name: name,
      dateFrom: _startDate,
      dateTo: _endDate,
      workingHoursSchedule: _workingHoursSchedule,
      company: entName,
    );

    await PublicHolidayService.instance.saveHoliday(holiday);

    setState(() {
      _isCreatingInline = false;
      _editingHolidayId = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jour férié "$name" enregistré avec succès'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allHolidays = PublicHolidayService.instance.holidays;

    // Filtrage par période et recherche
    final filtered = allHolidays.where((h) {
      if (_selectedPeriodYear != null && h.year != _selectedPeriodYear) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = h.name.toLowerCase().contains(q);
        final matchSchedule = h.workingHoursSchedule.toLowerCase().contains(q);
        if (!matchName && !matchSchedule) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Barre de navigation Odoo supérieure (Screenshots 1 & 2)
        _buildTopHeader(filtered.length),
        const Divider(height: 1),

        // 2. Tableau principal
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableHeader(filtered),
                const Divider(height: 1),

                // Ligne de création inline (Screenshot 2)
                if (_isCreatingInline) ...[
                  _buildInlineEditingRow(),
                  const Divider(height: 1),
                ],

                // Lignes de données
                if (filtered.isEmpty && !_isCreatingInline)
                  _buildEmptyState()
                else
                  for (final holiday in filtered)
                    if (_editingHolidayId != holiday.id)
                      _buildHolidayRow(holiday)
                    else ...[
                      _buildInlineEditingRow(),
                      const Divider(height: 1),
                    ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Header conforme Screenshots 1 & 2
  Widget _buildTopHeader(int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gauche: Boutons [Nouveau] ou [Enregistrer]/[Ignorer] + Titre "Jours fériés ⚙"
          Row(
            children: [
              if (!_isCreatingInline)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _startCreatingInline,
                  child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )
              else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _saveInline,
                  child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _cancelInline,
                  child: const Text('Ignorer', style: TextStyle(fontSize: 13)),
                ),
              ],
              const SizedBox(width: 14),
              const Text(
                'Jours fériés',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
            ],
          ),

          // Centre: Barre de recherche avec tag de filtre "Période: 2024 X" (Screenshot 1)
          Container(
            width: 380,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),

                // Filtre période pill (ex: [T Période: 2024 X])
                if (_selectedPeriodYear != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _odooPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _odooPurple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list, size: 12, color: _odooPurple),
                        const SizedBox(width: 4),
                        Text(
                          'Période: $_selectedPeriodYear',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _odooPurple),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => setState(() => _selectedPeriodYear = null),
                          child: const Icon(Icons.close, size: 12, color: _odooPurple),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: _selectedPeriodYear == null ? 'Rechercher ou filtrer...' : 'Rechercher...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                // Sélecteur de période dropdown
                PopupMenuButton<int?>(
                  tooltip: 'Filtrer par année / période',
                  icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  onSelected: (year) => setState(() => _selectedPeriodYear = year),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('Toutes les périodes', style: TextStyle(fontSize: 13)),
                    ),
                    const PopupMenuItem(
                      value: 2024,
                      child: Text('Période: 2024', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const PopupMenuItem(
                      value: 2025,
                      child: Text('Période: 2025', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const PopupMenuItem(
                      value: 2026,
                      child: Text('Période: 2026', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Droite: 1-2 / 2 < > et fermeture si dialog
          Row(
            children: [
              if (_selectedIds.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Supprimer la sélection (${_selectedIds.length})',
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () async {
                    for (final id in _selectedIds) {
                      await PublicHolidayService.instance.deleteHoliday(id);
                    }
                    setState(() => _selectedIds.clear());
                  },
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '1-$totalCount / $totalCount',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
              ),
              if (widget.isDialog) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Header des colonnes de table (Screenshots 1 & 2)
  Widget _buildTableHeader(List<PublicHoliday> filtered) {
    final allSelected = filtered.isNotEmpty && filtered.every((h) => _selectedIds.contains(h.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: allSelected,
              activeColor: _odooPurple,
              visualDensity: VisualDensity.compact,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.addAll(filtered.map((h) => h.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            flex: 4,
            child: Text(
              'Nom',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'Date de début',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'Date de fin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
            ),
          ),
          const Expanded(
            flex: 4,
            child: Text(
              'Heures de travail',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 60), // Actions space
        ],
      ),
    );
  }

  // Ligne de saisie inline (Screenshot 2)
  Widget _buildInlineEditingRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFAF5FF), // Subtle purple tint when editing
      child: Row(
        children: [
          const SizedBox(
            width: 32,
            child: Icon(Icons.edit_note, size: 20, color: _odooPurple),
          ),
          const SizedBox(width: 8),

          // Champ Nom (Screenshot 2)
          Expanded(
            flex: 4,
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'ex: fete d\'année, Jour de l\'An',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: UnderlineInputBorder(borderSide: BorderSide(color: _odooPurple, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Champ Date de début
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () async {
                final picked = await OdooDateTimePickerDialog.show(context, initialDateTime: _startDate);
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm:ss').format(_startDate),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 14, color: _odooPurple),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Champ Date de fin
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () async {
                final picked = await OdooDateTimePickerDialog.show(context, initialDateTime: _endDate);
                if (picked != null) {
                  setState(() => _endDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm:ss').format(_endDate),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 14, color: _odooPurple),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Heures de travail (Screenshot 2: Standard 40 hours/week)
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              initialValue: _workingHoursSchedule,
              isDense: true,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              items: _schedulePresets.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _workingHoursSchedule = val);
              },
            ),
          ),

          // Boutons inline OK / Annuler
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Enregistrer',
                icon: const Icon(Icons.check, size: 18, color: Colors.green),
                onPressed: _saveInline,
              ),
              IconButton(
                tooltip: 'Annuler',
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                onPressed: _cancelInline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Ligne de données standard (Screenshot 1)
  Widget _buildHolidayRow(PublicHoliday holiday) {
    final isSelected = _selectedIds.contains(holiday.id);

    return InkWell(
      onTap: () => _startEditing(holiday),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                activeColor: _odooPurple,
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(holiday.id);
                    } else {
                      _selectedIds.remove(holiday.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),

            // Nom (ex: "Public Time Off", "revolution")
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B), // Festive amber dot
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      holiday.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Date de début (ex: 13/02/2024 06:00:00)
            Expanded(
              flex: 3,
              child: Text(
                holiday.formattedDateFrom,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
              ),
            ),

            // Date de fin (ex: 13/02/2024 18:00:00)
            Expanded(
              flex: 3,
              child: Text(
                holiday.formattedDateTo,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
              ),
            ),

            // Heures de travail (ex: Standard 40 hours/week)
            Expanded(
              flex: 4,
              child: Text(
                holiday.workingHoursSchedule,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
            ),

            // Actions: Edit & Delete
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined, size: 16, color: _odooPurple),
                  onPressed: () => _startEditing(holiday),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  onPressed: () async {
                    await PublicHolidayService.instance.deleteHoliday(holiday.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'Aucun jour férié trouvé pour cette sélection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cliquez sur [Nouveau] pour ajouter un jour férié à votre calendrier.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _odooPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Créer un jour férié'),
              onPressed: _startCreatingInline,
            ),
          ],
        ),
      ),
    );
  }
}
