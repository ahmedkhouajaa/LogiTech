import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: Colors.transparent)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parametres des articles', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 4),
              Text('Gerer les familles et sous-familles', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await SyncService.instance.triggerSync();
              if (context.mounted) {
                context.read<ProductSettingsBloc>().add(LoadFamilies());
              }
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
                  builder: (context, state) {
                    if (state is ProductSettingsLoading) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (state is ProductSettingsLoaded) {
                      final rootFamilies = state.rootFamilies;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...rootFamilies.map((family) {
                            final subFamilies = state.getSubFamilies(family.id);
                            return _buildFamilyCard(context, family, subFamilies);
                          }),
                          
                          // Add new family
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _familyCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Nom de la famille',
                                    filled: true,
                                    fillColor: AppColors.surfaceAlt,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {
                                  if (_familyCtrl.text.trim().isNotEmpty) {
                                    final newFam = ProductFamily(
                                      id: const Uuid().v4(),
                                      name: _familyCtrl.text.trim(),
                                    );
                                    context.read<ProductSettingsBloc>().add(AddFamily(newFam));
                                    _familyCtrl.clear();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                child: Text('Ajouter une famille', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return SizedBox();
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

  Widget _buildFamilyCard(BuildContext context, ProductFamily family, List<ProductFamily> subFamilies) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  family.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Confirmer la suppression'),
                      content: Text('Voulez-vous vraiment supprimer la famille "${family.name}" ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProductSettingsBloc>().add(DeleteFamily(family.id));
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: Text('Supprimer', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          if (subFamilies.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Sous-familles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            SizedBox(height: 8),
            ...subFamilies.map((subFam) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  Expanded(child: Text(subFam.name, style: TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Confirmer la suppression'),
                          content: Text('Voulez-vous vraiment supprimer la sous-famille "${subFam.name}" ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                context.read<ProductSettingsBloc>().add(DeleteSubFamily(subFam.id));
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: Text('Supprimer', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            )),
          ],
          
          SizedBox(height: 16),
          Row(
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final ctrl = _getSubFamilyCtrl(family.id);
                  if (ctrl.text.trim().isNotEmpty) {
                    final newSub = ProductFamily(
                      id: const Uuid().v4(),
                      name: ctrl.text.trim(),
                      parentId: family.id,
                    );
                    context.read<ProductSettingsBloc>().add(AddSubFamily(newSub));
                    ctrl.clear();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: Text('Ajouter la sous-famille', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
