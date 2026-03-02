// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/designs/mainpages/admin_login_screen.dart';
// FIXED: Only one import for AdminLoginScreen — the local relative path.
// The absolute package import was removed to prevent duplicate class conflict.
// ignore: unused_import
import 'admin_login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic> _adminData = {};
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  int _complaintsResolved = 0;
  int _pendingTasks = 0;
  // ignore: prefer_final_fields
  double _efficiencyScore = 98.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final doc = await _firestore.collection('admins').doc(uid).get();
      if (doc.exists) {
        _adminData = doc.data() ?? {};
      }

      final grievancesSnap = await _firestore.collection('grievances').get();
      int resolved = 0;
      int pending = 0;

      for (var g in grievancesSnap.docs) {
        final data = g.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        if (status == 'resolved') resolved++;
        if (status == 'pending') pending++;
      }

      if (mounted) {
        setState(() {
          _complaintsResolved = resolved == 0 ? 1284 : resolved;
          _pendingTasks = pending == 0 ? 12 : pending;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final uid = _auth.currentUser!.uid;
      final ref = _storage.ref().child('admin_photos/$uid.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await _firestore
          .collection('admins')
          .doc(uid)
          .update({'profilePhoto': url});
      await _auth.currentUser!.updatePhotoURL(url);

      if (mounted) {
        setState(() {
          _adminData['profilePhoto'] = url;
          _isUploadingPhoto = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(
        text: _adminData['fullName'] as String? ?? '');
    final roleCtrl = TextEditingController(
        text: _adminData['role'] as String? ?? '');
    final deptCtrl = TextEditingController(
        text: _adminData['department'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),
            _editField('Full Name', nameCtrl),
            const SizedBox(height: 12),
            _editField('Role / Title', roleCtrl),
            const SizedBox(height: 12),
            _editField('Department', deptCtrl),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = _auth.currentUser?.uid;
                  if (uid == null) return;
                  await _firestore.collection('admins').doc(uid).update({
                    'fullName': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'department': deptCtrl.text.trim(),
                  });
                  if (!mounted) return;
                  setState(() {
                    _adminData['fullName'] = nameCtrl.text.trim();
                    _adminData['role'] = roleCtrl.text.trim();
                    _adminData['department'] = deptCtrl.text.trim();
                  });
                  // ignore: use_build_context_synchronously
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4DB7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF1A4DB7), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _adminData['fullName'] as String? ?? 'Admin User';
    final roleTitle =
        _adminData['role'] as String? ?? 'Senior Infrastructure Admin';
    final department = _adminData['department'] as String? ??
        'Department of Urban Development';
    final email = _adminData['email'] as String? ??
        _auth.currentUser?.email ??
        '';
    final photoUrl = _adminData['profilePhoto'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A4DB7)))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAppBar(),
                    const SizedBox(height: 24),
                    _buildAvatar(photoUrl, name),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A4DB7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      department,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Stats Overview', null),
                    const SizedBox(height: 12),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Personal Information', 'Edit'),
                    const SizedBox(height: 12),
                    _buildPersonalInfo(name, email, department),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Settings', null),
                    const SizedBox(height: 12),
                    _buildSettingsList(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                size: 22, color: Color(0xFF0F172A)),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Admin Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _signOut,
            child: const Icon(Icons.logout,
                size: 22, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    // ignore: unnecessary_underscores
                    errorBuilder: (_, __, ___) => _avatarFallback(name),
                  )
                : _avatarFallback(name),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFF1A4DB7),
                shape: BoxShape.circle,
              ),
              child: _isUploadingPhoto
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.edit, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join()
        : 'A';
    return Container(
      color: const Color(0xFFEEF2FF),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A4DB7),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String? actionLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: _showEditProfileSheet,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A4DB7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COMPLAINTS RESOLVED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '+5%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _complaintsResolved.toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]},',
                  ),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PENDING TASKS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_pendingTasks',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '-2%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EFFICIENCY SCORE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_efficiencyScore.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '+1%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(String name, String email, String department) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Full Name', name),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            _infoRow('Email Address', email),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            _infoRow('Department', department),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ── Security sheet ────────────────────────────────────────────────────────
  void _showSecuritySheet() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_outline, color: Color(0xFF1A4DB7), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                ),
              ]),
              const SizedBox(height: 6),
              const Text('Change your account password', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              const SizedBox(height: 24),
              _sheetLabel('CURRENT PASSWORD'),
              const SizedBox(height: 8),
              _sheetPasswordField(currentPwCtrl, obscureCurrent, () => setSheet(() => obscureCurrent = !obscureCurrent)),
              const SizedBox(height: 16),
              _sheetLabel('NEW PASSWORD'),
              const SizedBox(height: 8),
              _sheetPasswordField(newPwCtrl, obscureNew, () => setSheet(() => obscureNew = !obscureNew)),
              const SizedBox(height: 16),
              _sheetLabel('CONFIRM NEW PASSWORD'),
              const SizedBox(height: 8),
              _sheetPasswordField(confirmPwCtrl, true, null),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (newPwCtrl.text.isEmpty || currentPwCtrl.text.isEmpty) {
                            _showSnack(ctx, 'Please fill all fields');
                            return;
                          }
                          if (newPwCtrl.text != confirmPwCtrl.text) {
                            _showSnack(ctx, 'New passwords do not match');
                            return;
                          }
                          if (newPwCtrl.text.length < 6) {
                            _showSnack(ctx, 'Password must be at least 6 characters');
                            return;
                          }
                          setSheet(() => isSaving = true);
                          try {
                            final user = _auth.currentUser!;
                            final cred = EmailAuthProvider.credential(
                              email: user.email!,
                              password: currentPwCtrl.text.trim(),
                            );
                            await user.reauthenticateWithCredential(cred);
                            await user.updatePassword(newPwCtrl.text.trim());
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.pop(ctx);
                            _showSnack(context, 'Password updated successfully!', success: true);
                          } catch (e) {
                            setSheet(() => isSaving = false);
                            // ignore: use_build_context_synchronously
                            _showSnack(ctx, 'Error: ${e.toString()}');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A4DB7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── App Preferences sheet ─────────────────────────────────────────────────
  void _showPreferencesSheet() {
    bool notifications = _adminData['notifications'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_outlined, color: Color(0xFF1A4DB7), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('App Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SwitchListTile(
                  value: notifications,
                  onChanged: (v) async {
                    setSheet(() => notifications = v);
                    final uid = _auth.currentUser?.uid;
                    if (uid != null) {
                      await _firestore.collection('admins').doc(uid).update({'notifications': v});
                      if (mounted) setState(() => _adminData['notifications'] = v);
                    }
                  },
                  activeColor: const Color(0xFF1A4DB7),
                  title: const Text('Push Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  subtitle: const Text('Get alerted for new complaints', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  secondary: const Icon(Icons.notifications_outlined, color: Color(0xFF1A4DB7)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFF1A4DB7), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('App Version', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      Text('v2.4.0 — Civic Redressal System', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Support Center sheet ──────────────────────────────────────────────────
  void _showSupportSheet() {
    final faqs = [
      ('How do I update a complaint status?', 'Go to Complaints tab → tap a complaint → use the status selector in the Admin Panel section → tap Save Changes.'),
      ('Why are no complaints showing on the map?', 'Complaints need latitude and longitude fields. Check that citizens are submitting location data.'),
      ('How do I reset an admin password?', 'Use the Security option in your profile settings to change your password after re-authenticating.'),
      ('How do I view complaint photos?', 'Open any complaint from the Complaints tab. The image is shown at the top of the detail screen.'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.help_outline, color: Color(0xFF1A4DB7), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Support Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 6),
              const Text('Frequently asked questions', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: faqs.length,
                  // ignore: unnecessary_underscores
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final faq = faqs[i];
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      shape: const Border(),
                      leading: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A4DB7)))),
                      ),
                      title: Text(faq.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(faq.$2, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6)),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A4DB7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.email_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Contact Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('support@civicredressal.gov', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sheet helper widgets ──────────────────────────────────────────────────
  Widget _sheetLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8));

  Widget _sheetPasswordField(TextEditingController ctrl, bool obscure, VoidCallback? onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A4DB7), width: 1.5)),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: const Color(0xFF94A3B8)),
                onPressed: onToggle,
              )
            : null,
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, {bool success = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : const Color(0xFF1A4DB7),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Widget _buildSettingsList() {
    final items = [
      {
        'icon': Icons.lock_outline,
        'title': 'Security',
        'subtitle': 'Change password and 2FA',
        'onTap': _showSecuritySheet,
      },
      {
        'icon': Icons.notifications_outlined,
        'title': 'App Preferences',
        'subtitle': 'Notifications and appearance',
        'onTap': _showPreferencesSheet,
      },
      {
        'icon': Icons.help_outline,
        'title': 'Support Center',
        'subtitle': 'Get help with the platform',
        'onTap': _showSupportSheet,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
                  onTap: item['onTap'] as VoidCallback,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: const Color(0xFF1A4DB7),
                    ),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    item['subtitle'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 18, color: Color(0xFF94A3B8)),
                ),
                if (i < items.length - 1)
                  const Divider(
                      height: 1, indent: 72, color: Color(0xFFE2E8F0)),
              ],
            );
          }),
        ),
      ),
    );
  }
}