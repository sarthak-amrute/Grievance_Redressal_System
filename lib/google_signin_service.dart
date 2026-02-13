import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleSignInService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  GoogleSignInService();

  // Sign in with Google for Mobile/Android
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Attempt to sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print(' Google Sign-In cancelled by user');
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        // Create/update user in Firestore
        await _createOrUpdateUserInFirestore(
          userCredential.user!,
          fullName: userCredential.user!.displayName,
        );
      }

      return userCredential;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('Signed out successfully');
    } catch (e) {
      print(' Sign out error: $e');
      rethrow;
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Create or Update User in Firestore
  Future<void> _createOrUpdateUserInFirestore(
    User user, {
    String? fullName,
  }) async {
    try {
      DocumentReference userDoc = _firestore.collection('users').doc(user.uid);
      DocumentSnapshot docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // Create new user document
        await userDoc.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'phoneNumber': user.phoneNumber ?? '',
          'fullName': fullName ?? user.displayName ?? '',
          'role': 'citizen',
          'profilePhoto': user.photoURL ?? '',
          'address': {'street': '', 'city': '', 'state': '', 'pincode': ''},
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'preferences': {'notifications': true, 'darkMode': false},
          'grievances': [],
          'emailVerified': user.emailVerified,
          'isActive': true,
        });
        print(' New user created in Firestore via Google Sign-In');
      } else {
        // Update existing user's last active time
        await userDoc.update({'lastActive': FieldValue.serverTimestamp()});
        print(' User already exists, updated last active');
      }
    } catch (e) {
      print(' Error creating user in Firestore: $e');
      rethrow;
    }
  }
}
