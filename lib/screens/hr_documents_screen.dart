import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/hr_document.dart';
import '../services/hr_document_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../widgets/add_hr_document_dialog.dart';

class HrDocumentsScreen extends StatefulWidget {
  const HrDocumentsScreen({super.key});

  @override
  State<HrDocumentsScreen> createState() => _HrDocumentsScreenState();
}

class _HrDocumentsScreenState extends State<HrDocumentsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'Tous';

  final List<String> _typeFilters = [
    'Tous',
    'Attestation',
    'Autre',
    'Déclaration',
    'Document RH',
    'Pièce d\'identité',
    'Contrat de travail',
  ];

  @override
  void initState() {
    super.initState();
    _checkSeed();
  }

  void _checkSeed() {
    final state = context.read<EnterpriseBloc>().state;
    if (state is EnterpriseLoaded && state.currentEnterpriseId != null) {
      HrDocumentService.instance.seedInitialDemoDocumentsIfEmpty(state.currentEnterpriseId!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseLoaded && state.currentEnterpriseId != null) {
          HrDocumentService.instance.seedInitialDemoDocumentsIfEmpty(state.currentEnterpriseId!);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Documents title + "Ajouter" pill button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Documents',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => AddHrDocumentDialog.show(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Ajouter',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter & Search Row matching Image 1
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Search Input (100% white, no inner grey bubble)
                    Container(
                      width: 380,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: const InputDecorationTheme(
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Rechercher par nom, matricule, poste ou téléphone...',
                                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                onChanged: (v) => setState(() => _searchQuery = v),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Dropdown
                    Container(
                      height: 44,
                      constraints: const BoxConstraints(minWidth: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTypeFilter,
                          dropdownColor: Colors.white,
                          focusColor: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          icon: const Icon(Icons.arrow_drop_down, size: 24, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.normal),
                          items: _typeFilters.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTypeFilter = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Table Content
              Expanded(
                child: BlocBuilder<EnterpriseBloc, EnterpriseState>(
                  builder: (context, entState) {
                    final enterpriseId = entState is EnterpriseLoaded ? (entState.currentEnterpriseId ?? '') : '';

                    return StreamBuilder<List<HrDocument>>(
                      stream: HrDocumentService.instance.getDocumentsStream(enterpriseId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
                        }

                        final allDocs = snapshot.data ?? [];
                        final filtered = allDocs.where((doc) {
                          final matchQuery = _searchQuery.isEmpty ||
                              doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              doc.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              doc.type.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              doc.sharedWith.toLowerCase().contains(_searchQuery.toLowerCase());

                          final matchType = _selectedTypeFilter == 'Tous' ||
                              _selectedTypeFilter == 'Tous les types' ||
                              doc.type.toLowerCase() == _selectedTypeFilter.toLowerCase();

                          return matchQuery && matchType;
                        }).toList();

                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final minTableWidth = 980.0;
                              final tableWidth = constraints.maxWidth < minTableWidth
                                  ? minTableWidth
                                  : constraints.maxWidth;

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: tableWidth,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Table Header
                                      _buildTableHeader(),
                                      const Divider(height: 1, color: Color(0xFFE5E7EB)),

                                      // Table Body
                                      Expanded(
                                        child: filtered.isEmpty
                                            ? _buildEmptyState()
                                            : ListView.separated(
                                                itemCount: filtered.length,
                                                separatorBuilder: (_, __) =>
                                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                                itemBuilder: (context, index) {
                                                  final doc = filtered[index];
                                                  return _buildTableRow(doc);
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              'TITRE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'TYPE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'FICHIER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'CRÉÉ LE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PARTAGÉ AVEC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              'ACTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(HrDocument doc) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(doc.createdAt);
    final isPrivate = doc.sharedWith.toLowerCase() == 'privé';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titre
          Expanded(
            flex: 3,
            child: Text(
              doc.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Type Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  doc.type,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),

          // Fichier
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(
                  doc.fileExtension.toLowerCase() == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 16,
                  color: doc.fileExtension.toLowerCase() == 'pdf'
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF1A56DB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Créé le
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),

          // Partagé avec
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPrivate ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  doc.sharedWith,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPrivate ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ),
          ),

          // Actions: Aperçu | Télécharger | Delete
          SizedBox(
            width: 200,
            child: Row(
              children: [
                InkWell(
                  onTap: () => HrDocumentService.instance.previewDocument(context, doc),
                  child: const Text(
                    'Aperçu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                InkWell(
                  onTap: () => HrDocumentService.instance.downloadDocument(context, doc),
                  child: const Text(
                    'Télécharger',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                  tooltip: 'Supprimer',
                  hoverColor: const Color(0xFFFEE2E2),
                  onPressed: () => _confirmDelete(doc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Aucun document trouvé',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajoutez vos documents RH, déclarations et attestations.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(HrDocument doc) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'Supprimer le document',
      onConfirmed: () async {
        await HrDocumentService.instance.deleteDocument(doc.id);
      },
    );
  }
}
