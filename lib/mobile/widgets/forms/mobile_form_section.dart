import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

class MobileFormSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isInitiallyExpanded;
  final bool showProgress;
  final int completedFields;
  final int totalFields;

  const MobileFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.isInitiallyExpanded = true,
    this.showProgress = false,
    this.completedFields = 0,
    this.totalFields = 0,
  });

  @override
  State<MobileFormSection> createState() => _MobileFormSectionState();
}

class _MobileFormSectionState extends State<MobileFormSection> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.fastOutSlowIn));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.showProgress && widget.totalFields > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${widget.completedFields}/${widget.totalFields} complétés',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (widget.showProgress && widget.totalFields > 0) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: widget.totalFields > 0 ? widget.completedFields / widget.totalFields : 0,
                        backgroundColor: AppColors.border,
                        color: widget.completedFields == widget.totalFields ? AppColors.success : AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  RotationTransition(
                    turns: _iconTurns,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller.view,
            builder: _buildChildren,
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildChildren(BuildContext context, Widget? child) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: _heightFactor.value,
        child: child,
      ),
    );
  }
}
