import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/hr_manager.dart';
import '../services/hr_manager_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../widgets/invite_manager_dialog.dart';

class HrManagersScreen extends StatefulWidget {
  const HrManagersScreen({super.key});

  @override
  State<HrManagersScreen> createState() => _HrManagersScreenState();
}

class _HrManagersScreenState extends State<HrManagersScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 750;

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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: isMobile ? 18 : 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header: Title, Subtitle & Inviter Button (Image 1) ─
                    _buildHeader(context, enterpriseId, isMobile),
                    const SizedBox(height: 24),

                    // ─── Table Card (Image 1) ────────────────────────────────
                    _buildManagersTable(
                      context,
                      enterpriseId,
                      managers,
                      currentUserEmail,
                      isMobile,
                    ),
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
  Widget _buildHeader(BuildContext context, String enterpriseId, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gestionnaires',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              _buildInviteButton(context, enterpriseId, isCompact: true),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Personnes qui administrent la plateforme',
            style: TextStyle(
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestionnaires',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Personnes qui administrent la plateforme',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        _buildInviteButton(context, enterpriseId),
      ],
    );
  }

  // ─── Invite Button (+ Inviter un gestionnaire) ─────────────────────────────
  Widget _buildInviteButton(BuildContext context, String enterpriseId, {bool isCompact = false}) {
    return ElevatedButton.icon(
      onPressed: () => InviteManagerDialog.show(context, enterpriseId: enterpriseId),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 20,
          vertical: isCompact ? 10 : 12,
        ),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        isCompact ? 'Inviter' : 'Inviter un gestionnaire',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
        ),
      ),
    );
  }

  // ─── Managers Table matching Image 1 ───────────────────────────────────────
  Widget _buildManagersTable(
    BuildContext context,
    String enterpriseId,
    List<HrManager> managers,
    String currentUserEmail,
    bool isMobile,
  ) {
    if (isMobile) {
      return Column(
        children: managers.map((mgr) {
          final isMe = mgr.isOwner ||
              (currentUserEmail.isNotEmpty &&
                  mgr.email.toLowerCase().trim() == currentUserEmail);
          return _buildMobileManagerCard(context, enterpriseId, mgr, isMe);
        }).toList(),
      );
    }

    return Container(
      width: double.infinity,
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
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'NOM',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'EMAIL',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'RÔLES',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'ACTIONS',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          if (managers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Aucun gestionnaire enregistré',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
                  idx == 0; // First manager is current user / owner

              return _buildManagerRow(context, enterpriseId, mgr, isMe, idx < managers.length - 1);
            }),
        ],
      ),
    );
  }

  // ─── Table Row matching Image 1 ───────────────────────────────────────────
  Widget _buildManagerRow(
    BuildContext context,
    String enterpriseId,
    HrManager mgr,
    bool isMe,
    bool hasDivider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: hasDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1))
            : null,
      ),
      child: Row(
        children: [
          // NOM + Vous badge
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    mgr.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Vous',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // EMAIL
          Expanded(
            flex: 4,
            child: Text(
              mgr.email,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // RÔLES pills
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: mgr.roles.map((role) => _buildRoleBadge(role)).toList(),
            ),
          ),

          // ACTIONS
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Modifier',
                  onPressed: () {
                    InviteManagerDialog.show(
                      context,
                      enterpriseId: enterpriseId,
                      managerToEdit: mgr,
                    );
                  },
                ),
                if (!isMe)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Supprimer',
                    onPressed: () => _confirmDelete(context, enterpriseId, mgr),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Role Badges (Administrateur / Manager / RH / Comptable) ───────────────
  Widget _buildRoleBadge(String role) {
    Color bgColor;
    Color textColor;

    switch (role.toLowerCase()) {
      case 'administrateur':
      case 'admin':
        bgColor = const Color(0xFFDCFCE7); // Light green
        textColor = const Color(0xFF15803D); // Dark green
        break;
      case 'manager':
        bgColor = const Color(0xFFEDE9FE); // Light purple/lavender
        textColor = const Color(0xFF6D28D9); // Dark purple
        break;
      case 'responsable rh':
      case 'rh':
        bgColor = const Color(0xFFFFEDD5); // Light orange
        textColor = const Color(0xFFC2410C); // Dark orange
        break;
      case 'comptable':
        bgColor = const Color(0xFFE0F2FE); // Light sky blue
        textColor = const Color(0xFF0369A1); // Dark sky blue
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ─── Mobile Card View ─────────────────────────────────────────────────────
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
