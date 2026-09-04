import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../utils/file_download_helper.dart';

class ClientExportScreen extends StatefulWidget {
  const ClientExportScreen({super.key});

  @override
  State<ClientExportScreen> createState() => _ClientExportScreenState();
}

class _ClientExportScreenState extends State<ClientExportScreen> {
  String _exportScope = 'all'; // all, upgraded, trial, banned
  bool _isExporting = false;

  // Selected Fields
  bool _includeName = true;
  bool _includeTaxId = true;
  bool _includeEmail = true;
  bool _includePhone = true;
  bool _includePlan = true;
  bool _includeStatus = true;
  bool _includeTrialEnd = true;
  bool _includeCreatedAt = true;

  Future<void> _performExport() async {
    setState(() => _isExporting = true);

    try {
      final snap = await FirebaseFirestore.instance.collection('enterprises').get();
      final docs = snap.docs;

      final filtered = docs.where((doc) {
        final data = doc.data();
        final isUp = data['isUpgraded'] == true;
        final isBanned = data['isBanned'] == true || data['status'] == 'banned' || data['status'] == 'disabled';

        if (_exportScope == 'upgraded' && !isUp) return false;
        if (_exportScope == 'trial' && isUp) return false;
        if (_exportScope == 'banned' && !isBanned) return false;
        return true;
      }).toList();

      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      final csvBuffer = StringBuffer();

      // Header Row
      final headers = <String>[];
      headers.add('ID Client');
      if (_includeName) headers.add('Nom Entreprise');
      if (_includeTaxId) headers.add('Matricule Fiscal (SIRET)');
      if (_includeEmail) headers.add('Email');
      if (_includePhone) headers.add('Telephone');
      if (_includePlan) headers.add('Formule Abonnement');
      if (_includeStatus) headers.add('Statut');
      if (_includeTrialEnd) headers.add('Date Expiration Licence');
      if (_includeCreatedAt) headers.add('Date Creation');

      csvBuffer.writeln(headers.join(','));

      // Data Rows
      for (final doc in filtered) {
        final data = doc.data();
        final row = <String>[];

        row.add(doc.id);
        if (_includeName) row.add('"${(data['name'] ?? '').toString().replaceAll('"', '""')}"');
        if (_includeTaxId) row.add('"${(data['taxNumber'] ?? '').toString().replaceAll('"', '""')}"');
        if (_includeEmail) row.add('"${(data['email'] ?? '').toString().replaceAll('"', '""')}"');
        if (_includePhone) row.add('"${(data['phone'] ?? '').toString().replaceAll('"', '""')}"');
        if (_includePlan) {
          final isUp = data['isUpgraded'] == true;
          row.add('"${(data['plan'] ?? (isUp ? 'Annuel' : 'Essai')).toString()}"');
        }
        if (_includeStatus) {
          final isBanned = data['isBanned'] == true || data['status'] == 'banned';
          final isUp = data['isUpgraded'] == true;
          row.add(isBanned ? 'Banni' : (isUp ? 'Actif' : 'Essai'));
        }
        if (_includeTrialEnd) {
          final tEnd = (data['trialEndDate'] as Timestamp?)?.toDate();
          row.add(tEnd != null ? dateFormat.format(tEnd) : 'N/A');
        }
        if (_includeCreatedAt) {
          final cAt = (data['createdAt'] as Timestamp?)?.toDate();
          row.add(cAt != null ? dateFormat.format(cAt) : 'N/A');
        }

        csvBuffer.writeln(row.join(','));
      }

      final fileName = 'export_clients_${_exportScope}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      if (!mounted) return;
      await FileDownloadHelper.saveStringFile(
        csvBuffer.toString(),
        fileName,
        mimeType: 'text/csv',
        context: context,
      );

      setState(() => _isExporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export réussi (${filtered.length} clients exportés) : $fileName'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export : ${e.toString()}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.file_download_rounded, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Export des Données Clients (Excel / CSV)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Exportez les données des entreprises pour vos analyses comptables, audits ou sauvegardes externes.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Export Scope Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Périmètre de l\'Export', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      value: 'all',
                      groupValue: _exportScope,
                      title: const Text('Tous les clients enregistrés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Exporte l\'intégralité des entreprises de la base de données', style: TextStyle(fontSize: 12)),
                      onChanged: (v) => setState(() => _exportScope = v!),
                    ),
                    RadioListTile<String>(
                      value: 'upgraded',
                      groupValue: _exportScope,
                      title: const Text('Clients abonnés uniquement (Payants)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Exporte uniquement les entreprises disposant d\'un abonnement actif (Mensuel / Annuel)', style: TextStyle(fontSize: 12)),
                      onChanged: (v) => setState(() => _exportScope = v!),
                    ),
                    RadioListTile<String>(
                      value: 'trial',
                      groupValue: _exportScope,
                      title: const Text('Clients en période d\'essai uniquement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Idéal pour les campagnes de relance commerciale et conversion', style: TextStyle(fontSize: 12)),
                      onChanged: (v) => setState(() => _exportScope = v!),
                    ),
                    RadioListTile<String>(
                      value: 'banned',
                      groupValue: _exportScope,
                      title: const Text('Clients bannis ou suspendus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Pour le contrôle administratif et juridique', style: TextStyle(fontSize: 12)),
                      onChanged: (v) => setState(() => _exportScope = v!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Select Fields Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. Champs à Inclure dans le Fichier', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _fieldCheckbox('Nom Entreprise', _includeName, (v) => setState(() => _includeName = v!)),
                        _fieldCheckbox('Matricule Fiscal (SIRET)', _includeTaxId, (v) => setState(() => _includeTaxId = v!)),
                        _fieldCheckbox('Email Contact', _includeEmail, (v) => setState(() => _includeEmail = v!)),
                        _fieldCheckbox('Téléphone', _includePhone, (v) => setState(() => _includePhone = v!)),
                        _fieldCheckbox('Formule d\'abonnement', _includePlan, (v) => setState(() => _includePlan = v!)),
                        _fieldCheckbox('Statut (Actif/Banni)', _includeStatus, (v) => setState(() => _includeStatus = v!)),
                        _fieldCheckbox('Date Expiration Licence', _includeTrialEnd, (v) => setState(() => _includeTrialEnd = v!)),
                        _fieldCheckbox('Date Création', _includeCreatedAt, (v) => setState(() => _includeCreatedAt = v!)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Trigger Export Button
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _performExport,
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.file_download_rounded, size: 20),
              label: Text(_isExporting ? 'Génération de l\'export en cours...' : 'Télécharger le fichier CSV / Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return SizedBox(
      width: 250,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
