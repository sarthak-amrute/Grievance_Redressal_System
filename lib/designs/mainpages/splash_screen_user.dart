import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grievance_redressal_system/designs/mainpages/loginpage_user.dart';
import 'package:grievance_redressal_system/designs/mainpages/homepage_user.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Setup progress bar animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Navigate after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        // Check if user is already logged in
        User? currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser != null) {
          // User is already logged in, navigate to homepage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomepageUser()),
          );
        } else {
          // User is not logged in, navigate to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreenUser()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E5CDE),
              Color(0xFF144BA8),
              Color(0xFF0D3A7C),
            ],
          ),
        ),
        child: Stack(
          children: [
            // -------- MAIN CENTER CONTENT --------
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glassmorphism Logo Container
                  Container(
                    height: 110,
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.location_city,
                        size: 60,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // App Title
                  const Text(
                    "Civic Connect",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black26,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    "REPORT. TRACK. RESOLVE.",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),

            // -------- BOTTOM SCENIC IMAGE --------
            Positioned(
              bottom: 100,
              left: 130,
              right: 130,
              child: SizedBox(
                height: 130,
                width: 0,
                child: Stack(
                  children: [
                    // Scenic background image
                    Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            "https://lh3.googleusercontent.com/aida-public/AB6AXuAey4mp35oSpV_3EoHII8RdhxPJW2RNZd-3lQz5CG5G2MCWt7g9KptZsKPANwZgM3VusPVB7VyeorG_AwM7psl6_Z8wnzurX5ae8jcqYUPNFfER7TXvHTlbsfJJWDfIJOAXH-cUxe3ZlpdEqstEGGdEQCWCHq45b_vAmWR2HS0U3WcXin6YW9rHM4NKvGmsGbmwXmfrgE2Dn5afQOBjdXWvhdNIIaWCE78WzEehM_Bt2HJpo-kdZpZ2votsybVV8yzkLdc35vwNbsn5",
                          ),
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                          opacity: 0.6,
                        ),
                      ),
                    ),

            //         // Gradient overlay for smooth blend
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            const Color(0xFF0D3A7C).withOpacity(0.5),
                            const Color(0xFF0D3A7C),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // -------- ANIMATED LOADING INDICATOR --------
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 160,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
