import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialRange;
  const CustomDateRangePicker({super.key, this.initialRange});

  static Future<DateTimeRange?> show(BuildContext context, {DateTimeRange? initialRange}) {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) => CustomDateRangePicker(initialRange: initialRange),
    );
  }

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
  }

  void _selectQuickRange(int days) {
    setState(() {
      _end = DateTime.now();
      _start = _end!.subtract(Duration(days: days));
    });
  }

  void _selectThisMonth() {
    final now = DateTime.now();
    setState(() {
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month + 1, 0);
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart 
        ? (_start ?? DateTime.now()) 
        : (_end ?? _start ?? DateTime.now());
        
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_end != null && _end!.isBefore(_start!)) {
            _end = _start;
          }
        } else {
          _end = picked;
          if (_start != null && _start!.isAfter(_end!)) {
            _start = _end;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 4,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filtrer par période', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Quick selects
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickSelectChip(label: "Aujourd'hui", onTap: () => _selectQuickRange(0)),
                _QuickSelectChip(label: "7 derniers jours", onTap: () => _selectQuickRange(7)),
                _QuickSelectChip(label: "30 derniers jours", onTap: () => _selectQuickRange(30)),
                _QuickSelectChip(label: "Ce mois-ci", onTap: _selectThisMonth),
              ],
            ),
            const SizedBox(height: 24),
            
            // Custom Range
            const Text('Ou plage personnalisée', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateSelector(
                    label: 'Date début',
                    date: _start,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textTertiary),
                ),
                Expanded(
                  child: _DateSelector(
                    label: 'Date fin',
                    date: _end,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _start = null;
                        _end = null;
                      });
                      Navigator.pop(context, null);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Toutes les dates', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_start != null && _end != null) {
                        Navigator.pop(context, DateTimeRange(start: _start!, end: _end!));
                      } else if (_start != null) {
                        Navigator.pop(context, DateTimeRange(start: _start!, end: _start!));
                      } else {
                        Navigator.pop(context, null);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Appliquer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _QuickSelectChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  
  const _QuickSelectChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  
  const _DateSelector({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null ? formatDate(date!) : 'Sélectionner',
                    style: TextStyle(
                      fontSize: 13,
                      color: date != null ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
