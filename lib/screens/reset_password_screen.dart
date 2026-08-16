import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/error_handler.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? actionCode;
  final String? oobCode;
  final String? email;

  const ResetPasswordScreen({
    super.key,
    this.actionCode,
    this.oobCode,
    this.email,
  });

  String? get effectiveCode => actionCode ?? oobCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _isVerifyingCode = true;
  String? _resolvedEmail;
  String? _codeError;

  bool _passwordFocused = false;
  bool _confirmPasswordFocused = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Password strength evaluation
  int _passwordStrength = 0;
  String _strengthLabel = '';
  Color _strengthColor = const Color(0xFF6B7280);

  // Custom Palette Constants
  static const Color _primaryColor = Color(0xFF1A237E);
  static const Color _secondaryColor = Color(0xFF0D47A1);
  static const Color _bgColor = Color(0xFFF5F7FA);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _inputBg = Color(0xFFF3F4F6);
  static const Color _inputBorder = Color(0xFFD1D5DB);
  static const Color _dividerColor = Color(0xFFE5E7EB);
  static const Color _errorColor = Color(0xFFDC2626);
  static const Color _successColor = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _resolvedEmail = widget.email;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();

    _passwordCtrl.addListener(_evaluatePasswordStrength);

    _verifyActionCode();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _passwordCtrl.removeListener(_evaluatePasswordStrength);
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _evaluatePasswordStrength() {
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _strengthLabel = '';
        _strengthColor = _textSecondary;
      });
      return;
    }

    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password) || RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    setState(() {
      _passwordStrength = score;
      switch (score) {
        case 1:
          _strengthLabel = 'Faible';
          _strengthColor = _errorColor;
          break;
        case 2:
          _strengthLabel = 'Moyen';
          _strengthColor = const Color(0xFFD97706);
          break;
        case 3:
          _strengthLabel = 'Fort';
          _strengthColor = _primaryColor;
          break;
        case 4:
          _strengthLabel = 'Très fort';
          _strengthColor = _successColor;
          break;
        default:
          _strengthLabel = 'Trop court';
          _strengthColor = _errorColor;
      }
    });
  }

  Future<void> _verifyActionCode() async {
    final code = widget.effectiveCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _isVerifyingCode = false;
        _codeError = 'Lien de réinitialisation invalide ou manquant.';
      });
      return;
    }

    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(code);
      if (!mounted) return;
      setState(() {
        _resolvedEmail = email;
        _isVerifyingCode = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingCode = false;
        if (e.code == 'expired-action-code') {
          _codeError = 'Ce lien a expiré. Veuillez faire une nouvelle demande de réinitialisation.';
        } else if (e.code == 'invalid-action-code') {
          _codeError = 'Ce lien est invalide ou a déjà été utilisé.';
        } else {
          _codeError = 'Erreur de vérification : ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingCode = false;
        _codeError = 'Impossible de vérifier le lien de réinitialisation.';
      });
    }
  }

  Future<void> _handleConfirmReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = widget.effectiveCode;
    if (code == null || code.isEmpty) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Code de réinitialisation manquant. Veuillez recliquer sur le lien dans votre email.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: _passwordCtrl.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.code == 'weak-password') {
        ErrorHandler.showErrorSnackBar(
          context,
          'Le mot de passe est trop faible. Choisissez un mot de passe plus complexe.',
        );
      } else if (e.code == 'expired-action-code') {
        ErrorHandler.showErrorSnackBar(
          context,
          'Le lien a expiré. Veuillez demander un nouveau lien de réinitialisation.',
        );
      } else {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 24,
              vertical: 20,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isMobile ? 20 : 34),
                    child: _buildCardContent(isMobile: isMobile),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent({required bool isMobile}) {
    if (_isVerifyingCode) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LogiTech Pro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _primaryColor,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Vérification du lien...',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_codeError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LogiTech Pro',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _errorColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Lien invalide ou expiré',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _codeError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: _primaryColor),
              label: const Text(
                'Retour à la connexion',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _primaryColor),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _inputBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );
    }

    if (_isSuccess) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LogiTech Pro',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _successColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mot de passe modifié !',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Votre mot de passe a été réinitialisé avec succès.\nVous pouvez maintenant vous connecter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Se connecter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Name Header
          const Center(
            child: Text(
              'LogiTech Pro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _primaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Nouveau mot de passe',
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),

          // Subtitle with Email badge
          if (_resolvedEmail != null && _resolvedEmail!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 14, color: _textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _resolvedEmail!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Définissez votre nouveau mot de passe',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 1. Password Field
          _buildFieldHeader('Nouveau mot de passe'),
          const SizedBox(height: 4),
          Focus(
            onFocusChange: (f) => setState(() => _passwordFocused = f),
            child: TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
              style: const TextStyle(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
              decoration: _inputDecoration(
                hint: '••••••••',
                isFocused: _passwordFocused,
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 17,
                    color: _textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ),

          // Strength indicator bar
          if (_passwordCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: List.generate(4, (index) {
                      final isActive = index < _passwordStrength;
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: isActive ? _strengthColor : _dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _strengthLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _strengthColor,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? 8 : 12),

          // 2. Confirm Password Field
          _buildFieldHeader('Confirmer le mot de passe'),
          const SizedBox(height: 4),
          Focus(
            onFocusChange: (f) => setState(() => _confirmPasswordFocused = f),
            child: TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleConfirmReset(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation requise';
                if (v != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas';
                return null;
              },
              style: const TextStyle(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
              decoration: _inputDecoration(
                hint: '••••••••',
                isFocused: _confirmPasswordFocused,
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 17,
                    color: _textSecondary,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 14 : 18),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleConfirmReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer le mot de passe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Back to login
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: _primaryColor),
              label: const Text(
                'Retour à la connexion',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _textSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isFocused,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
      prefixIcon: Icon(
        prefixIcon,
        size: 17,
        color: isFocused ? _primaryColor : _textSecondary,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _errorColor, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 10, height: 0.8, color: _errorColor),
    );
  }
}
