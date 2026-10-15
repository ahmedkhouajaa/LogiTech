import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../services/error_handler.dart';
import '../utils/constants.dart';
import '../widgets/create_enterprise_wizard.dart';

class OnboardingEnterpriseScreen extends StatelessWidget {
  const OnboardingEnterpriseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseError) {
          ErrorHandler.showRetryableErrorDialog(
            context: context,
            title: "Erreur de création d'entreprise",
            error: state.message,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LogiTech Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              ),
              label: Text(
                'Déconnexion',
                style: TextStyle(
                  color: AppColors.isDarkMode ? Colors.white70 : const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: const CreateEnterpriseWizard(
                isOnboarding: true,
                isDismissible: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
