import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../models/product.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';
import '../../blocs/exit_vouchers/exit_vouchers_bloc.dart';

import '../../models/stock_withdrawal.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../database/database_helper.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_state.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import 'forms/mobile_exit_voucher_form_screen.dart';
import '../../screens/create_stock_withdrawal_screen.dart';
import '../../screens/exit_vouchers_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import '../../utils/offline_action_helper.dart';
import '../../services/custom_status_service.dart';
import '../../widgets/dialogs/change_status_dialog.dart';

class MobileStockWithdrawalDetailScreen extends StatefulWidget {
  final StockWithdrawal withdrawal;
  final bool isExitVoucher;

  const MobileStockWithdrawalDetailScreen({
    super.key,
    required this.withdrawal,
    this.isExitVoucher = false,
  });

  @override
  State<MobileStockWithdrawalDetailScreen> createState() => _MobileStockWithdrawalDetailScreenState();
}

class _MobileStockWithdrawalDetailScreenState extends State<MobileStockWithdrawalDetailScreen> {
  late StockWithdrawal currentWithdrawal;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentWithdrawal = widget.withdrawal;
    _loadFullWithdrawal();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await DatabaseHelper.instance.getProducts();
      if (mounted) {
        setState(() {
          _dbProducts = {for (var p in products) p.id: p};
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFullWithdrawal() async {
    final fullWithdrawal = await DatabaseHelper.instance.getStockWithdrawal(currentWithdrawal.id);
    if (fullWithdrawal != null && mounted) {
      setState(() {
        currentWithdrawal = fullWithdrawal;
      });
    }
  }

  Product? _getProduct(String id) {
    if (_dbProducts.containsKey(id)) {
      return _dbProducts[id];
    }
    final state = context.read<ProductsBloc>().state;
    if (state is ProductsLoaded) {
      try {
        return state.products.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return null;
  }

  DocumentWrapper _createDocumentWrapper(StockWithdrawal note) {
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: widget.isExitVoucher ? "BON DE SORTIE" : "BON DE PRÉLÈVEMENT",
      documentType: widget.isExitVoucher ? "exit_voucher" : "stock_withdrawal",
      date: note.date,
      customerName: widget.isExitVoucher ? (note.customerCompany ?? note.customerName) : null,
      customerId: widget.isExitVoucher ? note.customerId : null,
      totalHT: note.subTotalHT,
      totalTva: note.totalTVA,
      stampTax: note.timbreFiscal,
      totalTTC: note.totalTTC,
      notes: note.notes,
      conditionsGenerales: note.conditionsGenerales,
      items: note.items.map((item) {
        final product = _getProduct(item.productId);
        return DocumentItemWrapper(
          productName: product?.name ?? 'Article Inconnu',
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          totalHT: item.totalHT,
          customFields: {
            'code': (product?.reference != null && product!.reference!.isNotEmpty) 
                ? product.reference 
                : (product?.code ?? ''),
            'unit': product?.unit ?? 'pièce',
            'purchasePrice': product?.purchasePrice ?? 0,
          },
        );
      }).toList(),
      customFields: note.customFields,
      customData: {
        'warehouseId': note.warehouseId,
        'warehouseName': 'Entrepôt par défaut',
        'createdBy': 'Admin',
        'projectName': note.projectName,
        'driverName': note.driverName,
        'vehicleRegistration': note.vehicleRegistration,
        'customFields': note.customFields,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wState = context.watch<WarehousesBloc>().state;
    String getWhName(String? id) {
      if (id == null || id.isEmpty) return 'Entrepôt par défaut';
      if (id == 'default_warehouse') return 'Entrepôt par défaut';
      if (wState is WarehousesLoaded) {
        final match = wState.warehouses.cast<dynamic>().firstWhere(
          (w) => w.id == id, 
          orElse: () => null,
        );
        if (match != null) return match.name;
      }
      return 'Entrepôt par défaut';
    }
    final String warehouseName = getWhName(currentWithdrawal.warehouseId);

    final sInfo = CustomStatusService.instance.getStatusInfo('exit_voucher', currentWithdrawal.status);
    final statusLabel = sInfo.label;
    final statusColor = sInfo.color;
    final resKey = widget.isExitVoucher ? UserPermissionResources.salesExitVouchers : UserPermissionResources.stockWithdrawalVouchers;

    final infoSections = [
      PremiumInfoSection(
        title: context.tr('Informations Générales'),
        icon: Icons.info_outline,
        fields: [
          if (currentWithdrawal.customerName != null && currentWithdrawal.customerName!.isNotEmpty)
            PremiumInfoField(
              label: context.tr('Client'),
              value: currentWithdrawal.customerName!,
              icon: Icons.person_outline,
              isHighlight: true,
            ),
          PremiumInfoField(
            label: context.tr('Entrepôt'),
            value: warehouseName,
            icon: Icons.warehouse_outlined,
            isHighlight: currentWithdrawal.customerName == null,
          ),
          PremiumInfoField(
            label: 'Date',
            value: formatDateTimeLong(currentWithdrawal.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentWithdrawal.projectName != null && currentWithdrawal.projectName!.isNotEmpty)
            PremiumInfoField(
              label: 'Projet',
              value: currentWithdrawal.projectName!,
              icon: Icons.work_outline,
            ),
        ],
      ),
    ];

    final articles = currentWithdrawal.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? 'Article non spécifié';
      final refCode = product?.reference ?? product?.code;

      return PremiumArticleItem(
        reference: refCode,
        designation: productName,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
        totalHT: item.totalHT,
      );
    }).toList();

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: context.tr('Total HT'),
        amount: currentWithdrawal.subTotalHT,
      ),
      PremiumTotalRow(
        label: context.tr('Total TVA'),
        amount: currentWithdrawal.totalTVA,
      ),
      PremiumTotalRow(
        label: context.tr('Total TTC'),
        amount: currentWithdrawal.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return MultiBlocListener(
      listeners: [
        BlocListener<StockWithdrawalsBloc, StockWithdrawalsState>(
          listenWhen: (_, __) => !widget.isExitVoucher,
          listener: (context, state) {
            if (state is StockWithdrawalsLoaded) {
              try {
                final updatedWithdrawal = state.withdrawals.firstWhere((q) => (q as StockWithdrawal).id == currentWithdrawal.id);
                if (mounted) {
                  setState(() {
                    currentWithdrawal = (updatedWithdrawal as StockWithdrawal).copyWith(items: currentWithdrawal.items);
                  });
                }
              } catch (_) {
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            }
          },
        ),
        BlocListener<ExitVouchersBloc, ExitVouchersState>(
          listenWhen: (_, __) => widget.isExitVoucher,
          listener: (context, state) {
            if (state is ExitVouchersLoaded) {
              try {
                final updatedWithdrawal = state.withdrawals.firstWhere((q) => q.id == currentWithdrawal.id);
                if (mounted) {
                  setState(() {
                    currentWithdrawal = updatedWithdrawal.copyWith(items: currentWithdrawal.items);
                  });
                }
              } catch (_) {
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            '${widget.isExitVoucher ? 'BS' : 'BP'} ${currentWithdrawal.number}', 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentWithdrawal),
              itemBuilder: (_) {
                final canRead = PermissionService.instance.canRead(resKey);
                final canUpdate = PermissionService.instance.canUpdate(resKey);
                final canDelete = PermissionService.instance.canDelete(resKey);

                final entries = <PopupMenuEntry<String>>[];
                void addItem(String val, IconData icon, Color col, String label) {
                  if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                  entries.add(_buildMenuItem(val, icon, col, label));
                }

                if (canRead) {
                  addItem('view', Icons.visibility_outlined, AppColors.primary, context.tr('Voir'));
                }
                if (canUpdate) {
                  addItem('edit', Icons.edit_outlined, AppColors.primary, context.tr('Modifier'));
                  addItem('status', Icons.swap_horiz_outlined, AppColors.warning, context.tr('Changer le statut'));
                }
                if (canDelete) {
                  addItem('delete', Icons.delete_outline, AppColors.error, context.tr('Supprimer'));
                }
                if (canRead) {
                  addItem('print', Icons.print_outlined, AppColors.primary, context.tr('Imprimer'));
                  addItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, context.tr('Télécharger PDF'));
                  addItem('email', Icons.email_outlined, AppColors.primary, context.tr('Envoyer par email'));
                  addItem('whatsapp', Icons.chat_outlined, AppColors.success, context.tr('Envoyer par WhatsApp'));
                }

                return entries;
              },
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: widget.isExitVoucher ? context.tr('Bon de Sortie') : context.tr('Bon de Prélèvement'),
          referenceNumber: currentWithdrawal.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentWithdrawal.notes,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Color(0xFF64748B)),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, StockWithdrawal withdrawal) {
    if (OfflineActionHelper.writeActions.contains(action)) {
      OfflineActionHelper.executeAction(
        context: context,
        action: action,
        onConfirmed: () => _executeWriteAction(context, action, withdrawal),
      );
      return;
    }

    switch (action) {
      case 'view':
        final viewDoc = _createDocumentWrapper(withdrawal);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'print':
        final doc = _createDocumentWrapper(withdrawal);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final docPdf = _createDocumentWrapper(withdrawal);
        PdfService.instance.downloadDocument(context, docPdf);
        break;
      case 'email':
        final docEmail = _createDocumentWrapper(withdrawal);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = _createDocumentWrapper(withdrawal);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Action non implémentée'))));
    }
  }

  void _executeWriteAction(BuildContext context, String action, StockWithdrawal withdrawal) {
    switch (action) {
      case 'edit':
        if (widget.isExitVoucher) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<ExitVouchersBloc>()),
                  BlocProvider.value(value: context.read<CustomersBloc>()),
                  BlocProvider.value(value: context.read<ProductsBloc>()),
                ],
                child: MobileExitVoucherFormScreen(
                  existing: withdrawal,
                  isExitVoucher: true,
                ),
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateStockWithdrawalScreen(
                existing: withdrawal,
                isExitVoucher: false,
              ),
            ),
          );
        }
        break;
      case 'delete':
        if (widget.isExitVoucher) {
          context.read<ExitVouchersBloc>().add(DeleteExitVoucher(withdrawal.id));
        } else {
          context.read<StockWithdrawalsBloc>().add(DeleteStockWithdrawal(withdrawal.id));
        }
        break;
      case 'status':
        _showChangeStatusDialog(context, withdrawal);
        break;
    }
  }

  void _showChangeStatusDialog(BuildContext context, StockWithdrawal withdrawal) {
    showDocumentChangeStatusDialog(
      context: context,
      documentType: 'exit_voucher',
      currentStatus: withdrawal.status,
      onSave: (newStatusKey, notes) async {
        final updatedNote = withdrawal.copyWith(
          status: newStatusKey,
          notes: notes != null && notes.isNotEmpty ? '${withdrawal.notes ?? ''}\n$notes' : withdrawal.notes,
        );
        if (widget.isExitVoucher) {
          context.read<ExitVouchersBloc>().add(UpdateExitVoucher(updatedNote));
        } else {
          context.read<StockWithdrawalsBloc>().add(UpdateStockWithdrawal(updatedNote));
        }
      },
    );
  }
}
