import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/enterprise/enterprise_bloc.dart';
import '../../models/hr_legal_entity.dart';
import '../../services/hr_legal_entity_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';
import '../../widgets/add_legal_entity_dialog.dart';

class MobileHrLegalEntityScreen extends StatefulWidget {
  const MobileHrLegalEntityScreen({super.key});

  @override
  State<MobileHrLegalEntityScreen> createState() => _MobileHrLegalEntityScreenState();
}

class _MobileHrLegalEntityScreenState extends State<MobileHrLegalEntityScreen> {
  String? _selectedEntityId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnterpriseBloc, EnterpriseState>(
      builder: (context, entState) {
        final enterpriseId = entState is EnterpriseLoaded ? (entState.currentEnterpriseId ?? '') : '';
        final enterpriseName = entState is EnterpriseLoaded
            ? (entState.enterprises.firstWhere((e) => e.id == enterpriseId, orElse: () => entState.enterprises.first).name)
            : 'red';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: StreamBuilder<List<HrLegalEntity>>(
            stream: HrLegalEntityService.instance.streamLegalEntities(enterpriseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final entities = snapshot.data ?? [];
              final entity = entities.firstWhere(
                (e) => e.id == _selectedEntityId,
                orElse: () => entities.isNotEmpty
                    ? entities.first
                    : HrLegalEntity(
                        id: 'default',
                        enterpriseId: enterpriseId,
                        socialReason: enterpriseName,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Entity Header Card
                    _buildMobileHeader(context, entity, entities, enterpriseName),
                    const SizedBox(height: 16),

                    // Section 1: Informations légales
                    _buildSectionCard(
                      title: 'Informations légales',
                      onEdit: () => _openMobileEditSheet(context, entity, MobileSectionType.legalInfo),
                      child: Column(
                        children: [
                          _buildRow('Dénomination sociale', entity.socialReason.isNotEmpty ? entity.socialReason : '-'),
                          _buildRow('Matricule fiscal', entity.taxId.isNotEmpty ? entity.taxId : '-'),
                          _buildRow('TVA', entity.vatStatus.isNotEmpty ? entity.vatStatus : '-'),
                          _buildRow('Catégorie', entity.category.isNotEmpty ? entity.category : '-'),
                          _buildRow('N. CNSS', entity.cnssNumber.isNotEmpty ? entity.cnssNumber : '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Paramètres de paie
                    _buildSectionCard(
                      title: 'Paramètres de paie',
                      onEdit: () => _openMobileEditSheet(context, entity, MobileSectionType.payrollSettings),
                      child: Column(
                        children: [
                          _buildRow(
                            'Convention collective',
                            entity.hasNoCollectiveAgreement
                                ? 'Aucune convention applicable'
                                : (entity.collectiveAgreement.isNotEmpty ? entity.collectiveAgreement : '-'),
                          ),
                          _buildRow('Exercice fiscal', entity.fiscalYear.isNotEmpty ? entity.fiscalYear : 'Janvier → Décembre'),
                          _buildRow('Jour de clôture', entity.cutoffDay.isNotEmpty ? entity.cutoffDay : 'Le 25 du mois'),
                          _buildRow('Jour de paiement', entity.paymentDay.isNotEmpty ? entity.paymentDay : 'Le 28 du mois'),
                          _buildRow('Fuseau horaire', entity.timezone.isNotEmpty ? entity.timezone : 'Africa/Tunis'),
                          _buildRow('Secteur d\'activité', entity.activitySector.isNotEmpty ? entity.activitySector : '-'),
                          _buildRow('Taux AT/MP employeur', entity.employerAtMpRate.isNotEmpty ? entity.employerAtMpRate : '-'),
                          _buildRow('Taux TFP employeur', entity.employerTfpRate.isNotEmpty ? entity.employerTfpRate : '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Siège social
                    _buildSectionCard(
                      title: 'Siège social',
                      onEdit: () => _openMobileEditSheet(context, entity, MobileSectionType.headquarters),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRow('Adresse', entity.address.isNotEmpty ? entity.address : '-'),
                          _buildRow('Code postal', entity.postalCode.isNotEmpty ? entity.postalCode : '-'),
                          _buildRow('Ville', entity.city.isNotEmpty ? entity.city : '-'),
                          _buildRow('Rayon de pointage', entity.checkInRadius.isNotEmpty ? entity.checkInRadius : '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 4: Représentant légal
                    _buildSectionCard(
                      title: 'Représentant légal',
                      onEdit: () => _openMobileEditSheet(context, entity, MobileSectionType.legalRepresentative),
                      child: Column(
                        children: [
                          _buildRow('Nom', entity.legalRepName.isNotEmpty ? entity.legalRepName : '-'),
                          _buildRow('Fonction', entity.legalRepRole.isNotEmpty ? entity.legalRepRole : '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 5: Coordonnées bancaires
                    _buildSectionCard(
                      title: 'Coordonnées bancaires',
                      onEdit: () => _openMobileEditSheet(context, entity, MobileSectionType.bankDetails),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Les coordonnées bancaires sont utilisées pour générer les virements et doivent être au nom de l\'entité juridique.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildRow('Nom du compte', entity.bankAccountName.isNotEmpty ? entity.bankAccountName : '-'),
                          _buildRow('IBAN', entity.iban.isNotEmpty ? entity.iban : '-'),
                          _buildRow('BIC', entity.bic.isNotEmpty ? entity.bic : '-'),
                          _buildRow('Agence', entity.bankAgency.isNotEmpty ? entity.bankAgency : '-'),
                          _buildRow(
                            'Ordre de virement',
                            entity.transferOrderActive ? 'Activé' : 'Désactivé',
                            valueColor: entity.transferOrderActive ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileHeader(BuildContext context, HrLegalEntity entity, List<HrLegalEntity> entities, String enterpriseName) {
    final title = entity.socialReason.isNotEmpty ? entity.socialReason : enterpriseName;
    final formattedDate = DateFormat('dd/MM/yyyy').format(entity.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_outlined, color: Color(0xFF334155), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entity.country.isNotEmpty ? entity.country : 'Tunisie',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Immatriculée le $formattedDate',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Mobile Entity Selector Pill (Image 2)
              InkWell(
                onTap: () => _showMobileEntitySheet(context, entities, entity),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entities.length} entité${entities.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.unfold_more_rounded, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMobileEntitySheet(BuildContext context, List<HrLegalEntity> entities, HrLegalEntity currentEntity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Entités juridiques',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),

                // List of entities (Image 3)
                ...entities.map((ent) {
                  final isSelected = ent.id == currentEntity.id;
                  final countryCode = ent.country.isNotEmpty && ent.country != '-'
                      ? (ent.country.toLowerCase() == 'tunisie' ? 'TN' : ent.country)
                      : 'TN';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                    title: Text(
                      ent.socialReason.isNotEmpty ? ent.socialReason : 'Entité',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    subtitle: Text(
                      '${ent.socialReason} · $countryCode',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF15803D), size: 20) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedEntityId = ent.id);
                    },
                  );
                }),

                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // "+ Ajouter une entité juridique" (Image 3)
                InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final created = await AddLegalEntityDialog.show(context, enterpriseId: currentEntity.enterpriseId);
                    if (created != null && mounted) {
                      setState(() => _selectedEntityId = created.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Entité juridique "${created.socialReason}" ajoutée avec succès !'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 20, color: Color(0xFF334155)),
                        SizedBox(width: 8),
                        Text(
                          'Ajouter une entité juridique',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMobileEditSheet(BuildContext context, HrLegalEntity entity, MobileSectionType section) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileEditLegalEntitySheet(entity: entity, section: section),
    );
  }
}

enum MobileSectionType {
  legalInfo,
  payrollSettings,
  headquarters,
  legalRepresentative,
  bankDetails,
}

class _MobileEditLegalEntitySheet extends StatefulWidget {
  final HrLegalEntity entity;
  final MobileSectionType section;

  const _MobileEditLegalEntitySheet({required this.entity, required this.section});

  @override
  State<_MobileEditLegalEntitySheet> createState() => _MobileEditLegalEntitySheetState();
}

class _MobileEditLegalEntitySheetState extends State<_MobileEditLegalEntitySheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _c1;
  late TextEditingController _c2;
  late TextEditingController _c3;
  late TextEditingController _c4;
  late TextEditingController _c5;
  bool _boolVal = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entity;
    switch (widget.section) {
      case MobileSectionType.legalInfo:
        _c1 = TextEditingController(text: e.socialReason);
        _c2 = TextEditingController(text: e.taxId == '-' ? '' : e.taxId);
        _c3 = TextEditingController(text: e.vatStatus == '-' ? '' : e.vatStatus);
        _c4 = TextEditingController(text: e.category == '-' ? '' : e.category);
        _c5 = TextEditingController(text: e.cnssNumber == '-' ? '' : e.cnssNumber);
        break;
      case MobileSectionType.payrollSettings:
        _c1 = TextEditingController(text: e.collectiveAgreement == '-' ? '' : e.collectiveAgreement);
        _c2 = TextEditingController(text: e.fiscalYear);
        _c3 = TextEditingController(text: e.cutoffDay);
        _c4 = TextEditingController(text: e.paymentDay);
        _c5 = TextEditingController(text: e.timezone);
        _boolVal = e.hasNoCollectiveAgreement;
        break;
      case MobileSectionType.headquarters:
        _c1 = TextEditingController(text: e.address == '-' ? '' : e.address);
        _c2 = TextEditingController(text: e.postalCode == '-' ? '' : e.postalCode);
        _c3 = TextEditingController(text: e.city == '-' ? '' : e.city);
        _c4 = TextEditingController(text: e.checkInRadius == '-' ? '' : e.checkInRadius);
        _c5 = TextEditingController();
        _boolVal = e.hasGeozone;
        break;
      case MobileSectionType.legalRepresentative:
        _c1 = TextEditingController(text: e.legalRepName == '-' ? '' : e.legalRepName);
        _c2 = TextEditingController(text: e.legalRepRole == '-' ? '' : e.legalRepRole);
        _c3 = TextEditingController();
        _c4 = TextEditingController();
        _c5 = TextEditingController();
        break;
      case MobileSectionType.bankDetails:
        _c1 = TextEditingController(text: e.bankAccountName == '-' ? '' : e.bankAccountName);
        _c2 = TextEditingController(text: e.iban == '-' ? '' : e.iban);
        _c3 = TextEditingController(text: e.bic == '-' ? '' : e.bic);
        _c4 = TextEditingController(text: e.bankAgency == '-' ? '' : e.bankAgency);
        _c5 = TextEditingController();
        _boolVal = e.transferOrderActive;
        break;
    }
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();
    _c5.dispose();
    super.dispose();
  }

  String _title() {
    switch (widget.section) {
      case MobileSectionType.legalInfo: return 'Informations légales';
      case MobileSectionType.payrollSettings: return 'Paramètres de paie';
      case MobileSectionType.headquarters: return 'Siège social';
      case MobileSectionType.legalRepresentative: return 'Représentant légal';
      case MobileSectionType.bankDetails: return 'Coordonnées bancaires';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_title(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: _fields(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (widget.section) {
      case MobileSectionType.legalInfo:
        return [
          _input('Dénomination sociale *', _c1, required: true),
          _input('Matricule fiscal', _c2),
          _input('TVA', _c3),
          _input('Catégorie', _c4),
          _input('N. CNSS', _c5),
        ];
      case MobileSectionType.payrollSettings:
        return [
          CheckboxListTile(
            title: const Text('Aucune convention applicable', style: TextStyle(fontSize: 12.5)),
            value: _boolVal,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _boolVal = v ?? false),
          ),
          if (!_boolVal) _input('Convention collective', _c1),
          _input('Exercice fiscal', _c2),
          _input('Jour de clôture', _c3),
          _input('Jour de paiement', _c4),
          _input('Fuseau horaire', _c5),
        ];
      case MobileSectionType.headquarters:
        return [
          _input('Adresse', _c1),
          _input('Code postal', _c2),
          _input('Ville', _c3),
          _input('Rayon de pointage', _c4),
          SwitchListTile(
            title: const Text('Géozone active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            value: _boolVal,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _boolVal = v),
          ),
        ];
      case MobileSectionType.legalRepresentative:
        return [
          _input('Nom du représentant', _c1),
          _input('Fonction', _c2),
        ];
      case MobileSectionType.bankDetails:
        return [
          _input('Nom du compte', _c1),
          _input('IBAN / RIB', _c2),
          _input('BIC / SWIFT', _c3),
          _input('Agence bancaire', _c4),
          SwitchListTile(
            title: const Text('Ordre de virement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            value: _boolVal,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _boolVal = v),
          ),
        ];
    }
  }

  Widget _input(String label, TextEditingController ctrl, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
    if (!allowed) return;

    setState(() => _isSaving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      HrLegalEntity updated = widget.entity;
      switch (widget.section) {
        case MobileSectionType.legalInfo:
          updated = updated.copyWith(
            socialReason: _c1.text.trim().isNotEmpty ? _c1.text.trim() : updated.socialReason,
            taxId: _c2.text.trim().isNotEmpty ? _c2.text.trim() : '-',
            vatStatus: _c3.text.trim().isNotEmpty ? _c3.text.trim() : '-',
            category: _c4.text.trim().isNotEmpty ? _c4.text.trim() : '-',
            cnssNumber: _c5.text.trim().isNotEmpty ? _c5.text.trim() : '-',
          );
          break;
        case MobileSectionType.payrollSettings:
          updated = updated.copyWith(
            collectiveAgreement: _c1.text.trim().isNotEmpty ? _c1.text.trim() : '-',
            hasNoCollectiveAgreement: _boolVal,
            fiscalYear: _c2.text.trim().isNotEmpty ? _c2.text.trim() : updated.fiscalYear,
            cutoffDay: _c3.text.trim().isNotEmpty ? _c3.text.trim() : updated.cutoffDay,
            paymentDay: _c4.text.trim().isNotEmpty ? _c4.text.trim() : updated.paymentDay,
            timezone: _c5.text.trim().isNotEmpty ? _c5.text.trim() : updated.timezone,
          );
          break;
        case MobileSectionType.headquarters:
          updated = updated.copyWith(
            address: _c1.text.trim().isNotEmpty ? _c1.text.trim() : '-',
            postalCode: _c2.text.trim().isNotEmpty ? _c2.text.trim() : '-',
            city: _c3.text.trim().isNotEmpty ? _c3.text.trim() : '-',
            checkInRadius: _c4.text.trim().isNotEmpty ? _c4.text.trim() : '-',
            hasGeozone: _boolVal,
          );
          break;
        case MobileSectionType.legalRepresentative:
          updated = updated.copyWith(
            legalRepName: _c1.text.trim().isNotEmpty ? _c1.text.trim() : '-',
            legalRepRole: _c2.text.trim().isNotEmpty ? _c2.text.trim() : '-',
          );
          break;
        case MobileSectionType.bankDetails:
          updated = updated.copyWith(
            bankAccountName: _c1.text.trim().isNotEmpty ? _c1.text.trim() : '-',
            iban: _c2.text.trim().isNotEmpty ? _c2.text.trim() : '-',
            bic: _c3.text.trim().isNotEmpty ? _c3.text.trim() : '-',
            bankAgency: _c4.text.trim().isNotEmpty ? _c4.text.trim() : '-',
            transferOrderActive: _boolVal,
          );
          break;
      }

      await HrLegalEntityService.instance.saveLegalEntity(updated);
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Entité juridique mise à jour !'), backgroundColor: Color(0xFF10B981)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
