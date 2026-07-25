import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class MobileSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;

  const MobileSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Rechercher...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      color: AppColors.background,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
