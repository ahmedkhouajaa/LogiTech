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
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: Colors.transparent)),
          ),
          child: const Text('Parametres des articles', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gerer les familles et sous-familles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                
                BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
                  builder: (context, state) {
                    if (state is ProductSettingsLoading) {
                      return const Center(child: CircularProgressIndicator());
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _familyCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Nom de la famille',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                child: const Text('Ajouter une famille', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildFamilyCard(BuildContext context, ProductFamily family, List<ProductFamily> subFamilies) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                onPressed: () {
                  context.read<ProductSettingsBloc>().add(DeleteFamily(family.id));
                },
              ),
            ],
          ),
          
          if (subFamilies.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Sous-familles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...subFamilies.map((subFam) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(child: Text(subFam.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      context.read<ProductSettingsBloc>().add(DeleteSubFamily(subFam.id));
                    },
                  ),
                ],
              ),
            )),
          ],
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _getSubFamilyCtrl(family.id),
                  decoration: InputDecoration(
                    hintText: 'Nom de la nouvelle sous-famille',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
}
