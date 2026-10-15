import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../models/treasury_account.dart';
import '../utils/helpers.dart';

/// Representation of a single installment in a split traite schedule
class TraiteSplitItem {
  final int number;
  final String reference;
  double amount;
  DateTime maturityDate;
  bool sansEcheance;

  TraiteSplitItem({
    required this.number,
    required this.reference,
    required this.amount,
    required this.maturityDate,
    this.sansEcheance = false,
  });
}

/// Helper model for an editable row in the generated traites table
class GeneratedTraiteItem {
  final int number;
  final TextEditingController serialCtrl;
  final TextEditingController amountCtrl;
  DateTime? maturityDate;
  bool sansEcheance;

  GeneratedTraiteItem({
    required this.number,
    required this.serialCtrl,
    required this.amountCtrl,
    this.maturityDate,
    this.sansEcheance = false,
  });

  void dispose() {
    serialCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// Data returned when the traite editor validates and applies
class TraiteEditorData {
  final String documentNumber;
  final double amount;
  final String issuerName;
  final String recipientName;
  final DateTime creationDate;
  final DateTime? maturityDate;
  final bool sansEcheance;
  final String creationPlace;
  final String? clientBankAccount;
  final String? treasuryAccountId;
  final String? treasuryAccountName;
  final String printSettings;
  final String rib;
  final String bankName;
  final String notes;
  final List<TraiteSplitItem> splitItems;

  TraiteEditorData({
    required this.documentNumber,
    required this.amount,
    required this.issuerName,
    required this.recipientName,
    required this.creationDate,
    this.maturityDate,
    this.sansEcheance = false,
    this.creationPlace = 'Tunis',
    this.clientBankAccount,
    this.treasuryAccountId,
    this.treasuryAccountName,
    this.printSettings = 'Créer paramètres d\'impression',
    this.rib = '',
    this.bankName = '',
    this.notes = '',
    this.splitItems = const [],
  });
}

class TraiteEditorDialog extends StatefulWidget {
  final double initialAmount;
  final String initialNumber;
  final String initialIssuer;
  final String initialRecipient;
  final DateTime initialCreationDate;
  final DateTime? initialMaturityDate;
  final String? initialTreasuryAccountId;
  final Function(TraiteEditorData data)? onApply;

  const TraiteEditorDialog({
    super.key,
    required this.initialAmount,
    required this.initialNumber,
    required this.initialIssuer,
    this.initialRecipient = '',
    required this.initialCreationDate,
    this.initialMaturityDate,
    this.initialTreasuryAccountId,
    this.onApply,
  });

  static Future<TraiteEditorData?> show(
    BuildContext context, {
    required double initialAmount,
    required String initialNumber,
    required String initialIssuer,
    String initialRecipient = '',
    required DateTime initialCreationDate,
    DateTime? initialMaturityDate,
    String? initialTreasuryAccountId,
    Function(TraiteEditorData data)? onApply,
  }) {
    return showDialog<TraiteEditorData>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TraiteEditorDialog(
        initialAmount: initialAmount,
        initialNumber: initialNumber,
        initialIssuer: initialIssuer,
        initialRecipient: initialRecipient,
        initialCreationDate: initialCreationDate,
        initialMaturityDate: initialMaturityDate,
        initialTreasuryAccountId: initialTreasuryAccountId,
        onApply: onApply,
      ),
    );
  }

  @override
  State<TraiteEditorDialog> createState() => _TraiteEditorDialogState();
}

class _TraiteEditorDialogState extends State<TraiteEditorDialog> {
  final ScrollController _scrollController = ScrollController();

  int _selectedMode = 0; // 0: Une traite simple, 1: Plusieurs traites
  late TextEditingController _amountCtrl;
  late TextEditingController _creationPlaceCtrl;
  late TextEditingController _ribCtrl;
  late TextEditingController _notesCtrl;

  late DateTime _creationDate;
  DateTime? _maturityDate;
  bool _sansEcheance = false;

  String? _selectedClientBank;
  String? _selectedTreasuryAccountId;
  String? _selectedTreasuryAccountName;
  String _selectedPrintSettings = 'Créer paramètres d\'impression';
  bool _showAdvancedSettings = false;

  // Multi-traites (Plusieurs traites)
  int _splitCount = 3;
  String _periodicity = 'mensuelle'; // mensuelle, bimensuelle, trimestrielle

  // State flags for calculation and preview
  bool _hasCalculated = false;
  bool _hasAttemptedCalculation = false;
  List<GeneratedTraiteItem> _generatedTraites = [];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.initialAmount > 0 ? widget.initialAmount.toStringAsFixed(3) : '',
    );
    _creationPlaceCtrl = TextEditingController(text: 'Tunis');
    _ribCtrl = TextEditingController(text: '');
    _notesCtrl = TextEditingController(text: '');

