// lib/designs/screens/support_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/services_/chat_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({Key? key}) : super(key: key);

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────────
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ChatService _chatService = ChatService();
  final FocusNode _focusNode = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;       // bot typing indicator
  bool _isLoadingHistory = true;
  String _userName = 'there';
  String _userInitial = 'U';

  // ── Colours ───────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF195DE6);
  static const Color _bg         = Color(0xFFF0F2F8);
  static const Color _userBubble = Color(0xFFDCE8FF);
  static const Color _botBubble  = Colors.white;
  static const Color _textDark   = Color(0xFF1E293B);
  static const Color _textMid    = Color(0xFF64748B);
  static const Color _textLight  = Color(0xFF94A3B8);

  // Quick-reply chip labels
  final List<String> _quickReplies = [
    'How to report?',
    'Track status',
    'Contact support',
    'App guide',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadHistory();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────────

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final fullName = (doc.data()?['fullName'] as String? ?? '').trim();
        final first = fullName.split(' ').first;
        if (first.isNotEmpty) {
          setState(() {
            _userName    = first;
            _userInitial = first[0].toUpperCase();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _chatService.loadChatHistory();
    setState(() {
      _isLoadingHistory = false;
      if (history.isEmpty) {
        // Fresh session — show welcome message
        _messages.add(ChatMessage(
          id: 'welcome',
          role: MessageRole.assistant,
          text:
              'Hello $_userName! 👋 I\'m your Smart Urban Assistant. '
              'How can I help you with your grievances today?',
          timestamp: DateTime.now(),
        ));
      } else {
        _messages.addAll(history);
      }
    });
    _scrollToBottom();
  }

  // ── Messaging ──────────────────────────────────────────────────────────────────

  Future<void> _sendMessage({String? overrideText}) async {
    final text = (overrideText ?? _msgCtrl.text).trim();
    if (text.isEmpty || _isTyping) return;

    _msgCtrl.clear();
    _focusNode.unfocus();

    // Add user message immediately
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      text: text,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(
        message: text,
        history: _messages,
      );

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: MessageRole.assistant,
          text: reply,
          timestamp: DateTime.now(),
        ));
      });
    } on ChatException catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: MessageRole.assistant,
          text: _friendlyError(e),
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }
    _scrollToBottom();
  }

  String _friendlyError(ChatException e) {
    if (e.isNetworkError) {
      return '⚠️ Cannot reach the server. Please check your internet connection and try again.';
    }
    if (e.isOllamaDown) {
      return '⚠️ The AI model is currently offline. Please try again in a few minutes.';
    }
    if (e.isTimeout) {
      return '⏳ The AI is taking too long to respond. Please try again.';
    }
    return '⚠️ ${e.message}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: _primary))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (_, i) {
                      // Typing bubble at end
                      if (_isTyping && i == _messages.length) {
                        return _buildTypingBubble();
                      }
                      final msg  = _messages[i];
                      final prev = i > 0 ? _messages[i - 1] : null;
                      final showDate = prev == null ||
                          !_sameDay(prev.timestamp, msg.timestamp);
                      return Column(
                        children: [
                          if (showDate) _buildDateChip(msg.timestamp),
                          _buildMessageRow(msg),
                        ],
                      );
                    },
                  ),
          ),

          // Quick reply chips
          _buildQuickReplies(),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: _textDark),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Bot avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            ),
            child: const Icon(Icons.support_agent, color: _primary, size: 24),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Support Assistant',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textDark),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Online',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: _textMid),
          onPressed: _showOptionsMenu,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              _optionTile(Icons.delete_sweep_outlined, 'Clear Chat History',
                  Colors.red, _clearHistory),
              _optionTile(Icons.refresh, 'New Conversation',
                  _primary, _startNewConversation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _clearHistory() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        id: 'welcome_new',
        role: MessageRole.assistant,
        text: 'Hello! 👋 How can I help you today?',
        timestamp: DateTime.now(),
      ));
    });
  }

  void _startNewConversation() => _clearHistory();

  // ── Message row ───────────────────────────────────────────────────────────────

  Widget _buildMessageRow(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final timeStr = _formatTime(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          if (!isUser) ...[
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: const Icon(Icons.support_agent, color: _primary, size: 18),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble column
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isError
                        ? const Color(0xFFFFF3CD)
                        : (isUser ? _userBubble : _botBubble),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: msg.isError
                          ? const Color(0xFF92400E)
                          : _textDark,
                      height: 1.45,
                    ),
                  ),
                ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: _textLight),
                  ),
                ),
              ],
            ),
          ),

          // User avatar
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFDCEAFF),
              child: Text(
                _userInitial,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────────

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            ),
            child: const Icon(Icons.support_agent, color: _primary, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _botBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _animatedDot(0),
                const SizedBox(width: 4),
                _animatedDot(1),
                const SizedBox(width: 4),
                _animatedDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 500 + index * 180),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: _textLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // ── Date chip ─────────────────────────────────────────────────────────────────

  Widget _buildDateChip(DateTime dt) {
    final now = DateTime.now();
    String label;
    if (_sameDay(dt, now)) {
      label = 'Today, ${_formatTime(dt)}';
    } else {
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${months[dt.month]} ${dt.day}, ${_formatTime(dt)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: _textMid,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  // ── Quick replies ─────────────────────────────────────────────────────────────

  Widget _buildQuickReplies() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickReplies
              .map(
                (label) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _sendMessage(overrideText: label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment icon
          GestureDetector(
            onTap: () {}, // extend later for image sending
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.attach_file,
                  color: _textMid, size: 20),
            ),
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isTyping,
                      style: const TextStyle(
                          fontSize: 15, color: _textDark),
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle:
                            TextStyle(color: _textLight, fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  // Emoji button (placeholder)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 6),
                    child: Icon(Icons.sentiment_satisfied_outlined,
                        color: _textLight, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: _isTyping ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _isTyping ? _textLight : _primary,
                shape: BoxShape.circle,
                boxShadow: _isTyping
                    ? []
                    : [
                        BoxShadow(
                          color: _primary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime dt) {
    final hour   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm   = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }
}