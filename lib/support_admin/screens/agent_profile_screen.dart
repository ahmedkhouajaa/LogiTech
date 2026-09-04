import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgentProfileScreen extends StatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  final TextEditingController _signatureController = TextEditingController(
    text: 'Cordialement,\nÉquipe Support LogiTech Pro • assistance@logitech.tn',
  );

  String _selectedTheme = 'light';
  String _selectedLanguage = 'fr';

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = FirebaseAuth.instance.currentUser;
    final agentEmail = agent?.email ?? 'support@logitech.tn';
    final agentName = agent?.displayName ?? agentEmail.split('@').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mon Profil & Préférences Système', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Gérez vos paramètres d\'agent, signature de message et langue d\'affichage.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 24),

            // Profile Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(agentName.isNotEmpty ? agentName[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agentName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(agentEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('SUPERADMIN / LEAD SUPPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Signature Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Signature Automatique des Réponses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Cette signature est insérée automatiquement à la fin de vos réponses au client.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _signatureController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signature enregistrée avec succès !'), backgroundColor: Color(0xFF10B981)),
                        );
                      },
                      child: const Text('Enregistrer la signature'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Theme & Language
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Langue & Apparence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Langue de l\'interface : ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          items: const [
                            DropdownMenuItem(value: 'fr', child: Text('Français (Par défaut)')),
                            DropdownMenuItem(value: 'ar', child: Text('العربية (Arabic)')),
                            DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (v) => setState(() => _selectedLanguage = v!),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Text('Thème de la console : ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                        DropdownButton<String>(
                          value: _selectedTheme,
                          items: const [
                            DropdownMenuItem(value: 'light', child: Text('Mode Clair (Light)')),
                            DropdownMenuItem(value: 'dark', child: Text('Mode Sombre (Dark)')),
                          ],
                          onChanged: (v) => setState(() => _selectedTheme = v!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
