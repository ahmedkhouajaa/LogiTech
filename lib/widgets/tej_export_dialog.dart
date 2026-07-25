import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/payment_model.dart';
import '../services/tej_export_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class TejExportDialog extends StatefulWidget {
  final List<Payment> payments;
  final bool isSales;

  const TejExportDialog({
    super.key,
    required this.payments,
    required this.isSales,
  });

  @override
  State<TejExportDialog> createState() => _TejExportDialogState();
}

class _TejExportDialogState extends State<TejExportDialog> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  Set<String> _selectedPaymentIds = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Pre-select all payment IDs initially for the default month
    _updateInitialSelection();
  }

  void _updateInitialSelection() {
    final initialFiltered = _getFilteredPayments();
    _selectedPaymentIds = initialFiltered.map((p) => p.id).toSet();
  }

  List<Payment> _getFilteredPayments() {
    return widget.payments.where((p) {
      // Retenue source check
      if (p.method != 'retenue_source') return false;

      // Direction check
      if (widget.isSales && p.direction != 'encaissement') return false;
      if (!widget.isSales && p.direction != 'decaissement') return false;

      // Month filter inside dialog
      if (p.paymentDate.month != _selectedDate.month ||
          p.paymentDate.year != _selectedDate.year) {
        return false;
      }

      // Search filter (Ref / Facture or Contact Name)
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
    final filteredPayments = _getFilteredPayments();
    final allSelected = filteredPayments.isNotEmpty &&
        filteredPayments.every((p) => _selectedPaymentIds.contains(p.id));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      backgroundColor: AppColors.surface,
      child: Container(
        width: 750,
        constraints: BoxConstraints(maxHeight: 650),
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Icon(Icons.file_download_outlined,
                    color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Exportation TEJ (Retenue à la source)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textTertiary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),

            // Filters Section inside mini-interface
            Row(
              children: [
                // Month Picker
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mois de déclaration',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Month Popup Menu
                          Expanded(
                            flex: 3,
                            child: PopupMenuButton<int>(
                              tooltip: 'Changer de mois',
                              elevation: 6,
                              offset: Offset(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                side: BorderSide(color: AppColors.border),
                              ),
                              color: AppColors.surface,
                              onSelected: (month) {
                                setState(() {
                                  _selectedDate = DateTime(_selectedDate.year, month);
                                  _updateInitialSelection();
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
                                height: 40,
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMMM', 'fr').format(_selectedDate),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Year Popup Menu
                          Expanded(
                            flex: 2,
                            child: PopupMenuButton<int>(
                              tooltip: 'Changer d\'année',
                              elevation: 6,
                              offset: Offset(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                side: BorderSide(color: AppColors.border),
                              ),
                              color: AppColors.surface,
                              onSelected: (year) {
                                setState(() {
                                  _selectedDate = DateTime(year, _selectedDate.month);
                                  _updateInitialSelection();
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
                                      SizedBox(width: 10),
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
                                height: 40,
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_selectedDate.year}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
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
                const SizedBox(width: AppSpacing.md),

                // Search Field (Facture / Ref)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recherche (Facture / Réf / Fournisseur)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Rechercher par ref. ou fournisseur...',
                            hintStyle: TextStyle(
                                color: AppColors.textTertiary, fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 16, color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.surfaceAlt,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),

            // Table Header / List
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.md),
                  topRight: Radius.circular(AppRadius.md),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPaymentIds
                              .addAll(filteredPayments.map((p) => p.id));
                        } else {
                          for (var p in filteredPayments) {
                            _selectedPaymentIds.remove(p.id);
                          }
                        }
                      });
                    },
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Facture / Réf',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.isSales ? 'Client' : 'Fournisseur',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Date',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Montant RS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // List of Items
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.md),
                    bottomRight: Radius.circular(AppRadius.md),
                  ),
                ),
                child: filteredPayments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'Aucun enregistrement trouvé pour ce mois',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredPayments.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final payment = filteredPayments[index];
                          final isSelected =
                              _selectedPaymentIds.contains(payment.id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPaymentIds.remove(payment.id);
                                } else {
                                  _selectedPaymentIds.add(payment.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPaymentIds.add(payment.id);
                                        } else {
                                          _selectedPaymentIds
                                              .remove(payment.id);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      payment.reference ?? payment.paymentNumber,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      payment.contactName ?? '—',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      formatDate(payment.paymentDate),
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${formatCurrency(payment.amount, symbol: '')} DT',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Bottom Buttons Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedPaymentIds.intersection(filteredPayments.map((p) => p.id).toSet()).length} élément(s) sélectionné(s)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: Text(
                        'Annuler',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isExporting ||
                              _selectedPaymentIds
                                  .intersection(filteredPayments
                                      .map((p) => p.id)
                                      .toSet())
                                  .isEmpty
                          ? null
                          : () async {
                              setState(() {
                                _isExporting = true;
                              });

                              final toExport = filteredPayments
                                  .where(
                                      (p) => _selectedPaymentIds.contains(p.id))
                                  .toList();

                              try {
                                final path = await TejExportService.exportAchats(
                                  toExport,
                                  _selectedDate.year,
                                  _selectedDate.month,
                                );

                                if (mounted) {
                                  Navigator.of(context).pop();
                                  if (path != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        margin: EdgeInsets.all(AppSpacing.lg),
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.lg),
                                          side: BorderSide(color: AppColors.border),
                                        ),
                                        backgroundColor: const Color(0xFF1E293B),
                                        elevation: 8,
                                        duration: const Duration(seconds: 10),
                                        content: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Fichier XML TEJ généré avec succès',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: AppColors.surface,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    path,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white.withValues(alpha: 0.7),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            ElevatedButton.icon(
                                              onPressed: () async {
                                                try {
                                                  if (Platform.isWindows) {
                                                    await Process.run('explorer.exe', ['/select,', path]);
                                                  } else {
                                                    await OpenFilex.open(path);
                                                  }
                                                } catch (e) {
                                                  print('Error opening file location: $e');
                                                }
                                              },
                                              icon: const Icon(Icons.folder_open_rounded, size: 16, color: Colors.white),
                                              label: Text(
                                                'Voir',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(AppSpacing.lg),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                        content: const Text('Erreur lors de la génération du fichier XML'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    _isExporting = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.all(AppSpacing.lg),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                      ),
                                      content: Text('Erreur: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: _isExporting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.surface),
                            )
                          : const Icon(Icons.file_download_outlined,
                              size: 18, color: Colors.white),
                      label: Text(
                        'Exporter XML',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
