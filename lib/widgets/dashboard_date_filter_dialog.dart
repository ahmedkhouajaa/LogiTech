import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Predefined filter period keys matching the user's interface
enum DashboardDatePreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  last7Days,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  maximum,
}

class DashboardDateFilterDialog extends StatefulWidget {
  final DateTimeRange? initialRange;

  const DashboardDateFilterDialog({super.key, this.initialRange});

  static Future<DateTimeRange?> show(BuildContext context, {DateTimeRange? initialRange}) {
    return showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => DashboardDateFilterDialog(initialRange: initialRange),
    );
  }

  @override
  State<DashboardDateFilterDialog> createState() => _DashboardDateFilterDialogState();
}

class _DashboardDateFilterDialogState extends State<DashboardDateFilterDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  DashboardDatePreset? _selectedPreset;
  late DateTime _currentMonth;

  static const List<String> _monthsFr = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  static const List<String> _weekdaysFr = ['lu', 'ma', 'me', 'je', 've', 'sa', 'di'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.initialRange != null) {
      _startDate = DateTime(widget.initialRange!.start.year, widget.initialRange!.start.month, widget.initialRange!.start.day);
      _endDate = DateTime(widget.initialRange!.end.year, widget.initialRange!.end.month, widget.initialRange!.end.day);
      _currentMonth = DateTime(_startDate!.year, _startDate!.month);
      _selectedPreset = _detectPreset(_startDate!, _endDate!);
    } else {
      // Default to Ce mois
      _applyPreset(DashboardDatePreset.thisMonth, shouldSetState: false);
      _currentMonth = DateTime(now.year, now.month);
    }
  }

  DashboardDatePreset? _detectPreset(DateTime s, DateTime e) {
    for (final p in DashboardDatePreset.values) {
      if (p == DashboardDatePreset.maximum) continue;
      final range = _getPresetRange(p);
      if (range != null) {
        final rs = DateTime(range.start.year, range.start.month, range.start.day);
        final re = DateTime(range.end.year, range.end.month, range.end.day);
        if (rs.isAtSameMomentAs(s) && re.isAtSameMomentAs(e)) {
          return p;
        }
      }
    }
    return null;
  }

  DateTimeRange? _getPresetRange(DashboardDatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case DashboardDatePreset.today:
        return DateTimeRange(start: today, end: today);
      case DashboardDatePreset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: y, end: y);
      case DashboardDatePreset.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return DateTimeRange(start: startOfWeek, end: endOfWeek);
      case DashboardDatePreset.lastWeek:
        final startOfLastWeek = today.subtract(Duration(days: today.weekday + 6));
        final endOfLastWeek = startOfLastWeek.add(const Duration(days: 6));
        return DateTimeRange(start: startOfLastWeek, end: endOfLastWeek);
      case DashboardDatePreset.last7Days:
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
      case DashboardDatePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case DashboardDatePreset.lastMonth:
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final start = DateTime(prevYear, prevMonth, 1);
        final end = DateTime(prevYear, prevMonth + 1, 0);
        return DateTimeRange(start: start, end: end);
      case DashboardDatePreset.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return DateTimeRange(start: start, end: end);
      case DashboardDatePreset.lastYear:
        final start = DateTime(now.year - 1, 1, 1);
        final end = DateTime(now.year - 1, 12, 31);
        return DateTimeRange(start: start, end: end);
      case DashboardDatePreset.maximum:
        return null;
    }
  }

  void _applyPreset(DashboardDatePreset preset, {bool shouldSetState = true}) {
    if (preset == DashboardDatePreset.maximum) {
      if (shouldSetState) {
        setState(() {
          _selectedPreset = preset;
          _startDate = null;
          _endDate = null;
        });
      } else {
        _selectedPreset = preset;
        _startDate = null;
        _endDate = null;
      }
      return;
    }

    final range = _getPresetRange(preset);
    if (range != null) {
      void update() {
        _selectedPreset = preset;
        _startDate = range.start;
        _endDate = range.end;
        _currentMonth = DateTime(range.start.year, range.start.month);
      }

      if (shouldSetState) {
        setState(update);
      } else {
        update();
      }
    }
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      _selectedPreset = null; // custom selection

      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        if (day.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = day;
        } else {
          _endDate = day;
        }
      }
    });
  }

  String _presetLabel(DashboardDatePreset preset) {
    switch (preset) {
      case DashboardDatePreset.today:
        return "Aujourd'hui";
      case DashboardDatePreset.yesterday:
        return "Hier";
      case DashboardDatePreset.thisWeek:
        return "Cette semaine";
      case DashboardDatePreset.lastWeek:
        return "La semaine dernière";
      case DashboardDatePreset.last7Days:
        return "Les 7 derniers jours";
      case DashboardDatePreset.thisMonth:
        return "Ce mois";
      case DashboardDatePreset.lastMonth:
        return "Le mois dernier";
      case DashboardDatePreset.thisYear:
        return "Cette année";
      case DashboardDatePreset.lastYear:
        return "L'année dernière";
      case DashboardDatePreset.maximum:
        return "Maximum";
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 680;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.surface,
      elevation: 8,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? 420 : 530,
          maxHeight: isMobile ? 620 : 490,
        ),
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Content Area
        Flexible(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Presets list (left column)
              Container(
                width: 170,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border, width: 1)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: ListView(
                  shrinkWrap: true,
                  children: DashboardDatePreset.values.map((preset) {
                    final isSelected = _selectedPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: InkWell(
                        onTap: () => _applyPreset(preset),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _presetLabel(preset),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // 2. Single Calendar area (right)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildMonthCalendar(
                      month: _currentMonth,
                      onMonthChanged: (m) => setState(() => _currentMonth = m),
                      onPrev: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                      onNext: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom action buttons
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Presets Chips Bar (Horizontal scroll)
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: DashboardDatePreset.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final preset = DashboardDatePreset.values[index];
              final isSelected = _selectedPreset == preset;
              return InkWell(
                onTap: () => _applyPreset(preset),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : AppColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _presetLabel(preset),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Single Calendar view for mobile
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _buildMonthCalendar(
              month: _currentMonth,
              onMonthChanged: (m) => setState(() => _currentMonth = m),
              onPrev: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
              onNext: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
            ),
          ),
        ),

        // Bottom action buttons
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildMonthCalendar({
    required DateTime month,
    required ValueChanged<DateTime> onMonthChanged,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    final year = month.year;
    final monthIndex = month.month; // 1-12
    final monthName = _monthsFr[monthIndex - 1];

    final daysInMonth = DateUtils.getDaysInMonth(year, monthIndex);
    final firstDayOfWeek = DateTime(year, monthIndex, 1).weekday; // 1 = Mon ... 7 = Sun
    final leadingEmpty = firstDayOfWeek - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Dropdowns Row (Month dropdown + Year dropdown)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Month Dropdown
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: monthIndex,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  items: List.generate(12, (i) {
                    return DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text(_monthsFr[i]),
                    );
                  }),
                  onChanged: (newM) {
                    if (newM != null) onMonthChanged(DateTime(year, newM));
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Year Dropdown
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: year,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  items: List.generate(15, (i) {
                    final y = 2020 + i;
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text(y.toString()),
                    );
                  }),
                  onChanged: (newY) {
                    if (newY != null) onMonthChanged(DateTime(newY, monthIndex));
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Navigation Row: <   septembre 2026   >
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: onPrev,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chevron_left, size: 16),
              ),
            ),
            Text(
              '${monthName.toLowerCase()} $year',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            InkWell(
              onTap: onNext,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chevron_right, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Weekdays Row (lu ma me je ve sa di)
        Row(
          children: _weekdaysFr.map((w) {
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Days Grid
        _buildDaysGrid(year, monthIndex, leadingEmpty, daysInMonth),
      ],
    );
  }

  Widget _buildDaysGrid(int year, int monthIndex, int leadingEmpty, int daysInMonth) {
    final totalCells = leadingEmpty + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(totalRows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNumber = cellIndex - leadingEmpty + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 32));
            }

            final dayDate = DateTime(year, monthIndex, dayNumber);
            final isStart = _startDate != null && DateUtils.isSameDay(_startDate!, dayDate);
            final isEnd = _endDate != null && DateUtils.isSameDay(_endDate!, dayDate);
            final isInRange = _startDate != null &&
                _endDate != null &&
                dayDate.isAfter(_startDate!) &&
                dayDate.isBefore(_endDate!);

            final isSameStartEnd = isStart && isEnd;

            return Expanded(
              child: InkWell(
                onTap: () => _onDayTapped(dayDate),
                child: SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Range highlight background
                      if (isInRange)
                        Container(
                          color: const Color(0xFFDBEAFE), // light blue strip
                        ),
                      if (isStart && _endDate != null && !isSameStartEnd)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 16,
                              color: const Color(0xFFDBEAFE),
                            ),
                          ),
                        ),
                      if (isEnd && _startDate != null && !isSameStartEnd)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 16,
                              color: const Color(0xFFDBEAFE),
                            ),
                          ),
                        ),

                      // Circle / Rounded Indicator for start / end / normal
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: (isStart || isEnd) ? const Color(0xFF2563EB) : Colors.transparent,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (isStart || isEnd) ? FontWeight.bold : FontWeight.normal,
                              color: (isStart || isEnd)
                                  ? Colors.white
                                  : (isInRange ? const Color(0xFF1D4ED8) : AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Effacer button
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context, null); // Clear / All time
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              'Effacer',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),

          // Appliquer button
          ElevatedButton(
            onPressed: () {
              if (_startDate != null) {
                final end = _endDate ?? _startDate!;
                final range = DateTimeRange(start: _startDate!, end: end);
                Navigator.pop(context, range);
              } else {
                Navigator.pop(context, null);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'Appliquer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
