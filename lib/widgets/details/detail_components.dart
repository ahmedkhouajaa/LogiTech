import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';

/// Hero header card with entity avatar icon, title, subtitle, and badges row
class DetailHeroHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final VoidCallback? onCopyTitle;

  const DetailHeroHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.onCopyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large entity icon
          Container(
            width: isMobile ? 52 : 64,
            height: isMobile ? 52 : 64,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: isMobile ? 26 : 32),
            ),
          ),
          SizedBox(width: isMobile ? 14 : 20),
          // Main information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onCopyTitle != null)
                      IconButton(
                        icon: Icon(Icons.copy_rounded, size: 16, color: AppColors.textTertiary),
                        tooltip: 'Copier',
                        onPressed: onCopyTitle,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: badges,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlight KPI metric card
class DetailKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isHighlight;

  const DetailKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = const Color(0xFF1a56db),
    this.subtitle,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlight ? color.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isHighlight ? color.withValues(alpha: 0.35) : AppColors.border,
          width: isHighlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isHighlight ? color : AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isHighlight ? color.withValues(alpha: 0.8) : AppColors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Structured Section Container with Title and Icon
class DetailSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const DetailSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          // Body content
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Universal, high-contrast clipboard copy helper with instant visual feedback
void copyToClipboard(BuildContext context, {required String label, required String text}) {
  final clean = text.trim();
  if (clean.isEmpty) return;
  Clipboard.setData(ClipboardData(text: clean));

  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label copié dans le presse-papier !',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      duration: const Duration(milliseconds: 1800),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
    ),
  );
}

/// Clean key-value tile with interactive copy-to-clipboard button and full-tile tap support
class DetailInfoTile extends StatefulWidget {
  final String label;
  final String? value;
  final String? copyValue;
  final IconData? icon;
  final bool copyable;
  final Color? valueColor;
  final FontWeight? valueFontWeight;
  final Widget? customValueWidget;

  const DetailInfoTile({
    super.key,
    required this.label,
    this.value,
    this.copyValue,
    this.icon,
    this.copyable = false,
    this.valueColor,
    this.valueFontWeight,
    this.customValueWidget,
  });

  @override
  State<DetailInfoTile> createState() => _DetailInfoTileState();
}

class _DetailInfoTileState extends State<DetailInfoTile> {
  bool _justCopied = false;

  void _triggerCopy() {
    final textToCopy = widget.copyValue ?? widget.value;
    if (textToCopy == null || textToCopy.trim().isEmpty || textToCopy.trim() == '—') return;

    copyToClipboard(context, label: widget.label, text: textToCopy);

    if (mounted) {
      setState(() => _justCopied = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _justCopied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = (widget.value != null && widget.value!.trim().isNotEmpty) ? widget.value!.trim() : '—';
    final isNone = displayVal == '—';
    final isInteractive = widget.copyable && !isNone;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isInteractive ? _triggerCopy : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: isInteractive ? AppColors.primary.withValues(alpha: 0.04) : Colors.transparent,
        splashColor: isInteractive ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        mouseCursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _justCopied
                  ? AppColors.success.withValues(alpha: 0.8)
                  : AppColors.border.withValues(alpha: 0.5),
              width: _justCopied ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.copyable && !isNone) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: _justCopied ? 'Copié !' : 'Copier ${widget.label}',
                      child: InkWell(
                        onTap: _triggerCopy,
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _justCopied
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _justCopied ? Icons.check_rounded : Icons.copy_rounded,
                                size: 12,
                                color: _justCopied ? AppColors.success : AppColors.primary,
                              ),
                              if (_justCopied) ...[
                                const SizedBox(width: 4),
                                Text(
                                  'Copié',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              if (widget.customValueWidget != null)
                widget.customValueWidget!
              else
                Text(
                  displayVal,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: widget.valueFontWeight ?? (isNone ? FontWeight.normal : FontWeight.w600),
                    color: isNone ? AppColors.textTertiary : (widget.valueColor ?? AppColors.textPrimary),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper method to build simple status chip with copy support
Widget buildDetailBadge({
  required String label,
  required Color color,
  IconData? icon,
  VoidCallback? onTap,
}) {
  final chip = Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 5),
          Icon(Icons.copy_rounded, size: 11, color: color.withValues(alpha: 0.8)),
        ],
      ],
    ),
  );

  if (onTap != null) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Cliquer pour copier $label',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: chip,
        ),
      ),
    );
  }
  return chip;
}
