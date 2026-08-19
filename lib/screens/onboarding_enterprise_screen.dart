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
        backgroundColor: AppColors.sidebarBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
              icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white70),
              label: const Text('Déconnexion', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            const SizedBox(width: 12),
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
