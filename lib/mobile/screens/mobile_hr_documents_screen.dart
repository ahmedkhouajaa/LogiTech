import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/enterprise/enterprise_bloc.dart';
import '../../models/hr_document.dart';
import '../../services/hr_document_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';
import '../../widgets/add_hr_document_dialog.dart';

class MobileHrDocumentsScreen extends StatefulWidget {
  const MobileHrDocumentsScreen({super.key});

  @override
  State<MobileHrDocumentsScreen> createState() => _MobileHrDocumentsScreenState();
}

class _MobileHrDocumentsScreenState extends State<MobileHrDocumentsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'Tous';

  final List<String> _typeFilters = [
    'Tous',
    'Déclaration',
    'Pièce d\'identité',
    'Attestation',
    'Document RH',
    'Contrat de travail',
    'Autre',
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
      child: BlocBuilder<EnterpriseBloc, EnterpriseState>(
        builder: (context, entState) {
          final enterpriseId = entState is EnterpriseLoaded ? (entState.currentEnterpriseId ?? '') : '';

          return StreamBuilder<List<HrDocument>>(
            stream: HrDocumentService.instance.getDocumentsStream(enterpriseId),
            builder: (context, snapshot) {
              final allDocs = snapshot.data ?? [];
              final filtered = allDocs.where((doc) {
                final matchQuery = _searchQuery.isEmpty ||
                    doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    doc.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    doc.type.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    doc.sharedWith.toLowerCase().contains(_searchQuery.toLowerCase());

                final matchType = _selectedTypeFilter == 'Tous' ||
                    doc.type.toLowerCase() == _selectedTypeFilter.toLowerCase();

                return matchQuery && matchType;
              }).toList();

              return Column(
                children: [
                  // Top Action Bar with count and "Ajouter" pill button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Documents',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${filtered.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A56DB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => AddHrDocumentDialog.show(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search & Filter Row matching Image 1
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        // Search input matching Image 1
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
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
                                        hintText: 'Rechercher par nom, titre...',
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
                        ),
                        const SizedBox(width: 10),

                        // Dropdown filter matching Image 1
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTypeFilter,
                              icon: const Icon(Icons.arrow_drop_down, size: 24, color: Color(0xFF64748B)),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.normal),
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

                  const SizedBox(height: 4),

                  // Cards List (explicitly cards for Android, not tables)
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)))
                        : filtered.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final doc = filtered[index];
                                  return _buildDocumentCard(doc);
                                },
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(HrDocument doc) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(doc.createdAt);
    final isPrivate = doc.sharedWith.toLowerCase() == 'privé';
    final isPdf = doc.fileExtension.toLowerCase() == 'pdf';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Type Badge + Options Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  doc.type,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'preview') {
                    HrDocumentService.instance.previewDocument(context, doc);
                  } else if (val == 'download') {
                    HrDocumentService.instance.downloadDocument(context, doc);
                  } else if (val == 'delete') {
                    _confirmDelete(doc);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'preview',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1E293B)),
                        SizedBox(width: 8),
                        Text('Aperçu'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18, color: Color(0xFF1E293B)),
                        SizedBox(width: 8),
                        Text('Télécharger'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // File Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDF2F7)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    size: 20,
                    color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF1A56DB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (doc.formattedFileSize.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          doc.formattedFileSize,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Meta Row: Date & Shared With
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Créé le $formattedDate',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Partagé avec : ',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPrivate ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      doc.sharedWith,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPrivate ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Actions Row: Aperçu & Télécharger
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => HrDocumentService.instance.previewDocument(context, doc),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Aperçu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => HrDocumentService.instance.downloadDocument(context, doc),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Télécharger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Aucun document',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cliquez sur "Ajouter" pour téléverser votre premier document RH.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
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
