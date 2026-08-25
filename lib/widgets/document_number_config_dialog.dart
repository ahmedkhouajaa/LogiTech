import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class DocumentNumberConfigDialog extends StatefulWidget {
  final String docTypeName;
  final String prefix;
  final int initialNumber;

  const DocumentNumberConfigDialog({
    Key? key,
    required this.docTypeName,
    required this.prefix,
    this.initialNumber = 1,
  }) : super(key: key);

  static Future<int?> show({
    required BuildContext context,
    required String docTypeName,
    required String prefix,
    int initialNumber = 1,
  }) async {
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DocumentNumberConfigDialog(
        docTypeName: docTypeName,
        prefix: prefix,
        initialNumber: initialNumber,
      ),
    );
  }

  @override
  State<DocumentNumberConfigDialog> createState() =>
      _DocumentNumberConfigDialogState();
}

class _DocumentNumberConfigDialogState
    extends State<DocumentNumberConfigDialog> {
  late TextEditingController _numberController;
  int? _parsedNumber;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(
      text: widget.initialNumber.toString(),
    );
    _updateParsedNumber(_numberController.text);
  }

  void _updateParsedNumber(String text) {
    setState(() {
      final val = int.tryParse(text.trim());
      if (val != null && val > 0) {
        _parsedNumber = val;
      } else {
        _parsedNumber = null;
      }
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    if (_parsedNumber == null) return;

    if (_parsedNumber! > 10000) {
      final confirmHigh = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                'Numéro élevé',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Vous avez choisi un numéro élevé. Êtes-vous sûr de vouloir continuer ?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );

      if (confirmHigh != true) return;
    }

    final previewNumber = generateDocNumber(widget.prefix, _parsedNumber!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 26),
            const SizedBox(width: 8),
            const Text(
              'Confirmer la numérotation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment définir le numéro initial à "$previewNumber" ?\n\n'
          'Attention : Cette action est irréversible et ne pourra plus être modifiée par la suite.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    Navigator.of(context).pop(_parsedNumber);
  }

  @override
  Widget build(BuildContext context) {
    final previewDocNumber = _parsedNumber != null
        ? generateDocNumber(widget.prefix, _parsedNumber!)
        : '${widget.prefix}-${DateTime.now().year}----';

    final bool isValid = _parsedNumber != null && _parsedNumber! > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Configurer la Numérotation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Ceci est votre premier ${widget.docTypeName}. Choisissez le numéro de départ pour vos documents.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Prominent Red/Orange Warning Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('⚠️ ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      'Attention : Action irréversible - Ce numéro ne pourra pas être modifié après la création de votre premier document. Assurez-vous d\'avoir entré le bon numéro.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC2410C),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Number Input Label
            const Text(
              'Numéro du Prochain Document',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),

            // TextField
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _updateParsedNumber,
              decoration: InputDecoration(
                hintText: 'Ex: 1 ou 410',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Entrez le numéro que vous souhaitez pour votre prochain document',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 18),

            // Live Preview
            const Text(
              'Aperçu',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                previewDocNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isValid
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isValid ? _onConfirm : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continuer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
