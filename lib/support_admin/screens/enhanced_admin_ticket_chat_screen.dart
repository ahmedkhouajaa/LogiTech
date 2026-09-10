import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/ticket_stream_service.dart';
import '../../widgets/support_chat_image_viewer.dart';

class EnhancedAdminTicketChatScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticketData;

  const EnhancedAdminTicketChatScreen({
    super.key,
    required this.ticketId,
    required this.ticketData,
  });

  @override
  State<EnhancedAdminTicketChatScreen> createState() => _EnhancedAdminTicketChatScreenState();
}

class _EnhancedAdminTicketChatScreenState extends State<EnhancedAdminTicketChatScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentStatus;
  late String _currentPriority;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  String? _attachedImageBase64;
  bool _isUploadingImage = false;
  bool _isSending = false;

  // Quick reply canned templates
  final List<String> _templates = [
    'Bonjour, nous prenons en charge votre demande immédiatement.',
    'Votre virement bancaire a été vérifié et votre licence a été validée avec succès.',
    'Pouvez-vous nous transmettre une capture d\'écran de l\'erreur affichée ?',
    'Le problème a été résolu sur notre serveur. Veuillez redémarrer l\'application.',
    'Votre demande a été transmise à notre équipe technique supérieure.',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticketData['status'] ?? 'open';
    _currentPriority = widget.ticketData['priority'] ?? 'medium';

    // Initialize stream ONCE to prevent rebuild subscription resets & flickering
    _messagesStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(widget.ticketId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();

    _markTicketAsRead();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markTicketAsRead() async {
    try {
      final ticketRef = FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId);
      await ticketRef.update({
        'agentLastReadAt': FieldValue.serverTimestamp(),
      });

      // Mark unread client messages as read
      final unreadDocs = await ticketRef
          .collection('messages')
          .where('status', isEqualTo: 'sent')
          .get();

      if (unreadDocs.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in unreadDocs.docs) {
          batch.update(doc.reference, {'status': 'read'});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[EnhancedAdminTicketChatScreen] Error marking ticket read: $e');
    }
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

  Future<void> _sendMessage() async {
    if (_isSending) return; // Debounce rapid clicks

    final text = _replyController.text.trim();
    final image = _attachedImageBase64;
    if (text.isEmpty && image == null) return;

    setState(() => _isSending = true);
    _replyController.clear();
    setState(() => _attachedImageBase64 = null);

    try {
      final agent = FirebaseAuth.instance.currentUser;
      final agentName = agent?.displayName ?? agent?.email?.split('@').first ?? 'Support LogiTech';
      final agentInitial = agentName.isNotEmpty ? agentName[0].toUpperCase() : 'S';

      final batch = FirebaseFirestore.instance.batch();

      // 1. Append message to ticket messages subcollection
      final msgRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .doc();

      final msgData = <String, dynamic>{
        'ticketId': widget.ticketId,
        'senderId': agent?.uid ?? 'agent',
        'senderName': agentName,
        'senderEmail': agent?.email ?? '',
        'senderInitial': agentInitial,
        'isFromSupport': true,
        'isFromUser': false,
        'content': text.isNotEmpty ? text : '📷 Image jointe',
        'text': text,
        'status': 'read',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (image != null && image.isNotEmpty) {
        msgData['imageUrl'] = image;
      }

      batch.set(msgRef, msgData);

      // 2. Update ticket status & last message
      final ticketRef = FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId);
      batch.update(ticketRef, {
        'lastMessage': text.isNotEmpty ? text : '📷 Image jointe',
        'status': _currentStatus == 'open' ? 'in_progress' : _currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('[EnhancedAdminTicketChatScreen] Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _currentStatus = newStatus);
    await TicketStreamService.instance.updateTicketStatus(
      ticketId: widget.ticketId,
      status: newStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.ticketData['subject'] ?? 'Ticket Support';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(
              '#${widget.ticketId.substring(0, widget.ticketId.length >= 8 ? 8 : widget.ticketId.length)} • Client: ${widget.ticketData['userName'] ?? "N/A"}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Live SLA Countdown Chip (isolated to prevent chat list rebuilds)
          _SlaCountdownChip(
            deadline: (widget.ticketData['slaDeadline'] as Timestamp?)?.toDate() ??
                DateTime.now().add(const Duration(hours: 4)),
          ),
        ],
      ),
      body: Row(
        children: [
          // ─── Main Chat Pane ────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Real-time Chat Messages
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      // Only show full loader if waiting AND has no cached data
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('Aucun message. Envoyez une réponse au client.', style: TextStyle(color: Colors.black54)),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final m = docs[index].data();
                          final isSupport = m['isFromSupport'] == true || m['isFromUser'] == false;
                          final date = (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final content = (m['content'] ?? m['text'] ?? '').toString();
                          final imageUrl = (m['imageUrl'] ?? '').toString();

                          return Align(
                            alignment: isSupport ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 520),
                              decoration: BoxDecoration(
                                color: isSupport ? const Color(0xFF2563EB) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSupport ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isSupport ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSupport ? 'Vous (Support)' : (m['senderName'] ?? 'Client'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSupport ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  if (imageUrl.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    ChatImageWidget(
                                      imageUrl: imageUrl,
                                      isUser: isSupport,
                                      maxHeight: 220,
                                      maxWidth: 320,
                                    ),
                                  ],
                                  if (content.isNotEmpty && content != '📷 Image jointe') ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      content,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSupport ? Colors.white : const Color(0xFF0F172A),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('HH:mm').format(date),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSupport ? Colors.white60 : Colors.black38,
                                    ),
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

                // Quick Response Templates Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      const Text('Réponse rapide : ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          hint: const Text('Choisir un modèle...', style: TextStyle(fontSize: 12)),
                          items: _templates.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _replyController.text = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Attachment Preview Banner if selected
                if (_attachedImageBase64 != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: ChatImageWidget(
                              imageUrl: _attachedImageBase64!,
                              maxHeight: 40,
                              maxWidth: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Capture/Image jointe prête à l\'envoi',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Supprimer',
                          onPressed: () => setState(() => _attachedImageBase64 = null),
                        ),
                      ],
                    ),
                  ),

                // Message Composer
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: _isUploadingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2563EB), size: 22),
                        tooltip: 'Joindre une capture / image',
                        onPressed: _isUploadingImage ? null : _pickImage,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Rédiger une réponse au client...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Envoyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Right Sidebar: Ticket & Client Metadata ─────────────────
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Détails du Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Divider(height: 24),

                _infoItem('Statut du ticket', DropdownButton<String>(
                  value: _currentStatus,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Ouvert')),
                    DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
                    DropdownMenuItem(value: 'resolved', child: Text('Résolu')),
                    DropdownMenuItem(value: 'closed', child: Text('Fermé')),
                  ],
                  onChanged: (v) => v != null ? _updateStatus(v) : null,
                )),

                const SizedBox(height: 12),
                _infoText('Priorité', _currentPriority.toUpperCase()),
                const SizedBox(height: 12),
                _infoText('Client', widget.ticketData['userName'] ?? 'N/A'),
                const SizedBox(height: 12),
                _infoText('Email', widget.ticketData['userEmail'] ?? 'N/A'),
                const SizedBox(height: 12),
                _infoText('Entreprise (Tenant)', widget.ticketData['enterpriseName'] ?? widget.ticketData['enterpriseId'] ?? 'N/A'),

                const Spacer(),

                // Mark as resolved button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus('resolved'),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Marquer comme Résolu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _infoItem(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _infoText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      ],
    );
  }
}

/// Isolated SLA countdown chip that ticks independently without triggering parent rebuilds
class _SlaCountdownChip extends StatefulWidget {
  final DateTime deadline;

  const _SlaCountdownChip({required this.deadline});

  @override
  State<_SlaCountdownChip> createState() => _SlaCountdownChipState();
}

class _SlaCountdownChipState extends State<_SlaCountdownChip> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.deadline.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remaining = widget.deadline.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNegative = _remaining.isNegative;
    final hours = _remaining.inHours.abs();
    final mins = _remaining.inMinutes.abs().remainder(60);
    final secs = _remaining.inSeconds.abs().remainder(60);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNegative ? const Color(0xFFDC2626) : const Color(0xFF059669),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            isNegative
                ? 'SLA Dépassé'
                : 'SLA: ${hours}h ${mins}m ${secs}s',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
