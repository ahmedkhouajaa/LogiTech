import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/crm_service.dart';

class MobileCrmEmailsScreen extends StatelessWidget {
  const MobileCrmEmailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: const TabBar(
          indicatorColor: Color(0xFF2563EB),
          labelColor: Color(0xFF2563EB),
          tabs: [
            Tab(text: 'Modèles Types'),
            Tab(text: 'Historique'),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([
            CrmService.instance.templatesNotifier,
            CrmService.instance.emailLogsNotifier,
          ]),
          builder: (context, _) {
            final templates = CrmService.instance.templatesNotifier.value;
            final logs = CrmService.instance.emailLogsNotifier.value;

            return TabBarView(
              children: [
                // Tab 1: Templates
                templates.isEmpty
                    ? const Center(child: Text('Aucun modèle d\'email.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: templates.length,
                        itemBuilder: (context, idx) {
                          final tpl = templates[idx];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: const Icon(Icons.bookmark_outline, color: Color(0xFF2563EB)),
                              title: Text(tpl.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: Text(tpl.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),

                // Tab 2: Logs
                logs.isEmpty
                    ? const Center(child: Text('Aucun email enregistré.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        itemBuilder: (context, idx) {
                          final l = logs[idx];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: const Icon(Icons.mail_outline_rounded, color: Color(0xFF10B981)),
                              title: Text(l.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: Text(l.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              trailing: Text(dateFmt.format(l.sentAt), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ),
                          );
                        },
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}
