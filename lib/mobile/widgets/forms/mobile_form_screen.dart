import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import '../../../widgets/dashboard_card.dart'; // For StatusBadge

class MobileFormScreen extends StatelessWidget {
  final String title;
  final String? statusLabel;
  final Color? statusColor;
  final List<Widget> children;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final bool isLoading;
  final bool isSaveEnabled;

  const MobileFormScreen({
    super.key,
    required this.title,
    this.statusLabel,
    this.statusColor,
    required this.children,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Créer',
    this.isLoading = false,
    this.isSaveEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9), // Light background for contrast with white sections
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: onCancel,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (statusLabel != null && statusColor != null) ...[
              SizedBox(width: 8),
              StatusBadge(label: statusLabel!, color: statusColor!),
              SizedBox(width: 16),
            ]
          ],
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: children,
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, -2),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isLoading || !isSaveEnabled) ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.surface,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              saveLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
