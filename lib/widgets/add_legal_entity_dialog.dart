import 'package:flutter/material.dart';
import '../models/hr_legal_entity.dart';
import '../services/connectivity_service.dart';
import '../services/hr_legal_entity_service.dart';
import '../utils/constants.dart';

class AddLegalEntityDialog extends StatefulWidget {
  final String enterpriseId;
  final ValueChanged<HrLegalEntity>? onEntityCreated;

  const AddLegalEntityDialog({
    super.key,
    required this.enterpriseId,
    this.onEntityCreated,
  });

  static Future<HrLegalEntity?> show(
    BuildContext context, {
    required String enterpriseId,
    ValueChanged<HrLegalEntity>? onEntityCreated,
  }) {
    return showDialog<HrLegalEntity>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddLegalEntityDialog(
        enterpriseId: enterpriseId,
        onEntityCreated: onEntityCreated,
      ),
    );
  }

  @override
  State<AddLegalEntityDialog> createState() => _AddLegalEntityDialogState();
}

class _AddLegalEntityDialogState extends State<AddLegalEntityDialog> {
  int _currentStep = 0;
  bool _isSaving = false;

  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  // Step 1: Identité & Siège social
  final _socialReasonCtrl = TextEditingController();
  String _selectedActivitySector = 'Technologies de l\'information & Télécoms';
  final _addressCtrl = TextEditingController();
  final _addressSuiteCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Tunis');

  // Step 2: Représentant légal
  final _legalRepNameCtrl = TextEditingController();
  String _selectedLegalRepRole = 'Gérant';

  // Step 3: CNSS & Fiscalité
  final _taxIdCtrl = TextEditingController();
  final _cnssNumberCtrl = TextEditingController();
  String _selectedVatStatus = 'Assujetti';
  String _selectedCategory = 'Personne morale';
  final _atMpRateCtrl = TextEditingController(text: '0.4 %');
  final _tfpRateCtrl = TextEditingController(text: '1.0 %');

  // Step 4: Coordonnées bancaires
  final _bankAccountNameCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bicCtrl = TextEditingController();
  String _selectedBank = AppColors.tunisianBanks.first;
  bool _transferOrderActive = true;

  final List<String> _activitySectors = [
    'Technologies de l\'information & Télécoms',
    'Commerce & Distribution',
    'Services aux entreprises / Conseil',
    'Industrie, Agroalimentaire & Fabrication',
    'BTP & Construction',
    'Santé, Pharmacie & Médical',
    'Transport, Logistique & Fret',
    'Tourisme, Hôtellerie & Restauration',
    'Banque, Finance & Assurance',
    'Éducation & Formation',
    'Autre',
  ];

  final List<String> _legalRoles = [
    'Gérant',
    'Président Directeur Général (PDG)',
    'Directeur Général (DG)',
    'Gérant associé',
    'Administrateur',
  ];

