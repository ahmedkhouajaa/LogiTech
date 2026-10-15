import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/enterprise/enterprise_bloc.dart';
import '../../models/hr_establishment.dart';
import '../../services/hr_establishment_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';
import '../../widgets/add_establishment_dialog.dart';
import '../../screens/hr_establishment_detail_screen.dart';

class MobileHrEstablishmentsScreen extends StatefulWidget {
  const MobileHrEstablishmentsScreen({super.key});

  @override
  State<MobileHrEstablishmentsScreen> createState() => _MobileHrEstablishmentsScreenState();
}

class _MobileHrEstablishmentsScreenState extends State<MobileHrEstablishmentsScreen> {
  @override
  Widget build(BuildContext context) {
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

              final totalLabel = establishments.length == 1
                  ? '1 établissement'
                  : '${establishments.length} établissements';
              final activeLabel =
                  activeCount == 1 ? '1 actif' : '$activeCount actifs';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top header row matching image 1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Établissements',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalLabel · $activeLabel',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => AddEstablishmentDialog.show(
                            context,
                            enterpriseId: enterpriseId,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Ajouter',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Empty State or List
                    if (establishments.isEmpty)
                      _buildMobileEmptyCard(context, enterpriseId)
                    else
                      ...establishments.map(
                        (est) => _buildMobileEstablishmentCard(
                          context,
                          enterpriseId,
                          est,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            onPressed: () => AddEstablishmentDialog.show(
              context,
              enterpriseId: enterpriseId,
            ),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  Widget _buildMobileEmptyCard(BuildContext context, String enterpriseId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.domain_outlined,
              size: 42,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucun établissement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ajoutez votre premier établissement.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEstablishmentCard(
    BuildContext context,
    String enterpriseId,
    HrEstablishment est,
  ) {
    final fullAddress = [
      if (est.address.isNotEmpty) est.address,
      if (est.addressSuite.isNotEmpty) est.addressSuite,
      if (est.postalCode.isNotEmpty || est.city.isNotEmpty)
        '${est.postalCode} ${est.city}'.trim(),
    ].join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      est.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (est.registrationNumber.isNotEmpty)
                      Text(
                        est.registrationNumber,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: est.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  est.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: est.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          if (fullAddress.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fullAddress,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => AddEstablishmentDialog.show(
                  context,
                  enterpriseId: enterpriseId,
                  establishmentToEdit: est,
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
