import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/enterprise/enterprise_bloc.dart';
import '../../models/hr_manager.dart';
import '../../services/hr_manager_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';
import '../../widgets/invite_manager_dialog.dart';

class MobileHrManagersScreen extends StatefulWidget {
  const MobileHrManagersScreen({super.key});

  @override
  State<MobileHrManagersScreen> createState() => _MobileHrManagersScreenState();
}

class _MobileHrManagersScreenState extends State<MobileHrManagersScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnterpriseBloc, EnterpriseState>(
      builder: (context, entState) {
        final enterpriseId = entState is EnterpriseLoaded
            ? (entState.currentEnterpriseId ?? '')
            : '';

        final currentUserEmail =
            FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: StreamBuilder<List<HrManager>>(
            stream: HrManagerService.instance.streamManagers(enterpriseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final managers = snapshot.data ?? [];

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
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestionnaires',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Personnes qui administrent la plateforme',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => InviteManagerDialog.show(
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
                            'Inviter',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (managers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'Aucun gestionnaire enregistré',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                          ),
                        ),
                      )
                    else
                      ...managers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final mgr = entry.value;
                        final isMe = mgr.isOwner ||
                            (currentUserEmail.isNotEmpty &&
                                mgr.email.toLowerCase().trim() == currentUserEmail) ||
                            idx == 0;
                        return _buildMobileManagerCard(context, enterpriseId, mgr, isMe);
                      }),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            onPressed: () => InviteManagerDialog.show(
              context,
              enterpriseId: enterpriseId,
            ),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  Widget _buildMobileManagerCard(
    BuildContext context,
    String enterpriseId,
    HrManager mgr,
    bool isMe,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Row(
                  children: [
                    Text(
                      mgr.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Vous',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  InviteManagerDialog.show(
                    context,
                    enterpriseId: enterpriseId,
                    managerToEdit: mgr,
                  );
                },
              ),
              if (!isMe) ...[
                const SizedBox(width: 14),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context, enterpriseId, mgr),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mgr.email,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          if (mgr.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              mgr.phone,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: mgr.roles.map((role) => _buildRoleBadge(role)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bgColor;
    Color textColor;

    switch (role.toLowerCase()) {
      case 'administrateur':
      case 'admin':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        break;
      case 'manager':
        bgColor = const Color(0xFFEDE9FE);
        textColor = const Color(0xFF6D28D9);
        break;
      case 'responsable rh':
      case 'rh':
        bgColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFFC2410C);
        break;
      case 'comptable':
        bgColor = const Color(0xFFE0F2FE);
        textColor = const Color(0xFF0369A1);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String enterpriseId, HrManager mgr) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'Supprimer le gestionnaire',
      onConfirmed: () async {
        await HrManagerService.instance.deleteManager(enterpriseId, mgr.id);
      },
    );
  }
}
