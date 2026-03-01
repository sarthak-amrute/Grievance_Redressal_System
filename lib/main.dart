import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:grievance_redressal_system/services_/firebase_options.dart';
import 'package:grievance_redressal_system/designs/mainpages/splash_screen_user.dart';
// ignore: unused_import
import '../mainpages/admin_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
