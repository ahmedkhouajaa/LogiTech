import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sélecteur de Date & Heure inspiré directement d'Odoo ERP (Screenshot 3)
/// Inclut le calendrier avec numéros de semaine (#), jours lun-dim,
/// et saisie précise HH : mm : ss au bas avec boutons Fermer / Appliquer.
class OdooDateTimePickerDialog extends StatefulWidget {
  final DateTime initialDateTime;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const OdooDateTimePickerDialog({
    super.key,
    required this.initialDateTime,
    this.firstDate,
    this.lastDate,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDateTime,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OdooDateTimePickerDialog(
        initialDateTime: initialDateTime ?? DateTime.now(),
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }

  @override
  State<OdooDateTimePickerDialog> createState() => _OdooDateTimePickerDialogState();
}

class _OdooDateTimePickerDialogState extends State<OdooDateTimePickerDialog> {
  late DateTime _selectedDate;
  late int _viewMonth;
  late int _viewYear;

  late TextEditingController _hourCtrl;
  late TextEditingController _minCtrl;
  late TextEditingController _secCtrl;

  static const Color _odooPurple = Color(0xFF1A56DB);
  static const List<String> _monthsFr = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDateTime;
    _viewMonth = widget.initialDateTime.month;
    _viewYear = widget.initialDateTime.year;

    _hourCtrl = TextEditingController(text: widget.initialDateTime.hour.toString().padLeft(2, '0'));
    _minCtrl = TextEditingController(text: widget.initialDateTime.minute.toString().padLeft(2, '0'));
    _secCtrl = TextEditingController(text: widget.initialDateTime.second.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() {
    setState(() {
      if (_viewMonth == 1) {
        _viewMonth = 12;
        _viewYear--;
      } else {
        _viewMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == 12) {
        _viewMonth = 1;
        _viewYear++;
      } else {
        _viewMonth++;
      }
    });
  }

  int _getWeekNumber(DateTime date) {
    // ISO 8601 week number calculation
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) return 52;
    if (woy > 52) return 1;
    return woy;
  }

  void _applySelection() {
    final h = (int.tryParse(_hourCtrl.text) ?? _selectedDate.hour).clamp(0, 23);
    final m = (int.tryParse(_minCtrl.text) ?? _selectedDate.minute).clamp(0, 59);
    final s = (int.tryParse(_secCtrl.text) ?? _selectedDate.second).clamp(0, 59);

    final result = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, h, m, s);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.white,
      elevation: 10,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: < novembre 2024 >
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22, color: Color(0xFF64748B)),
                    onPressed: _prevMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    '${_monthsFr[_viewMonth - 1]} $_viewYear',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22, color: Color(0xFF64748B)),
                    onPressed: _nextMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Calendar Grid with Week Numbers (#)
              _buildCalendarTable(),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Bottom Bar: [Fermer] | [17] : [00] : [00] | [✔ Appliquer]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),

                  // Time inputs: HH : mm : ss
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTimeBox(_hourCtrl, 23),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Text(':', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                      ),
                      _buildTimeBox(_minCtrl, 59),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Text(':', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                      ),
                      _buildTimeBox(_secCtrl, 59),
                    ],
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _odooPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: _applySelection,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 14),
                        SizedBox(width: 4),
                        Text('Appliquer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBox(TextEditingController ctrl, int maxVal) {
    return Container(
      width: 32,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) {
          final n = int.tryParse(val);
          if (n != null && n > maxVal) {
            ctrl.text = maxVal.toString().padLeft(2, '0');
          }
        },
      ),
    );
  }

  Widget _buildCalendarTable() {
    final firstDayOfMonth = DateTime(_viewYear, _viewMonth, 1);
    final daysInMonth = DateTime(_viewYear, _viewMonth + 1, 0).day;

    // ISO week day: 1 = Monday, 7 = Sunday
    final startWeekday = firstDayOfMonth.weekday; // 1 to 7

    // Previous month filler
    final prevMonthLastDay = DateTime(_viewYear, _viewMonth, 0).day;
    final prevMonthDaysCount = startWeekday - 1;

    final List<List<DateTime>> weeks = [];
    List<DateTime> currentWeek = [];

    // Fill start of first week with prev month days
    for (int i = prevMonthDaysCount - 1; i >= 0; i--) {
      currentWeek.add(DateTime(_viewYear, _viewMonth - 1, prevMonthLastDay - i));
    }

    // Fill current month
    for (int d = 1; d <= daysInMonth; d++) {
      currentWeek.add(DateTime(_viewYear, _viewMonth, d));
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }

    // Fill end of last week with next month days
    if (currentWeek.isNotEmpty) {
      int nextD = 1;
      while (currentWeek.length < 7) {
        currentWeek.add(DateTime(_viewYear, _viewMonth + 1, nextD++));
      }
      weeks.add(currentWeek);
    }

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Table Header: # lun. mar. mer. jeu. ven. sam. dim.
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          children: [
            _buildHeaderCell('#'),
            _buildHeaderCell('lun.'),
            _buildHeaderCell('mar.'),
            _buildHeaderCell('mer.'),
            _buildHeaderCell('jeu.'),
            _buildHeaderCell('ven.'),
            _buildHeaderCell('sam.'),
            _buildHeaderCell('dim.'),
          ],
        ),
        // Rows
        for (final week in weeks)
          TableRow(
            children: [
              // Week number
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  '${_getWeekNumber(week.first)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
              ),
              // 7 Days
              for (final day in week)
                _buildDayCell(day),
            ],
          ),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final isCurrentMonth = day.month == _viewMonth;
    final isSelected = day.year == _selectedDate.year &&
        day.month == _selectedDate.month &&
        day.day == _selectedDate.day;

    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = DateTime(day.year, day.month, day.day);
          if (day.month != _viewMonth) {
            _viewMonth = day.month;
            _viewYear = day.year;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: isSelected
            ? const BoxDecoration(
                color: Color(0xFFD6C7D2), // Odoo light purple circle highlight (as in Screenshot 3)
                shape: BoxShape.circle,
              )
            : isToday
                ? BoxDecoration(
                    border: Border.all(color: _odooPurple, width: 1.2),
                    shape: BoxShape.circle,
                  )
                : null,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? _odooPurple
                : (isCurrentMonth ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }
}
