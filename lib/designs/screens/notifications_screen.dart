import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/designs/models/complaint_model.dart';
import 'package:grievance_redressal_system/designs/screens/complaint_detail_screen.dart';

/// A notification is derived from each complaint document.
/// Every status change and submission becomes a notification entry.
/// We also read from a dedicated `notifications` Firestore collection
/// if it exists, and fall back to generating them from complaints.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _complaintsSub;
  List<_NotifItem> _notifications = [];
  bool _isLoading = true;

  // Track which IDs are "read" locally during this session
  final Set<String> _readIds = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Listen to the user's complaints — derive notifications from them
    _complaintsSub = _firestore
        .collection('complaints')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            final notifs = <_NotifItem>[];

            for (final doc in snapshot.docs) {
              final c = ComplaintModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );

              // 1. Submission notification
              notifs.add(_NotifItem(
                id: '${c.complaintId}_submitted',
                complaintId: c.complaintId,
                complaint: c,
                type: _NotifType.submitted,
                title: 'Complaint Submitted',
                body:
                    'Your complaint "${c.title}" has been received and is pending review.',
                time: c.createdAt,
              ));

              // 2. Status-based notifications
              if (c.status == 'In Progress') {
                notifs.add(_NotifItem(
                  id: '${c.complaintId}_inprogress',
                  complaintId: c.complaintId,
                  complaint: c,
                  type: _NotifType.inProgress,
                  title: 'Complaint In Progress',
                  body:
                      'Your complaint "${c.title}" is now being actively worked on.',
                  time: c.createdAt
                      .add(const Duration(hours: 1)), // estimated
                ));
              }

              if (c.status == 'Resolved') {
                notifs.add(_NotifItem(
                  id: '${c.complaintId}_resolved',
                  complaintId: c.complaintId,
                  complaint: c,
                  type: _NotifType.resolved,
                  title: 'Complaint Resolved ✓',
                  body:
                      'Great news! Your complaint "${c.title}" has been resolved.',
                  time: c.createdAt
                      .add(const Duration(days: 1)), // estimated
                ));
              }

              if (c.status == 'Cancelled') {
                notifs.add(_NotifItem(
                  id: '${c.complaintId}_cancelled',
                  complaintId: c.complaintId,
                  complaint: c,
                  type: _NotifType.cancelled,
                  title: 'Complaint Cancelled',
                  body:
                      'Your complaint "${c.title}" has been cancelled.',
                  time: c.createdAt
                      .add(const Duration(minutes: 30)), // estimated
                ));
              }
            }

            // Sort newest first
            notifs.sort((a, b) => b.time.compareTo(a.time));

            setState(() {
              _notifications = notifs;
              _isLoading = false;
            });
          },
          onError: (e) {
            debugPrint('Notifications stream error: $e');
            setState(() => _isLoading = false);
          },
        );
  }

  @override
  void dispose() {
    _complaintsSub?.cancel();
    super.dispose();
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        _readIds.add(n.id);
      }
    });
  }

  int get _unreadCount =>
      _notifications.where((n) => !_readIds.contains(n.id)).length;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  // ── Notif appearance per type ──────────────────────────────────────────────

  Color _bgColor(_NotifType t) {
    switch (t) {
      case _NotifType.submitted:   return const Color(0xFFDCEAFF);
      case _NotifType.inProgress:  return const Color(0xFFFEF3C7);
      case _NotifType.resolved:    return const Color(0xFFDCFCE7);
      case _NotifType.cancelled:   return const Color(0xFFF1F5F9);
    }
  }

  Color _iconColor(_NotifType t) {
    switch (t) {
      case _NotifType.submitted:   return const Color(0xFF2563EB);
      case _NotifType.inProgress:  return const Color(0xFFCA8A04);
      case _NotifType.resolved:    return const Color(0xFF16A34A);
      case _NotifType.cancelled:   return const Color(0xFF64748B);
    }
  }

  IconData _icon(_NotifType t) {
    switch (t) {
      case _NotifType.submitted:   return Icons.send_outlined;
      case _NotifType.inProgress:  return Icons.autorenew;
      case _NotifType.resolved:    return Icons.check_circle_outline;
      case _NotifType.cancelled:   return Icons.cancel_outlined;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF195DE6),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF195DE6)),
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEAFF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.notifications_none_outlined,
                size: 44, color: Color(0xFF195DE6)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You ll get notified when there are\nupdates on your complaints.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Group by date label
    final Map<String, List<_NotifItem>> grouped = {};
    for (final n in _notifications) {
      final label = _dateLabel(n.time);
      grouped.putIfAbsent(label, () => []).add(n);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map((n) => _buildNotifCard(n)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return 'THIS WEEK';
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildNotifCard(_NotifItem n) {
    final isRead = _readIds.contains(n.id);
    final bg = _bgColor(n.type);
    final ic = _iconColor(n.type);
    final icon = _icon(n.type);

    return GestureDetector(
      onTap: () {
        setState(() => _readIds.add(n.id));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaint: n.complaint),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead
                ? const Color(0xFFF1F5F9)
                : ic.withOpacity(0.3),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isRead ? 0.03 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: ic, size: 22),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ic,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          n.complaint.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ic,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(n.time),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

enum _NotifType { submitted, inProgress, resolved, cancelled }

class _NotifItem {
  final String id;
  final String complaintId;
  final ComplaintModel complaint;
  final _NotifType type;
  final String title;
  final String body;
  final DateTime time;

  const _NotifItem({
    required this.id,
    required this.complaintId,
    required this.complaint,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
  });
}