  @override
  void dispose() {
    _socialReasonCtrl.dispose();
    _addressCtrl.dispose();
    _addressSuiteCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();

    _legalRepNameCtrl.dispose();

    _taxIdCtrl.dispose();
    _cnssNumberCtrl.dispose();
    _atMpRateCtrl.dispose();
    _tfpRateCtrl.dispose();

    _bankAccountNameCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    super.dispose();
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Identité';
      case 1:
        return 'Représentant légal';
      case 2:
        return 'CNSS';
      case 3:
        return 'Coordonnées bancaires';
      default:
        return '';
    }
  }

  void _onNext() {
    if (_currentStep == 0) {
      if (!_formKeyStep0.currentState!.validate()) return;
      if (_bankAccountNameCtrl.text.trim().isEmpty) {
        _bankAccountNameCtrl.text = _socialReasonCtrl.text.trim();
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (!_formKeyStep2.currentState!.validate()) return;
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      if (!_formKeyStep3.currentState!.validate()) return;
      _submit();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);

    try {
      final suite = _addressSuiteCtrl.text.trim();
      final baseAddress = _addressCtrl.text.trim();
      final fullAddress = suite.isNotEmpty ? '$baseAddress, $suite' : baseAddress;

      final now = DateTime.now();
      final newEntity = HrLegalEntity(
        id: '',
        enterpriseId: widget.enterpriseId,
        socialReason: _socialReasonCtrl.text.trim(),
        activitySector: _selectedActivitySector,
        address: fullAddress.isNotEmpty ? fullAddress : '-',
        postalCode: _postalCodeCtrl.text.trim().isNotEmpty ? _postalCodeCtrl.text.trim() : '-',
        city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : 'Tunis',
        country: 'Tunisie',

        legalRepName: _legalRepNameCtrl.text.trim().isNotEmpty ? _legalRepNameCtrl.text.trim() : '-',
        legalRepRole: _selectedLegalRepRole,

        taxId: _taxIdCtrl.text.trim().isNotEmpty ? _taxIdCtrl.text.trim() : '-',
        cnssNumber: _cnssNumberCtrl.text.trim().isNotEmpty ? _cnssNumberCtrl.text.trim() : '-',
        vatStatus: _selectedVatStatus,
        category: _selectedCategory,
        employerAtMpRate: _atMpRateCtrl.text.trim().isNotEmpty ? _atMpRateCtrl.text.trim() : '0.4 %',
        employerTfpRate: _tfpRateCtrl.text.trim().isNotEmpty ? _tfpRateCtrl.text.trim() : '1.0 %',

        bankAccountName: _bankAccountNameCtrl.text.trim().isNotEmpty ? _bankAccountNameCtrl.text.trim() : _socialReasonCtrl.text.trim(),
        iban: _ibanCtrl.text.trim().isNotEmpty ? _ibanCtrl.text.trim() : '-',
        bankAgency: _selectedBank,
        bic: _bicCtrl.text.trim().isNotEmpty ? _bicCtrl.text.trim() : '-',
        transferOrderActive: _transferOrderActive,

        createdAt: now,
        updatedAt: now,
      );

      final created = await HrLegalEntityService.instance.createLegalEntity(newEntity);

      if (mounted) {
        final isOnline = ConnectivityService.instance.isOnline;
        if (!isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Entité juridique enregistrée hors ligne - en attente de synchronisation'),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        widget.onEntityCreated?.call(created);
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.92 : 720,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header: Back arrow & Title (Image 4) ──────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 20, top: 16, bottom: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF0F172A)),
                    onPressed: _onBack,
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ajouter une entité juridique',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _stepSubtitle(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── Stepper Progress Bar (Image 4) ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildStepperBar(),
            ),

            const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),

            // ─── Body Form ─────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildActiveStepForm(),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // ─── Footer Action Bar (Image 4 & 5) ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      _currentStep == 0 ? 'Annuler' : 'Précédent',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, // Blue button matching image 2
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _currentStep == 3 ? 'Créer l\'entité' : 'Suivant',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stepper Row ─────────────────────────────────────────────────────────
  Widget _buildStepperBar() {
    final steps = [
      {'num': '1', 'label': 'Identité'},
      {'num': '2', 'label': 'Représentant lé...'},
      {'num': '3', 'label': 'CNSS'},
      {'num': '4', 'label': 'Coordonnées ba...'},
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _buildStepCircle(i, steps[i]['num']!, steps[i]['label']!),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 1,
                color: i < _currentStep ? AppColors.primary : const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStepCircle(int index, String num, String label) {
    final isActive = index == _currentStep;
    final isDone = index < _currentStep;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: (isActive || isDone) ? AppColors.primary : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: (isActive || isDone) ? AppColors.primary : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : Text(
                    num,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? AppColors.primary
                : isDone
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  // ─── Step Form Content ───────────────────────────────────────────────────
  Widget _buildActiveStepForm() {
    switch (_currentStep) {
      case 0:
        return _buildStep0Identite();
      case 1:
        return _buildStep1Representant();
      case 2:
        return _buildStep2Cnss();
      case 3:
        return _buildStep3Banque();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Identité (Image 4 & 5)
  Widget _buildStep0Identite() {
    return Form(
      key: _formKeyStep0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Dénomination sociale *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _socialReasonCtrl,
            decoration: _inputDecoration('Ex. Medina Tech'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'La dénomination sociale est obligatoire' : null,
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Secteur d\'activité'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedActivitySector,
            decoration: _inputDecoration('Rechercher un secteur...'),
            icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF64748B)),
            isExpanded: true,
            items: _activitySectors.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedActivitySector = v);
            },
          ),
          const SizedBox(height: 22),

          _buildSectionSubheader('SIÈGE SOCIAL'),
          const SizedBox(height: 12),

          _buildFieldLabel('Adresse *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _addressCtrl,
            decoration: _inputDecoration('N° et rue'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'L\'adresse est obligatoire' : null,
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('Adresse (suite)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _addressSuiteCtrl,
            decoration: _inputDecoration('Complément d\'adresse, étage, bureau...'),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Code postal'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _postalCodeCtrl,
                      decoration: _inputDecoration('1053'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Ville *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: _inputDecoration('Tunis'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'La ville est obligatoire' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2: Représentant légal
  Widget _buildStep1Representant() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionSubheader('INFORMATIONS DU REPRÉSENTANT LÉGAL'),
          const SizedBox(height: 14),

          _buildFieldLabel('Nom & prénom du représentant légal *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _legalRepNameCtrl,
            decoration: _inputDecoration('Ex. Mohamed Ben Salah'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom du représentant est requis' : null,
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Rôle / Qualité *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedLegalRepRole,
            decoration: _inputDecoration('Sélectionner le rôle'),
            icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF64748B)),
            items: _legalRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedLegalRepRole = v);
            },
          ),
        ],
      ),
    );
  }

  // Step 3: CNSS & Fiscalité
  Widget _buildStep2Cnss() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionSubheader('ORGANISME & IDENTIFIANTS FISCAUX'),
          const SizedBox(height: 14),

          _buildFieldLabel('Matricule fiscal'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _taxIdCtrl,
            decoration: _inputDecoration('Ex. 1234567/A/M/000'),
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('N. CNSS'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _cnssNumberCtrl,
            decoration: _inputDecoration('Ex. 123456-78'),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Statut TVA'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedVatStatus,
                      decoration: _inputDecoration('Statut'),
                      items: const [
                        DropdownMenuItem(value: 'Assujetti', child: Text('Assujetti')),
                        DropdownMenuItem(value: 'Non assujetti', child: Text('Non assujetti')),
                        DropdownMenuItem(value: 'Exonéré', child: Text('Exonéré')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedVatStatus = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Catégorie juridique'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: _inputDecoration('Catégorie'),
                      items: const [
                        DropdownMenuItem(value: 'Personne morale', child: Text('Personne morale')),
                        DropdownMenuItem(value: 'Personne physique', child: Text('Personne physique')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Taux AT/MP employeur'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _atMpRateCtrl,
                      decoration: _inputDecoration('0.4 %'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Taux TFP employeur'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tfpRateCtrl,
                      decoration: _inputDecoration('1.0 %'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 4: Coordonnées bancaires
  Widget _buildStep3Banque() {
    return Form(
      key: _formKeyStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionSubheader('COORDONNÉES BANCAIRES'),
          const SizedBox(height: 14),

          _buildFieldLabel('Titulaire du compte bancaire'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _bankAccountNameCtrl,
            decoration: _inputDecoration('Ex. Nom de l\'entité'),
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('IBAN / RIB *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _ibanCtrl,
            decoration: _inputDecoration('Ex. TN59 0123 4567 8901 2345 6789'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'L\'IBAN / RIB est obligatoire' : null,
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('Banque / Agence'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedBank,
            decoration: _inputDecoration('Sélectionner la banque'),
            isExpanded: true,
            items: AppColors.tunisianBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedBank = v);
            },
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('Code BIC / SWIFT'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _bicCtrl,
            decoration: _inputDecoration('Ex. BIATNTTT'),
          ),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Activer pour les ordres de virement',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            subtitle: const Text(
              'Permet d\'émettre les fichiers de virements bancaires pour les fiches de paie.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            value: _transferOrderActive,
            activeTrackColor: AppColors.primary,
            onChanged: (v) => setState(() => _transferOrderActive = v),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

  Widget _buildSectionSubheader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: Color(0xFF94A3B8),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
