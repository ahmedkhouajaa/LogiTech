import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';


import '../blocs/products/products_bloc.dart';
import '../models/stock_withdrawal.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_stock_withdrawal_screen.dart';

enum StockWithdrawalStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Valide', AppColors.primary),
  cancelled('Annule', AppColors.error);

  final String label;
  final Color color;
  const StockWithdrawalStatus(this.label, this.color);
}

class StockWithdrawalsScreen extends StatefulWidget {
  final bool isExitVoucher;
  const StockWithdrawalsScreen({super.key, this.isExitVoucher = false});

  @override
  State<StockWithdrawalsScreen> createState() => _StockWithdrawalsScreenState();
}

class _StockWithdrawalsScreenState extends State<StockWithdrawalsScreen> {
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<StockWithdrawalsBloc>().add(LoadStockWithdrawals());
  }

  void _navigate(BuildContext context, [StockWithdrawal? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStockWithdrawalScreen(existing: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context);
      },
    );
  }

  // ─── Mobile Layout ─────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mobile header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isExitVoucher ? "Bons de sortie" : "Bons de prélèvement",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cards list
            Expanded(
              child: BlocBuilder<StockWithdrawalsBloc, StockWithdrawalsState>(
                builder: (context, state) {
                  if (state is StockWithdrawalsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is StockWithdrawalsError) {
                    return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                  }
                  if (state is StockWithdrawalsLoaded) {
                    final entries = state.withdrawals;

                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(widget.isExitVoucher ? "Aucun Bon de sortie" : "Aucun Bon de prélèvement", style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text("Appuyez sur + pour en créer un", style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 80),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildMobileCard(context, entries[index]);
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
        // Floating Action Button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _navigate(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard(BuildContext context, StockWithdrawal entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _navigate(context, entry),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Reference + Actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        entry.number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(entry.status),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      color: AppColors.surface,
                      onSelected: (val) {
                        if (val == 'edit') _navigate(context, entry);
                        if (val == 'delete') _confirmDelete(entry);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: AppColors.error)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info rows
                Row(
                  children: [
                    _buildInfoItem(Icons.calendar_today_rounded, formatDateTimeLong(entry.date)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(Icons.warehouse_rounded, 'Entrepôt par défaut'),
                    ),
                    _buildInfoItem(Icons.shopping_bag_rounded, '${entry.items.length} article${entry.items.length > 1 ? 's' : ''}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoItem(Icons.person_rounded, 'Admin'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final StockWithdrawalStatus entryStatus;
    switch (status) {
      case 'validated':
        entryStatus = StockWithdrawalStatus.validated;
        break;
      case 'cancelled':
        entryStatus = StockWithdrawalStatus.cancelled;
        break;
      default:
        entryStatus = StockWithdrawalStatus.draft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: entryStatus.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        entryStatus.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: entryStatus.color,
        ),
      ),
    );
  }

  // ─── Desktop Layout ────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.play_arrow, color: Colors.red, size: 28), // The YouTube-like icon from mockup
              const SizedBox(width: 8),
              Text(
                widget.isExitVoucher ? "Bon de sortie" : "Bon de prélèvement",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _navigate(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Créer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Matching the blue 'Créer' button
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border),
            ),
            child: BlocBuilder<StockWithdrawalsBloc, StockWithdrawalsState>(
              builder: (context, state) {
                if (state is StockWithdrawalsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is StockWithdrawalsError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                }
                if (state is StockWithdrawalsLoaded) {
                  final entries = state.withdrawals;

                  if (entries.isEmpty) {
                    return Center(
                      child: Text(widget.isExitVoucher ? "Aucun Bon de sortie trouvé" : "Aucun Bon de prélèvement trouvé", style: const TextStyle(color: AppColors.textSecondary)),
                    );
                  }

                  final totalItems = entries.length;
                  final totalPages = (totalItems / _rowsPerPage).ceil();
                  final startIndex = _currentPage * _rowsPerPage;
                  final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                  final currentPageItems = entries.sublist(startIndex, endIndex);

                  return Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Entrepôt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 1, child: Text('Articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Cree par', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                          ],
                        ),
                      ),
                      
                      // Table body
                      Expanded(
                        child: ListView.builder(
                          itemCount: currentPageItems.length,
                          itemBuilder: (context, index) {
                            return _buildRow(context, currentPageItems[index], index);
                          },
                        ),
                      ),

                      // Pagination
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            const Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButton<int>(
                                value: _rowsPerPage,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                items: [10, 20, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _rowsPerPage = v;
                                      _currentPage = 0;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(width: 24),
                            Text('Affichage de ${startIndex + 1} a $endIndex sur $totalItems resultats', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const Spacer(),
                            Row(
                              children: [
                                _pageButton(
                                  icon: Icons.chevron_left,
                                  enabled: _currentPage > 0,
                                  onTap: () => setState(() => _currentPage--),
                                ),
                                const SizedBox(width: 8),
                                _pageButton(
                                  icon: Icons.chevron_right,
                                  enabled: _currentPage < totalPages - 1,
                                  onTap: () => setState(() => _currentPage++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, StockWithdrawal entry, int index) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(entry.number, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDateTimeLong(entry.date), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          const Expanded(
            flex: 2,
            child: Text('Entrepôt par defaut', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)), // Temporary hardcoded warehouse to match mockup
          ),
          Expanded(
            flex: 1,
            child: Text('${entry.items.length}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          const Expanded(
            flex: 2,
            child: Text('Admin', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'edit') _navigate(context, entry);
                  if (val == 'delete') _confirmDelete(entry);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Modifier')
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Supprimer', style: TextStyle(color: AppColors.error))
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageButton({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.surface,
        ),
        child: Icon(icon, size: 20, color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
      ),
    );
  }

  void _confirmDelete(StockWithdrawal entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text("Voulez-vous vraiment supprimer le ${widget.isExitVoucher ? 'Bon de sortie' : 'Bon de prélèvement'} ${entry.number} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<StockWithdrawalsBloc>().add(DeleteStockWithdrawal(entry.id));
              // Refresh products list so stock quantities are updated immediately
              context.read<ProductsBloc>().add(LoadProducts());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

