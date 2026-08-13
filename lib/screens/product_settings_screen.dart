import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/shimmer_effect.dart';
import 'package:uuid/uuid.dart';
import '../blocs/product_settings/product_settings_bloc.dart';
import '../blocs/product_settings/product_settings_event.dart';
import '../blocs/product_settings/product_settings_state.dart';
import '../models/product_family.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class ProductSettingsScreen extends StatefulWidget {
  const ProductSettingsScreen({super.key});

  @override
  State<ProductSettingsScreen> createState() => _ProductSettingsScreenState();
}

class _ProductSettingsScreenState extends State<ProductSettingsScreen> {
  final _familyCtrl = TextEditingController();
  final Map<String, TextEditingController> _subFamilyCtrls = {};

  @override
  void initState() {
    super.initState();
    context.read<ProductSettingsBloc>().add(LoadFamilies());
  }

  @override
  void dispose() {
    _familyCtrl.dispose();
    for (var c in _subFamilyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getSubFamilyCtrl(String familyId) {
    if (!_subFamilyCtrls.containsKey(familyId)) {
      _subFamilyCtrls[familyId] = TextEditingController();
    }
    return _subFamilyCtrls[familyId]!;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paramètres des articles', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Gérer les familles et sous-familles d\'articles', style: TextStyle(color: AppColors.textSecondary, fontSize: isMobile ? 12 : 14)),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<ProductSettingsBloc>().add(LoadFamilies());
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add new family section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajouter une nouvelle famille',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        isMobile
                            ? Column(
                                children: [
                                  TextField(
                                    controller: _familyCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Nom de la famille (ex: Informatique, Mobilier...)',
                                      filled: true,
                                      fillColor: AppColors.surfaceAlt,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleAddFamily,
                                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                      label: const Text('Ajouter une famille', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _familyCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Nom de la famille (ex: Informatique, Mobilier...)',
                                        filled: true,
                                        fillColor: AppColors.surfaceAlt,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      onSubmitted: (_) => _handleAddFamily(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    onPressed: _handleAddFamily,
                                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                    label: const Text('Ajouter une famille', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),

                  BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
                    builder: (context, state) {
                      if (state is ProductSettingsLoading || state is ProductSettingsInitial) {
                        return AppShimmer(
                          child: Column(
                            children: List.generate(
                              4,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: const [
                                      ShimmerBox(width: 24, height: 24, borderRadius: 6),
                                      SizedBox(width: 12),
                                      ShimmerBox(width: 150, height: 14, borderRadius: 4),
                                      Spacer(),
                                      ShimmerBox(width: 60, height: 24, borderRadius: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductSettingsLoaded) {
                        final rootFamilies = state.rootFamilies;

                        if (rootFamilies.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.category_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune famille enregistrée',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Saisissez un nom ci-dessus pour créer votre première famille d\'articles.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rootFamilies.map((family) {
                            final subFamilies = state.getSubFamilies(family.id);
                            return _buildFamilyCard(context, family, subFamilies, isMobile);
                          }).toList(),
                        );
                      }
                      
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAddFamily() {
    print("DEBUG: _handleAddFamily called, text='${_familyCtrl.text.trim()}'");
    final name = _familyCtrl.text.trim();
    if (name.isNotEmpty) {
      final newFam = ProductFamily(
        id: const Uuid().v4(),
        name: name,
      );
      print("DEBUG: Adding family '${newFam.name}' with id=${newFam.id}");
      context.read<ProductSettingsBloc>().add(AddFamily(newFam));
      _familyCtrl.clear();
    } else {
      print("DEBUG: Family name is empty, not adding");
    }
  }

  Widget _buildFamilyCard(BuildContext context, ProductFamily family, List<ProductFamily> subFamilies, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${subFamilies.length} sous-famille(s)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                tooltip: 'Supprimer la famille',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirmer la suppression'),
                      content: Text('Voulez-vous vraiment supprimer la famille "${family.name}" ainsi que toutes ses sous-familles ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProductSettingsBloc>().add(DeleteFamily(family.id));
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          if (subFamilies.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Sous-familles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...subFamilies.map((subFam) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(subFam.name, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmer la suppression'),
                          content: Text('Voulez-vous vraiment supprimer la sous-famille "${subFam.name}" ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                context.read<ProductSettingsBloc>().add(DeleteSubFamily(subFam.id));
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, color: AppColors.textSecondary.withOpacity(0.7), size: 16),
                    ),
                  ),
                ],
              ),
            )),
          ],
          
          const SizedBox(height: 16),
          isMobile
              ? Column(
                  children: [
                    TextField(
                      controller: _getSubFamilyCtrl(family.id),
                      decoration: InputDecoration(
                        hintText: 'Nom de la nouvelle sous-famille',
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleAddSubFamily(family.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Ajouter la sous-famille', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _getSubFamilyCtrl(family.id),
                        decoration: InputDecoration(
                          hintText: 'Nom de la nouvelle sous-famille',
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _handleAddSubFamily(family.id),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _handleAddSubFamily(family.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Text('Ajouter la sous-famille', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  void _handleAddSubFamily(String familyId) {
    final ctrl = _getSubFamilyCtrl(familyId);
    if (ctrl.text.trim().isNotEmpty) {
      final newSub = ProductFamily(
        id: const Uuid().v4(),
        name: ctrl.text.trim(),
        parentId: familyId,
      );
      context.read<ProductSettingsBloc>().add(AddSubFamily(newSub));
      ctrl.clear();
    }
  }
}
