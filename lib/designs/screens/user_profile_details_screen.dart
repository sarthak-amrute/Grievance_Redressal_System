import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class UserProfileDetails extends StatefulWidget {
  // ignore: use_super_parameters
  const UserProfileDetails({Key? key}) : super(key: key);

  @override
  State<UserProfileDetails> createState() => _UserProfileDetailsState();
}

class _UserProfileDetailsState extends State<UserProfileDetails>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // Controllers for editable fields
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _pincodeCtrl;

  final _formKey = GlobalKey<FormState>();

  static const Color _primary = Color(0xFF195DE6);
  static const Color _bg = Color(0xFFF6F8FD);
  static const Color _cardBg = Colors.white;
  static const Color _labelColor = Color(0xFF94A3B8);
  static const Color _textColor = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _pincodeCtrl = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[ProfileDetails] No logged-in user found');
        setState(() => _isLoading = false);
        _showSnackBar('No user session found. Please log in again.', isError: true);
        return;
      }

      debugPrint('[ProfileDetails] Loading data for uid: ${user.uid}');
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        debugPrint('[ProfileDetails] Document does not exist — creating empty profile');
        // Document missing: show empty editable form so user can fill details
        final fallback = <String, dynamic>{
          'fullName': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': '',
          'address': '',
          'city': '',
          'state': '',
          'pincode': '',
        };
        setState(() {
          _userData = fallback;
          _populateControllers(fallback);
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      debugPrint('[ProfileDetails] Loaded fields: ${data.keys.toList()}');
      setState(() {
        _userData = data;
        _populateControllers(data);
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('[ProfileDetails] ERROR loading user data: $e');
      debugPrint(stack.toString());
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load profile data: ${e.toString()}', isError: true);
    }
  }

  void _populateControllers(Map<String, dynamic> data) {
    _nameCtrl.text = data['fullName'] ?? '';
    // Firestore has both 'phoneNumber' and 'phone' — prefer phoneNumber
    _phoneCtrl.text = data['phoneNumber'] ?? data['phone'] ?? '';
    _addressCtrl.text = data['address'] ?? '';
    _cityCtrl.text = data['city'] ?? '';
    _stateCtrl.text = data['state'] ?? '';
    _pincodeCtrl.text = data['pincode'] ?? '';
  }

  String _getMemberSince() {
    if (_userData?['createdAt'] != null) {
      try {
        final ts = _userData!['createdAt'] as Timestamp;
        return DateFormat('d MMM yyyy').format(ts.toDate());
      } catch (_) {}
    }
    return 'N/A';
  }

  // ── Edit / Cancel ─────────────────────────────────────────────────────────

  void _toggleEdit() {
    if (_isEditing) {
      // Cancel — restore original values
      _populateControllers(_userData ?? {});
    }
    setState(() => _isEditing = !_isEditing);
  }

  // ── Save with confirmation ─────────────────────────────────────────────────

  void _onSaveTapped() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.save_outlined, color: _primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Save Changes?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to update your profile information?',
          style: TextStyle(fontSize: 14, color: _subtleText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _subtleText, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveChanges();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final updates = <String, dynamic>{
        'fullName': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(), // primary field in your schema
        'phone': _phoneCtrl.text.trim(),        // keep in sync
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updates, SetOptions(merge: true));

      debugPrint('[ProfileDetails] Saved: $updates');

      setState(() {
        _userData = {...?_userData, ...updates};
        _isEditing = false;
        _isSaving = false;
      });
      _showSnackBar('Profile updated successfully!');
    } catch (e) {
      debugPrint('[ProfileDetails] Save error: $e');
      setState(() => _isSaving = false);
      _showSnackBar('Failed to update profile: ${e.toString()}', isError: true);
    }
  }

  // ── Profile photo ──────────────────────────────────────────────────────────

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 20),
              _photoOptionTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              _photoOptionTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if ((_userData?['profilePhoto'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _photoOptionTile(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  color: const Color(0xFFDC2626),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          // ignore: deprecated_member_use
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? img = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (img == null) return;

      _showLoadingOverlay();

      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final ref =
          _storage.ref().child('profile_photos/${user.uid}/profile.jpg');
      await ref.putFile(
          File(img.path), SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'profilePhoto': url});

      if (!mounted) return;
      Navigator.pop(context); // close loading
      setState(() {
        _userData = {...?_userData, 'profilePhoto': url};
      });
      _showSnackBar('Profile photo updated!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Failed to upload photo', isError: true);
    }
  }

  Future<void> _removePhoto() async {
    try {
      _showLoadingOverlay();
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'profilePhoto': ''});
      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _userData = {...?_userData, 'profilePhoto': ''};
      });
      _showSnackBar('Profile photo removed');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Failed to remove photo', isError: true);
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primary),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primary),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildAvatarSection(),
                    const SizedBox(height: 28),
                    _buildSectionCard(
                      title: 'Basic Information',
                      icon: Icons.person_outline,
                      children: [
                        _buildEditableField(
                          label: 'Full Name',
                          controller: _nameCtrl,
                          icon: Icons.badge_outlined,
                          firestoreKey: 'fullName',
                          hint: 'Enter your full name',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildDivider(),
                        _buildReadOnlyField(
                          label: 'Email Address',
                          value: _userData?['email'] ?? '—',
                          icon: Icons.email_outlined,
                          locked: true,
                        ),
                        _buildDivider(),
                        _buildEditableField(
                          label: 'Mobile Number',
                          controller: _phoneCtrl,
                          icon: Icons.phone_outlined,
                          firestoreKey: 'phoneNumber',
                          hint: 'Enter mobile number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Address',
                      icon: Icons.location_on_outlined,
                      children: [
                        _buildEditableField(
                          label: 'Street / Area',
                          controller: _addressCtrl,
                          icon: Icons.home_outlined,
                          firestoreKey: 'address',
                          hint: 'Enter street or area',
                          maxLines: 2,
                        ),
                        _buildDivider(),
                        _buildEditableField(
                          label: 'City',
                          controller: _cityCtrl,
                          icon: Icons.location_city_outlined,
                          firestoreKey: 'city',
                          hint: 'Enter city',
                        ),
                        _buildDivider(),
                        _buildEditableField(
                          label: 'State',
                          controller: _stateCtrl,
                          icon: Icons.map_outlined,
                          firestoreKey: 'state',
                          hint: 'Enter state',
                        ),
                        _buildDivider(),
                        _buildEditableField(
                          label: 'Pincode',
                          controller: _pincodeCtrl,
                          icon: Icons.pin_outlined,
                          firestoreKey: 'pincode',
                          hint: 'Enter pincode',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Account Information',
                      icon: Icons.info_outline,
                      children: [
                        _buildReadOnlyField(
                          label: 'Role',
                          value: _userData?['role'] ?? 'citizen',
                          icon: Icons.shield_outlined,
                          valueColor: const Color(0xFF195DE6),
                        ),
                        _buildDivider(),
                        _buildReadOnlyField(
                          label: 'Member Since',
                          value: _getMemberSince(),
                          icon: Icons.calendar_today_outlined,
                        ),
                        _buildDivider(),
                        _buildReadOnlyField(
                          label: 'Email Verified',
                          value: (_userData?['emailVerified'] == true)
                              ? 'Verified ✓'
                              : 'Not Verified',
                          icon: Icons.mark_email_read_outlined,
                          valueColor: (_userData?['emailVerified'] == true)
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                        _buildDivider(),
                        _buildReadOnlyField(
                          label: 'Account Status',
                          value: (_userData?['isActive'] == true)
                              ? 'Active'
                              : 'Inactive',
                          icon: Icons.toggle_on_outlined,
                          valueColor: (_userData?['isActive'] == true)
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                        _buildDivider(),
                        _buildReadOnlyField(
                          label: 'User ID',
                          value: _auth.currentUser?.uid ?? '—',
                          icon: Icons.fingerprint,
                          monospace: true,
                        ),
                      ],
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 28),
                      _buildSaveButton(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: _textColor),
      ),
      title: const Text(
        'Personal Info',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
      centerTitle: true,
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_primary),
              ),
            ),
          )
        else
          TextButton(
            onPressed: _toggleEdit,
            child: Text(
              _isEditing ? 'Cancel' : 'Edit',
              style: TextStyle(
                color: _isEditing ? const Color(0xFFDC2626) : _primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final photoUrl = _userData?['profilePhoto'] ?? '';
    final name = _userData?['fullName'] ?? 'User';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Column(
      children: [
        Stack(
          children: [
            // Avatar
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: _primary.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        // ignore: unnecessary_underscores
                        errorBuilder: (_, __, ___) =>
                            _initialsAvatar(initials),
                      )
                    : _initialsAvatar(initials),
              ),
            ),
            // Camera button
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: _primary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _textColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Text(
            'Change profile photo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              // ignore: deprecated_member_use
              color: _primary.withOpacity(0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialsAvatar(String initials) {
    return Container(
      color: _primary,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDivider() => Divider(
        height: 1,
        thickness: 1,
        color: const Color(0xFFF8FAFC),
        indent: 56,
        endIndent: 16,
      );

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    bool locked = false,
    bool monospace = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _subtleText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _labelColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _textColor,
                    fontFamily: monospace ? 'monospace' : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline, size: 11, color: _labelColor),
                  SizedBox(width: 3),
                  Text(
                    'Locked',
                    style: TextStyle(
                      fontSize: 10,
                      color: _labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String firestoreKey,   // actual Firestore field key for display
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    // In view mode read straight from _userData so we never show stale controller text
    final displayValue = _isEditing
        ? null
        : () {
            if (firestoreKey == 'phoneNumber') {
              return (_userData?['phoneNumber'] ?? _userData?['phone'] ?? '').toString();
            }
            return (_userData?[firestoreKey] ?? '').toString();
          }();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _isEditing
                  // ignore: deprecated_member_use
                  ? _primary.withOpacity(0.08)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: _isEditing ? _primary : _subtleText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _isEditing
                ? TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    validator: validator,
                    maxLines: maxLines,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: _primary,
                        fontWeight: FontWeight.w600,
                      ),
                      hintText: hint,
                      hintStyle: TextStyle(
                        // ignore: deprecated_member_use
                        color: _labelColor.withOpacity(0.7),
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFDC2626)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFBFF),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _labelColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (displayValue == null || displayValue.isEmpty)
                            ? '—'
                            : displayValue,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: (displayValue == null || displayValue.isEmpty)
                              ? _labelColor
                              : _textColor,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _onSaveTapped,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          // ignore: deprecated_member_use
          disabledBackgroundColor: _primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.save_outlined, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}