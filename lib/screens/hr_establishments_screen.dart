import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/hr_establishment.dart';
import '../services/hr_establishment_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../widgets/add_establishment_dialog.dart';
import 'hr_establishment_detail_screen.dart';

class HrEstablishmentsScreen extends StatefulWidget {
  const HrEstablishmentsScreen({super.key});

  @override
  State<HrEstablishmentsScreen> createState() => _HrEstablishmentsScreenState();
}

class _HrEstablishmentsScreenState extends State<HrEstablishmentsScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return BlocBuilder<EnterpriseBloc, EnterpriseState>(
      builder: (context, entState) {
        final enterpriseId = entState is EnterpriseLoaded
            ? (entState.currentEnterpriseId ?? '')
            : '';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: StreamBuilder<List<HrEstablishment>>(
            stream: HrEstablishmentService.instance.streamEstablishments(enterpriseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final establishments = snapshot.data ?? [];
              final activeCount = establishments.where((e) => e.isActive).length;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: isMobile ? 18 : 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header: Title, Counter & Add Button (Image 1) ───────
                    _buildHeader(context, enterpriseId, establishments.length, activeCount, isMobile),
                    const SizedBox(height: 24),

                    // ─── Content Area: Empty State Card or List ──────────────
                    if (establishments.isEmpty)
                      _buildEmptyStateCard(context, enterpriseId)
                    else
                      _buildEstablishmentsList(context, enterpriseId, establishments, isMobile),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── Header matching Image 1 ───────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    String enterpriseId,
    int totalCount,
    int activeCount,
    bool isMobile,
  ) {
    final totalLabel = totalCount == 1 ? '1 établissement' : '$totalCount établissements';
    final activeLabel = activeCount == 1 ? '1 actif' : '$activeCount actifs';

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Établissements',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              _buildAddButton(context, enterpriseId, isCompact: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$totalLabel · $activeLabel',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Établissements',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalLabel · $activeLabel',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        _buildAddButton(context, enterpriseId),
      ],
    );
  }

  // ─── Add Button (+ Ajouter un établissement) ───────────────────────────────
  Widget _buildAddButton(BuildContext context, String enterpriseId, {bool isCompact = false}) {
    return ElevatedButton.icon(
      onPressed: () => AddEstablishmentDialog.show(context, enterpriseId: enterpriseId),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 20,
          vertical: isCompact ? 10 : 12,
        ),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        isCompact ? 'Ajouter' : 'Ajouter un établissement',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
        ),
      ),
    );
  }

  // ─── Empty State Card matching Image 1 ─────────────────────────────────────
  Widget _buildEmptyStateCard(BuildContext context, String enterpriseId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Building outline icon matching Image 1
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.domain_outlined,
              size: 46,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aucun établissement',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajoutez votre premier établissement.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Establishments List / Grid ───────────────────────────────────────────
  Widget _buildEstablishmentsList(
    BuildContext context,
    String enterpriseId,
    List<HrEstablishment> list,
    bool isMobile,
  ) {
    return Column(
      children: list.map((est) => _buildEstablishmentCard(context, enterpriseId, est, isMobile)).toList(),
    );
  }

  Widget _buildEstablishmentCard(
    BuildContext context,
    String enterpriseId,
    HrEstablishment est,
    bool isMobile,
  ) {
    final fullAddress = [
      if (est.address.isNotEmpty) est.address,
      if (est.addressSuite.isNotEmpty) est.addressSuite,
      if (est.postalCode.isNotEmpty || est.city.isNotEmpty)
        '${est.postalCode} ${est.city}'.trim(),
    ].join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HrEstablishmentDetailScreen(
                  enterpriseId: enterpriseId,
                  establishment: est,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.apartment_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Info
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: est.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          est.isActive ? 'Actif' : 'Inactif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: est.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (est.registrationNumber.isNotEmpty) ...[
                    Text(
                      'N° immatriculation : ${est.registrationNumber}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  if (fullAddress.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            fullAddress,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF64748B)),
                  tooltip: 'Modifier',
                  onPressed: () {
                    AddEstablishmentDialog.show(
                      context,
                      enterpriseId: enterpriseId,
                      establishmentToEdit: est,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    est.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    size: 26,
                    color: est.isActive ? AppColors.primary : const Color(0xFF94A3B8),
                  ),
                  tooltip: est.isActive ? 'Désactiver' : 'Activer',
                  onPressed: () async {
                    final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
                    if (!allowed) return;
                    await HrEstablishmentService.instance.toggleEstablishmentStatus(
                      enterpriseId,
                      est.id,
                      est.isActive,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFEF4444)),
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDelete(context, enterpriseId, est),
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

  void _confirmDelete(BuildContext context, String enterpriseId, HrEstablishment est) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'Supprimer l\'établissement',
      onConfirmed: () async {
        await HrEstablishmentService.instance.deleteEstablishment(enterpriseId, est.id);
      },
    );
  }
}
