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
  final Widget Function(T row)? customActionsBuilder;
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
    this.customActionsBuilder,
    this.emptyMessage = 'Aucun enregistrement',
  });

  @override
  State<DataTableWidget<T>> createState() => _DataTableWidgetState<T>();
}

class _DataTableWidgetState<T> extends State<DataTableWidget<T>> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  int _rowsPerPage = 20;
  int _page = 0;

  int get _totalPages => (widget.rows.length / _rowsPerPage).ceil() == 0 ? 1 : (widget.rows.length / _rowsPerPage).ceil();
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
              Text(widget.emptyMessage, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final hasActions = widget.onEdit != null || widget.onDelete != null || widget.onView != null || widget.onPrint != null || widget.customActionsBuilder != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget table = DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          headingRowHeight: 38,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 46,
          headingRowColor: WidgetStateProperty.resolveWith((_) => AppColors.surfaceAlt),
          headingTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
          dataTextStyle: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          dividerThickness: 0.5,
          columnSpacing: 20,
          horizontalMargin: 16,
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
                  DataCell(
                    widget.customActionsBuilder != null 
                    ? widget.customActionsBuilder!(row)
                    : PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        color: AppColors.surface,
                        onSelected: (val) {
                          switch (val) {
                            case 'view': widget.onView?.call(row); break;
                            case 'edit': widget.onEdit?.call(row); break;
                            case 'print': widget.onPrint?.call(row); break;
                            case 'delete': _confirmDelete(context, row); break;
                          }
                        },
                        itemBuilder: (_) => [
                          if (widget.onView != null)
                            PopupMenuItem(value: 'view', height: 36, child: Row(children: [Icon(Icons.visibility_outlined, size: 16, color: AppColors.info), const SizedBox(width: 8), const Text('Voir', style: TextStyle(fontSize: 13))])),
                          if (widget.onEdit != null)
                            PopupMenuItem(value: 'edit', height: 36, child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: AppColors.primary), const SizedBox(width: 8), const Text('Modifier', style: TextStyle(fontSize: 13))])),
                          if (widget.onPrint != null)
                            PopupMenuItem(value: 'print', height: 36, child: Row(children: [Icon(Icons.print_outlined, size: 16, color: AppColors.success), const SizedBox(width: 8), const Text('Imprimer', style: TextStyle(fontSize: 13))])),
                          if (widget.onDelete != null) ...[
                            if (widget.onView != null || widget.onEdit != null || widget.onPrint != null)
                              const PopupMenuDivider(height: 1),
                            PopupMenuItem(value: 'delete', height: 36, child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.error), const SizedBox(width: 8), Text('Supprimer', style: TextStyle(fontSize: 13, color: AppColors.error))])),
                          ],
                        ],
                      ),
                  ),
              ],
            );
          }).toList(),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (constraints.hasBoundedHeight)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: table,
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: table,
                ),
              ),
            if (widget.rows.isNotEmpty) _buildPagination(),
          ],
        );
      },
    );
  }

  Widget _buildPagination() {
    final startItem = widget.rows.isEmpty ? 0 : (_page * _rowsPerPage) + 1;
    final endItem = ((_page + 1) * _rowsPerPage).clamp(0, widget.rows.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
              color: AppColors.surface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                items: [20, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString(), style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _rowsPerPage = newValue;
                      _page = 0;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text('Page ${_page + 1} sur $_totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            widget.rows.isEmpty ? 'Affichage de 0 à 0 sur 0 résultats' : 'Affichage de $startItem à $endItem sur ${widget.rows.length} résultats',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              InkWell(
                onTap: _page > 0 ? () => setState(() => _page--) : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _page > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.surface,
                  ),
                  child: Icon(Icons.chevron_left, size: 18, color: _page > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _page < _totalPages - 1 ? () => setState(() => _page++) : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _page < _totalPages - 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.surface,
                  ),
                  child: Icon(Icons.chevron_right, size: 18, color: _page < _totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, T row) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer cet enregistrement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); widget.onDelete!(row); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
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
          padding: EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
