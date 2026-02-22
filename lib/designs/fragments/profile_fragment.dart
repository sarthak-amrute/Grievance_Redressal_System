import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:grievance_redressal_system/designs/screens/user_profile_details_screen.dart';

class ProfileFragment extends StatefulWidget {
  const ProfileFragment({Key? key}) : super(key: key);

  @override
  State<ProfileFragment> createState() => _ProfileFragmentState();
}

class _ProfileFragmentState extends State<ProfileFragment> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  static const Color _primary = Color(0xFF195DE6);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load profile data');
    }
  }

  // Called when returning from UserProfileDetails so the header refreshes
  Future<void> _refreshUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) setState(() => _userData = doc.data());
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B)),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _auth.signOut();
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/login');
              } catch (_) {
                Navigator.pop(ctx);
                _showSnackBar('Failed to logout');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _getMemberSince() {
    if (_userData?['createdAt'] != null) {
      try {
        final ts = _userData!['createdAt'] as Timestamp;
        return 'Member since ${DateFormat('MMM yyyy').format(ts.toDate())}';
      } catch (_) {}
    }
    return 'Member since Feb 2024';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primary),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildStatsSection(),
          const SizedBox(height: 24),
          _buildSectionLabel('Account'),
          _buildAccountGroup(),
          const SizedBox(height: 16),
          _buildSectionLabel('More'),
          _buildMoreGroup(),
          const SizedBox(height: 16),
          _buildLogoutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Profile header ─────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final photoUrl = _userData?['profilePhoto'] ?? '';
    final name = _userData?['fullName'] ?? 'User';
    final email = _userData?['email'] ?? '';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? Image.network(photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _initialsAvatar(initials))
                    : _initialsAvatar(initials),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 4),
        Text(
          _getMemberSince(),
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.verified, color: _primary, size: 16),
              SizedBox(width: 4),
              Text(
                'Verified Citizen',
                style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _initialsAvatar(String initials) => Container(
        color: _primary,
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );

  // ── Stats ──────────────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
              child: _statCard('12', 'REPORTS SUBMITTED',
                  const Color(0xFF195DE6))),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(
                  '5', 'RESOLVED', const Color(0xFF16A34A))),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Section helpers ────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(List<_ListItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: List.generate(items.length, (i) {
            final item = items[i];
            final isLast = i == items.length - 1;
            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.vertical(
                      top: i == 0
                          ? const Radius.circular(14)
                          : Radius.zero,
                      bottom: isLast
                          ? const Radius.circular(14)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: item.iconBg ??
                                  _primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon,
                                color: item.iconColor ?? _primary,
                                size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (item.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (item.trailing != null)
                            item.trailing!
                          else if (item.onTap != null)
                            const Icon(Icons.chevron_right,
                                color: Color(0xFFCBD5E1), size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: const Color(0xFFF8FAFC),
                    indent: 70,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Account group ──────────────────────────────────────────────────────────

  Widget _buildAccountGroup() {
    return _buildGroup([
      _ListItem(
        icon: Icons.person_outline,
        label: 'Personal Info',
        subtitle: 'Name, mobile, address & more',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UserProfileDetails(),
            ),
          );
          _refreshUserData();
        },
      ),
    ]);
  }

  // ── Settings group ─────────────────────────────────────────────────────────

  // ── More group ─────────────────────────────────────────────────────────────

  Widget _buildMoreGroup() {
    return _buildGroup([
      _ListItem(
        icon: Icons.help_outline,
        label: 'Help & Support',
        subtitle: 'FAQs, contact us',
        iconBg: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0284C7),
        onTap: () {},
      ),
      _ListItem(
        icon: Icons.info_outline,
        label: 'About App',
        subtitle: 'Version & licenses',
        iconBg: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF9333EA),
        onTap: () {
          showAboutDialog(
            context: context,
            applicationName: 'Citizen App',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2025 Grievance Redressal System',
          );
        },
      ),
    ]);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: Color(0xFFDC2626), size: 18),
          label: const Text(
            'Log Out',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDC2626),
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFECACA)),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ─── Data class for list items ─────────────────────────────────────────────

class _ListItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconBg;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ListItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconBg,
    this.iconColor,
    this.onTap,
    this.trailing,
  });
}