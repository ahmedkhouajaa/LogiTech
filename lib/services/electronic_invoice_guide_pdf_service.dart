import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Service générant le PDF officiel complet de 10 pages :
/// "Accompagnement pour la signature et la facturation électronique"
/// pour l'interconnexion entre LogiTech et le système national elFatoora (TTN / Tuntrust).
class ElectronicInvoiceGuidePdfService {
  static final ElectronicInvoiceGuidePdfService instance = ElectronicInvoiceGuidePdfService._();
  ElectronicInvoiceGuidePdfService._();

  pw.Font? _cachedRegular;
  pw.Font? _cachedBold;

  Future<(pw.Font, pw.Font)> _getFonts() async {
    if (_cachedRegular != null && _cachedBold != null) {
      return (_cachedRegular!, _cachedBold!);
    }
    try {
      final reg = await PdfGoogleFonts.robotoRegular().timeout(const Duration(milliseconds: 2500));
      final bold = await PdfGoogleFonts.robotoBold().timeout(const Duration(milliseconds: 2500));
      _cachedRegular = reg;
      _cachedBold = bold;
      return (reg, bold);
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  /// Génère le PDF complet de 10 pages
  Future<Uint8List> generateGuidePdf() async {
    final pdf = pw.Document(
      title: 'Guide d\'accompagnement - Facturation Électronique & elFatoora - LogiTech',
      author: 'LogiTech ERP',
    );

    final fonts = await _getFonts();
    final fontRegular = fonts.$1;
    final fontBold = fonts.$2;

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // Palette de couleurs
    const primaryColor = PdfColor.fromInt(0xFF0284C7); // Bleu LogiTech
    const darkColor = PdfColor.fromInt(0xFF0F172A);
    const bodyColor = PdfColor.fromInt(0xFF334155);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const greenColor = PdfColor.fromInt(0xFF16A34A);
    const redColor = PdfColor.fromInt(0xFFDC2626);

    // Header standard pour les pages intérieures
    pw.Widget buildPageHeader(String title) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'LogiTech  •  Facture Électronique & elFatoora TTN',
              style: pw.TextStyle(fontSize: 9, color: primaryColor, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 9, color: bodyColor),
            ),
          ],
        ),
      );
    }

    // Footer standard
    pw.Widget buildPageFooter(int pageNumber) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Guide officiel de démarrage - Tunisie Trade Net & Tuntrust',
              style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8)),
            ),
            pw.Text(
              'Page $pageNumber / 10',
              style: pw.TextStyle(fontSize: 8, color: primaryColor, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 1 : Page de garde & Introduction
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Spacer(flex: 1),
              // Logo & Badge
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'LogiTech ERP',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text(
                    'elFatoora  •  TTN  •  Tuntrust',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF64748B)),
                  ),
                ],
              ),
              pw.SizedBox(height: 36),

              // Titre Principal
              pw.Text(
                'Accompagnement pour la signature\net la facturation électronique',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: darkColor,
                  lineSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 24),

              // Salutations & Présentation
              pw.Text(
                'Bonjour,',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Nous vous souhaitons la bienvenue et vous remercions pour votre confiance. Nous sommes bien entendu à vos côtés pour vous accompagner pas à pas dans la mise en place de la signature électronique et l\'activation de la facturation électronique via LogiTech.',
                style: const pw.TextStyle(fontSize: 11, color: bodyColor, lineSpacing: 3),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Avant d\'entrer dans les aspects techniques, nous vous présentons ci-dessous les différentes étapes du processus.',
                style: const pw.TextStyle(fontSize: 11, color: bodyColor, lineSpacing: 3),
              ),
              pw.SizedBox(height: 24),

              // Encadré Note
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      margin: const pw.EdgeInsets.only(right: 10, top: 1),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'NOTE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Vous pouvez vous référer directement à l\'étape qui correspond à votre situation actuelle, sans obligation de suivre l\'ordre si certaines étapes sont déjà complétées.',
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          color: darkColor,
                          fontWeight: pw.FontWeight.bold,
                          lineSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(flex: 2),

              // Signature de marque centrale
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: 50,
                      height: 5,
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(2.5),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'LogiTech - Plateforme de Gestion Commerciale & Facturation Conforme',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              buildPageFooter(1),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 2 : Vue d'ensemble du processus
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          final steps = [
            {'num': '01', 'title': 'Achat de la signature électronique (Digigo)'},
            {'num': '02', 'title': 'Ajout de l\'adresse e-mail Digigo dans LogiTech'},
            {'num': '03', 'title': 'Dépôt du dossier auprès de la TTN'},
            {'num': '04', 'title': 'Envoi de la demande d\'accès à l\'Environnement de Test'},
            {'num': '05', 'title': 'Réception des accès à l\'Environnement de Test TTN'},
            {'num': '06', 'title': 'Émission d\'une facture de test depuis LogiTech'},
            {'num': '07', 'title': 'Demande d\'activation de l\'Environnement de Production'},
          ];

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Vue d\'ensemble'),
              pw.Text(
                'Vue d\'ensemble du processus',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 24),

              pw.Expanded(
                child: pw.ListView.separated(
                  itemCount: steps.length,
                  separatorBuilder: (context, index) => pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 10),
                    height: 1,
                    color: borderColor,
                  ),
                  itemBuilder: (context, index) {
                    final item = steps[index];
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 38,
                            height: 38,
                            decoration: pw.BoxDecoration(
                              color: primaryColor.shade(0.1),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              item['num']!,
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                            ),
                          ),
                          pw.SizedBox(width: 18),
                          pw.Expanded(
                            child: pw.Text(
                              item['title']!,
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
                            ),
                          ),
                          pw.Text(
                            'Étape ${index + 1}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              buildPageFooter(2),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 3 : 1. Achat de la signature électronique (Digigo)
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Étape 1 : Signature électronique'),
              pw.Text(
                '1. Achat de la signature électronique (Digigo)',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'La première étape consiste à acquérir une signature électronique valide (Digigo) auprès d\'un fournisseur agréé. Cette étape doit être effectuée directement par le client.',
                style: const pw.TextStyle(fontSize: 11, color: bodyColor, lineSpacing: 3),
              ),
              pw.SizedBox(height: 20),

              // Options
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Option 1
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Option 1 : Tuntrust',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Validation en présentiel (via un agent de la Poste Tunisienne)',
                            style: const pw.TextStyle(fontSize: 10, color: bodyColor),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text('• Coût approx : ~70 DT', style: const pw.TextStyle(fontSize: 10, color: darkColor)),
                          pw.SizedBox(height: 4),
                          pw.Text('• Délai : variable', style: const pw.TextStyle(fontSize: 10, color: darkColor)),
                          pw.SizedBox(height: 12),
                          pw.Text('Portail : https://www.tuntrust.tn', style: pw.TextStyle(fontSize: 9.5, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Option 2
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Option 2 : Shadoc',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Validation à distance via appel vidéo direct',
                            style: const pw.TextStyle(fontSize: 10, color: bodyColor),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text('• Coût : 46 DT', style: const pw.TextStyle(fontSize: 10, color: darkColor)),
                          pw.SizedBox(height: 4),
                          pw.Text('• Délai : ~48h', style: const pw.TextStyle(fontSize: 10, color: darkColor)),
                          pw.SizedBox(height: 12),
                          pw.Text('Portail : https://www.shadoc.tn', style: pw.TextStyle(fontSize: 9.5, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Encadré Important
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF2F2),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFECACA)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Important :',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: redColor),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('• Une fois le code reçu sur votre téléphone, la procédure est finalisée.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),
                    pw.SizedBox(height: 4),
                    pw.Text('• Ce code est strictement personnel et confidentiel. Ne le partagez sous aucun prétexte.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),
                    pw.SizedBox(height: 4),
                    pw.Text('• LogiTech inclut 300 signatures dès l\'activation. N\'achetez pas de signatures supplémentaires via Digigo.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(3),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 4 : 2. Ajout de l'adresse e-mail Digigo dans LogiTech
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Étape 2 : Configuration LogiTech'),
              pw.Text(
                '2. Ajout de l\'adresse e-mail Digigo dans LogiTech',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Dès la réception du code Digigo, cela signifie que votre adresse e-mail est désormais associée à une signature électronique valide.',
                style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2),
              ),
              pw.SizedBox(height: 14),

              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const pw.EdgeInsets.only(right: 8),
                    decoration: pw.BoxDecoration(
                      color: darkColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('GUIDE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Text('Étapes à suivre dans LogiTech', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('1. Connectez-vous à votre compte LogiTech.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('2. Depuis le menu principal (barre latérale à gauche), accédez à la section « Facture électronique ».', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('3. Cliquez sur « Activer la facturation électronique » ou sur l\'Étape 1.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('4. Sélectionnez le type de signature Digigo.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('5. Saisissez l\'adresse e-mail associée à la signature Digigo.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('6. Cliquez sur « Enregistrer » ou « Vérifier ».', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),

              pw.SizedBox(height: 16),

              // Résultat
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF0FDF4),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFBBF7D0)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const pw.EdgeInsets.only(right: 8),
                          decoration: pw.BoxDecoration(
                            color: greenColor,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('SUCCÈS', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text('Résultat', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: greenColor)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'En cas de succès, la signature est automatiquement reliée à votre compte LogiTech. Le numéro de série (KEY / Serial Number) de la signature s\'affiche immédiatement.',
                      style: const pw.TextStyle(fontSize: 10, color: bodyColor, lineSpacing: 2),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 5,
                          height: 5,
                          margin: const pw.EdgeInsets.only(top: 4, right: 6),
                          decoration: const pw.BoxDecoration(
                            color: darkColor,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Ce numéro est obligatoire et devra être renseigné dans la fiche de renseignements (Fiche de Renseignements TTN) lors du dépôt du dossier.',
                            style: pw.TextStyle(fontSize: 10, color: darkColor, fontWeight: pw.FontWeight.bold, lineSpacing: 2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // En cas d'erreur
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF2F2),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFECACA)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const pw.EdgeInsets.only(right: 8),
                          decoration: pw.BoxDecoration(
                            color: redColor,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('ATTENTION', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text('En cas d\'erreur', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: redColor)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Si la vérification échoue :', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
                    pw.Text('• Vérifiez que l\'adresse e-mail saisie est bien celle utilisée lors de l\'achat Digigo.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
                    pw.Text('• Si le problème persiste, contactez le support LogiTech ou ouvrez un ticket d\'assistance.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(4),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 5 : 3. Dépôt du dossier auprès de la TTN
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          final ttnSteps = [
            {'num': '01', 'title': 'Télécharger le dossier', 'desc': 'Accédez au site officiel tradenet.com.tn pour télécharger le dossier d\'adhésion.'},
            {'num': '02', 'title': 'Impression', 'desc': 'Imprimez tous les documents administratifs en double exemplaire complet.'},
            {'num': '03', 'title': 'Mise à jour technique', 'desc': 'Remplissez la partie technique de la fiche de renseignements avec les coordonnées requises.'},
            {'num': '04', 'title': 'Éviter le dépôt prématuré', 'desc': 'Ne déposez pas la déclaration d\'adhésion avant la finalisation de la signature électronique.'},
            {'num': '05', 'title': 'Dépôt final', 'desc': 'Déposez le contrat et la fiche en double exemplaire au bureau des dépôts et obtenez la décharge.'},
          ];

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Étape 3 : Dépôt TTN'),
              pw.Text(
                '3. Dépôt du dossier auprès de la TTN',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 18),

              pw.Expanded(
                child: pw.ListView.separated(
                  itemCount: ttnSteps.length,
                  separatorBuilder: (context, index) => pw.SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = ttnSteps[index];
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 30,
                            height: 30,
                            decoration: pw.BoxDecoration(
                              color: primaryColor,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              item['num']!,
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.SizedBox(width: 14),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(item['title']!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
                                pw.SizedBox(height: 4),
                                pw.Text(item['desc']!, style: const pw.TextStyle(fontSize: 10, color: bodyColor, lineSpacing: 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              buildPageFooter(5),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 6 : 4. Demande d'accès & 5. Réception accès Test TTN
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Étapes 4 & 5 : Environnement de Test'),
              pw.Text(
                '4. Envoi de la demande d\'accès à l\'Environnement de Test',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF3C7),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFDE68A)),
                ),
                child: pw.Text(
                  'Condition préalable : Vous ne pouvez envoyer la demande d\'accès que si votre dossier a été préalablement déposé auprès de la TTN.',
                  style: pw.TextStyle(fontSize: 9.5, color: darkColor, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Toutes les informations nécessaires se trouvent dans votre compte LogiTech après l\'ajout de la signature électronique, notamment :',
                style: const pw.TextStyle(fontSize: 10, color: bodyColor),
              ),
              pw.SizedBox(height: 4),
              pw.Text('• Votre clé (KEY / Serial Number)', style: const pw.TextStyle(fontSize: 10, color: darkColor)),
              pw.Text('• Votre adresse IP publique fixe : 46.224.185.96', style: pw.TextStyle(fontSize: 10, color: primaryColor, fontWeight: pw.FontWeight.bold)),
              pw.Text('• Veuillez consulter l\'Annexe 1 pour le modèle d\'email à envoyer.', style: pw.TextStyle(fontSize: 10, color: primaryColor, fontWeight: pw.FontWeight.bold)),

              pw.SizedBox(height: 18),
              pw.Divider(color: borderColor),
              pw.SizedBox(height: 12),

              pw.Text(
                '5. Réception des accès à l\'Environnement de Test TTN',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Objectif : Finaliser les dernières étapes pour être prêt à émettre et signer vos factures dans l\'Environnement de Test.',
                style: const pw.TextStyle(fontSize: 10, color: bodyColor),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Actions :', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkColor)),
              pw.SizedBox(height: 4),
              pw.Text('1. Connectez-vous à votre compte LogiTech.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('2. Ajoutez les informations reçues dans les champs dédiés du module Facture Électronique.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('3. Assurez-vous que le matricule fiscal fourni par TTN correspond exactement à celui dans LogiTech.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),
              pw.Text('4. Après validation, vous serez prêt à émettre et signer vos factures dans l\'Environnement de Test.', style: const pw.TextStyle(fontSize: 10, color: bodyColor)),

              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Text(
                  'Assistance : En cas de difficulté pour configurer l\'Environnement de Test, contactez immédiatement l\'équipe support de LogiTech via l\'onglet Support Client.',
                  style: const pw.TextStyle(fontSize: 9.5, color: bodyColor),
                ),
              ),

              pw.Spacer(),
              buildPageFooter(6),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 7 : 6. Émission d'une facture de test depuis LogiTech
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Étape 6 : Facture de Test'),
              pw.Text(
                '6. Émission d\'une facture de test depuis LogiTech',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Objectif : Signer et envoyer votre première facture de test dans l\'Environnement de Test TTN.',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 14),
              pw.Text('1. Vous pouvez soit signer une facture existante dans LogiTech, soit en créer une nouvelle.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),
              pw.SizedBox(height: 6),
              pw.Text('2. Après validation de la facture, l\'option « XML TEF / elFatoora » devient accessible.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),
              pw.SizedBox(height: 6),
              pw.Text('3. Cliquez sur cette option pour générer la structure XML homologuée et initier la signature Digigo.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),
              pw.SizedBox(height: 14),
              pw.Text(
                'Vous aurez ainsi émis et signé avec succès votre première facture dans votre Environnement de Test.',
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: greenColor),
              ),

              pw.SizedBox(height: 24),

              // Encadré illustré
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Aperçu du suivi de facturation électronique dans LogiTech', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkColor)),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: borderColor, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Référence', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Client', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Montant TTC', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Statut TTN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('FAC-TEST-0001', style: const pw.TextStyle(fontSize: 8.5))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('15/10/2026', style: const pw.TextStyle(fontSize: 8.5))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('STE EXEMPLE SARL', style: const pw.TextStyle(fontSize: 8.5))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('1 190.000 TND', style: const pw.TextStyle(fontSize: 8.5))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Signé par TTN (Test)', style: pw.TextStyle(fontSize: 8.5, color: greenColor, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(7),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 8 : 7. Demande d'activation de l'Environnement de Production
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Étape 7 : Passage en Production'),
              pw.Text(
                '7. Demande d\'activation de l\'Environnement de Production',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Après avoir signé votre première facture de test, deux petits fichiers apparaîtront : un certificat de test et un fichier XML signé.',
                style: const pw.TextStyle(fontSize: 11, color: bodyColor, lineSpacing: 2),
              ),
              pw.SizedBox(height: 16),

              pw.Text('Téléchargement des fichiers :', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
              pw.SizedBox(height: 4),
              pw.Text('Téléchargez les deux fichiers directement sur votre ordinateur.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor)),

              pw.SizedBox(height: 16),
              pw.Text('Envoi de la demande :', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
              pw.SizedBox(height: 4),
              pw.Text('Envoyez un mail officiel pour demander l\'accès à l\'Environnement de Production (voir modèle Annexe 3), en joignant les deux fichiers.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor, lineSpacing: 2)),

              pw.SizedBox(height: 20),

              // Conséquence
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Conséquence :', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 8),
                    pw.Text('• Toutes les signatures effectuées en Test seront archivées séparément.', style: const pw.TextStyle(fontSize: 10.5, color: bodyColor)),
                    pw.SizedBox(height: 6),
                    pw.Text('• Vous commencerez à émettre et signer vos factures officiellement et légalement en Production.', style: pw.TextStyle(fontSize: 10.5, color: darkColor, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(8),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 9 : Annexes 1 & 2
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Annexes 1 & 2 : Modèles & Vigilance'),
              pw.Text(
                'Annexe 1 : Modèle - Demande de configuration TTN',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('À : commercial@elfatoora.tn, support@elfatoora.tn', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('Objet : Demande de configuration TTN - Environnement de Test', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkColor)),
                    pw.SizedBox(height: 6),
                    pw.Text('Bonjour,', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Veuillez trouver ci-dessous les informations nécessaires pour la configuration de l\'accès au service TTN :', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 5),
                    pw.Text('Client : [Nom de l\'entreprise]', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Matricule fiscal : [Matricule fiscal – 13 caractères, sans séparateurs]', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Adresse IP publique fixe : 46.224.185.96', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('Personne habilitée à signer : [Nom et prénom]', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Numéro de série du certificat électronique (hexadécimal) : [Numéro de série]', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Adresse email associée au certificat électronique : [Adresse email]', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Mode de connexion : Webservice', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 5),
                    pw.Text('Nous restons à votre disposition pour toute information complémentaire.', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              pw.Text(
                'Annexe 2 : Problèmes fréquents et points de vigilance',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Erreurs courantes :', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: redColor)),
                    pw.Text('• Le matricule fiscal dans LogiTech doit être strictement identique à celui de la TTN (7 chiffres + 1 lettre).', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('• "Signature non autorisée" : nécessite un e-mail à la TTN pour réémission ou validation de la clé.', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 8),
                    pw.Text('Checklist avant signature :', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: greenColor)),
                    pw.Text('• Matricule fiscal du client correctement renseigné', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('• Adresse client < 37 caractères pour conformité XML TEF', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('• RIB bancaire tunisien valide (20 chiffres)', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('• Raison sociale strictement conforme aux statuts fiscaux', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(9),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 10 : Annexe 3 : Modèle d'email - Confirmation fin de test
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPageHeader('Annexe 3 : Passage en Production'),
              pw.Text(
                'Annexe 3 : Modèle - Passage en production',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 14),

              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('À : support@elfatoora.tn, commercial@elfatoora.tn', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text('Objet : Demande de passage en production – Intégration TTN', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkColor)),
                    pw.SizedBox(height: 12),
                    pw.Text('Bonjour,', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('Suite à la validation des tests, nous souhaitons procéder au passage en environnement de production pour l\'entreprise suivante :', style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2)),
                    pw.SizedBox(height: 8),
                    pw.Text('Entreprise : [Nom de l\'entreprise]', style: const pw.TextStyle(fontSize: 9.5)),
                    pw.Text('Matricule fiscal : [Matricule fiscal – 13 caractères, sans séparateurs ni espaces]', style: const pw.TextStyle(fontSize: 9.5)),
                    pw.Text('Adresse(s) IP publique(s) fixe(s) : 46.224.185.96', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('Numéro de série du certificat de signature électronique (hexadécimal) : [Numéro de série]', style: const pw.TextStyle(fontSize: 9.5)),
                    pw.SizedBox(height: 10),
                    pw.Text('Nous restons à votre disposition pour toute information complémentaire.', style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Clôture
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF0FDF4),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFBBF7D0)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      margin: const pw.EdgeInsets.only(right: 10),
                      decoration: pw.BoxDecoration(
                        color: greenColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'OFFICIEL',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Félicitations ! Votre entreprise est désormais 100% opérationnelle pour la facturation électronique conforme en Tunisie avec LogiTech ERP.',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: greenColor),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
