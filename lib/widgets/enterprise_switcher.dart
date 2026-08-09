import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/enterprise.dart';
import '../utils/constants.dart';

/// Interactive Enterprise Switcher widget for both Desktop and Mobile.
class EnterpriseSwitcherWidget extends StatelessWidget {
  final bool isCollapsed;
  final bool isMobile;

  const EnterpriseSwitcherWidget({
    super.key,
    this.isCollapsed = false,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnterpriseBloc, EnterpriseState>(
      builder: (context, state) {
        if (state is! EnterpriseLoaded) {
          return SizedBox.shrink();
        }

        final currentEnterprise = state.enterprises.firstWhere(
          (e) => e.id == state.currentEnterpriseId,
          orElse: () => Enterprise(
            id: '',
            name: 'Mon Entreprise',
            ownerId: '',
          ),
        );

        if (isMobile) {
          return _buildMobileSwitcher(context, currentEnterprise, state.enterprises);
        }

        return _buildDesktopSwitcher(context, currentEnterprise, state.enterprises);
      },
    );
  }

  Widget _buildDesktopSwitcher(
    BuildContext context,
    Enterprise current,
    List<Enterprise> enterprises,
  ) {
    if (isCollapsed) {
      return Tooltip(
        message: current.name,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: Text(
              current.name.isNotEmpty ? current.name[0].toUpperCase() : 'E',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Changer d\'entreprise',
      offset: const Offset(0, 45),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
      onSelected: (value) {
        if (value == '__create_new__') {
          showCreateEnterpriseDialog(context);
        } else {
          context.read<EnterpriseBloc>().add(SwitchEnterprise(value));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'MES ENTREPRISES',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...enterprises.map((e) {
          final isSelected = e.id == current.id;
          return PopupMenuItem<String>(
            value: e.id,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.business_rounded,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__create_new__',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Créer une entreprise',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  current.name.isNotEmpty ? current.name[0].toUpperCase() : 'E',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    current.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Workspace',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded, color: AppColors.sidebarText, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSwitcher(
    BuildContext context,
    Enterprise current,
    List<Enterprise> enterprises,
  ) {
    return InkWell(
      onTap: () => _showMobileBottomSheet(context, current, enterprises),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                current.name.isNotEmpty ? current.name[0].toUpperCase() : 'E',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        current.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 20),
                  ],
                ),
                Text(
                  'Gestion d\'entreprise',
                  style: TextStyle(color: AppColors.sidebarText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileBottomSheet(
    BuildContext context,
    Enterprise current,
    List<Enterprise> enterprises,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mes Entreprises',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: enterprises.length,
                    itemBuilder: (context, index) {
                      final e = enterprises[index];
                      final isSelected = e.id == current.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceAlt,
                          child: Text(
                            e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          e.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          context.read<EnterpriseBloc>().add(SwitchEnterprise(e.id));
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.add, color: AppColors.primary),
                  ),
                  title: Text(
                    'Créer une entreprise',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    showCreateEnterpriseDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showCreateEnterpriseDialog(BuildContext context, {bool isDismissible = true}) {
    showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) => PopScope(
        canPop: isDismissible,
        child: _CreateEnterpriseFormDialog(isDismissible: isDismissible),
      ),
    );
  }
}

class _CreateEnterpriseFormDialog extends StatefulWidget {
  final bool isDismissible;
  const _CreateEnterpriseFormDialog({this.isDismissible = true});

  @override
  State<_CreateEnterpriseFormDialog> createState() => _CreateEnterpriseFormDialogState();
}

class _CreateEnterpriseFormDialogState extends State<_CreateEnterpriseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _rcController = TextEditingController();
  final _addressController = TextEditingController();
  final _ribController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _rcController.dispose();
    _addressController.dispose();
    _ribController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 780),
        padding: EdgeInsets.all(isMobile ? 18 : 28),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Créer une nouvelle entreprise',
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (widget.isDismissible)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (isMobile) ...[
                  _buildField('Nom de votre société (Tireur)', _nameController, hint: 'Mon Entreprise', isRequired: true),
                  const SizedBox(height: 16),
                  _buildField('Téléphone', _phoneController, hint: '27755999', keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildField('Email', _emailController, hint: 'ahmed@gmail.com', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildField('Site Web', _websiteController, hint: 'www.ahmed.com'),
                  const SizedBox(height: 16),
                  _buildField('Matricule Fiscale', _taxIdController, hint: 'MF1234567/A/B/C/000'),
                  const SizedBox(height: 16),
                  _buildField('Registre de Commerce', _rcController, hint: 'RC123456789'),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildField('Nom de votre société (Tireur)', _nameController, hint: 'Mon Entreprise', isRequired: true),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildField('Téléphone', _phoneController, hint: '27755999', keyboardType: TextInputType.phone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField('Email', _emailController, hint: 'ahmed@gmail.com', keyboardType: TextInputType.emailAddress),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildField('Site Web', _websiteController, hint: 'www.ahmed.com'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField('Matricule Fiscale', _taxIdController, hint: 'MF1234567/A/B/C/000'),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildField('Registre de Commerce', _rcController, hint: 'RC123456789'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _buildField('Adresse de votre société', _addressController, hint: '123 Rue Exemple, Ville, Pays'),
                const SizedBox(height: 20),
                _buildField('Coordonnées bancaires (RIB)', _ribController, hint: 'BIAT - Agence X - RIB: 08001002003004005006'),
                const SizedBox(height: 32),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _submitForm,
                        child: const Text('Créer l\'entreprise', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (widget.isDismissible) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.isDismissible) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _submitForm,
                        child: const Text('Créer l\'entreprise', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF3F5F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
              : null,
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final website = _websiteController.text.trim();
      final taxId = _taxIdController.text.trim();
      final rc = _rcController.text.trim();
      final address = _addressController.text.trim();
      final rib = _ribController.text.trim();

      Navigator.pop(context);

      context.read<EnterpriseBloc>().add(
            CreateEnterprise(
              name,
              phone: phone.isNotEmpty ? phone : null,
              email: email.isNotEmpty ? email : null,
              website: website.isNotEmpty ? website : null,
              taxId: taxId.isNotEmpty ? taxId : null,
              rcNumber: rc.isNotEmpty ? rc : null,
              address: address.isNotEmpty ? address : null,
              rib: rib.isNotEmpty ? rib : null,
            ),
          );
    }
  }
}
