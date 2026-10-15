import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_chat_service.dart';
import '../utils/constants.dart';

class AiChatModalSheet extends StatefulWidget {
  final bool isDialog;
  const AiChatModalSheet({super.key, this.isDialog = false});

  static void show(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktopOrWeb = media.size.width > 700;

    if (isDesktopOrWeb) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withAlpha(120),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 580,
              maxHeight: 760,
            ),
            child: const AiChatModalSheet(isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const AiChatModalSheet(isDialog: false),
      );
    }
  }

  @override
  State<AiChatModalSheet> createState() => _AiChatModalSheetState();
}

class _AiChatModalSheetState extends State<AiChatModalSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasInputText = false;

  final List<_QuickSuggestionItem> _quickSuggestions = const [
    _QuickSuggestionItem(
      label: "État de la trésorerie",
      icon: Icons.account_balance_wallet_outlined,
      prompt: "État trésorerie",
    ),
    _QuickSuggestionItem(
      label: "Factures impayées",
      icon: Icons.receipt_long_outlined,
      prompt: "Factures impayées ?",
    ),
    _QuickSuggestionItem(
      label: "Alertes de stock",
      icon: Icons.inventory_2_outlined,
      prompt: "Alerte stock articles",
    ),
    _QuickSuggestionItem(
      label: "Devis en cours",
      icon: Icons.request_quote_outlined,
      prompt: "Devis en cours",
    ),
    _QuickSuggestionItem(
      label: "Historique paiements",
      icon: Icons.payments_outlined,
      prompt: "Historique des paiements",
    ),
  ];

  @override
  void initState() {
    super.initState();
    AiChatService.instance.initialize();
    _inputController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() {
        _hasInputText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? text]) {
    final query = text ?? _inputController.text;
    if (query.trim().isEmpty) return;

    _inputController.clear();
    AiChatService.instance.sendMessage(query, context);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final isDialog = widget.isDialog;

    final borderRadius = isDialog
        ? BorderRadius.circular(20)
        : const BorderRadius.vertical(top: Radius.circular(20));

    final containerHeight = isDialog
        ? mediaQuery.size.height.clamp(520.0, 760.0)
        : mediaQuery.size.height * 0.85;

    return Container(
      height: containerHeight,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 160 : 70),
            blurRadius: isDialog ? 32 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          children: [
            // ─── Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Column(
                children: [
                  if (!isDialog)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(isDark ? 70 : 40),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "LogiTech Copilot",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(isDark ? 30 : 20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.primary.withAlpha(isDark ? 60 : 35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    "ASSISTANT IA",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "En direct • Analyse ERP & Trésorerie",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        onPressed: () => _confirmClearHistory(context, isDark),
                        tooltip: "Effacer la discussion",
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.pop(context),
                        tooltip: "Fermer",
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Messages List ─────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<AiChatMessage>>(
                stream: AiChatService.instance.messagesStream,
                initialData: AiChatService.instance.currentMessages,
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
                  final isThinking = AiChatService.instance.isProcessing;
                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    itemCount: messages.length + (isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildThinkingBubble(isDark, borderColor);
                      }
                      final msg = messages[index];
                      return _buildMessageBubble(msg, isDark, borderColor);
                    },
                  );
                },
              ),
            ),

            // ─── Quick Suggestion Chips ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: _quickSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _quickSuggestions[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _handleSend(item.prompt),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 14,
                                color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ─── Input Bar ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13.5,
                              ),
                              onSubmitted: (_) => _handleSend(),
                              decoration: InputDecoration(
                                hintText: "Demandez une analyse, un montant, une situation...",
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: _hasInputText ? AppColors.primary : Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _hasInputText ? () => _handleSend() : null,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _hasInputText
                                      ? AppColors.primary
                                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                ),
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: _hasInputText
                                      ? Colors.white
                                      : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "LogiTech Copilot analyse vos données d'entreprise en direct.",
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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

  void _confirmClearHistory(BuildContext context, bool isDark) {
    if (AiChatService.instance.currentMessages.length <= 1) {
      AiChatService.instance.clearHistory();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Effacer l'historique ?",
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          "Toutes les discussions archivées sur cet appareil seront réinitialisées.",
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Annuler",
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AiChatService.instance.clearHistory();
            },
            child: const Text("Effacer"),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(bool isDark, Color borderColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(4),
                ),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "LogiTech Copilot analyse les données...",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

  Widget _buildMessageBubble(AiChatMessage msg, bool isDark, Color borderColor) {
    final timeStr =
        "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}";

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(50),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withAlpha(isDark ? 60 : 35),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        topLeft: Radius.circular(4),
                      ),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rich formatted content (handles Markdown, dividers, bold, lists)
                        _FormattedAiMessage(text: msg.text, isDark: isDark),

                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: msg.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Réponse copiée dans le presse-papiers"),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Optional Data KPI Card
                  if (msg.dataCard != null) ...[
                    const SizedBox(height: 8),
                    _buildDataCard(msg.dataCard!, isDark, borderColor),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(Map<String, dynamic> card, bool isDark, Color borderColor) {
    final rawColor = card['color'];
    Color cardColor = AppColors.primary;
    if (rawColor is Color) {
      cardColor = rawColor;
    } else if (rawColor is int) {
      cardColor = Color(rawColor);
    }

    final title = card['title']?.toString() ?? '';
    final value = card['value']?.toString() ?? '';
    final badge = card['badge']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cardColor.withAlpha(isDark ? 25 : 12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardColor.withAlpha(isDark ? 70 : 45),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cardColor.withAlpha(isDark ? 45 : 20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.analytics_outlined, color: cardColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: cardColor.withAlpha(isDark ? 45 : 25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cardColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickSuggestionItem {
  final String label;
  final IconData icon;
  final String prompt;
  const _QuickSuggestionItem({
    required this.label,
    required this.icon,
    required this.prompt,
  });
}

/// Robust, lightweight formatter that converts raw markdown text
/// (bolding, lists, headers, dividers) into clean, elegant Flutter widgets.
class _FormattedAiMessage extends StatelessWidget {
  final String text;
  final bool isDark;

  const _FormattedAiMessage({
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        if (widgets.isNotEmpty && widgets.last is! SizedBox && widgets.last is! Divider) {
          widgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      // Check for horizontal divider: --- or *** or ___
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: dividerColor,
            ),
          ),
        );
        continue;
      }

      // Check for headings (#, ##, ###)
      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: _buildRichLine(
              trimmed.substring(4),
              isHeader: true,
              fontSize: 14.0,
              baseColor: textColor,
            ),
          ),
        );
        continue;
      } else if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final content = trimmed.startsWith('## ') ? trimmed.substring(3) : trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 5),
            child: _buildRichLine(
              content,
              isHeader: true,
              fontSize: 15.0,
              baseColor: textColor,
            ),
          ),
        );
        continue;
      }

      // Check for bullet list item: *, -, • (including indented)
      final isSubBullet = line.startsWith('  * ') || line.startsWith('  - ') || line.startsWith('    * ');
      final isBullet = trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('• ');

      if (isBullet) {
        final bulletContent = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: isSubBullet ? 18.0 : 2.0,
              top: 2.5,
              bottom: 2.5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  width: isSubBullet ? 4 : 5,
                  height: isSubBullet ? 4 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildRichLine(
                    bulletContent,
                    fontSize: 13.5,
                    baseColor: textColor,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Standard text line
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichLine(
            trimmed,
            fontSize: 13.5,
            baseColor: textColor,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildRichLine(
    String rawText, {
    required double fontSize,
    required Color baseColor,
    bool isHeader = false,
  }) {
    final spans = <InlineSpan>[];
    final boldColor = isDark ? Colors.white : const Color(0xFF0F172A);

    // Matches **bold** or *italic*
    final regex = RegExp(r'(\*\*([^*]+)\*\*)|(\*([^*]+)\*)');
    int lastEnd = 0;

    for (final match in regex.allMatches(rawText)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: rawText.substring(lastEnd, match.start),
            style: TextStyle(
              color: baseColor,
              fontSize: fontSize,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
              height: 1.45,
            ),
          ),
        );
      }

      if (match.group(2) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              color: boldColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: match.group(4),
            style: TextStyle(
              color: baseColor.withAlpha(210),
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
              height: 1.45,
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < rawText.length) {
      spans.add(
        TextSpan(
          text: rawText.substring(lastEnd),
          style: TextStyle(
            color: baseColor,
            fontSize: fontSize,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
            height: 1.45,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: fontSize,
        height: 1.45,
      ),
    );
  }
}
