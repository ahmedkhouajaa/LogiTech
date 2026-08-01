import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/payment_model.dart';
import '../../services/tej_export_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class MobileTejExportDialog extends StatefulWidget {
  final List<Payment> payments;
  final bool isSales;

  const MobileTejExportDialog({
    super.key,
    required this.payments,
    required this.isSales,
  });

  static Future<void> show(BuildContext context, {required List<Payment> payments, required bool isSales}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileTejExportDialog(payments: payments, isSales: isSales),
    );
  }

  @override
  State<MobileTejExportDialog> createState() => _MobileTejExportDialogState();
}

class _MobileTejExportDialogState extends State<MobileTejExportDialog> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  bool _isExporting = false;

  bool get _isMonthClosed {
    final now = DateTime.now();
    if (_selectedDate.year < now.year) return true;
    if (_selectedDate.year == now.year && _selectedDate.month < now.month) return true;
    return false;
  }

  List<Payment> _getFilteredPayments() {
    return widget.payments.where((p) {
      if (p.method != 'retenue_source') return false;

      if (widget.isSales && p.direction != 'encaissement') return false;
      if (!widget.isSales && p.direction != 'decaissement') return false;

      if (p.paymentDate.month != _selectedDate.month ||
          p.paymentDate.year != _selectedDate.year) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchRef = p.reference?.toLowerCase().contains(query) ?? false;
        final matchNumber = p.paymentNumber.toLowerCase().contains(query);
        final matchContact = p.contactName?.toLowerCase().contains(query) ?? false;
        if (!matchRef && !matchNumber && !matchContact) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final filteredPayments = _getFilteredPayments();
    final isClosed = _isMonthClosed;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.file_download_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exportation TEJ (Retenue à la source)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Closed month info alert banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isClosed
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isClosed ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                          color: isClosed ? AppColors.success : AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isClosed
                                ? 'Mois clôturé. L\'exportation TEJ est disponible.'
                                : 'L\'exportation TEJ est uniquement disponible pour les mois clôturés (terminés).',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isClosed ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Month Picker Section
                  Text(
                    'Mois de déclaration',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Month Popup
                      Expanded(
                        flex: 3,
                        child: PopupMenuButton<int>(
                          tooltip: 'Changer de mois',
                          elevation: 6,
                          offset: const Offset(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(color: AppColors.border),
                          ),
                          color: AppColors.surface,
                          onSelected: (month) {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year, month);
                            });
                          },
                          itemBuilder: (context) {
                            const months = [
                              'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
                              'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
                            ];
                            return List.generate(12, (index) {
                              final monthNum = index + 1;
                              final isSelected = monthNum == _selectedDate.month;
                              return PopupMenuItem<int>(
                                value: monthNum,
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                      size: 16,
                                      color: isSelected ? AppColors.primary : AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      months[index],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat('MMMM', 'fr').format(_selectedDate),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Year Popup
                      Expanded(
                        flex: 2,
                        child: PopupMenuButton<int>(
                          tooltip: 'Changer d\'année',
                          elevation: 6,
                          offset: const Offset(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(color: AppColors.border),
                          ),
                          color: AppColors.surface,
                          onSelected: (year) {
                            setState(() {
                              _selectedDate = DateTime(year, _selectedDate.month);
                            });
                          },
                          itemBuilder: (context) => List.generate(10, (i) => 2022 + i).map((y) {
                            final isSelected = y == _selectedDate.year;
                            return PopupMenuItem<int>(
                              value: y,
                              height: 40,
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    size: 16,
                                    color: isSelected ? AppColors.primary : AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$y',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_selectedDate.year}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Field
                  Text(
                    'Recherche (Facture / Réf / ${widget.isSales ? "Client" : "Fournisseur"})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par ref. ou contact...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header title for invoices
                  Text(
                    'Factures à inclure (${filteredPayments.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  // Invoices List
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: filteredPayments.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'Aucun enregistrement trouvé pour ce mois',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredPayments.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final payment = filteredPayments[index];

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          payment.reference ?? payment.paymentNumber,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        Text(
                                          '${formatCurrency(payment.amount, symbol: '')} DT',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          payment.contactName ?? '—',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          formatDate(payment.paymentDate),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isExporting || !_isMonthClosed || filteredPayments.isEmpty)
                        ? null
                        : () async {
                            setState(() {
                              _isExporting = true;
                            });

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            try {
                              final path = await TejExportService.exportAchats(
                                filteredPayments,
                                _selectedDate.year,
                                _selectedDate.month,
                              );

                              if (mounted) {
                                navigator.pop();
                                if (path != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.all(16),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        side: BorderSide(color: AppColors.border),
                                      ),
                                      backgroundColor: const Color(0xFF1E293B),
                                      elevation: 8,
                                      duration: const Duration(seconds: 10),
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Fichier TEJ XML généré avec succès !',
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  path.split(RegExp(r'[/\\]')).last,
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      action: SnackBarAction(
                                        label: 'Ouvrir / Partager',
                                        textColor: AppColors.primary,
                                        onPressed: () async {
                                          try {
                                            // ignore: deprecated_member_use
                                            await Share.shareXFiles([XFile(path)], text: 'Export TEJ Retenue à la source');
                                          } catch (_) {
                                            await OpenFilex.open(path);
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _isExporting = false;
                                });
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur lors de la génération du fichier TEJ: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.file_download_outlined, size: 18, color: Colors.white),
                    label: const Text('Exporter XML', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
