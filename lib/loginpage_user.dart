import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/homepage_user.dart';
import 'registration_screen.dart';
import 'google_signin_service.dart';

class LoginScreenUser extends StatefulWidget {
  const LoginScreenUser({super.key});

  @override
  State<LoginScreenUser> createState() => _LoginScreenUserState();
}

class _LoginScreenUserState extends State<LoginScreenUser> {
  bool isPhoneSelected = true;
  bool isDarkMode = false;
  String selectedCountryCode = '+91';
  bool isLoading = false;
  
  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignInService _googleSignInService = GoogleSignInService();
  
  // For phone verification
  String? _verificationId;
  
  final List<Map<String, String>> countryCodes = [
    {'code': '+1', 'name': 'US'},
    {'code': '+44', 'name': 'UK'},
    {'code': '+91', 'name': 'IN'},
    {'code': '+86', 'name': 'CN'},
    {'code': '+81', 'name': 'JP'},
    {'code': '+61', 'name': 'AU'},
    {'code': '+49', 'name': 'DE'},
    {'code': '+33', 'name': 'FR'},
    {'code': '+971', 'name': 'AE'},
    {'code': '+65', 'name': 'SG'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Create or Update User in Firestore
  Future<void> createUserInFirestore(User user, {String? fullName, String? phoneNumber}) async {
    try {
      DocumentReference userDoc = _firestore.collection('users').doc(user.uid);
      DocumentSnapshot docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'phoneNumber': phoneNumber ?? user.phoneNumber ?? '',
          'fullName': fullName ?? user.displayName ?? '',
          'role': 'citizen',
          'profilePhoto': user.photoURL ?? '',
          'address': {
            'street': '',
            'city': '',
            'state': '',
            'pincode': ''
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'preferences': {
            'notifications': true,
            'darkMode': false
          },
          'grievances': [],
          'emailVerified': user.emailVerified,
          'isActive': true,
        });
        print(' New user created in Firestore');
      } else {
        await userDoc.update({
          'lastActive': FieldValue.serverTimestamp(),
        });
        print('User updated in Firestore');
      }
    } catch (e) {
      print('Firestore Error: $e');
      // Don't throw error, just log it
    }
  }

  // Phone Authentication - Send OTP
  Future<void> _sendOTP() async {
    String phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showSnackBar('Please enter phone number');
      return;
    }

    if (phone.length < 10) {
      _showSnackBar('Please enter valid phone number');
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    String phoneNumber = selectedCountryCode + phone;
    print('📱 Sending OTP to: $phoneNumber');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Auto verification completed');
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print(' Verification failed: ${e.code} - ${e.message}');
          if (!mounted) return;
          setState(() => isLoading = false);
          
          String errorMessage = 'Verification failed';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Try later.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded. Use test number: +91 1234567890';
          } else {
            errorMessage = e.message ?? 'Verification failed';
          }
          
