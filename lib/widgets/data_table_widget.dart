import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// A generic reusable data table with search, sorting, and row actions.
class DataTableWidget<T> extends StatefulWidget {
  final List<String> columns;
  final List<T> rows;
  final List<DataCell> Function(T row) cellBuilder;
  final void Function(T row)? onEdit;
  final void Function(T row)? onDelete;
  final void Function(T row)? onView;
  final void Function(T row)? onPrint;
  final String emptyMessage;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellBuilder,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onPrint,
    this.emptyMessage = 'Aucun enregistrement',
  });

  @override
  State<DataTableWidget<T>> createState() => _DataTableWidgetState<T>();
}

class _DataTableWidgetState<T> extends State<DataTableWidget<T>> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  int _rowsPerPage = 15;
  int _page = 0;

  int get _totalPages => (widget.rows.length / _rowsPerPage).ceil();
  List<T> get _pageRows {
    final start = _page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, widget.rows.length);
    if (start >= widget.rows.length) return [];
    return widget.rows.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(widget.emptyMessage, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final hasActions = widget.onEdit != null || widget.onDelete != null || widget.onView != null || widget.onPrint != null;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowColor: WidgetStateProperty.resolveWith((_) => AppColors.surfaceAlt),
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
            dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            dividerThickness: 0.5,
            columnSpacing: 20,
            horizontalMargin: 20,
            columns: [
              ...widget.columns.asMap().entries.map((e) => DataColumn(
                label: Text(e.value),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              )),
              if (hasActions) const DataColumn(label: Text('Actions')),
            ],
            rows: _pageRows.map((row) {
              final cells = widget.cellBuilder(row);
              return DataRow(
                cells: [
                  ...cells,
                  if (hasActions)
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onView != null)
                          _ActionButton(icon: Icons.visibility_rounded, color: AppColors.info, tooltip: 'Voir', onTap: () => widget.onView!(row)),
                        if (widget.onEdit != null)
                          _ActionButton(icon: Icons.edit_rounded, color: AppColors.primary, tooltip: 'Modifier', onTap: () => widget.onEdit!(row)),
                        if (widget.onPrint != null)
                          _ActionButton(icon: Icons.print_rounded, color: AppColors.success, tooltip: 'Imprimer', onTap: () => widget.onPrint!(row)),
                        if (widget.onDelete != null)
                          _ActionButton(icon: Icons.delete_rounded, color: AppColors.error, tooltip: 'Supprimer', onTap: () => _confirmDelete(context, row)),
                      ],
                    )),
                ],
              );
            }).toList(),
          ),
        ),
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${widget.rows.length} enregistrements', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text('Page ${_page + 1} / $_totalPages', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _page < _totalPages - 1 ? () => setState(() => _page++) : null,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, T row) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet enregistrement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); widget.onDelete!(row); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
