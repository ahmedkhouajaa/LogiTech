import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/hr_legal_entity.dart';
import '../services/hr_legal_entity_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../widgets/add_legal_entity_dialog.dart';

class HrLegalEntityScreen extends StatefulWidget {
  const HrLegalEntityScreen({super.key});

  @override
  State<HrLegalEntityScreen> createState() => _HrLegalEntityScreenState();
}

class _HrLegalEntityScreenState extends State<HrLegalEntityScreen> {
  String? _selectedEntityId;
  final GlobalKey _badgeKey = GlobalKey();

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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header: Entity Title & Dropdown (Image 1 & 2) ───
                    _buildHeader(context, entity, entities, enterpriseName),
                    const SizedBox(height: 22),

                    // ─── Row 1: Informations légales & Paramètres de paie ───
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildInformationsLegalesCard(context, entity)),
                              const SizedBox(width: 20),
                              Expanded(child: _buildParametresPaieCard(context, entity)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildInformationsLegalesCard(context, entity),
                              const SizedBox(height: 20),
                              _buildParametresPaieCard(context, entity),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // ─── Row 2: Siège social (Screenshot 2) ───
                    _buildSiegeSocialCard(context, entity),
                    const SizedBox(height: 20),

                    // ─── Row 3: Représentant légal & Coordonnées bancaires (Screenshot 3) ───
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildRepresentantLegalCard(context, entity)),
                              const SizedBox(width: 20),
                              Expanded(child: _buildCoordonneesBancairesCard(context, entity)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildRepresentantLegalCard(context, entity),
                              const SizedBox(height: 20),
                              _buildCoordonneesBancairesCard(context, entity),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── Top Header Widget ───────────────────────────────────────────
  Widget _buildHeader(BuildContext context, HrLegalEntity entity, List<HrLegalEntity> entities, String enterpriseName) {
    final title = entity.socialReason.isNotEmpty ? entity.socialReason : enterpriseName;
    final formattedDate = DateFormat('dd/MM/yyyy').format(entity.createdAt);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bank/Entity Icon in rounded box
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: Color(0xFF334155),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entity.country.isNotEmpty ? entity.country : 'Tunisie',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$title · Immatriculée depuis le $formattedDate',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Right side: Entity Selector Badge (Image 2)
        GestureDetector(
          key: _badgeKey,
          onTap: () => _showEntityDropdown(context, entities, entity),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '$title · ${entities.length} entité${entities.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Dropdown Menu (Image 3) ──────────────────────────────────────
  void _showEntityDropdown(BuildContext context, List<HrLegalEntity> entities, HrLegalEntity currentEntity) {
    final renderBox = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(context).size.width;
        const popupWidth = 270.0;
        double left = offset.dx + size.width - popupWidth;
        if (left < 16) left = 16;
        if (left + popupWidth > screenWidth - 16) left = screenWidth - popupWidth - 16;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: offset.dy + size.height + 6,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: popupWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // List of entities (Image 3)
                      ...entities.map((ent) {
                        final isSelected = ent.id == currentEntity.id;
                        final countryCode = ent.country.isNotEmpty && ent.country != '-'
                            ? (ent.country.toLowerCase() == 'tunisie' ? 'TN' : ent.country)
                            : 'TN';

                        return InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _selectedEntityId = ent.id;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ent.socialReason.isNotEmpty ? ent.socialReason : 'Entité',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${ent.socialReason} · $countryCode',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Color(0xFF15803D),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      ),

                      // "+ Ajouter une entité juridique" (Image 3)
                      InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openAddEntityWizard(context, currentEntity.enterpriseId);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Color(0xFF334155),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Ajouter une entité juridique',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAddEntityWizard(BuildContext context, String enterpriseId) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await AddLegalEntityDialog.show(
      context,
      enterpriseId: enterpriseId,
    );

    if (created != null && mounted) {
      setState(() {
        _selectedEntityId = created.id;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Entité juridique "${created.socialReason}" ajoutée avec succès !'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // ─── Card 1: Informations légales ─────────────────────────────────
  Widget _buildInformationsLegalesCard(BuildContext context, HrLegalEntity entity) {
    return _buildSectionCard(
      title: 'Informations légales',
      onEdit: () => _openEditDialog(context, entity, SectionType.legalInfo),
      child: Column(
        children: [
          _buildInfoRow('Dénomination sociale', entity.socialReason.isNotEmpty ? entity.socialReason : '-'),
          _buildInfoRow('Matricule fiscal', entity.taxId.isNotEmpty ? entity.taxId : '-'),
          _buildInfoRow('TVA', entity.vatStatus.isNotEmpty ? entity.vatStatus : '-'),
          _buildInfoRow('Catégorie', entity.category.isNotEmpty ? entity.category : '-'),
          _buildInfoRow('N. CNSS', entity.cnssNumber.isNotEmpty ? entity.cnssNumber : '-'),
        ],
      ),
    );
  }

  // ─── Card 2: Paramètres de paie ───────────────────────────────────
  Widget _buildParametresPaieCard(BuildContext context, HrLegalEntity entity) {
    return _buildSectionCard(
      title: 'Paramètres de paie',
      onEdit: () => _openEditDialog(context, entity, SectionType.payrollSettings),
      child: Column(
        children: [
          _buildInfoRow(
            'Convention collective',
            entity.hasNoCollectiveAgreement
                ? 'Déclarer qu\'aucune convention ne s\'applique'
                : (entity.collectiveAgreement.isNotEmpty ? entity.collectiveAgreement : '-'),
            customAction: entity.collectiveAgreement == '-' && !entity.hasNoCollectiveAgreement
                ? InkWell(
                    onTap: () async {
                      final updated = entity.copyWith(hasNoCollectiveAgreement: true);
                      await HrLegalEntityService.instance.saveLegalEntity(updated);
                    },
                    child: const Text(
                      'Déclarer qu\'aucune convention ne s\'applique',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : null,
          ),
          _buildInfoRow('Exercice fiscal', entity.fiscalYear.isNotEmpty ? entity.fiscalYear : 'Janvier → Décembre'),
          _buildInfoRow('Jour de clôture', entity.cutoffDay.isNotEmpty ? entity.cutoffDay : 'Le 25 du mois'),
          _buildInfoRow('Jour de paiement', entity.paymentDay.isNotEmpty ? entity.paymentDay : 'Le 28 du mois'),
          _buildInfoRow('Fuseau horaire', entity.timezone.isNotEmpty ? entity.timezone : 'Africa/Tunis'),
          _buildInfoRow('Secteur d\'activité', entity.activitySector.isNotEmpty ? entity.activitySector : '-'),
          _buildInfoRow('Taux AT/MP employeur', entity.employerAtMpRate.isNotEmpty ? entity.employerAtMpRate : '-'),
          _buildInfoRow('Taux TFP employeur', entity.employerTfpRate.isNotEmpty ? entity.employerTfpRate : '-'),
        ],
      ),
    );
  }

  // ─── Card 3: Siège social ─────────────────────────────────────────
  Widget _buildSiegeSocialCard(BuildContext context, HrLegalEntity entity) {
    return _buildSectionCard(
      title: 'Siège social',
      onEdit: () => _openEditDialog(context, entity, SectionType.headquarters),
      child: Column(
        children: [
          _buildInfoRow('Adresse', entity.address.isNotEmpty ? entity.address : '-'),
          _buildInfoRow('Code postal', entity.postalCode.isNotEmpty ? entity.postalCode : '-'),
          _buildInfoRow('Ville', entity.city.isNotEmpty ? entity.city : '-'),
          _buildInfoRow('Rayon de pointage', entity.checkInRadius.isNotEmpty ? entity.checkInRadius : '-'),
        ],
      ),
    );
  }

  // ─── Card 4: Représentant légal ───────────────────────────────────
  Widget _buildRepresentantLegalCard(BuildContext context, HrLegalEntity entity) {
    return _buildSectionCard(
      title: 'Représentant légal',
      onEdit: () => _openEditDialog(context, entity, SectionType.legalRepresentative),
      child: Column(
        children: [
          _buildInfoRow('Nom', entity.legalRepName.isNotEmpty ? entity.legalRepName : '-'),
          _buildInfoRow('Fonction', entity.legalRepRole.isNotEmpty ? entity.legalRepRole : '-'),
        ],
      ),
    );
  }

  // ─── Card 5: Coordonnées bancaires ────────────────────────────────
  Widget _buildCoordonneesBancairesCard(BuildContext context, HrLegalEntity entity) {
    return _buildSectionCard(
      title: 'Coordonnées bancaires',
      onEdit: () => _openEditDialog(context, entity, SectionType.bankDetails),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green helper alert banner (Screenshot 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les coordonnées bancaires sont utilisées pour générer les virements et doivent être au nom de l\'entité juridique.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildInfoRow('Nom du compte', entity.bankAccountName.isNotEmpty ? entity.bankAccountName : '-'),
          _buildInfoRow('IBAN', entity.iban.isNotEmpty ? entity.iban : '-'),
          _buildInfoRow('BIC', entity.bic.isNotEmpty ? entity.bic : '-'),
          _buildInfoRow('Agence', entity.bankAgency.isNotEmpty ? entity.bankAgency : '-'),
          _buildInfoRow(
            'Ordre de virement',
            entity.transferOrderActive ? 'Activé' : 'Désactivé',
            valueColor: entity.transferOrderActive ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ─── Helper: Card Container ───────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Modifier',
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ─── Helper: Key - Value Row ──────────────────────────────────────
  Widget _buildInfoRow(
    String label,
    String value, {
    Widget? customAction,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 16),
          if (customAction != null)
            customAction
          else
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? const Color(0xFF0F172A),
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Edit Dialog ───────────────────────────────────────────────────
  void _openEditDialog(BuildContext context, HrLegalEntity entity, SectionType section) {
    showDialog(
      context: context,
      builder: (ctx) => _EditLegalEntityDialog(entity: entity, section: section),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// EDIT DIALOG
// ──────────────────────────────────────────────────────────────────
enum SectionType {
  legalInfo,
  payrollSettings,
  headquarters,
  legalRepresentative,
  bankDetails,
}

class _EditLegalEntityDialog extends StatefulWidget {
  final HrLegalEntity entity;
  final SectionType section;

  const _EditLegalEntityDialog({
    required this.entity,
    required this.section,
  });

  @override
  State<_EditLegalEntityDialog> createState() => _EditLegalEntityDialogState();
}

class _EditLegalEntityDialogState extends State<_EditLegalEntityDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _socialReasonCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _vatStatusCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _cnssNumberCtrl;

  late TextEditingController _collectiveAgreementCtrl;
  late bool _hasNoCollectiveAgreement;
  late TextEditingController _fiscalYearCtrl;
  late TextEditingController _cutoffDayCtrl;
  late TextEditingController _paymentDayCtrl;
  late TextEditingController _timezoneCtrl;
  late TextEditingController _activitySectorCtrl;
  late TextEditingController _employerAtMpRateCtrl;
  late TextEditingController _employerTfpRateCtrl;

  late TextEditingController _addressCtrl;
  late TextEditingController _postalCodeCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _checkInRadiusCtrl;
  late bool _hasGeozone;

  late TextEditingController _legalRepNameCtrl;
  late TextEditingController _legalRepRoleCtrl;

  late TextEditingController _bankAccountNameCtrl;
  late TextEditingController _ibanCtrl;
  late TextEditingController _bicCtrl;
  late TextEditingController _bankAgencyCtrl;
  late bool _transferOrderActive;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entity;
    _socialReasonCtrl = TextEditingController(text: e.socialReason);
    _taxIdCtrl = TextEditingController(text: e.taxId == '-' ? '' : e.taxId);
    _vatStatusCtrl = TextEditingController(text: e.vatStatus == '-' ? '' : e.vatStatus);
    _categoryCtrl = TextEditingController(text: e.category == '-' ? '' : e.category);
    _cnssNumberCtrl = TextEditingController(text: e.cnssNumber == '-' ? '' : e.cnssNumber);

    _collectiveAgreementCtrl = TextEditingController(text: e.collectiveAgreement == '-' ? '' : e.collectiveAgreement);
    _hasNoCollectiveAgreement = e.hasNoCollectiveAgreement;
    _fiscalYearCtrl = TextEditingController(text: e.fiscalYear);
    _cutoffDayCtrl = TextEditingController(text: e.cutoffDay);
    _paymentDayCtrl = TextEditingController(text: e.paymentDay);
    _timezoneCtrl = TextEditingController(text: e.timezone);
    _activitySectorCtrl = TextEditingController(text: e.activitySector == '-' ? '' : e.activitySector);
    _employerAtMpRateCtrl = TextEditingController(text: e.employerAtMpRate == '-' ? '' : e.employerAtMpRate);
    _employerTfpRateCtrl = TextEditingController(text: e.employerTfpRate == '-' ? '' : e.employerTfpRate);

    _addressCtrl = TextEditingController(text: e.address == '-' ? '' : e.address);
    _postalCodeCtrl = TextEditingController(text: e.postalCode == '-' ? '' : e.postalCode);
    _cityCtrl = TextEditingController(text: e.city == '-' ? '' : e.city);
    _checkInRadiusCtrl = TextEditingController(text: e.checkInRadius == '-' ? '' : e.checkInRadius);
    _hasGeozone = e.hasGeozone;

    _legalRepNameCtrl = TextEditingController(text: e.legalRepName == '-' ? '' : e.legalRepName);
    _legalRepRoleCtrl = TextEditingController(text: e.legalRepRole == '-' ? '' : e.legalRepRole);

    _bankAccountNameCtrl = TextEditingController(text: e.bankAccountName == '-' ? '' : e.bankAccountName);
    _ibanCtrl = TextEditingController(text: e.iban == '-' ? '' : e.iban);
    _bicCtrl = TextEditingController(text: e.bic == '-' ? '' : e.bic);
    _bankAgencyCtrl = TextEditingController(text: e.bankAgency == '-' ? '' : e.bankAgency);
    _transferOrderActive = e.transferOrderActive;
  }

  @override
  void dispose() {
    _socialReasonCtrl.dispose();
    _taxIdCtrl.dispose();
    _vatStatusCtrl.dispose();
    _categoryCtrl.dispose();
    _cnssNumberCtrl.dispose();

    _collectiveAgreementCtrl.dispose();
    _fiscalYearCtrl.dispose();
    _cutoffDayCtrl.dispose();
    _paymentDayCtrl.dispose();
    _timezoneCtrl.dispose();
    _activitySectorCtrl.dispose();
    _employerAtMpRateCtrl.dispose();
    _employerTfpRateCtrl.dispose();

    _addressCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _checkInRadiusCtrl.dispose();

    _legalRepNameCtrl.dispose();
    _legalRepRoleCtrl.dispose();

    _bankAccountNameCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    _bankAgencyCtrl.dispose();
    super.dispose();
  }

  String _dialogTitle() {
    switch (widget.section) {
      case SectionType.legalInfo:
        return 'Modifier les informations légales';
      case SectionType.payrollSettings:
        return 'Modifier les paramètres de paie';
      case SectionType.headquarters:
        return 'Modifier le siège social';
      case SectionType.legalRepresentative:
        return 'Modifier le représentant légal';
      case SectionType.bankDetails:
        return 'Modifier les coordonnées bancaires';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dialogTitle(),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSectionFormFields(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSectionFormFields() {
    switch (widget.section) {
      case SectionType.legalInfo:
        return [
          _buildTextField('Dénomination sociale *', _socialReasonCtrl, required: true),
          const SizedBox(height: 12),
          _buildTextField('Matricule fiscal', _taxIdCtrl, hint: 'Ex. 1234567/A/M/000'),
          const SizedBox(height: 12),
          _buildTextField('TVA', _vatStatusCtrl, hint: 'Ex. Assujetti'),
          const SizedBox(height: 12),
          _buildTextField('Catégorie', _categoryCtrl, hint: 'Ex. Personne morale'),
          const SizedBox(height: 12),
          _buildTextField('N. CNSS', _cnssNumberCtrl, hint: 'Ex. 123456-78'),
        ];

      case SectionType.payrollSettings:
        return [
          CheckboxListTile(
            title: const Text('Aucune convention collective ne s\'applique', style: TextStyle(fontSize: 13)),
            value: _hasNoCollectiveAgreement,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _hasNoCollectiveAgreement = v ?? false),
          ),
          if (!_hasNoCollectiveAgreement) ...[
            const SizedBox(height: 8),
            _buildTextField('Convention collective', _collectiveAgreementCtrl, hint: 'Ex. Métallurgie'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Exercice fiscal', _fiscalYearCtrl, hint: 'Janvier → Décembre')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Fuseau horaire', _timezoneCtrl, hint: 'Africa/Tunis')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Jour de clôture', _cutoffDayCtrl, hint: 'Le 25 du mois')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Jour de paiement', _paymentDayCtrl, hint: 'Le 28 du mois')),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField('Secteur d\'activité', _activitySectorCtrl, hint: 'Ex. Technologies'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Taux AT/MP employeur', _employerAtMpRateCtrl, hint: '0.4 %')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Taux TFP employeur', _employerTfpRateCtrl, hint: '1.0 %')),
            ],
          ),
        ];

      case SectionType.headquarters:
        return [
          _buildTextField('Adresse', _addressCtrl, hint: 'Rue, avenue...'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Code postal', _postalCodeCtrl, hint: '1000')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Ville', _cityCtrl, hint: 'Tunis')),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField('Rayon de pointage', _checkInRadiusCtrl, hint: 'Ex. 100 m'),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Activer la géozone pour le pointage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: _hasGeozone,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _hasGeozone = v),
          ),
        ];

      case SectionType.legalRepresentative:
        return [
          _buildTextField('Nom du représentant', _legalRepNameCtrl, hint: 'Prénom et Nom'),
          const SizedBox(height: 12),
          _buildTextField('Fonction', _legalRepRoleCtrl, hint: 'Gérant, PDG, Directeur...'),
        ];

      case SectionType.bankDetails:
        return [
          _buildTextField('Nom du compte', _bankAccountNameCtrl, hint: 'Dénomination de l\'entité'),
          const SizedBox(height: 12),
          _buildTextField('IBAN / RIB', _ibanCtrl, hint: 'TN59 ...'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('BIC / SWIFT', _bicCtrl, hint: 'Code BIC')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Agence bancaire', _bankAgencyCtrl, hint: 'Agence...')),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Ordre de virement bancaire', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Générer automatiquement les ordres de virement', style: TextStyle(fontSize: 11.5)),
            value: _transferOrderActive,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _transferOrderActive = v),
          ),
        ];
    }
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {String? hint, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          ),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null : null,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
    if (!allowed) return;

    setState(() => _isSaving = true);

    try {
      final updated = widget.entity.copyWith(
        socialReason: _socialReasonCtrl.text.trim().isNotEmpty ? _socialReasonCtrl.text.trim() : widget.entity.socialReason,
        taxId: _taxIdCtrl.text.trim().isNotEmpty ? _taxIdCtrl.text.trim() : '-',
        vatStatus: _vatStatusCtrl.text.trim().isNotEmpty ? _vatStatusCtrl.text.trim() : '-',
        category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : '-',
        cnssNumber: _cnssNumberCtrl.text.trim().isNotEmpty ? _cnssNumberCtrl.text.trim() : '-',

        collectiveAgreement: _collectiveAgreementCtrl.text.trim().isNotEmpty ? _collectiveAgreementCtrl.text.trim() : '-',
        hasNoCollectiveAgreement: _hasNoCollectiveAgreement,
        fiscalYear: _fiscalYearCtrl.text.trim().isNotEmpty ? _fiscalYearCtrl.text.trim() : widget.entity.fiscalYear,
        cutoffDay: _cutoffDayCtrl.text.trim().isNotEmpty ? _cutoffDayCtrl.text.trim() : widget.entity.cutoffDay,
        paymentDay: _paymentDayCtrl.text.trim().isNotEmpty ? _paymentDayCtrl.text.trim() : widget.entity.paymentDay,
        timezone: _timezoneCtrl.text.trim().isNotEmpty ? _timezoneCtrl.text.trim() : widget.entity.timezone,
        activitySector: _activitySectorCtrl.text.trim().isNotEmpty ? _activitySectorCtrl.text.trim() : '-',
        employerAtMpRate: _employerAtMpRateCtrl.text.trim().isNotEmpty ? _employerAtMpRateCtrl.text.trim() : '-',
        employerTfpRate: _employerTfpRateCtrl.text.trim().isNotEmpty ? _employerTfpRateCtrl.text.trim() : '-',

        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : '-',
        postalCode: _postalCodeCtrl.text.trim().isNotEmpty ? _postalCodeCtrl.text.trim() : '-',
        city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : '-',
        checkInRadius: _checkInRadiusCtrl.text.trim().isNotEmpty ? _checkInRadiusCtrl.text.trim() : '-',
        hasGeozone: _hasGeozone,

        legalRepName: _legalRepNameCtrl.text.trim().isNotEmpty ? _legalRepNameCtrl.text.trim() : '-',
        legalRepRole: _legalRepRoleCtrl.text.trim().isNotEmpty ? _legalRepRoleCtrl.text.trim() : '-',

        bankAccountName: _bankAccountNameCtrl.text.trim().isNotEmpty ? _bankAccountNameCtrl.text.trim() : '-',
        iban: _ibanCtrl.text.trim().isNotEmpty ? _ibanCtrl.text.trim() : '-',
        bic: _bicCtrl.text.trim().isNotEmpty ? _bicCtrl.text.trim() : '-',
        bankAgency: _bankAgencyCtrl.text.trim().isNotEmpty ? _bankAgencyCtrl.text.trim() : '-',
        transferOrderActive: _transferOrderActive,
      );

      await HrLegalEntityService.instance.saveLegalEntity(updated);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entité juridique mise à jour !'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