          _showSnackBar(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          print(' OTP sent successfully');
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            isLoading = false;
          });
          _showOTPDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print(' Auto retrieval timeout');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      print(' Error sending OTP: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  // Verify OTP and Sign In
  Future<void> _verifyOTP(String otp) async {
    if (_verificationId == null) {
      _showSnackBar('Verification ID not found. Please resend OTP.');
      return;
    }

    if (otp.isEmpty || otp.length != 6) {
      _showSnackBar('Please enter valid 6-digit OTP');
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);
    print('Verifying OTP: $otp');

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      print('OTP verification failed: ${e.code}');
      if (!mounted) return;
      setState(() => isLoading = false);
      
      String errorMessage = 'Invalid OTP';
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid OTP. Please try again.';
      } else if (e.code == 'session-expired') {
        errorMessage = 'OTP expired. Please request a new one.';
      } else {
        errorMessage = 'Verification failed. Please try again.';
      }
      
      _showSnackBar(errorMessage);
    } catch (e) {
      print('Error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  // Sign in with credential
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        print('Phone login successful');
        
        // Create/update user in Firestore
        await createUserInFirestore(
          userCredential.user!,
          phoneNumber: selectedCountryCode + _phoneController.text.trim(),
        );
        
        if (!mounted) return;
        setState(() => isLoading = false);
        
        _showSnackBar('Login successful!');
        
        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const HomepageUser())
          );
        }
      }
    } catch (e) {
      print(' Sign in error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Sign in failed: ${e.toString()}');
    }
  }

  // Email/Password Login
  Future<void> _loginWithEmail() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showSnackBar('Please enter email and password');
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (userCredential.user != null) {
        print(' Email login successful');
        
        // Create/update user in Firestore
        await createUserInFirestore(userCredential.user!);
        
        if (!mounted) return;
        setState(() => isLoading = false);
        
        _showSnackBar('Login successful! ');
        
        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const HomepageUser())
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Email login failed: ${e.code}');
      if (!mounted) return;
      setState(() => isLoading = false);
      
      String message = '';
      if (e.code == 'user-not-found') {
        message = 'No user found. Please register first.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      _showSnackBar(message);
    } catch (e) {
      print('Error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  // Google Sign In
  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      UserCredential? userCredential = await _googleSignInService.signInWithGoogle();
      
      if (!mounted) return;
      setState(() => isLoading = false);
      
      if (userCredential != null && userCredential.user != null) {
        _showSnackBar('Google sign in successful!');
        
        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const HomepageUser())
          );
        }
      }
    } catch (e) {
      print(' Google sign in failed: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Google sign in failed: $e');
    }
  }

  // Show OTP Dialog - FIXED VERSION
  void _showOTPDialog() {
    // Create a new controller for OTP dialog
    final TextEditingController otpController = TextEditingController();
    bool isDialogLoading = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? const Color(0xFF1A2233) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Enter OTP',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We sent a code to ${selectedCountryCode} ${_phoneController.text}',
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 4,
                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (isDialogLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () {
                    otpController.dispose();
                    _verificationId = null;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading ? null : () async {
                    String otp = otpController.text.trim();
                    if (otp.length == 6) {
                      setDialogState(() {
                        isDialogLoading = true;
                      });
                      
                      // Close dialog first
                      Navigator.of(dialogContext).pop();
                      otpController.dispose();
                      
                      // Then verify OTP
                      await _verifyOTP(otp);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter 6-digit OTP'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195DE6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show SnackBar
  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('successful') || message.contains('Login successful') 
            ? Colors.green 
            : const Color(0xFF195DE6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF111621) : const Color(0xFFF6F6F8),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(isDarkMode: isDarkMode),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: 448,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildLoginForm(),
                            const Spacer(),
                            _buildFooter(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF195DE6)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF195DE6),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF195DE6).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_city,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Report. Resolve. Rebuild.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            height: 1.2,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to track your grievances and make your city better.',
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF1A2233) 
                : const Color(0xFFE2E8F0).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(child: _buildSegmentButton('Phone', true)),
              Expanded(child: _buildSegmentButton('Email', false)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (isPhoneSelected) _buildPhoneInput() else _buildEmailInput(),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : () {
              if (isPhoneSelected) {
                _sendOTP();
              } else {
                _loginWithEmail();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF195DE6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: const Color(0xFF195DE6).withOpacity(0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isPhoneSelected ? 'Get OTP' : 'Login',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                );
              },
              child: const Text(
                'Register',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF195DE6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDarkMode ? const Color(0xFF1A2233) : Colors.white,
              side: BorderSide(
                color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4285F4),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton(String label, bool isPhone) {
    final isSelected = isPhone == isPhoneSelected;
    return GestureDetector(
      onTap: () {
        setState(() {
          isPhoneSelected = isPhone;
        });
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF195DE6)
                  : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A2233) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => _showCountryCodePicker(),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCountryCode,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 1,
                        color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: '1234567890',
                    hintStyle: TextStyle(
                      color: isDarkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A2233) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'your.email@example.com',
              hintStyle: TextStyle(
                color: isDarkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A2233) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: true,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(
                color: isDarkMode ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1A2233) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Country Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: countryCodes.length,
                  itemBuilder: (context, index) {
                    final country = countryCodes[index];
                    final isSelected = selectedCountryCode == country['code'];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF195DE6).withOpacity(0.1)
                              : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            country['name']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? const Color(0xFF195DE6)
                                  : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        country['code']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF195DE6),
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          selectedCountryCode = country['code']!;
                        });
                        Navigator.pop(context);
                      },
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

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            children: const [
              TextSpan(text: 'Are you an official? '),
              TextSpan(
                text: 'Login as Admin',
                style: TextStyle(
                  color: Color(0xFF195DE6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '•',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DotPatternPainter extends CustomPainter {
  final bool isDarkMode;

  DotPatternPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDarkMode ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1))
          .withOpacity(0.6)
      ..style = PaintingStyle.fill;

    const dotSpacing = 24.0;
    const dotRadius = 1.0;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}