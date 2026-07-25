import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        child: Row(
          children: [
            // Left branding panel
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Icon(Icons.business_center_rounded, color: Colors.white, size: 40),
                    ),
                    SizedBox(height: 24),
                    Text('LogiTech Pro', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('ERP · CRM · Facturation · Stock', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                    SizedBox(height: 48),
                    _buildFeatureRow(Icons.offline_bolt_rounded, 'Offline-First', 'Fonctionne sans connexion'),
                    SizedBox(height: 16),
                    _buildFeatureRow(Icons.sync_rounded, 'Synchronisation', 'Sync automatique avec le cloud'),
                    SizedBox(height: 16),
                    _buildFeatureRow(Icons.picture_as_pdf_rounded, 'PDF professionnel', 'Factures et devis imprimables'),
                  ],
                ),
              ),
            ),
            // Right login form
            Expanded(
              flex: 3,
              child: Container(
                color: AppColors.background,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bienvenue !', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          SizedBox(height: 8),
                          Text('Connectez-vous a votre espace', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                          SizedBox(height: 40),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTextField(
                                  label: 'Adresse email',
                                  hint: 'exemple@entreprise.com',
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefix: Icon(Icons.email_outlined, size: 18, color: AppColors.textTertiary),
                                  validator: (v) => v == null || v.isEmpty ? 'Email requis' : null,
                                ),
                                SizedBox(height: 20),
                                AppTextField(
                                  label: 'Mot de passe',
                                  hint: '••••••••',
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  prefix: Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textTertiary),
                                  suffix: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AppColors.textTertiary),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Mot de passe requis' : null,
                                ),
                                SizedBox(height: 32),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final loading = state is AuthLoading;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: loading ? null : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                            ),
                                            child: loading
                                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                : Text('Se connecter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        TextButton.icon(
                                          onPressed: loading ? null : _handleOfflineMode,
                                          icon: Icon(Icons.offline_bolt_rounded, size: 16),
                                          label: Text('Continuer en mode hors ligne'),
                                          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(AuthLoginRequested(_emailCtrl.text.trim(), _passwordCtrl.text));
    }
  }

  void _handleOfflineMode() {
    context.read<AuthBloc>().add(AuthOfflineModeRequested());
  }
}