    _creationDate = widget.initialCreationDate;
    final creationDay = DateTime(_creationDate.year, _creationDate.month, _creationDate.day);
    if (widget.initialMaturityDate != null &&
        !DateTime(widget.initialMaturityDate!.year, widget.initialMaturityDate!.month, widget.initialMaturityDate!.day).isBefore(creationDay)) {
      _maturityDate = widget.initialMaturityDate;
    } else {
      _maturityDate = _creationDate.add(const Duration(days: 30));
    }
    _selectedTreasuryAccountId = widget.initialTreasuryAccountId;

    // Load treasury accounts
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _amountCtrl.dispose();
    _creationPlaceCtrl.dispose();
    _ribCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _generatedTraites) {
      item.dispose();
    }
    super.dispose();
  }

  double get _currentAmount {
    return double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? widget.initialAmount;
  }

  DateTime get _creationDay => DateTime(_creationDate.year, _creationDate.month, _creationDate.day);

  bool get _isMaturityBeforeCreation {
    if (_sansEcheance || _maturityDate == null) return false;
    final maturityDay = DateTime(_maturityDate!.year, _maturityDate!.month, _maturityDate!.day);
    return maturityDay.isBefore(_creationDay);
  }

  // Required fields validation
  bool get _isAmountValid => _currentAmount > 0;
  bool get _isMaturityValid => _sansEcheance || (_maturityDate != null && !_isMaturityBeforeCreation);
  bool get _isTreasuryAccountValid =>
      _selectedTreasuryAccountId != null && _selectedTreasuryAccountId!.trim().isNotEmpty;

  bool get _isFormValid => _isAmountValid && _isMaturityValid && _isTreasuryAccountValid;

  void _performCalculation() {
    if (!_isFormValid) {
      setState(() => _hasAttemptedCalculation = true);
      String missing = '';
      if (!_isAmountValid) missing += 'Montant total, ';
      if (_maturityDate == null && !_sansEcheance) {
        missing += 'Date d\'échéance, ';
      } else if (_isMaturityBeforeCreation) {
        missing += 'Date d\'échéance (doit être postérieure à la date de création), ';
      }
      if (!_isTreasuryAccountValid) missing += 'Compte de trésorerie, ';
      if (missing.endsWith(', ')) missing = missing.substring(0, missing.length - 2);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMaturityBeforeCreation && _isAmountValid && _isTreasuryAccountValid
                ? 'La date d\'échéance doit être postérieure ou égale à la date de création.'
                : 'Veuillez renseigner les champs obligatoires : $missing',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Clean previous generated items
    for (final item in _generatedTraites) {
      item.dispose();
    }
    _generatedTraites = [];

    final total = _currentAmount;
    final baseRef = widget.initialNumber.isNotEmpty ? widget.initialNumber : '010450765935';

    if (_selectedMode == 0) {
      // Une traite simple
      final serialCtrl = TextEditingController(text: baseRef);
      final amountCtrl = TextEditingController(text: total.toStringAsFixed(3));
      _generatedTraites.add(GeneratedTraiteItem(
        number: 1,
        serialCtrl: serialCtrl,
        amountCtrl: amountCtrl,
        maturityDate: _maturityDate,
        sansEcheance: _sansEcheance,
      ));
    } else {
      // Plusieurs traites
      final double partAmount = double.parse((total / _splitCount).toStringAsFixed(3));
      double remainder = double.parse((total - (partAmount * _splitCount)).toStringAsFixed(3));
      final baseDate = _maturityDate ?? _creationDate.add(const Duration(days: 30));

      for (int i = 0; i < _splitCount; i++) {
        DateTime mDate;
        if (_periodicity == 'bimensuelle') {
          mDate = baseDate.add(Duration(days: i * 15));
        } else if (_periodicity == 'trimestrielle') {
          mDate = DateTime(baseDate.year, baseDate.month + (i * 3), baseDate.day);
        } else {
          mDate = DateTime(baseDate.year, baseDate.month + i, baseDate.day);
        }

        double itemAmount = partAmount;
        if (i == _splitCount - 1) {
          itemAmount = double.parse((partAmount + remainder).toStringAsFixed(3));
        }

        final ref = '${baseRef.substring(0, baseRef.length > 3 ? baseRef.length - 2 : baseRef.length)}${(i + 1).toString().padLeft(2, '0')}';
        final serialCtrl = TextEditingController(text: ref);
        final amountCtrl = TextEditingController(text: itemAmount.toStringAsFixed(3));

        _generatedTraites.add(GeneratedTraiteItem(
          number: i + 1,
          serialCtrl: serialCtrl,
          amountCtrl: amountCtrl,
          maturityDate: mDate,
          sansEcheance: false,
        ));
      }
    }

    setState(() {
      _hasCalculated = true;
    });

    // Smooth scroll down to generated items and preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  double get _totalGeneratedAmount {
    if (_generatedTraites.isEmpty) return _currentAmount;
    double sum = 0.0;
    for (final it in _generatedTraites) {
      sum += double.tryParse(it.amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    }
    return sum;
  }

  void _onAddAndPrintTraites() async {
    // If not calculated yet, run calculation first
    if (!_hasCalculated || _generatedTraites.isEmpty) {
      _performCalculation();
      if (!_hasCalculated || _generatedTraites.isEmpty) return;
    }

    final firstItem = _generatedTraites.first;
    final totalAmount = _totalGeneratedAmount;
    final primarySerial = firstItem.serialCtrl.text.trim().isNotEmpty
        ? firstItem.serialCtrl.text.trim()
        : '010450765935';
    final primaryMaturity = firstItem.sansEcheance ? null : (firstItem.maturityDate ?? _maturityDate);

    final splitItems = _generatedTraites.map((it) {
      return TraiteSplitItem(
        number: it.number,
        reference: it.serialCtrl.text.trim(),
        amount: double.tryParse(it.amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
        maturityDate: it.maturityDate ?? _creationDate,
        sansEcheance: it.sansEcheance,
      );
    }).toList();

    final data = TraiteEditorData(
      documentNumber: primarySerial,
      amount: totalAmount,
      issuerName: widget.initialIssuer,
      recipientName: widget.initialRecipient,
      creationDate: _creationDate,
      maturityDate: primaryMaturity,
      sansEcheance: firstItem.sansEcheance,
      creationPlace: _creationPlaceCtrl.text.trim(),
      clientBankAccount: _selectedClientBank,
      treasuryAccountId: _selectedTreasuryAccountId,
      treasuryAccountName: _selectedTreasuryAccountName,
      printSettings: _selectedPrintSettings,
      rib: _ribCtrl.text.trim(),
      bankName: _selectedClientBank ?? '',
      notes: _notesCtrl.text.trim(),
      splitItems: splitItems,
    );

    if (widget.onApply != null) {
      widget.onApply!(data);
    }

    // Launch official print preview
    await _printOfficialTraitesPdf();

    if (mounted) {
      Navigator.of(context).pop(data);
    }
  }

  String _numberToWordsFrench(double value) {
    if (value <= 0) return 'ZÉRO DINAR';

    final dinars = value.floor();
    final millimes = ((value - dinars) * 1000).round();

    String dinarsText = _intToWordsFrench(dinars);
    String result = '$dinarsText Dinar${dinars > 1 ? 's' : ''}';

    if (millimes > 0) {
      String millimesText = _intToWordsFrench(millimes);
      result += ' et $millimesText Millime${millimes > 1 ? 's' : ''}';
    }

    return result.toUpperCase();
  }

  String _intToWordsFrench(int n) {
    if (n == 0) return 'zéro';
    if (n < 0) return 'moins ${_intToWordsFrench(-n)}';

    final units = [
      '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
      'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
      'dix-sept', 'dix-huit', 'dix-neuf'
    ];
    final tens = [
      '', 'dix', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante',
      'soixante-dix', 'quatre-vingts', 'quatre-vingt-dix'
    ];

    if (n < 20) return units[n];

    if (n < 70) {
      final t = n ~/ 10;
      final u = n % 10;
      if (u == 0) return tens[t];
      if (u == 1) return '${tens[t]} et un';
      return '${tens[t]}-${units[u]}';
    }

    if (n < 80) {
      final u = n - 60;
      if (u == 11) return 'soixante et onze';
      return 'soixante-${units[u]}';
    }

    if (n < 100) {
      final u = n - 80;
      if (u == 0) return 'quatre-vingts';
      return 'quatre-vingt-${units[u]}';
    }

    if (n < 1000) {
      final h = n ~/ 100;
      final rem = n % 100;
      String hText = h == 1 ? 'cent' : '${units[h]} cent';
      if (rem == 0) return hText;
      return '$hText ${_intToWordsFrench(rem)}';
    }

    if (n < 1000000) {
      final th = n ~/ 1000;
      final rem = n % 1000;
      String thText = th == 1 ? 'mille' : '${_intToWordsFrench(th)} mille';
      if (rem == 0) return thText;
      return '$thText ${_intToWordsFrench(rem)}';
    }

    final mill = n ~/ 1000000;
    final rem = n % 1000000;
    String millText = mill == 1 ? 'un million' : '${_intToWordsFrench(mill)} millions';
    if (rem == 0) return millText;
    return '$millText ${_intToWordsFrench(rem)}';
  }

  Future<void> _printOfficialTraitesPdf() async {
    final doc = pw.Document();
    final items = _generatedTraites.isNotEmpty
        ? _generatedTraites
        : [
            GeneratedTraiteItem(
              number: 1,
              serialCtrl: TextEditingController(text: '010450765935'),
              amountCtrl: TextEditingController(text: _currentAmount.toStringAsFixed(3)),
              maturityDate: _maturityDate,
              sansEcheance: _sansEcheance,
            )
          ];

    final tireurName = widget.initialRecipient.isNotEmpty ? widget.initialRecipient : 'RED';
    final tireName = widget.initialIssuer.isNotEmpty ? widget.initialIssuer : 'CLIENT PASSAGER';
    final creationDateStr = DateFormat('dd/MM/yyyy').format(_creationDate);

    for (final item in items) {
      final amount = double.tryParse(item.amountCtrl.text.replaceAll(',', '.')) ?? _currentAmount;
      final amountFormatted = formatCurrencyDT(amount);
      final amountWords = _numberToWordsFrench(amount);
      final serial = item.serialCtrl.text.trim().isNotEmpty ? item.serialCtrl.text.trim() : '010450765935';
      final maturityStr = item.sansEcheance
          ? 'À VUE (SANS ÉCHÉANCE)'
          : (item.maturityDate != null ? DateFormat('dd/MM/yyyy').format(item.maturityDate!) : creationDateStr);

      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(21.0 * PdfPageFormat.cm, 9.8 * PdfPageFormat.cm, marginAll: 0.5 * PdfPageFormat.cm),
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Ornate Header Banner
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.red900, width: 1.5)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('République Tunisienne', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Lettre de Change  /  Bill of Exchange  /  كمبيالة', style: pw.TextStyle(fontSize: 12, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                        pw.Text('الجمهورية التونسية', style: pw.TextStyle(fontSize: 9, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),

                  // Top metadata row
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Signature du tiré
                      pw.Container(
                        width: 95,
                        height: 38,
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 0.7)),
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('Signature du tiré\nإمضاء المسحوب عليه', style: const pw.TextStyle(fontSize: 6.5)),
                      ),
                      pw.SizedBox(width: 8),

                      // Dates
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 0.7)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Échéance / حلول الأجل : $maturityStr', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text('À / في : ${_creationPlaceCtrl.text.isNotEmpty ? _creationPlaceCtrl.text : "Tunis"}, le $creationDateStr', style: const pw.TextStyle(fontSize: 7)),
                          ],
                        ),
                      ),
                      pw.Spacer(),

                      // Serial & Amount
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Ordre de paiement L - CN° $serial', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.2)),
                            child: pw.Text('B.P.F. : $amountFormatted', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),

                  // Clause & Order
                  pw.Row(
                    children: [
                      pw.Text('Tireur / الساحب : ', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text(tireurName, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 15),
                      pw.Text('Contre cette lettre de change stipulée sans frais, payer à l\'ordre de : ', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text(tireurName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),

                  // Amount in letters
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    color: PdfColors.grey100,
                    child: pw.Text(
                      'Montant en lettres / المبلغ بلسان القلم : $amountWords',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                  ),
                  pw.SizedBox(height: 5),

                  // Tiré and Domiciliation
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // RIB
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('RIB ou RIP du Tiré / المعرف البنكي أو البريدي :', style: const pw.TextStyle(fontSize: 6.5)),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(3),
                              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 0.6)),
                              child: pw.Text('${_selectedClientBank ?? "Banque"} - RIB : ${_ribCtrl.text.isNotEmpty ? _ribCtrl.text : "—"}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text('Lieu de création : ${_creationPlaceCtrl.text.isNotEmpty ? _creationPlaceCtrl.text : "Tunis"}', style: const pw.TextStyle(fontSize: 6.5)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),

                      // Tiré box
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Nom et adresse du Tiré / اسم و عنوان المسحوب عليه :', style: const pw.TextStyle(fontSize: 6.5)),
                              pw.Text(tireName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),

                      // Signature & Stamp
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          children: [
                            pw.Text('Signature du Tireur\nتوقيع الساحب', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
                            pw.SizedBox(height: 12),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red800, width: 0.8)),
                              child: pw.Text('TIMBRE FISCAL', style: pw.TextStyle(fontSize: 6, color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),

                  // Bottom MICR line
                  pw.Center(
                    child: pw.Text('⑈ $serial ⑈   <$serial>', style: pw.TextStyle(fontSize: 8, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Traites_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 750;
    final tireurName = widget.initialRecipient.isNotEmpty ? widget.initialRecipient : 'red';
    final tireName = widget.initialIssuer.isNotEmpty ? widget.initialIssuer : 'Client passager';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 36,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 880),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Éditeur de traite',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Traites tirées par $tireurName sur $tireName.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── Scrollable Body ─────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Switcher [ Une traite simple (?) ] | [ Plusieurs traites (?) ]
                    _buildSegmentedSwitcher(),
                    const SizedBox(height: 20),

                    // Row 1: Montant total (?) | Date de création (?)
                    if (isSmallScreen) ...[
                      _buildAmountField(),
                      const SizedBox(height: 14),
                      _buildCreationDateField(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAmountField()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildCreationDateField()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Row 2: Date d'échéance (?) | Sans échéance (?)
                    if (isSmallScreen) ...[
                      _buildMaturityDateField(),
                      const SizedBox(height: 12),
                      _buildSansEcheanceCheckbox(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildMaturityDateField()),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: _buildSansEcheanceCheckbox(),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Row 3: Compte bancaire du client (?) | Lieu de création (?)
                    if (isSmallScreen) ...[
                      _buildClientBankField(),
                      const SizedBox(height: 14),
                      _buildCreationPlaceField(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildClientBankField()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildCreationPlaceField()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Row 4: Compte de trésorerie * (?) | Paramètres d'impression (?)
                    if (isSmallScreen) ...[
                      _buildTreasuryAccountField(),
                      const SizedBox(height: 14),
                      _buildPrintSettingsField(),
                      const SizedBox(height: 8),
                      _buildAdvancedSettingsToggle(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTreasuryAccountField()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildPrintSettingsField()),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildAdvancedSettingsToggle(),
                      ),
                    ],

                    // Advanced collapsible section
                    if (_showAdvancedSettings) ...[
                      const SizedBox(height: 14),
                      _buildAdvancedSection(),
                    ],

                    // Multi-traites (Plusieurs traites breakdown configuration)
                    if (_selectedMode == 1) ...[
                      const SizedBox(height: 16),
                      _buildMultiTraitesConfig(),
                    ],

                    const SizedBox(height: 20),

                    // ── Primary Button: Calculer la répartition des traites ──
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _performCalculation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB), // Vibrant blue
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text(
                          'Calculer la répartition des traites',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // ── Traites générées & Aperçu (Shown after calculation) ──
                    if (_hasCalculated && _generatedTraites.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildGeneratedTraitesSection(),
                      const SizedBox(height: 24),
                      _buildTraiteApercuSection(tireurName, tireName),
                    ],

                    const SizedBox(height: 18),

                    // ── Print & Add Button: Ajouter et imprimer les traites ──
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _onAddAndPrintTraites,
                        icon: const Icon(Icons.print_outlined, size: 18, color: Colors.white),
                        label: const Text(
                          'Ajouter et imprimer les traites',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasCalculated ? const Color(0xFF2563EB) : const Color(0xFF93C5FD),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
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

  // ── Mode Switcher: [ Une traite simple (?) ] | [ Plusieurs traites (?) ] ──
  Widget _buildSegmentedSwitcher() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light slate gray track
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              index: 0,
              label: 'Une traite simple',
              tooltip: 'Créer une seule traite pour le montant total',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              label: 'Plusieurs traites',
              tooltip: 'Diviser le montant en plusieurs traites échelonnées',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required String tooltip,
  }) {
    final isSelected = _selectedMode == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = index;
          _hasCalculated = false;
        });
      },
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: tooltip,
              child: Icon(
                Icons.help_outline_rounded,
                size: 15,
                color: isSelected ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Label with Question Mark Help Icon ─────────────────────
  Widget _buildLabelWithHelp(
    String label, {
    bool isRequired = false,
    String? tooltip,
    bool hasError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: hasError ? const Color(0xFFDC2626) : const Color(0xFF334155),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
            ),
          if (tooltip != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip,
              child: const Icon(
                Icons.help_outline_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Input Fields ────────────────────────────────────────────────
  Widget _buildAmountField() {
    final hasError = _hasAttemptedCalculation && !_isAmountValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Montant total', isRequired: true, tooltip: 'Montant total à régler par traite', hasError: hasError),
        SizedBox(
          height: 42,
          child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              suffixText: 'DT',
              suffixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              hintText: '0.000',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: hasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: hasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreationDateField() {
    final dateStr = DateFormat('dd/MM/yyyy').format(_creationDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Date de création', tooltip: 'Date d\'émission de la lettre de change'),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _creationDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (d != null) {
              setState(() {
                _creationDate = d;
                final newCreationDay = DateTime(d.year, d.month, d.day);
                // If maturity date is before new creation date, adjust it
                if (_maturityDate != null && _maturityDate!.isBefore(newCreationDay)) {
                  _maturityDate = newCreationDay.add(const Duration(days: 30));
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaturityDateField() {
    final dateStr = _maturityDate != null ? DateFormat('dd/MM/yyyy').format(_maturityDate!) : 'jj/mm/aaaa';
    final isEnabled = !_sansEcheance;
    final hasError = (_hasAttemptedCalculation && !_isMaturityValid) || _isMaturityBeforeCreation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Date d\'échéance', isRequired: true, tooltip: 'Date limite d\'encaissement de la traite', hasError: hasError),
        InkWell(
          onTap: isEnabled
              ? () async {
                  final initial = (_maturityDate != null && !_maturityDate!.isBefore(_creationDay))
                      ? _maturityDate!
                      : _creationDay.add(const Duration(days: 30));
                  final d = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: _creationDay, // Cannot pick before creation date
                    lastDate: DateTime(2035),
                    selectableDayPredicate: (day) => !day.isBefore(_creationDay),
                  );
                  if (d != null) {
                    setState(() => _maturityDate = d);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : const Color(0xFFF8FAFC),
              border: Border.all(color: hasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _sansEcheance ? 'Sans échéance (À vue)' : dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    color: _sansEcheance
                        ? const Color(0xFF64748B)
                        : (_maturityDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: isEnabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
        if (_isMaturityBeforeCreation)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'L\'échéance doit être postérieure ou égale à la date de création',
              style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildSansEcheanceCheckbox() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _sansEcheance,
            activeColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                _sansEcheance = val ?? false;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Sans échéance',
          style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        const Tooltip(
          message: 'La traite sera payable à vue (dès présentation)',
          child: Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildClientBankField() {
    final tunisianBanks = [
      'BIAT',
      'Attijari Bank',
      'BNA',
      'STB',
      'BH Bank',
      'Amen Bank',
      'UIB',
      'ATB',
      'BT (Banque de Tunisie)',
      'UBCI',
      'Zitouna Bank',
      'Al Baraka Bank',
      'Wifak Bank',
      'La Poste Tunisienne (CCP)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Compte bancaire du client', tooltip: 'Banque domiciliataire du tiré (client)'),
        Container(
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedClientBank,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Sélectionner un compte bancaire', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
              icon: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.unfold_more_rounded, size: 18, color: Color(0xFF64748B)),
              ),
              items: tunisianBanks.map((b) => DropdownMenuItem(
                value: b,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(b, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                ),
              )).toList(),
              onChanged: (val) => setState(() => _selectedClientBank = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreationPlaceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Lieu de création', tooltip: 'Ville où la traite a été dressée'),
        SizedBox(
          height: 42,
          child: TextField(
            controller: _creationPlaceCtrl,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'Ex. Tunis',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreasuryAccountField() {
    final hasError = _hasAttemptedCalculation && !_isTreasuryAccountValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Compte de trésorerie', isRequired: true, tooltip: 'Compte de trésorerie d\'encaissement', hasError: hasError),
        BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
          builder: (context, state) {
            final accounts = state is TreasuryAccountsLoaded ? state.accounts : <TreasuryAccount>[];
            if (_selectedTreasuryAccountId == null && accounts.isNotEmpty) {
              _selectedTreasuryAccountId = accounts.first.id;
              _selectedTreasuryAccountName = accounts.first.name;
            }

            return Container(
              height: 42,
              decoration: BoxDecoration(
                border: Border.all(color: hasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: accounts.any((a) => a.id == _selectedTreasuryAccountId) ? _selectedTreasuryAccountId : null,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Sélectionner un compte', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  ),
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                  ),
                  items: accounts.map((acc) => DropdownMenuItem(
                    value: acc.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${acc.name} (${acc.type == "cash" ? "Caisse" : "Banque"})',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTreasuryAccountId = val;
                      final acc = accounts.firstWhere((a) => a.id == val, orElse: () => accounts.first);
                      _selectedTreasuryAccountName = acc.name;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrintSettingsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp('Paramètres d\'impression', tooltip: 'Format et modèle d\'impression de la traite'),
        Container(
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedPrintSettings,
              icon: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Créer paramètres d\'impression',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Créer paramètres d\'impression', style: TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Modèle standard Lettre de Change',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Modèle standard Lettre de Change', style: TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedPrintSettings = val ?? _selectedPrintSettings),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettingsToggle() {
    return InkWell(
      onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paramètres avancés',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(
              _showAdvancedSettings ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: const Color(0xFF475569),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabelWithHelp('RIB Bancaire du client (20 chiffres)', tooltip: 'Relevé d\'identité bancaire complet'),
          SizedBox(
            height: 40,
            child: TextField(
              controller: _ribCtrl,
              maxLength: 20,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Ex: 08001000123456789012',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabelWithHelp('Mentions légales & Instructions d\'acceptation', tooltip: 'Mentions spéciales inscrites sur la traite'),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ex: Bon pour acceptation et paiement à l\'ordre de...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiTraitesConfig() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Text(
                'Échéancier de répartition des traites',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelWithHelp('Nombre de traites', tooltip: 'Nombre total d\'échéances'),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _splitCount,
                          items: [2, 3, 4, 5, 6, 8, 10, 12].map((n) => DropdownMenuItem(
                            value: n,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$n traites', style: const TextStyle(fontSize: 13)),
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _splitCount = val;
                                _hasCalculated = false;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelWithHelp('Périodicité', tooltip: 'Intervalle entre chaque traite'),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _periodicity,
                          items: const [
                            DropdownMenuItem(value: 'bimensuelle', child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Tous les 15 jours', style: TextStyle(fontSize: 13)))),
                            DropdownMenuItem(value: 'mensuelle', child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Mensuelle (30 jours)', style: TextStyle(fontSize: 13)))),
                            DropdownMenuItem(value: 'trimestrielle', child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Trimestrielle (90 jours)', style: TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _periodicity = val;
                                _hasCalculated = false;
                              });
                            }
                          },
                        ),
                      ),
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

  // ── Traites Générées Table (Matching User Screenshot) ─────────────
  Widget _buildGeneratedTraitesSection() {
    final totalFormatted = formatCurrencyDT(_totalGeneratedAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Traites générées',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            Text(
              'Total : $totalFormatted',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: const [
                          Text('N° de série', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(width: 4),
                          Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                    const SizedBox(width: 10),
                    const Expanded(flex: 3, child: Text('Échéance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: const [
                          Text('Sans échéance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(width: 3),
                          Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _generatedTraites.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, i) {
                  final item = _generatedTraites[i];
                  final dateStr = item.maturityDate != null
                      ? DateFormat('dd/MM/yyyy').format(item.maturityDate!)
                      : 'jj/mm/aaaa';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // #
                        SizedBox(
                          width: 28,
                          child: Text('${item.number}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        ),

                        // N° de série (with red outline border as in screenshot)
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: item.serialCtrl,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'N° de série',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2), // Red border
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Montant
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: item.amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Échéance
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: item.sansEcheance
                                ? null
                                : () async {
                                    final initial = (item.maturityDate != null && !item.maturityDate!.isBefore(_creationDay))
                                        ? item.maturityDate!
                                        : _creationDay.add(const Duration(days: 30));
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: _creationDay, // Cannot pick before creation date
                                      lastDate: DateTime(2035),
                                      selectableDayPredicate: (day) => !day.isBefore(_creationDay),
                                    );
                                    if (d != null) {
                                      setState(() => item.maturityDate = d);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: item.sansEcheance ? const Color(0xFFF8FAFC) : Colors.white,
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.sansEcheance ? 'À vue' : dateStr,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: item.sansEcheance ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: item.sansEcheance ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Sans échéance checkbox
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: Checkbox(
                                value: item.sansEcheance,
                                activeColor: const Color(0xFF2563EB),
                                onChanged: (val) {
                                  setState(() {
                                    item.sansEcheance = val ?? false;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        // Edit icon
                        SizedBox(
                          width: 32,
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                            splashRadius: 14,
                            padding: EdgeInsets.zero,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Aperçu de la Traite / Lettre de Change (Matching User Benchmark) ──
  Widget _buildTraiteApercuSection(String tireurName, String tireName) {
    final firstItem = _generatedTraites.isNotEmpty ? _generatedTraites.first : null;
    final amount = firstItem != null
        ? (double.tryParse(firstItem.amountCtrl.text.replaceAll(',', '.')) ?? _currentAmount)
        : _currentAmount;
    final amountFormatted = formatCurrencyDT(amount);
    final amountWords = _numberToWordsFrench(amount);
    final serial = firstItem?.serialCtrl.text.trim().isNotEmpty == true
        ? firstItem!.serialCtrl.text.trim()
        : '010450765935';

    final creationDateStr = DateFormat('dd/MM/yyyy').format(_creationDate);
    final maturityStr = (firstItem?.sansEcheance ?? _sansEcheance)
        ? 'À VUE'
        : (firstItem?.maturityDate != null
            ? DateFormat('dd/MM/yyyy').format(firstItem!.maturityDate!)
            : (_maturityDate != null ? DateFormat('dd/MM/yyyy').format(_maturityDate!) : creationDateStr));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aperçu',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: 780,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Ornate Header Strip in Red
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFB91C1C), width: 1.2),
                      color: const Color(0xFFFEF2F2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.shield_outlined, size: 14, color: Color(0xFFB91C1C)),
                            SizedBox(width: 4),
                            Text(
                              'République Tunisienne',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                            ),
                          ],
                        ),
                        Row(
                          children: const [
                            Text(
                              'Lettre de Change',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C), fontFamily: 'serif'),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Bill of exchange',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'كمبيالة',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                            ),
                          ],
                        ),
                        const Text(
                          'الجمهورية التونسية',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. Upper Strip: Signature tiré | Échéance | Date | Ordre de paiement | Montant BPF
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Signature du tiré box
                      Container(
                        width: 120,
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF475569), width: 1),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Signature du tiré', style: TextStyle(fontSize: 8, color: Color(0xFF475569))),
                            Text('إمضاء المسحوب عليه', style: TextStyle(fontSize: 7.5, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Dates boxes
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF475569), width: 1),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Échéance / حلول الأجل', style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(maturityStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('A / في', style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(creationDateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Ordre de paiement & Montant BPF
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Text('Ordre de paiement L - CN° ', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                              Text(serial, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Row(
                              children: [
                                const Text('Montant / المبلغ : ', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                                Text(
                                  '*** $amountFormatted ***',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3. Middle Section: Tireur & Beneficiary
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1))),
                        child: Row(
                          children: [
                            const Text('Tireur / الساحب : ', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                            Text(tireurName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Contre cette lettre de change (Payable*) / مقابل هذه الكمبيالة (القابلة للاحتجاج*) : ',
                        style: TextStyle(fontSize: 8, color: Color(0xFF475569)),
                      ),
                      const Text('Non / لا [✓]', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      const Text('payer à l\'ordre de / إدفعوا لأمر : ', style: TextStyle(fontSize: 8, color: Color(0xFF475569))),
                      Text(tireurName.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      const Spacer(),
                      Text(amountFormatted, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 4. Montant en lettres
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Text('Montant en lettres / المبلغ بلسان القلم : ', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                        Expanded(
                          child: Text(
                            amountWords,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4C1D95), // Deep purple as benchmark
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 5. Grid Details: Lieu de création | Nom cédant | Codes
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lieu de création / مكان الإنشاء : ${_creationPlaceCtrl.text.isNotEmpty ? _creationPlaceCtrl.text : "Tunis"} - $creationDateStr',
                          style: const TextStyle(fontSize: 8, color: Color(0xFF475569)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Échéance / حلول الأجل : $maturityStr',
                          style: const TextStyle(fontSize: 8, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Nom du cédant / اسم المحيل : —',
                          style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Codes réservés / رموز خاصة : 001',
                          style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 6. Bottom Row: Domiciliation RIB | Tiré details | Signature Tireur | Timbre fiscal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RIB / Domiciliation
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RIB ou RIP du Tiré / المعرف البنكي أو البريدي للمسحوب عليه :', style: TextStyle(fontSize: 8, color: Color(0xFF475569))),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                _buildRibBox('Code Banque', _selectedClientBank != null ? '08' : '—'),
                                const SizedBox(width: 4),
                                _buildRibBox('Code Guichet', '001'),
                                const SizedBox(width: 4),
                                _buildRibBox('N° de Compte', _ribCtrl.text.isNotEmpty ? _ribCtrl.text : '12345678901'),
                                const SizedBox(width: 4),
                                _buildRibBox('Clé', '45'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Domiciliation : ${_selectedClientBank ?? "Banque"} (${_creationPlaceCtrl.text})',
                              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            const Text('Acceptation / قبول', style: TextStyle(fontSize: 7.5, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Nom et adresse du Tiré (Prominent boxed cell)
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nom et adresse du Tiré / اسم و عنوان المسحوب عليه :', style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text(
                                tireName.toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              const Text('Tunis, Tunisie', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Signature du tireur & Timbre Fiscal
                      Expanded(
                        flex: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: const [
                                Text('Signature du tireur', style: TextStyle(fontSize: 7.5, color: Color(0xFF475569))),
                                Text('توقيع الساحب', style: TextStyle(fontSize: 7, color: Color(0xFF475569))),
                                SizedBox(height: 24),
                                Text('— — — — — —', style: TextStyle(fontSize: 8, color: Color(0xFFCBD5E1))),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFB91C1C), width: 1.2),
                                color: const Color(0xFFFEF2F2),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.verified_outlined, size: 14, color: Color(0xFFB91C1C)),
                                  SizedBox(height: 2),
                                  Text('TIMBRE FISCAL', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                                  Text('LETTRE DE CHANGE', style: TextStyle(fontSize: 5, color: Color(0xFFB91C1C))),
                                  Text('كمبيالة', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 7. Bottom MICR / Barcode Band
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Center(
                      child: Text(
                        '⑈ $serial ⑈   <$serial>',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          fontFamily: 'monospace',
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRibBox(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 6.5, color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

/// Helper method to build standard traite editor trigger button
Widget buildTraiteEditorButton({
  required VoidCallback onTap,
  String label = 'Éditeur de traite',
  bool isSmall = false,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: isSmall ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: isSmall ? 13 : 15,
            color: const Color(0xFF334155),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    ),
  );
}
