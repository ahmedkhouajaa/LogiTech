import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hr_establishment.dart';
import '../services/hr_establishment_service.dart';
import '../utils/constants.dart';
import '../widgets/add_establishment_dialog.dart';

class HrEstablishmentDetailScreen extends StatefulWidget {
  final String enterpriseId;
  final HrEstablishment establishment;

  const HrEstablishmentDetailScreen({
    super.key,
    required this.enterpriseId,
    required this.establishment,
  });

  @override
  State<HrEstablishmentDetailScreen> createState() =>
      _HrEstablishmentDetailScreenState();
}

class _HrEstablishmentDetailScreenState
    extends State<HrEstablishmentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return StreamBuilder<HrEstablishment?>(
      stream: HrEstablishmentService.instance.streamEstablishment(
        widget.enterpriseId,
        widget.establishment.id,
      ),
      initialData: widget.establishment,
      builder: (context, snapshot) {
        final est = snapshot.data ?? widget.establishment;

        final fullAddress = [
          if (est.address.isNotEmpty) est.address,
          if (est.addressSuite.isNotEmpty) est.addressSuite,
          if (est.postalCode.isNotEmpty || est.city.isNotEmpty)
            '${est.postalCode} ${est.city}'.trim(),
        ].join(', ');

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Retour aux établissements',
            ),
            titleSpacing: 0,
            title: const Text(
              'Retour aux établissements',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 36,
              vertical: isMobile ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Top Header (Screenshots 1 & 2) ─────────────────────────
                _buildHeader(context, est, fullAddress, isMobile),
                const SizedBox(height: 24),

                // ─── Tabs Bar ───────────────────────────────────────────────
                _buildTabBar(),
                const SizedBox(height: 24),

                // ─── Tab Content ────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    switch (_tabController.index) {
                      case 0:
                        return _buildDetailTab(context, est, isMobile);
                      case 1:
                        return _buildCollaboratorsTab(context, est);
                      case 2:
                        return _buildAttendanceRulesTab(context, est);
                      default:
                        return _buildDetailTab(context, est, isMobile);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Top Header: Name, Badge, Address, Modifier & Supprimer ───────────────
  Widget _buildHeader(
    BuildContext context,
    HrEstablishment est,
    String fullAddress,
    bool isMobile,
  ) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.domain_outlined,
                  size: 26,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            est.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(est.isActive),
                      ],
                    ),
                    if (fullAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        fullAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildModifierButton(context, est)),
              const SizedBox(width: 10),
              Expanded(child: _buildSupprimerButton(context, est)),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left info
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.domain_outlined,
                  size: 30,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          est.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildStatusBadge(est.isActive),
                      ],
                    ),
                    if (fullAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        fullAddress,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right action buttons (Modifier & Supprimer)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModifierButton(context, est),
            const SizedBox(width: 12),
            _buildSupprimerButton(context, est),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildModifierButton(BuildContext context, HrEstablishment est) {
    return OutlinedButton.icon(
      onPressed: () {
        AddEstablishmentDialog.show(
          context,
          enterpriseId: widget.enterpriseId,
          establishmentToEdit: est,
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: const Text(
        'Modifier',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildSupprimerButton(BuildContext context, HrEstablishment est) {
    return OutlinedButton.icon(
      onPressed: () => _confirmDelete(context, est),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      icon: const Icon(Icons.delete_outline_rounded, size: 16),
      label: const Text(
        'Supprimer',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  // ─── Tabs Bar matching screenshot ─────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        indicatorColor: const Color(0xFF0F172A),
        indicatorWeight: 2.5,
        tabs: const [
          Tab(text: 'Détail'),
          Tab(text: 'Collaborateurs'),
          Tab(text: 'Règles de pointage'),
        ],
      ),
    );
  }

  // ─── Tab 1: Détail (Cards Administratif & Adresse SANS CARTE) ─────────────
  Widget _buildDetailTab(
    BuildContext context,
    HrEstablishment est,
    bool isMobile,
  ) {
    return Column(
      children: [
        // ── Card 1: Administratif ──────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Administratif',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),

              _buildInfoRow(
                label: 'N° d\'immatriculation',
                value: est.registrationNumber.isNotEmpty
                    ? est.registrationNumber
                    : 'Non renseigné',
                isBoldValue: false,
              ),
              const SizedBox(height: 16),

              _buildInfoRow(
                label: 'Effectif rattaché',
                value: 'Aucun collaborateur',
                isBoldValue: true,
              ),
              const SizedBox(height: 16),

              _buildInfoRow(
                label: 'Créé le',
                value: DateFormat('dd/MM/yyyy').format(est.createdAt),
                isBoldValue: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Card 2: Adresse de l'établissement (SANS LA CARTE) ──────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
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
                  const Text(
                    'Adresse de l\'établissement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Modifier l\'adresse',
                    onPressed: () {
                      AddEstablishmentDialog.show(
                        context,
                        enterpriseId: widget.enterpriseId,
                        establishmentToEdit: est,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildInfoRow(
                label: 'Adresse',
                value: est.address.isNotEmpty ? est.address : 'Non renseignée',
                isBoldValue: true,
              ),
              if (est.addressSuite.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInfoRow(
                  label: 'Adresse (suite)',
                  value: est.addressSuite,
                  isBoldValue: false,
                ),
              ],
              const SizedBox(height: 16),

              _buildInfoRow(
                label: 'Code postal',
                value: est.postalCode.isNotEmpty ? est.postalCode : 'Non renseigné',
                isBoldValue: true,
              ),
              const SizedBox(height: 16),

              _buildInfoRow(
                label: 'Ville',
                value: est.city.isNotEmpty ? est.city : 'Non renseignée',
                isBoldValue: true,
              ),
              if (est.country.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInfoRow(
                  label: 'Pays',
                  value: est.country,
                  isBoldValue: false,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tab 2: Collaborateurs ────────────────────────────────────────────────
  Widget _buildCollaboratorsTab(BuildContext context, HrEstablishment est) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 42,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun collaborateur rattaché',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les collaborateurs associés à cet établissement s\'afficheront ici.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Règles de pointage ────────────────────────────────────────────
  Widget _buildAttendanceRulesTab(BuildContext context, HrEstablishment est) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres & Règles de pointage',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            label: 'Mode de pointage',
            value: 'Application mobile & Web',
            isBoldValue: true,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            label: 'Tolérance de retard',
            value: '15 minutes',
            isBoldValue: false,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            label: 'Validation automatique des présences',
            value: 'Activée',
            isBoldValue: true,
          ),
        ],
      ),
    );
  }

  // ─── Clean Key-Value Row matching Screenshot ──────────────────────────────
  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool isBoldValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              color: const Color(0xFF0F172A),
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, HrEstablishment est) {
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'établissement ?'),
        content: Text(
          'Voulez-vous vraiment supprimer "${est.name}" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // pop dialog
              await HrEstablishmentService.instance
                  .deleteEstablishment(widget.enterpriseId, est.id);
              if (mounted) {
                nav.pop(); // pop detail screen
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
