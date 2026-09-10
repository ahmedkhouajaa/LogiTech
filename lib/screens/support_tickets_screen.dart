import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/support_ticket.dart';
import '../services/support_service.dart';
import '../services/permission_service.dart';
import '../widgets/support_chat_image_viewer.dart';
import '../utils/constants.dart';
import '../utils/anti_spam_guard.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  SupportTicket? _selectedTicket;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String? _attachedImageBase64;
  bool _isUploadingImage = false;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isUploadingImage = true);
    final dataUri = await SupportImageHelper.pickAndProcessImage(context: context);
    if (mounted) {
      setState(() {
        _attachedImageBase64 = dataUri;
        _isUploadingImage = false;
      });
    }
  }

  void _sendMessage() async {
    if (_isSending) return; // Debounce rapid taps or fast enter spam

    final text = _messageController.text.trim();
    final image = _attachedImageBase64;
    if ((text.isEmpty && image == null) || _selectedTicket == null) return;

    // 1. Anti-spam pre-flight check
    final spamCheck = AntiSpamGuard.instance.checkMessageAllowed(text);
    if (!spamCheck.isAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spamCheck.message,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706), // Amber warning
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: spamCheck.waitSeconds > 3 ? 4 : 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();
    setState(() {
      _attachedImageBase64 = null;
    });

    try {
      await SupportService.instance.sendMessage(
        ticketId: _selectedTicket!.id,
        text: text,
        imageUrl: image,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AntiSpamException ? e.message : 'Erreur d\'envoi: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showNewTicketDialog() {
    final subjectController = TextEditingController();
    final initialMsgController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Nouveau ticket de support',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Décrivez votre problème ou votre question pour notre équipe d\'assistance.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Sujet / Objet *',
                    hintText: 'Ex: Problème d\'impression des factures',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Veuillez saisir un sujet' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: initialMsgController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Message *',
                    hintText: 'Expliquez en détail votre demande...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Veuillez rédiger un message' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;

              final spamCheck = AntiSpamGuard.instance.checkTicketCreationAllowed();
              if (!spamCheck.isAllowed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(spamCheck.message)),
                      ],
                    ),
                    backgroundColor: const Color(0xFFD97706),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              try {
                final ticket = await SupportService.instance.createTicket(
                  subject: subjectController.text.trim(),
                  initialMessage: initialMsgController.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx);

                setState(() {
                  _selectedTicket = ticket;
                });
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(e is AntiSpamException ? e.message : 'Erreur: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Créer le ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          if (isMobile) {
            return _selectedTicket != null
                ? _buildChatDetail(isMobile)
                : _buildTicketsList(isMobile);
          }

          return Row(
            children: [
              // Left Column: Tickets List (Width ~340px)
              SizedBox(
                width: 340,
                child: _buildTicketsList(isMobile),
              ),
              VerticalDivider(width: 1, color: AppColors.border),
              // Right Column: Chat Detail
              Expanded(
                child: _selectedTicket != null
                    ? _buildChatDetail(isMobile)
                    : _buildEmptyState(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Tickets List Sidebar / Master View ──────────────────────────────
  Widget _buildTicketsList(bool isMobile) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Header Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support & Aide',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Vos tickets d\'assistance',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showNewTicketDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isMobile ? 'Nouveau' : 'Nouveau ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Tickets List Stream
          Expanded(
            child: StreamBuilder<List<SupportTicket>>(
              stream: SupportService.instance.getTicketsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tickets = snapshot.data ?? [];

                // Keep _selectedTicket synchronized with latest status/updates from stream
                if (_selectedTicket != null) {
                  final matching = tickets.where((t) => t.id == _selectedTicket!.id);
                  if (matching.isNotEmpty && matching.first != _selectedTicket) {
                    _selectedTicket = matching.first;
                  }
                }

                if (tickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.question_answer_outlined, size: 48, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucun ticket pour le moment',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Besoin d\'assistance ? Créez un nouveau ticket et notre équipe vous répondra rapidement.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _showNewTicketDialog,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Créer un ticket'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    final isSelected = _selectedTicket?.id == ticket.id;

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                        onTap: () {
                          setState(() {
                            _selectedTicket = ticket;
                          });
                        },
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: _getStatusColor(ticket.status).withValues(alpha: 0.15),
                          child: Icon(
                            _getStatusIcon(ticket.status),
                            size: 20,
                            color: _getStatusColor(ticket.status),
                          ),
                        ),
                        title: Text(
                          ticket.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(
                              ticket.lastMessage.isNotEmpty ? ticket.lastMessage : 'Aucun message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(ticket.status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Text(
                                    ticket.statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(ticket.status),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('dd/MM HH:mm').format(ticket.updatedAt),
                                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chat Detail Screen ──────────────────────────────────────────────
  Widget _buildChatDetail(bool isMobile) {
    final ticket = _selectedTicket!;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Chat Top Bar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _selectedTicket = null),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getStatusColor(ticket.status),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Statut : ${ticket.statusLabel} • Ticket #${ticket.id.substring(0, ticket.id.length > 8 ? 8 : ticket.id.length)}',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser',
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          ),

          // Messages List View
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: SupportService.instance.getMessagesStream(ticket.id),
              initialData: SupportService.instance.getLocalMessages(ticket.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(child: Text('Aucun message. Ecrivez ci-dessous pour discuter.'));
                }

                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageItem(msg);
                  },
                );
              },
            ),
          ),

          // Image Attachment Preview Banner
          if (_attachedImageBase64 != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                boxShadow: AppShadows.sm,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: ChatImageWidget(
                        imageUrl: _attachedImageBase64!,
                        maxHeight: 44,
                        maxWidth: 44,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Image jointe prête à l\'envoi',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Envoyez directement ou ajoutez un commentaire',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Supprimer',
                    onPressed: () => setState(() => _attachedImageBase64 = null),
                  ),
                ],
              ),
            ),

          // Chat Input Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                  tooltip: 'Joindre une image / capture',
                  onPressed: _isUploadingImage ? null : _pickImage,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Rédigez votre message...',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _isSending ? AppColors.primary.withValues(alpha: 0.6) : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: InkWell(
                    onTap: _isSending ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Single Message Item Builder ─────────────────────────────────────
  Widget _buildMessageItem(SupportMessage msg) {
    final isUser = msg.isFromUser;
    final initial = msg.senderInitial.isNotEmpty
        ? msg.senderInitial
        : (PermissionService.instance.userInitial);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // Support Avatar Icon
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Icon(Icons.support_agent_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],

          // Message Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                    ChatImageWidget(
                      imageUrl: msg.imageUrl!,
                      isUser: isUser,
                    ),
                    if (msg.text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (msg.text.isNotEmpty)
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isUser ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white.withValues(alpha: 0.75) : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            // Custom User Avatar with Status Badge (Matching user's screenshots!)
            _buildUserAvatarWithStatusBadge(
              initial: initial,
              status: msg.status,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Custom User Avatar Widget with Status Badge ─────────────────────
  /// Renders a small round avatar with the user's initial (e.g. 'H')
  /// and a status badge overlay on the bottom right corner:
  /// - Status 'sent' / Sending: Empty circle badge (Matching Screenshot 1)
  /// - Status 'read' / Delivered: Checkmark inside a circle badge (Matching Screenshot 2)
  Widget _buildUserAvatarWithStatusBadge({
    required String initial,
    required String status,
  }) {
    final isRead = status == 'read';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Blue rounded avatar bubble containing user initial
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Center(
            child: Text(
              initial.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Status badge icon at the bottom right corner
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: isRead
                // Delivered / Read Status: Checkmark inside circle (Matching Screenshot 2)
                ? Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.primary,
                  )
                // Just Sent Status: Empty circle (Matching Screenshot 1)
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Empty Selection State ───────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent_rounded, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Centre de Support & Assistance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionnez un ticket dans la liste à gauche pour voir la discussion ou créez un nouveau ticket.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showNewTicketDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nouveau ticket de support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Colors & Icons for Ticket Status ─────────────────────────
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return AppColors.warning;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      case 'open':
      default:
        return AppColors.primary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return Icons.pending_rounded;
      case 'resolved':
      case 'closed':
        return Icons.check_circle_rounded;
      case 'open':
      default:
        return Icons.mark_chat_unread_rounded;
    }
  }
}
