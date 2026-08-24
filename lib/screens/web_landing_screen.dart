import 'package:flutter/material.dart';
import '../utils/file_download_helper.dart';

/// Professional Web Landing Page in Finco style.
/// Color Palette:
/// - Background: #F8F9FA (light gray) & #FFFFFF (white sections)
/// - Primary: #1A56DB (Finco Blue)
/// - Primary Light: #DBEAFE (badges/tags)
/// - Text Primary: #1A1A2E
/// - Text Secondary: #4A5568
/// - Borders: #E2E8F0
/// - Alternate Sections: #F1F5F9 / Dark Accent: #0F172A
/// Strictly Web-only (`kIsWeb`).
class WebLandingScreen extends StatefulWidget {
  final VoidCallback onLoginRequested;
  final VoidCallback onSignUpRequested;

  const WebLandingScreen({
    super.key,
    required this.onLoginRequested,
    required this.onSignUpRequested,
  });

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _benefitsKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _sectorsKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  int _selectedSectorIndex = 0;
  bool _isAnnualBilling = true;
  final Set<int> _expandedFaqIndices = {0};

  // ─── Finco Style Color Palette ─────────────────────────────────────────
  static const Color _bg = Color(0xFFF8F9FA); // Light gray background
  static const Color _cardBg = Color(0xFFFFFFFF); // Pure white sections
  static const Color _bgAlt = Color(0xFFF1F5F9); // Alternate section
  static const Color _bgDark = Color(0xFF0F172A); // Dark navy for contrast sections
  static const Color _primary = Color(0xFF1A56DB); // Finco Blue
  static const Color _primaryLight = Color(0xFFDBEAFE); // Primary light (badges)
  static const Color _textPrimary = Color(0xFF1A1A2E); // Deep text
  static const Color _textSecondary = Color(0xFF4A5568); // Muted text
  static const Color _border = Color(0xFFE2E8F0); // Light borders

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _triggerDesktopDownload(BuildContext context) async {
    await FileDownloadHelper.downloadUrl('downloads/logitechpro.zip', 'logitechpro.zip');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Téléchargement de logitechpro.zip lancé !',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;
    final isTablet = width >= 800 && width < 1150;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const SizedBox(height: 72), // Header spacing
                _buildHeroSection(context, isMobile, isTablet),
                _buildTrustIndicatorsBar(context, isMobile),
                _buildDocumentTypesRow(context, isMobile),
                _buildKeyBenefitsSection(context, isMobile, isTablet),
                _buildWorkflowPipelineSection(context, isMobile, isTablet),
                _buildTargetSectorsSection(context, isMobile, isTablet),
                _buildFeaturesGridSection(context, isMobile, isTablet),
                _buildPricingSection(context, isMobile, isTablet),
                _buildFaqSection(context, isMobile),
                _buildFinalCtaBanner(context, isMobile),
                const SizedBox(height: 60), // Bottom padding
              ],
            ),
          ),

          // Top Navbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildNavbar(context, isMobile),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. NAVBAR (Brand logo/name hidden for now)
  // =========================================================================
  Widget _buildNavbar(BuildContext context, bool isMobile) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.96),
        border: const Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo/Name hidden for now
          const SizedBox.shrink(),

          // Nav links (Desktop only)
          if (!isMobile)
            Row(
              children: [
                _navLink('Avantages', () => _scrollToKey(_benefitsKey)),
                _navLink('Secteurs', () => _scrollToKey(_sectorsKey)),
                _navLink('Fonctionnalités', () => _scrollToKey(_featuresKey)),
                _navLink('Tarifs', () => _scrollToKey(_pricingKey)),
                _navLink('FAQ', () => _scrollToKey(_faqKey)),
              ],
            ),

          // Action Buttons
          Row(
            children: [
              TextButton(
                onPressed: widget.onLoginRequested,
                style: TextButton.styleFrom(
                  foregroundColor: _textPrimary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: const Text('Se connecter'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onSignUpRequested,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  isMobile ? 'Essayer' : 'Essayer gratuitement',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navLink(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: _textSecondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        child: Text(title),
      ),
    );
  }

  // =========================================================================
  // 2. HERO SECTION (With Télécharger Desktop CTA & Note)
  // =========================================================================
  Widget _buildHeroSection(BuildContext context, bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: isMobile ? 40 : 60,
      ),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Main Headline (Editorial bold with Finco blue accent)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: _textPrimary,
                fontSize: isMobile ? 36 : (isTablet ? 52 : 62),
                height: 1.12,
                letterSpacing: -1.2,
                fontFamily: 'Inter',
              ),
              children: const [
                TextSpan(
                  text: 'Probablement\n',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: 'votre\n',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: 'dernier logiciel de gestion.',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sub-paragraph with bold/italic emphasis
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 17,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
                children: [
                  TextSpan(text: 'Une reconception moderne du '),
                  TextSpan(
                    text: 'logiciel d\'ERP & de facturation',
                    style: TextStyle(fontStyle: FontStyle.italic, color: _textPrimary),
                  ),
                  TextSpan(text: ', avec une architecture '),
                  TextSpan(
                    text: '100% hors-ligne',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _primary),
                  ),
                  TextSpan(text: ' et une '),
                  TextSpan(
                    text: 'synchronisation cloud automatique',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _primary),
                  ),
                  TextSpan(text: ', conçu pour offrir une gestion commerciale '),
                  TextSpan(
                    text: 'simple, fluide',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' et '),
                  TextSpan(
                    text: 'sécurisée',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),

          // CTAs (Primary Blue + Télécharger Desktop + Outline Se connecter)
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Créer un compte gratuit
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onSignUpRequested,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Créer un compte gratuit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),

              // 2. Télécharger Desktop (ZIP Windows)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _triggerDesktopDownload(context),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Télécharger Desktop',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),

              // 3. Se connecter
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: widget.onLoginRequested,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _border, width: 1.5),
                    backgroundColor: _cardBg,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Small note below the buttons
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.desktop_windows_rounded, size: 14, color: _textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Disponible pour Windows • Version 1.0.0 (64-bit)',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. TRUST INDICATORS BAR (White surface on #F8F9FA)
  // =========================================================================
  Widget _buildTrustIndicatorsBar(BuildContext context, bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: 16),
      constraints: const BoxConstraints(maxWidth: 1100),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 36,
        runSpacing: 20,
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _trustMetricItem('100%', 'Offline-First', 'Fonctionne sans connexion'),
          _divider(),
          _trustMetricItem('0 DT', 'Démarrage', 'Version gratuite sans carte'),
          _divider(),
          _trustMetricItem('∞', 'Tout Illimité', 'Sociétés, devis, factures'),
          _divider(),
          _trustMetricItem('4 en 1', 'Multi-Plateforme', 'Windows • Web • Android • iOS'),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: _border,
    );
  }

  Widget _trustMetricItem(String number, String label, String subtext) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: _primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtext,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. DOCUMENT TYPES ROW (Badges in #DBEAFE with #1A56DB text)
  // =========================================================================
  Widget _buildDocumentTypesRow(BuildContext context, bool isMobile) {
    final types = [
      'Devis',
      'Commandes Clients',
      'Bons de Livraison',
      'Factures A4',
      'Avoirs & Retours',
      'Commandes Fournisseurs',
      'Bons de Réception',
      'Chèques & Traites',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        children: [
          const Text(
            'CYCLE COMMERCIAL COMPLET INTÉGRÉ',
            style: TextStyle(
              color: _primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: types.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  t,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. KEY BENEFITS SECTION (White cards on #F1F5F9)
  // =========================================================================
  Widget _buildKeyBenefitsSection(BuildContext context, bool isMobile, bool isTablet) {
    return Container(
      key: _benefitsKey,
      color: _bgAlt, // Alternate section background
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 56,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AVANTAGES FONDAMENTAUX',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'L\'essentiel d\'un outil de travail bien pensé.',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              // 6 Benefits Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: isMobile ? 1.5 : (isTablet ? 1.35 : 1.3),
                    children: [
                      _minimalBenefitCard(
                        '100% Hors-Ligne',
                        'Travaillez sans interruption. Les devis, factures et stocks sont édités localement et synchronisés automatiquement dès le retour du réseau.',
                        Icons.cloud_off_rounded,
                      ),
                      _minimalBenefitCard(
                        '4 en 1 Multi-Plateforme',
                        'Une seule solution sur PC Windows au bureau, sur smartphone/tablette Android & iOS sur le terrain et sur navigateur Web.',
                        Icons.devices_rounded,
                      ),
                      _minimalBenefitCard(
                        'Cycle 1-Clic',
                        'Conversion instantanée sans ressaisie : Devis → Bon de Commande → Bon de Livraison → Facture → Règlement.',
                        Icons.bolt_rounded,
                      ),
                      _minimalBenefitCard(
                        'Tout en Illimité',
                        'Créez autant de sociétés, d\'utilisateurs, de factures, de devis et d\'articles que vous le souhaitez sans surcoût.',
                        Icons.all_inclusive_rounded,
                      ),
                      _minimalBenefitCard(
                        'Éditeur A4 Sur-Mesure',
                        'Personnalisez vos factures en direct : logo, couleurs de votre entreprise, signature, cachet et mentions légales.',
                        Icons.design_services_rounded,
                      ),
                      _minimalBenefitCard(
                        'Conformité Fiscale & TEJ',
                        'Génération de QR Code fiscal, conformité TTN, retenues à la source (RS vente & achat) et exports certifiés XML TEJ.',
                        Icons.verified_user_rounded,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _minimalBenefitCard(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. WORKFLOW PIPELINE SECTION
  // =========================================================================
  Widget _buildWorkflowPipelineSection(BuildContext context, bool isMobile, bool isTablet) {
    final steps = [
      {'n': '01', 'title': 'Devis', 'desc': 'Création en 30 secondes'},
      {'n': '02', 'title': 'Commande', 'desc': 'Validation sans ressaisie'},
      {'n': '03', 'title': 'Livraison', 'desc': 'Sortie automatique de stock'},
      {'n': '04', 'title': 'Facture', 'desc': 'QR Code fiscal & conformité'},
      {'n': '05', 'title': 'Règlement', 'desc': 'Suivi des caisses & banques'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 48,
      ),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'CYCLE COMMERCIAL 1-CLIC',
              style: TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Un flux de facturation continu et sans friction.',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),

          if (isMobile)
            Column(
              children: steps.map((s) => _pipelineCard(s['n']!, s['title']!, s['desc']!)).toList(),
            )
          else
            Row(
              children: steps.map((s) => Expanded(child: _pipelineCard(s['n']!, s['title']!, s['desc']!))).toList(),
            ),
        ],
      ),
    );
  }

  Widget _pipelineCard(String number, String title, String desc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              color: _primary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. TARGET SECTORS SECTION (Finco Dark Section Style as in the image!)
  // =========================================================================
  Widget _buildTargetSectorsSection(BuildContext context, bool isMobile, bool isTablet) {
    final sectors = [
      {
        'title': 'Commerce & Grossistes',
        'desc': 'Gestion des stocks multi-entrepôts, codes-barres, tarifs de gros et détail, et suivi des créances clients.',
        'points': ['Multi-dépôts & transferts', 'Codes-barres & inventaires', 'Suivi des impayés'],
      },
      {
        'title': 'Bureautique & Services IT',
        'desc': 'Facturation de prestations, contrats de maintenance récurrents, gestion multi-devises et devis détaillés.',
        'points': ['Multi-devises (DZD, EUR, USD)', 'Devis détaillés avec acomptes', 'Export TEJ conforme'],
      },
      {
        'title': 'Services, BTP & Artisans',
        'desc': 'Devis et bons d\'intervention créés directement sur le terrain sur smartphone Android & iOS en mode 100% hors-ligne.',
        'points': ['Fonctionne sans Internet', 'Signature client sur écran', 'Conversion en facture 1-clic'],
      },
      {
        'title': 'Industrie & Ateliers',
        'desc': 'Suivi des matières premières, commandes d\'achat fournisseurs et valorisation du coût moyen pondéré (CMP).',
        'points': ['Bons de réception & retours', 'Alertes de seuils critiques', 'Valorisation CMP'],
      },
    ];

    return Container(
      key: _sectorsKey,
      color: _bgDark, // Deep navy background like Finco reference
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 60,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill tag matching image: "Domaines d'activités"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primary.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Domaines d\'activités',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Heading matching image: "Pour tous les secteurs d'activité"
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    fontFamily: 'Inter',
                  ),
                  children: [
                    TextSpan(text: 'Pour tous les '),
                    TextSpan(
                      text: 'secteurs d\'activité',
                      style: TextStyle(color: Color(0xFF60A5FA)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Sector selector buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(sectors.length, (idx) {
                    final isSel = _selectedSectorIndex == idx;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedSectorIndex = idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? _primary : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? _primary : const Color(0xFF334155),
                            ),
                          ),
                          child: Text(
                            sectors[idx]['title'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Active Sector Details Card on dark
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectors[_selectedSectorIndex]['title'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sectors[_selectedSectorIndex]['desc'] as String,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: (sectors[_selectedSectorIndex]['points'] as List<String>).map((p) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF60A5FA), size: 16),
                            const SizedBox(width: 8),
                            Text(p, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 8. FEATURES GRID SECTION
  // =========================================================================
  Widget _buildFeaturesGridSection(BuildContext context, bool isMobile, bool isTablet) {
    final modules = [
      {
        'title': 'Ventes & Facturation',
        'desc': 'Devis, BL avec reliquats, Factures QR Code fiscal, Avoirs et Bons de retour.',
      },
      {
        'title': 'Achats & Fournisseurs',
        'desc': 'Commandes d\'achat, Réceptions avec contrôle des quantités, Factures d\'achat.',
      },
      {
        'title': 'Stock Multi-Entrepôts',
        'desc': 'Mouvements d\'entrées/sorties, transferts inter-dépôts, inventaires et alertes seuil.',
      },
      {
        'title': 'Trésorerie & Chèques',
        'desc': 'Comptes bancaires, caisses, échéancier Chèques & Traites et Retenue à la source (RS).',
      },
      {
        'title': 'Multi-Sociétés',
        'desc': 'Entreprises illimitées sous le même compte avec basculement en 1 clic.',
      },
      {
        'title': 'Permissions Équipe',
        'desc': 'Contrôle d\'accès granulaire par rôle (Administrateur, Commercial, Magasinier).',
      },
    ];

    return Container(
      key: _featuresKey,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 56,
      ),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'MODULES & FONCTIONNALITÉS',
              style: TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Une couverture fonctionnelle sans compromis.',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final cols = isMobile ? 1 : (isTablet ? 2 : 3);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isMobile ? 2.2 : 1.6,
                children: modules.map((m) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check, color: _primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m['title']!,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            m['desc']!,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 9. PRICING SECTION (Updated to 49 DT Annual / 59 DT Monthly)
  // =========================================================================
  Widget _buildPricingSection(BuildContext context, bool isMobile, bool isTablet) {
    return Container(
      key: _pricingKey,
      color: _bgAlt,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 56,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TARIFS TRANSPARENTS',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Une tarification claire et sans engagement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Billing Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pricingToggleBtn('Facturation mensuelle', !_isAnnualBilling, () {
                      setState(() => _isAnnualBilling = false);
                    }),
                    _pricingToggleBtn('Facturation annuelle (-20%)', _isAnnualBilling, () {
                      setState(() => _isAnnualBilling = true);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (isMobile)
                Column(
                  children: [
                    _pricingCard(
                      title: 'Pack Démarrage',
                      price: '0 DT',
                      sub: 'Gratuit pour toujours',
                      features: [
                        'Mode Hors-Ligne 100% actif',
                        'Devis, Factures & BL illimités',
                        'Catalogue clients & articles',
                        'Export PDF & QR Code fiscal',
                      ],
                      isPro: false,
                    ),
                    const SizedBox(height: 16),
                    _pricingCard(
                      title: 'Pack Professionnel',
                      price: _isAnnualBilling ? '49 DT' : '59 DT',
                      sub: 'par mois sans engagement',
                      features: [
                        'Tout du pack Démarrage',
                        'Entreprises illimitées & collaborateurs',
                        'Stock multi-entrepôts & inventaires',
                        'Achats & fournisseurs complets',
                        'Trésorerie, Chèques & Traites',
                        'Éditeur A4 sur-mesure & Export TEJ',
                      ],
                      isPro: true,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _pricingCard(
                        title: 'Pack Démarrage',
                        price: '0 DT',
                        sub: 'Gratuit pour toujours',
                        features: [
                          'Mode Hors-Ligne 100% actif',
                          'Devis, Factures & BL illimités',
                          'Catalogue clients & articles',
                          'Export PDF & QR Code fiscal',
                        ],
                        isPro: false,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _pricingCard(
                        title: 'Pack Professionnel',
                        price: _isAnnualBilling ? '49 DT' : '59 DT',
                        sub: 'par mois sans engagement',
                        features: [
                          'Tout du pack Démarrage',
                          'Entreprises illimitées & collaborateurs',
                          'Stock multi-entrepôts & inventaires',
                          'Achats & fournisseurs complets',
                          'Trésorerie, Chèques & Traites',
                          'Éditeur A4 sur-mesure & Export TEJ',
                        ],
                        isPro: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pricingToggleBtn(String label, bool isSel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : _textSecondary,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _pricingCard({
    required String title,
    required String price,
    required String sub,
    required List<String> features,
    required bool isPro,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPro ? _primary : _border, width: isPro ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('RECOMMANDÉ', style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: const TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Text(sub, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: _border),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check, color: _primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onSignUpRequested,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPro ? _primary : _cardBg,
                foregroundColor: isPro ? Colors.white : _textPrimary,
                side: isPro ? null : const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: Text(
                isPro ? 'Commencer l\'essai' : 'Démarrer gratuitement',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 10. FAQ SECTION
  // =========================================================================
  Widget _buildFaqSection(BuildContext context, bool isMobile) {
    final faqs = [
      {
        'q': 'Comment fonctionne le mode hors-ligne sans connexion ?',
        'a': 'Toutes les créations et modifications de devis, factures ou mouvements de stock sont stockées immédiatement sur votre appareil. Dès que la connexion est rétablie, l\'application se synchronise automatiquement avec le cloud sans aucune perte de données.',
      },
      {
        'q': 'Puis-je gérer plusieurs entreprises avec un seul compte ?',
        'a': 'Oui. La gestion multi-sociétés est native : vous pouvez créer et basculer entre plusieurs entreprises en 1 clic avec des données strictement cloisonnées.',
      },
      {
        'q': 'L\'application est-elle conforme aux normes fiscales et au format TEJ ?',
        'a': 'Oui. La solution intègre la génération automatique des QR Codes fiscaux, la conformité TTN, les retenues à la source (RS vente & achat) et l\'export XML certifié pour la plateforme TEJ.',
      },
      {
        'q': 'Puis-je utiliser l\'application sur Windows, Android et iOS ?',
        'a': 'Oui. L\'application fonctionne sur PC Windows (bureau), sur navigateur Web, et sur smartphones et tablettes Android et iOS.',
      },
    ];

    return Container(
      key: _faqKey,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 56,
      ),
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'QUESTIONS FRÉQUENTES',
              style: TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tout ce que vous devez savoir.',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),

          ...List.generate(faqs.length, (idx) {
            final faq = faqs[idx];
            final isOpen = _expandedFaqIndices.contains(idx);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (isOpen) {
                      _expandedFaqIndices.remove(idx);
                    } else {
                      _expandedFaqIndices.add(idx);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              faq['q']!,
                              style: TextStyle(
                                color: isOpen ? _primary : _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            isOpen ? Icons.remove : Icons.add,
                            color: isOpen ? _primary : _textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                      if (isOpen) ...[
                        const SizedBox(height: 10),
                        const Divider(color: _border),
                        const SizedBox(height: 6),
                        Text(
                          faq['a']!,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // 11. FINAL CTA BANNER (Exact Style from Finco Reference Image)
  // =========================================================================
  Widget _buildFinalCtaBanner(BuildContext context, bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 40,
      ),
      constraints: const BoxConstraints(maxWidth: 1100),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: _bgDark, // Deep navy banner matching Finco reference image
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Text matching reference image
          const Text(
            'Rejoignez des centaines d\'entreprises qui ont transformé leur gestion',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 24),
          // White button matching reference image: "Créer un compte gratuit →"
          ElevatedButton.icon(
            onPressed: widget.onSignUpRequested,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Créer un compte gratuit',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _bgDark,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
