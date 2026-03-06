// ignore_for_file: deprecated_member_use
// ✅ FIXED: removed self-import (import admin_profile.dart) that broke all settings sheets
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:grievance_redressal_system/designs/mainpages/admin_login_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;

  // ── Real-time stream subscriptions ───────────────────────────
  // These auto-update the UI whenever Firestore data changes
  Stream<DocumentSnapshot>? _adminStream;
  Stream<QuerySnapshot>?     _complaintsStream;

  bool   _isUploadingPhoto = false;
  File?  _pickedImageFile;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // ✅ REAL-TIME: listen to admin doc changes
      _adminStream = _firestore.collection('admins').doc(uid).snapshots();
      // ✅ REAL-TIME: listen to all complaints changes
      _complaintsStream = _firestore.collection('complaints').snapshots();
    }
  }

  // ── Photo upload ─────────────────────────────────────────────
  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() { _pickedImageFile = File(picked.path); _isUploadingPhoto = true; });

    try {
      final uid = _auth.currentUser!.uid;
      final ref = _storage.ref().child('admin_photos/$uid.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      // ✅ Update Firestore → stream auto-refreshes avatar instantly
      await _firestore.collection('admins').doc(uid).update({'profilePhoto': url});
      await _auth.currentUser!.updatePhotoURL(url);
      if (mounted) setState(() { _pickedImageFile = null; _isUploadingPhoto = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnack(context, 'Upload failed: $e', isError: true);
      }
    }
  }

  // ── Sign out ─────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()), (_) => false);
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _monthName(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _copyAdminId() {
    final uid = _auth.currentUser?.uid ?? '';
    final shortId = uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();
    Clipboard.setData(ClipboardData(text: shortId));
    _showSnack(context, 'Admin ID $shortId copied!');
  }

  // ════════════════════════════════════════════════════════════
  // BUILD — outer shell: wait for admin doc stream
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_adminStream == null || _complaintsStream == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4FF),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A4DB7))),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _adminStream,
      builder: (context, adminSnap) {
        // Loading state
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F4FF),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1A4DB7))),
          );
        }

        // ✅ Admin data - auto-updates whenever Firestore doc changes
        final adminData = adminSnap.data?.data() as Map<String, dynamic>? ?? {};
        final name       = adminData['fullName']    as String? ?? _auth.currentUser?.displayName ?? 'Admin';
        final role       = adminData['role']         as String? ?? 'Senior Infrastructure Admin';
        final department = adminData['department']   as String? ?? 'Department of Urban Development';
        final email      = adminData['email']        as String? ?? _auth.currentUser?.email ?? '';
        final phone      = adminData['phone']        as String? ?? '';
        final photoUrl   = adminData['profilePhoto'] as String?;

        // Member since
        String memberSince = '';
        final createdAt = adminData['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final d = createdAt.toDate();
          memberSince = '${_monthName(d.month)} ${d.year}';
        } else {
          final meta = _auth.currentUser?.metadata.creationTime;
          if (meta != null) memberSince = '${_monthName(meta.month)} ${meta.year}';
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                _buildHeader(name, role, department, photoUrl, memberSince),
                const SizedBox(height: 20),
                _buildQuickActions(adminData),
                const SizedBox(height: 20),

                // ✅ Stats section also uses real-time complaints stream
                _buildSection('Live Statistics', _buildStatsGrid()),
                const SizedBox(height: 20),
                _buildSection('Resolution Efficiency', _buildEfficiencyCard()),
                const SizedBox(height: 20),

                _buildSection(
                  'Personal Information',
                  _buildPersonalInfo(name, email, phone, department, role),
                  action: ('Edit', () => _showEditProfileSheet(adminData)),
                ),
                const SizedBox(height: 20),
                _buildSection('Account', _buildAccountInfo()),
                const SizedBox(height: 20),
                _buildSection('Settings', _buildSettingsList(adminData)),
                const SizedBox(height: 20),
                _buildSignOutButton(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════
  Widget _buildHeader(String name, String role, String dept,
      String? photoUrl, String memberSince) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1A4DB7),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 40),
          const Expanded(
            child: Center(child: Text('My Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          GestureDetector(
            onTap: _signOut,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Avatar with real-time photo
        Stack(children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: ClipOval(
              child: _pickedImageFile != null
                  ? Image.file(_pickedImageFile!, fit: BoxFit.cover)
                  : photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl, fit: BoxFit.cover,
                          loadingBuilder: (_, child, p) => p == null
                              ? child
                              : Container(
                                  color: const Color(0xFF2563EB),
                                  child: const Center(child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))),
                          errorBuilder: (_, __, ___) => _avatarFallback(name),
                        )
                      : _avatarFallback(name),
            ),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                ),
                child: _isUploadingPhoto
                    ? const Padding(padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                            color: Color(0xFF1A4DB7), strokeWidth: 2))
                    : const Icon(Icons.camera_alt_rounded,
                        color: Color(0xFF1A4DB7), size: 16),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        Text(name, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20)),
          child: Text(role, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Text(dept, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
        if (memberSince.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.calendar_today_outlined,
                size: 11, color: Colors.white.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text('Member since $memberSince',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
          ]),
        ],
      ]),
    );
  }

  Widget _avatarFallback(String name) {
    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    return Container(
      color: const Color(0xFF2563EB),
      child: Center(child: Text(initials.isEmpty ? 'A' : initials,
          style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
    );
  }

  // ════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ════════════════════════════════════════════════════════════
  Widget _buildQuickActions(Map<String, dynamic> adminData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(child: _quickBtn(Icons.edit_outlined,   'Edit Profile',
            const Color(0xFF1A4DB7), () => _showEditProfileSheet(adminData))),
        const SizedBox(width: 10),
        Expanded(child: _quickBtn(Icons.lock_outline,    'Security',
            const Color(0xFF6366F1), _showSecuritySheet)),
        const SizedBox(width: 10),
        Expanded(child: _quickBtn(Icons.content_copy,   'Copy ID',
            const Color(0xFF10B981), _copyAdminId)),
      ]),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // STATS GRID — uses complaints stream
  // ════════════════════════════════════════════════════════════
  Widget _buildStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _complaintsStream,
      builder: (ctx, snap) {
        int total = 0, resolved = 0, pending = 0, escalated = 0;

        if (snap.hasData) {
          total = snap.data!.docs.length;
          for (var d in snap.data!.docs) {
            final s = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
            switch (s.toLowerCase()) {
              case 'resolved':    resolved++;    break;
              case 'pending':     pending++;     break;
              case 'escalated':   escalated++;   break;
            }
          }
        }

        return GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7,
          children: [
            _statTile('Total',     total,     Icons.inbox_rounded,         const Color(0xFF1A4DB7)),
            _statTile('Pending',   pending,   Icons.hourglass_top_rounded, const Color(0xFFF59E0B)),
            _statTile('Resolved',  resolved,  Icons.check_circle_rounded,  const Color(0xFF10B981)),
            _statTile('Escalated', escalated, Icons.warning_amber_rounded, const Color(0xFFEF4444)),
          ],
        );
      },
    );
  }

  Widget _statTile(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$value', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ]),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // EFFICIENCY CARD — uses complaints stream
  // ════════════════════════════════════════════════════════════
  Widget _buildEfficiencyCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _complaintsStream,
      builder: (ctx, snap) {
        int total = 0, resolved = 0;
        if (snap.hasData) {
          total = snap.data!.docs.length;
          for (var d in snap.data!.docs) {
            final s = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
            if (s.toLowerCase() == 'resolved') resolved++;
          }
        }

        final pct = (total == 0 ? 0.0 : (resolved / total) * 100).clamp(0.0, 100.0);
        Color barColor;
        String ratingLabel;
        if (pct >= 75)      { barColor = const Color(0xFF10B981); ratingLabel = 'Excellent'; }
        else if (pct >= 50) { barColor = const Color(0xFF1A4DB7); ratingLabel = 'Good'; }
        else if (pct >= 25) { barColor = const Color(0xFFF59E0B); ratingLabel = 'Moderate'; }
        else                { barColor = const Color(0xFFEF4444); ratingLabel = 'Needs Attention'; }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${pct.toStringAsFixed(1)}%', style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800, color: barColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: barColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(ratingLabel, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: barColor)),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Complaints resolved vs total received',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct / 100, minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$resolved resolved',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: barColor)),
              Text('$total total',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
          ]),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // PERSONAL INFO
  // ════════════════════════════════════════════════════════════
  Widget _buildPersonalInfo(String name, String email, String phone,
      String dept, String role) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        _infoTile(Icons.person_outline,    'Full Name',  name.isEmpty  ? '—' : name),
        _divider(),
        _infoTile(Icons.email_outlined,    'Email',      email.isEmpty ? '—' : email),
        _divider(),
        _infoTile(Icons.phone_outlined,    'Phone',      phone.isEmpty ? 'Tap Edit to add' : phone),
        _divider(),
        _infoTile(Icons.business_outlined, 'Department', dept.isEmpty  ? '—' : dept),
        _divider(),
        _infoTile(Icons.badge_outlined,    'Role',       role.isEmpty  ? '—' : role),
      ]),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: const Color(0xFF1A4DB7)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
              fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ])),
      ]),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 68, endIndent: 16, color: Color(0xFFE2E8F0));

  // ════════════════════════════════════════════════════════════
  // ACCOUNT INFO
  // ════════════════════════════════════════════════════════════
  Widget _buildAccountInfo() {
    final uid = _auth.currentUser?.uid ?? '';
    final shortId = uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();
    final emailVerified = _auth.currentUser?.emailVerified ?? false;
    final lastSignIn    = _auth.currentUser?.metadata.lastSignInTime;

    String lastSignInText = '—';
    if (lastSignIn != null) lastSignInText = _timeAgo(lastSignIn);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        // Admin ID
        GestureDetector(
          onTap: _copyAdminId,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.fingerprint, size: 18, color: Color(0xFF1A4DB7)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Admin ID',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text(shortId, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A), letterSpacing: 1.5)),
              ])),
              const Icon(Icons.copy_outlined, size: 16, color: Color(0xFF94A3B8)),
            ]),
          ),
        ),
        _divider(),
        // Email verification
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: emailVerified
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                emailVerified ? Icons.verified_outlined : Icons.warning_amber_outlined,
                size: 18,
                color: emailVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Email Verification',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              Text(
                emailVerified ? 'Verified' : 'Not verified',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: emailVerified
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B)),
              ),
            ])),
            if (!emailVerified)
              GestureDetector(
                onTap: () async {
                  await _auth.currentUser?.sendEmailVerification();
                  _showSnack(context, 'Verification email sent!');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Send', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B))),
                ),
              ),
          ]),
        ),
        _divider(),
        _infoTile(Icons.access_time_rounded, 'Last Sign In', lastSignInText),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SETTINGS LIST
  // ════════════════════════════════════════════════════════════
  Widget _buildSettingsList(Map<String, dynamic> adminData) {

  final items = [
    {
      "icon": Icons.lock_outline,
      "title": "Security",
      "subtitle": "Change password",
      "color": const Color(0xFF6366F1),
      "action": _showSecuritySheet
    },
    {
      "icon": Icons.notifications_outlined,
      "title": "App Preferences",
      "subtitle": "Notifications & display",
      "color": const Color(0xFF1A4DB7),
      "action": () => _showPreferencesSheet(adminData)
    },
    {
      "icon": Icons.help_outline,
      "title": "Support Center",
      "subtitle": "FAQs and contact",
      "color": const Color(0xFF06B6D4),
      "action": _showSupportSheet
    },
    {
      "icon": Icons.history_rounded,
      "title": "Activity Log",
      "subtitle": "Recent complaint actions",
      "color": const Color(0xFF10B981),
      "action": _showActivityLog
    },
  ];

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: List.generate(items.length, (i) {

        final item = items[i];

        return Column(
          children: [

            ListTile(
              onTap: item["action"] as VoidCallback,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (item["color"] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item["icon"] as IconData,
                  size: 20,
                  color: item["color"] as Color,
                ),
              ),

              title: Text(
                item["title"] as String,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),

              subtitle: Text(
                item["subtitle"] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),

              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),

            if (i < items.length - 1)
              const Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: Color(0xFFE2E8F0),
              ),
          ],
        );
      }),
    ),
  );
}

   

  // ════════════════════════════════════════════════════════════
  // SIGN OUT BUTTON
  // ════════════════════════════════════════════════════════════
  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign Out',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SECTION WRAPPER
  // ════════════════════════════════════════════════════════════
  Widget _buildSection(String title, Widget content,
      {(String, VoidCallback)? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          if (action != null)
            GestureDetector(
              onTap: action.$2,
              child: Text(action.$1, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A4DB7))),
            ),
        ]),
        const SizedBox(height: 12),
        content,
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM SHEETS
  // ════════════════════════════════════════════════════════════

  void _showEditProfileSheet(Map<String, dynamic> adminData) {
    final nameCtrl  = TextEditingController(text: adminData['fullName']   as String? ?? '');
    final roleCtrl  = TextEditingController(text: adminData['role']        as String? ?? '');
    final deptCtrl  = TextEditingController(text: adminData['department']  as String? ?? '');
    final phoneCtrl = TextEditingController(text: adminData['phone']       as String? ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHeader(ctx, Icons.edit_outlined,
                'Edit Profile', 'Update your information'),
            const SizedBox(height: 20),
            _editField('Full Name',    nameCtrl,  Icons.person_outline),
            const SizedBox(height: 12),
            _editField('Phone Number', phoneCtrl, Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _editField('Role / Title', roleCtrl,  Icons.badge_outlined),
            const SizedBox(height: 12),
            _editField('Department',   deptCtrl,  Icons.business_outlined),
            const SizedBox(height: 24),
            _saveButton('Save Changes', isSaving, () async {
              setSheet(() => isSaving = true);
              final uid = _auth.currentUser?.uid;
              if (uid == null) return;
              // ✅ Update Firestore → stream auto-refreshes UI
              await _firestore.collection('admins').doc(uid).update({
                'fullName':   nameCtrl.text.trim(),
                'role':       roleCtrl.text.trim(),
                'department': deptCtrl.text.trim(),
                'phone':      phoneCtrl.text.trim(),
              });
              if (!mounted) return;
              Navigator.pop(ctx);
              _showSnack(context, 'Profile updated!');
            }),
          ]),
        ),
      ),
    );
  }

  void _showSecuritySheet() {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true, obscureNew = true, isSaving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHeader(ctx, Icons.lock_outline,
                'Security', 'Change your account password'),
            const SizedBox(height: 20),
            _sheetLabel('CURRENT PASSWORD'),
            const SizedBox(height: 8),
            _passwordField(currentCtrl, obscureCurrent,
                () => setSheet(() => obscureCurrent = !obscureCurrent)),
            const SizedBox(height: 14),
            _sheetLabel('NEW PASSWORD'),
            const SizedBox(height: 8),
            _passwordField(newCtrl, obscureNew,
                () => setSheet(() => obscureNew = !obscureNew)),
            const SizedBox(height: 14),
            _sheetLabel('CONFIRM NEW PASSWORD'),
            const SizedBox(height: 8),
            _passwordField(confirmCtrl, true, null),
            const SizedBox(height: 24),
            _saveButton('Update Password', isSaving, () async {
              if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                _showSnack(ctx, 'Fill all fields', isError: true); return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                _showSnack(ctx, 'Passwords do not match', isError: true); return;
              }
              if (newCtrl.text.length < 6) {
                _showSnack(ctx, 'Minimum 6 characters', isError: true); return;
              }
              setSheet(() => isSaving = true);
              try {
                final user = _auth.currentUser!;
                final cred = EmailAuthProvider.credential(
                    email: user.email!, password: currentCtrl.text.trim());
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                _showSnack(context, 'Password updated!');
              } catch (e) {
                setSheet(() => isSaving = false);
                _showSnack(ctx, 'Error: $e', isError: true);
              }
            }),
          ]),
        ),
      ),
    );
  }

  void _showPreferencesSheet(Map<String, dynamic> adminData) {
    bool notifications = adminData['notifications'] as bool? ?? true;
    bool emailAlerts   = adminData['emailAlerts']   as bool? ?? false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHeader(ctx, Icons.notifications_outlined,
                'App Preferences', 'Notifications & display settings'),
            const SizedBox(height: 20),
            _prefToggle('Push Notifications', 'New complaint alerts on device',
                Icons.notifications_outlined, notifications, (v) async {
              setSheet(() => notifications = v);
              final uid = _auth.currentUser?.uid;
              // ✅ Saves to Firestore → stream auto-updates toggle state
              if (uid != null) {
                await _firestore.collection('admins').doc(uid).update({'notifications': v});
              }
            }),
            const SizedBox(height: 10),
            _prefToggle('Email Alerts', 'Get emails for escalated complaints',
                Icons.email_outlined, emailAlerts, (v) async {
              setSheet(() => emailAlerts = v);
              final uid = _auth.currentUser?.uid;
              if (uid != null) {
                await _firestore.collection('admins').doc(uid).update({'emailAlerts': v});
              }
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Color(0xFF1A4DB7), size: 18),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('App Version', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  Text('v1.0.0 — Civic Grievance Redressal', style: TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8))),
                ])),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _prefToggle(String title, String subtitle, IconData icon,
      bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: SwitchListTile(
        value: value, onChanged: onChanged,
        activeColor: const Color(0xFF1A4DB7),
        secondary: Icon(icon, color: const Color(0xFF1A4DB7), size: 20),
        title: Text(title, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        subtitle: Text(subtitle, style: const TextStyle(
            fontSize: 12, color: Color(0xFF94A3B8))),
      ),
    );
  }

  void _showSupportSheet() {
    final faqs = [
      ('How do I update a complaint status?',
       'Complaints tab → tap complaint → status selector → Save Changes.'),
      ('Why are no complaints showing on the map?',
       'Complaints need latitude & longitude. Ensure citizens submit location when filing.'),
      ('How do I change my password?',
       'Profile → Settings → Security → enter current password and set new one.'),
      ('How do I view complaint photos?',
       'Open any complaint from Complaints tab. Photo appears at top of detail screen.'),
      ('Why is analytics data not updating?',
       'Data is live from Firestore. Check your network connection.'),
    ];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHeader(ctx, Icons.help_outline,
                'Support Center', 'Frequently asked questions'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                itemCount: faqs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  if (i == faqs.length) {
                    return Column(children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A4DB7),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Row(children: [
                          Icon(Icons.email_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Contact Support', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('support@civicredressal.gov', style: TextStyle(
                                fontSize: 12, color: Colors.white70)),
                          ])),
                          Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ]);
                  }
                  final faq = faqs[i];
                  return Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      shape: const Border(),
                      leading: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${i + 1}', style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: Color(0xFF1A4DB7)))),
                      ),
                      title: Text(faq.$1, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                      children: [Text(faq.$2, style: const TextStyle(
                          fontSize: 13, color: Color(0xFF475569), height: 1.6))],
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showActivityLog() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHeader(ctx, Icons.history_rounded,
                'Activity Log', 'Live recent complaint updates'),
            const SizedBox(height: 16),
            Expanded(
              // ✅ REAL-TIME stream in activity log too
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('complaints')
                    .orderBy('updatedAt', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: Color(0xFF1A4DB7)));
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Center(child: Text('No recent activity',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)));
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    itemCount: snap.data!.docs.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (ctx, i) {
                      final data = snap.data!.docs[i].data()
                          as Map<String, dynamic>;
                      final status   = data['status']   as String? ?? 'Pending';
                      final category = data['category'] as String? ?? 'General';
                      final updatedAt = data['updatedAt'] as Timestamp?;
                      Color color;
                      switch (status.toLowerCase()) {
                        case 'resolved':    color = const Color(0xFF10B981); break;
                        case 'in progress': color = const Color(0xFF1A4DB7); break;
                        case 'escalated':   color = const Color(0xFFEF4444); break;
                        default:            color = const Color(0xFFF59E0B);
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.task_alt_outlined,
                              color: color, size: 18),
                        ),
                        title: Text(category, style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A))),
                        subtitle: Text(status, style: TextStyle(
                            fontSize: 12, color: color,
                            fontWeight: FontWeight.w600)),
                        trailing: updatedAt != null
                            ? Text(_timeAgo(updatedAt.toDate()),
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8)))
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ════════════════════════════════════════════════════════════
  Widget _sheetHeader(BuildContext ctx, IconData icon,
      String title, String subtitle) {
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF1A4DB7), size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        Text(subtitle, style: const TextStyle(
            fontSize: 12, color: Color(0xFF94A3B8))),
      ])),
      GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: const Icon(Icons.close, color: Color(0xFF94A3B8))),
    ]);
  }

  Widget _sheetLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8), letterSpacing: 0.8));

  Widget _editField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1A4DB7), width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _passwordField(TextEditingController ctrl, bool obscure,
      VoidCallback? onToggle) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        filled: true, fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A4DB7), width: 1.5)),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20, color: const Color(0xFF94A3B8),
                ),
                onPressed: onToggle)
            : null,
      ),
    );
  }

  Widget _saveButton(String label, bool isSaving, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: isSaving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A4DB7),
          foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isSaving
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}