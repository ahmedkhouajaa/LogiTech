import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/ticket_stream_service.dart';
import 'enhanced_admin_ticket_chat_screen.dart';

class AgentDashboardScreen extends StatefulWidget {
  final TicketMenuFilter menuFilter;
  final bool initialOnlyMyTickets;
  final String initialPriorityFilter;
  final String initialStatusFilter;

  const AgentDashboardScreen({
    super.key,
    this.menuFilter = TicketMenuFilter.queue,
    this.initialOnlyMyTickets = false,
    this.initialPriorityFilter = 'all',
    this.initialStatusFilter = 'all',
  });

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _statusFilter;
  late String _priorityFilter;
  late bool _onlyMyTickets;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _priorityFilter = widget.initialPriorityFilter;
    _onlyMyTickets = widget.initialOnlyMyTickets;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Real-time KPI Statistics Cards
            _buildKpiSection(),
            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            _buildSearchBarAndFilters(),
            const SizedBox(height: 12),

            // 3. Real-time Ticket Stream List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: TicketStreamService.instance.getFilteredTicketsStream(
                  menuFilter: widget.menuFilter,
                  status: _statusFilter,
                  priority: _priorityFilter,
                  onlyMyTickets: _onlyMyTickets,
                  searchQuery: _searchController.text.trim(),
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur : ${snapshot.error}'));
                  }

                  final tickets = snapshot.data ?? [];
                  if (tickets.isEmpty) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
                          SizedBox(height: 8),
                          Text(
                            'Aucun ticket ne correspond aux critères',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = tickets[index];
                      return _buildTicketCard(t);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('support_tickets').snapshots(),
      builder: (context, snapshot) {
        int open = 0;
        int myTickets = 0;
        int urgent = 0;
        int breached = 0;
        final myUid = TicketStreamService.instance.currentAgentUid;
        final now = DateTime.now();

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'open';
            final priority = data['priority'] ?? 'medium';
            final assignedUid = data['assignedAgentId'];
            final deadline = (data['slaDeadline'] as Timestamp?)?.toDate();

            if (status != 'resolved' && status != 'closed') {
              open++;
              if (assignedUid == myUid) myTickets++;
              if (priority == 'urgent' || priority == 'high') urgent++;
              if (deadline != null && now.isAfter(deadline)) breached++;
            }
          }
        }

        return Row(
          children: [
            _kpiCard(
              title: 'Total Ouverts',
              count: open,
              color: const Color(0xFF2563EB),
              icon: Icons.all_inbox_rounded,
              onTap: () {
                setState(() {
                  _statusFilter = 'open';
                  _priorityFilter = 'all';
                  _onlyMyTickets = false;
                });
              },
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'Mes Tickets',
              count: myTickets,
              color: const Color(0xFF8B5CF6),
              icon: Icons.person_rounded,
              onTap: () {
                setState(() {
                  _onlyMyTickets = true;
                  _statusFilter = 'all';
                  _priorityFilter = 'all';
                });
              },
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'Urgents (SLA)',
              count: urgent,
              color: const Color(0xFFF97316),
              icon: Icons.warning_amber_rounded,
              onTap: () {
                setState(() {
                  _priorityFilter = 'urgent';
                  _onlyMyTickets = false;
                });
              },
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'Dépassements SLA',
              count: breached,
              color: const Color(0xFFEF4444),
              icon: Icons.timer_off_rounded,
              onTap: () {
                setState(() {
                  _priorityFilter = 'urgent';
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(count.toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.1)),
                      const SizedBox(height: 2),
                      Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarAndFilters() {
    return Row(
      children: [
        // 1. Search Input
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher par sujet, client ou email...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 2. Status Segmented Filter (Pill Switch)
        Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusSegment('all', 'Tous'),
              _statusSegment('open', 'Ouverts'),
              _statusSegment('in_progress', 'En cours'),
              _statusSegment('resolved', 'Résolus'),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // 3. Priority Dropdown Filter
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _priorityFilter,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Toutes priorités')),
                DropdownMenuItem(value: 'urgent', child: Text('🔥 Urgent (1h)')),
                DropdownMenuItem(value: 'high', child: Text('⚡ Haute (4h)')),
                DropdownMenuItem(value: 'medium', child: Text('📌 Normale (24h)')),
                DropdownMenuItem(value: 'low', child: Text('☕ Basse (48h)')),
              ],
              onChanged: (v) => v != null ? setState(() => _priorityFilter = v) : null,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 4. "Mes tickets assignés" Toggle Button
        InkWell(
          onTap: () => setState(() => _onlyMyTickets = !_onlyMyTickets),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _onlyMyTickets ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _onlyMyTickets ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _onlyMyTickets ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                  size: 16,
                  color: _onlyMyTickets ? Colors.white : const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mes tickets assignés',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _onlyMyTickets ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusSegment(String key, String label) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
      case 'normal':
        return const Color(0xFF10B981);
      case 'low':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final ticketId = t['id'] ?? '';
    final subject = t['subject'] ?? 'Sans sujet';
    final status = t['status'] ?? 'open';
    final priority = t['priority'] ?? 'medium';
    final user = t['userName'] ?? 'Client';
    final tenant = t['enterpriseName'] ?? t['enterpriseId'] ?? 'Tenant';
    final updatedAt = (t['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final priorityColor = _getPriorityColor(priority);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EnhancedAdminTicketChatScreen(ticketId: ticketId, ticketData: t),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.5,
                color: priorityColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('#${ticketId.substring(0, ticketId.length >= 8 ? 8 : ticketId.length)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(width: 8),
                                _badge(status.toUpperCase(), const Color(0xFF3B82F6)),
                                const SizedBox(width: 6),
                                _badge(priority.toUpperCase(), priorityColor),
                                const Spacer(),
                                Text(DateFormat('dd MMM, HH:mm').format(updatedAt), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('$user • $tenant', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
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
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
