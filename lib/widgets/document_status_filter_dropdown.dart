import 'dart:async';
import 'package:flutter/material.dart';
import '../services/custom_status_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class DocumentStatusFilterDropdown extends StatefulWidget {
  final String documentType;
  final String? currentStatusFilter;
  final ValueChanged<String?> onStatusSelected;

  const DocumentStatusFilterDropdown({
    super.key,
    required this.documentType,
    required this.currentStatusFilter,
    required this.onStatusSelected,
  });

  @override
  State<DocumentStatusFilterDropdown> createState() => _DocumentStatusFilterDropdownState();
}

class _DocumentStatusFilterDropdownState extends State<DocumentStatusFilterDropdown> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    CustomStatusService.instance.getCustomStatuses(widget.documentType).then((_) {
      if (mounted) setState(() {});
    });
    _sub = CustomStatusService.instance.changeStream.listen((type) {
      if ((type == widget.documentType || type == 'all') && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(DocumentStatusFilterDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentType != widget.documentType) {
      CustomStatusService.instance.getCustomStatuses(widget.documentType).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allStatuses = CustomStatusService.instance.getAllStatusesSync(widget.documentType);

    return SizedBox(
      height: 32,
      child: PopupMenuButton<String?>(
        tooltip: context.tr('Filtrer par statut'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        color: AppColors.surface,
        elevation: 4,
        offset: const Offset(0, 36),
        initialValue: widget.currentStatusFilter,
        onSelected: widget.onStatusSelected,
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            value: null,
            height: 34,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.tr('Tous'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.currentStatusFilter == null)
                  Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ),
          ...allStatuses.map(
            (s) => PopupMenuItem<String?>(
              value: s.key,
              height: 34,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.tr(s.name),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: s.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.currentStatusFilter == s.key)
                    Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.currentStatusFilter != null ? AppColors.primary : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: widget.currentStatusFilter == null
                    ? Text(
                        context.tr('Tous'),
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      )
                    : () {
                        final sInfo = CustomStatusService.instance.getStatusInfo(
                          widget.documentType,
                          widget.currentStatusFilter,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.tr(sInfo.label),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sInfo.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }(),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
