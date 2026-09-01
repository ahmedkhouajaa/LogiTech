import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/support_service.dart';
import '../services/subscription_payment_service.dart';
import '../services/app_navigation_service.dart';
import 'sidebar_menu.dart' show AppModule;

enum PaymentMethod { card, bankTransfer }

class PaymentConfirmationDialog extends StatefulWidget {
  final String planName; // 'Plan Mensuel', 'Plan Annuel', 'Plan Personnalisé'
  final double priceTtc; // e.g. 49.0 or 499.0
  final int durationDays; // 30 or 365

  const PaymentConfirmationDialog({
    super.key,
    required this.planName,
    required this.priceTtc,
    required this.durationDays,
  });

  static Future<void> show(
    BuildContext context, {
    required String planName,
    required double priceTtc,
    required int durationDays,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PaymentConfirmationDialog(
        planName: planName,
        priceTtc: priceTtc,
        durationDays: durationDays,
      ),
    );
  }

  @override
  State<PaymentConfirmationDialog> createState() => _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.bankTransfer;

  final String _bankName = 'BTE Banque Al tijeri';
  final String _accountHolder = 'Logitech Pro';
  final String _rib = '2500 1524 2555 1255 1244';

  void _copyRib() {
    Clipboard.setData(ClipboardData(text: _rib.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('RIB copié dans le presse-papier !'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _contactSupportForPayment() {
    final message = 'Bonjour, je souhaite valider mon paiement pour le ${widget.planName} (${widget.priceTtc.toStringAsFixed(0)} DT TTC).\nMode de paiement : ${_selectedMethod == PaymentMethod.bankTransfer ? "Virement / Versement bancaire" : "Carte bancaire"}.';

    // 1. Record to Payment History
    final double totalWithTimbre = widget.priceTtc + 1.0;
    SubscriptionPaymentService.instance.recordPaymentRequest(
      planName: widget.planName,
      amount: totalWithTimbre,
      method: _selectedMethod == PaymentMethod.bankTransfer ? 'bank_transfer' : 'card',
      durationDays: widget.durationDays,
    );

    // 2. Create ticket
    SupportService.instance.createTicket(
      subject: 'Paiement : ${widget.planName}',
      initialMessage: message,
    );

    // 3. Navigate back to main App Shell with Support client active (Image 2!)
    AppNavigationService.instance.navigateToModule(context, AppModule.support);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: widget.durationDays));
    final dateFormat = DateFormat('dd MMMM, yyyy HH:mm', 'fr_FR');
    final dateRangeStr = '${dateFormat.format(now)} → ${dateFormat.format(endDate)}';

    // Financial breakdown calculations
    final double timbre = 1.000;
    final double netTtc = widget.priceTtc;
    final double totalTtcWithTimbre = netTtc + timbre;
    final double totalHt = netTtc / 1.19;
    final double tva = netTtc - totalHt;

    final numberFormat = NumberFormat('#,##0.000', 'fr_FR');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Confirmer le paiement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: AppColors.border),

            // ─── Scrollable Content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Name & Dates
                    Text(
                      widget.planName == 'Plan Annuel'
                          ? 'Abonnement Annuel'
                          : widget.planName == 'Plan Mensuel'
                              ? 'Abonnement Mensuel'
                              : 'Abonnement Personnalisé',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateRangeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Mode de paiement ──────────────────────────────
                    const Text(
                      'Mode de paiement',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Option 1: Carte bancaire
                        Expanded(
                          child: _buildPaymentMethodCard(
                            method: PaymentMethod.card,
                            icon: Icons.credit_card_rounded,
                            title: 'Carte bancaire',
                            subtitle: 'Activation instantanée',
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Option 2: Virement / Versement
                        Expanded(
                          child: _buildPaymentMethodCard(
                            method: PaymentMethod.bankTransfer,
                            icon: Icons.account_balance_rounded,
                            title: 'Virement / Versement',
                            subtitle: 'Activation manuelle',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ─── Bank Details Section (RIB) ────────────────────
                    if (_selectedMethod == PaymentMethod.bankTransfer) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, color: Color(0xFF2980B9), size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Coordonnées bancaires (RIB)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                                // Bank Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B4F72),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    'BTE',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildInfoRow('Banque', _bankName),
                            const SizedBox(height: 8),
                            _buildInfoRow('Titulaire du compte', _accountHolder),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text('RIB', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ),
                                Expanded(
                                  child: Text(
                                    _rib,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 17, color: Colors.black54),
                                  onPressed: _copyRib,
                                  tooltip: 'Copier le RIB',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ─── Steps to activate ────────────────────────────
                      const Text(
                        'Étapes pour activer votre abonnement',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      _buildStepItem('1. Effectuez le virement ou versement du montant indiqué'),
                      _buildStepItem('2. Envoyez le reçu de paiement à notre équipe support'),
                      _buildStepItem('3. Votre abonnement sera activé dans les plus brefs délais'),

                      const SizedBox(height: 16),

                      // Notice: Support Hours
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF9E7),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: const Color(0xFFF9E79F)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.access_time_rounded, color: Color(0xFFB7950B), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Notre équipe est disponible du lundi au vendredi, de 9h à 18h',
                                style: TextStyle(fontSize: 12, color: Color(0xFF7D6608), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Carte bancaire form
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paiement sécurisé par Carte Bancaire',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Le paiement par carte bancaire permet une activation instantanée et automatique de votre licence.',
                              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ─── Price Breakdown Table ─────────────────────────
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),

                    _buildPriceRow('Total (HT)', '${numberFormat.format(totalHt)} DT'),
                    const SizedBox(height: 6),
                    _buildPriceRow('TVA', '${numberFormat.format(tva)} DT'),
                    const SizedBox(height: 6),
                    _buildPriceRow('Timbre fiscal', '${numberFormat.format(timbre)} DT'),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Total (TTC)',
                      '${numberFormat.format(totalTtcWithTimbre)} DT',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Footer Buttons (Responsive & No Overflow) ──────────────
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: const Text('Annuler', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _contactSupportForPayment,
                      icon: const Icon(Icons.headset_mic_rounded, size: 17),
                      label: const Text(
                        'Contacter le support',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
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

  Widget _buildPaymentMethodCard({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMethod == method;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4F9FD) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? const Color(0xFF2980B9) : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF2980B9) : Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFF2980B9) : Colors.black87,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: isSelected ? const Color(0xFF2980B9).withValues(alpha: 0.8) : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black87 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 15 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
