import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grievance_redressal_system/designs/models/complaint_model.dart';
import 'package:grievance_redressal_system/designs/widgets/complaint_confirmation_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:grievance_redressal_system/services_/complaint_service.dart';
import 'complaint_success_screen.dart';

class ReportComplaintScreen extends StatefulWidget {
  final String? initialCategory;
  const ReportComplaintScreen({super.key, this.initialCategory});

  @override
  State<ReportComplaintScreen> createState() => _ReportComplaintScreenState();
}

class _ReportComplaintScreenState extends State<ReportComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final ComplaintService _complaintService = ComplaintService();
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategory;
  final List<File> _selectedImages = []; // up to 3
  static const int _maxImages = 3;

  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _isEditingAddress = false;

  static const Color _primary = Color(0xFF195DE6);
  static const Color _bg = Color(0xFFF6F6F8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);

  // ── Categories ─────────────────────────────────────────────────────────────

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Roads',       'icon': Icons.edit_road,          'color': Color(0xFF2563EB), 'bgColor': Color(0xFFDCEAFF)},
    {'name': 'Water',       'icon': Icons.water_drop,          'color': Color(0xFF0891B2), 'bgColor': Color(0xFFCFFAFE)},
    {'name': 'Sanitation',  'icon': Icons.delete_sweep,        'color': Color(0xFF16A34A), 'bgColor': Color(0xFFDCFCE7)},
    {'name': 'Power',       'icon': Icons.lightbulb,           'color': Color(0xFFCA8A04), 'bgColor': Color(0xFFFEF3C7)},
    {'name': 'Parks',       'icon': Icons.park,                'color': Color(0xFFEA580C), 'bgColor': Color(0xFFFFEDD5)},
    {'name': 'Safety',      'icon': Icons.health_and_safety,   'color': Color(0xFF9333EA), 'bgColor': Color(0xFFF3E8FF)},
    {'name': 'Noise',       'icon': Icons.volume_up,           'color': Color(0xFFDB2777), 'bgColor': Color(0xFFFFE4F0)},
    {'name': 'Transport',   'icon': Icons.directions_bus,      'color': Color(0xFF0284C7), 'bgColor': Color(0xFFE0F2FE)},
    {'name': 'Buildings',   'icon': Icons.apartment,           'color': Color(0xFF64748B), 'bgColor': Color(0xFFF1F5F9)},
    {'name': 'Animals',     'icon': Icons.pets,                'color': Color(0xFFD97706), 'bgColor': Color(0xFFFEF3C7)},
    {'name': 'Environment', 'icon': Icons.eco,                 'color': Color(0xFF15803D), 'bgColor': Color(0xFFDCFCE7)},
    {'name': 'Healthcare',  'icon': Icons.local_hospital,      'color': Color(0xFFDC2626), 'bgColor': Color(0xFFFEE2E2)},
  ];

  Map<String, dynamic>? get _selectedCategoryData =>
      _selectedCategory == null
          ? null
          : _categories.firstWhere((c) => c['name'] == _selectedCategory,
              orElse: () => _categories[0]);

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Please enable location services');
        setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied');
        setState(() => _isLoadingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((p) => p != null && p.isNotEmpty).join(', ');
        setState(() {
          _currentPosition = position;
          _currentAddress = parts;
          _addressController.text = parts;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Failed to get location');
      setState(() => _isLoadingLocation = false);
    }
  }

  // ── Images ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= _maxImages) {
      _showSnackBar('Maximum $_maxImages photos allowed');
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImages.add(File(image.path)));
      }
    } catch (e) {
      _showSnackBar('Failed to pick image');
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _showImageSourceSheet() {
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
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add Photo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _sourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _sourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: _primary),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textMid)),
          ],
        ),
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnackBar('Please select a grievance type');
      return;
    }
    if (_selectedImages.isEmpty) {
      _showSnackBar('Please add at least one photo of the issue');
      return;
    }
    if (_currentPosition == null) {
      _showSnackBar('Please wait for location to be detected');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => ComplaintConfirmationDialog(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        imageFile: _selectedImages.first,
        address: _addressController.text.isNotEmpty
            ? _addressController.text
            : (_currentAddress ?? 'Location detected'),
        onEdit: () => Navigator.pop(context),
        onConfirm: _submitComplaint,
      ),
    );
  }

  Future<void> _submitComplaint() async {
    setState(() => _isSubmitting = true);
    try {
      final address = _addressController.text.isNotEmpty
          ? _addressController.text
          : (_currentAddress ?? '');

      final complaint = ComplaintModel(
        complaintId: '',
        userId: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        imageUrl: '',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: address,
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      final complaintId = await _complaintService.submitComplaint(
        complaint,
        _selectedImages.first,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context); // close confirmation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintSuccessScreen(
            complaintId: complaintId,
            category: _selectedCategory!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      _showSnackBar('Failed to submit complaint: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: _textDark),
        ),
        title: const Text(
          'Report Complaint',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      bottomNavigationBar: _buildSubmitBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Issue Details section ──────────────────────────────────────
              _sectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Issue Details'),
                    const SizedBox(height: 20),

                    // Complaint Category dropdown
                    _fieldLabel('Complaint Category'),
                    const SizedBox(height: 8),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 20),

                    // Description
                    _fieldLabel('Description'),
                    const SizedBox(height: 8),
                    _buildDescriptionField(),
                  ],
                ),
              ),

              _sectionDivider(),

              // ── Evidence section ───────────────────────────────────────────
              _sectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Evidence'),
                        Text(
                          'Max $_maxImages',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPhotoGrid(),
                  ],
                ),
              ),

              _sectionDivider(),

              // ── Incident Location section ──────────────────────────────────
              _sectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Incident Location'),
                    const SizedBox(height: 16),
                    _buildMapPlaceholder(),
                    const SizedBox(height: 12),
                    _buildAddressBar(),
                  ],
                ),
              ),

              const SizedBox(height: 100), // space above bottom bar
            ],
          ),
        ),
      ),
    );
  }

  // ── Section wrappers ────────────────────────────────────────────────────────

  Widget _sectionContainer({required Widget child}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: child,
    );
  }

  Widget _sectionDivider() => Container(
        height: 8,
        color: _bg,
      );

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: _textDark),
      );

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: _textDark),
      );

  // ── Category dropdown ────────────────────────────────────────────────────────

  Widget _buildCategoryDropdown() {
    final catData = _selectedCategoryData;
    return GestureDetector(
      onTap: _showCategorySheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedCategory != null ? _primary : _border,
            width: _selectedCategory != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (catData != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (catData['bgColor'] as Color),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(catData['icon'] as IconData,
                    color: catData['color'] as Color, size: 18),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                _selectedCategory ?? 'Select grievance type',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: _selectedCategory != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: _selectedCategory != null ? _textDark : _textLight,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _selectedCategory != null ? _primary : _textLight,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Grievance Type',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose the category that best describes your issue',
                      style: TextStyle(fontSize: 13, color: _textMid),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: _border),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: _categories.length,
                  // ignore: unnecessary_underscores
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: _bg),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSelected = _selectedCategory == cat['name'];
                    return InkWell(
                      onTap: () {
                        setState(
                            () => _selectedCategory = cat['name'] as String);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              // ignore: deprecated_member_use
                              ? _primary.withOpacity(0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    // ignore: deprecated_member_use
                                    ? _primary.withOpacity(0.12)
                                    : cat['bgColor'] as Color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                cat['icon'] as IconData,
                                color: isSelected
                                    ? _primary
                                    : cat['color'] as Color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                cat['name'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? _primary : _textDark,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 15),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Description ──────────────────────────────────────────────────────────────

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      maxLength: 500,
      style: const TextStyle(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText: 'Describe the issue in detail...',
        hintStyle: const TextStyle(color: _textLight, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFFAFBFF),
        counterStyle: const TextStyle(fontSize: 11, color: _textLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please enter a description';
        if (v.length < 10) return 'Description must be at least 10 characters';
        return null;
      },
    );
  }

  // ── Photo grid ──────────────────────────────────────────────────────────────

  Widget _buildPhotoGrid() {
    final showAddButton = _selectedImages.length < _maxImages;
    final items = <Widget>[];

    // Add photo button (only if under limit)
    if (showAddButton) {
      items.add(_addPhotoButton());
    }

    // Existing photos
    for (int i = 0; i < _selectedImages.length; i++) {
      items.add(_photoThumbnail(_selectedImages[i], i));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items,
    );
  }

  Widget _addPhotoButton() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // ignore: deprecated_member_use
            color: _primary.withOpacity(0.4),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, color: _primary, size: 28),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add,
                        color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Add Photo',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoThumbnail(File file, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.65),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Map + Address ────────────────────────────────────────────────────────────

  Widget _buildMapPlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Map placeholder visual
          CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _MapPatternPainter(),
          ),
          // Pin icon centered
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: const Color(0xFFEF4444).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 20),
                ),
                CustomPaint(
                  size: const Size(12, 6),
                  painter: _PinShadowPainter(),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isLoadingLocation)
            Container(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primary),
                  strokeWidth: 2,
                ),
              ),
            ),
          // Re-center button
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location,
                    color: _primary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBar() {
    final address = _addressController.text.isNotEmpty
        ? _addressController.text
        : (_isLoadingLocation ? 'Detecting location...' : 'Location not detected');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: _isEditingAddress
          ? Row(
              children: [
                const Icon(Icons.location_on, color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textDark),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) =>
                        setState(() => _isEditingAddress = false),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isEditingAddress = false),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _primary)),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.location_on, color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DETECTED ADDRESS',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                            letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        address,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isEditingAddress = true),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Bottom submit bar ────────────────────────────────────────────────────────

  Widget _buildSubmitBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _showConfirmationDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: _textLight,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Submit Complaint',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Custom painters for map visual ──────────────────────────────────────────

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE8F0FB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final greenPaint = Paint()..color = const Color(0xFFD1E8C0);

    // Green blocks
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(20, 20, 90, 60), const Radius.circular(6)),
        greenPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 110, 20, 90, 70),
            const Radius.circular(6)),
        greenPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(20, size.height - 80, 80, 60),
            const Radius.circular(6)),
        greenPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 100, size.height - 70, 80, 55),
            const Radius.circular(6)),
        greenPaint);

    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.72),
        Offset(size.width, size.height * 0.72), roadPaint);

    // Vertical roads
    canvas.drawLine(Offset(size.width * 0.35, 0),
        Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.72, 0),
        Offset(size.width * 0.72, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PinShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
        Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}