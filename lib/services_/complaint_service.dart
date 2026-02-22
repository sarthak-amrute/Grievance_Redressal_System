import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:grievance_redressal_system/designs/models/complaint_model.dart';

class ComplaintService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Submit complaint with image upload
  Future<String> submitComplaint(
    ComplaintModel complaint,
    File imageFile,
  ) async {
    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate complaint ID
      final complaintRef = _firestore.collection('complaints').doc();
      final complaintId = complaintRef.id;

      // Upload image to Firebase Storage
      final imageUrl = await _uploadImage(imageFile, complaintId);

      // Create complaint with updated data
      final updatedComplaint = complaint.copyWith(
        complaintId: complaintId,
        userId: user.uid,
        imageUrl: imageUrl,
      );

      // Save to Firestore
      await complaintRef.set(updatedComplaint.toMap());

      // Update user's grievances array
      await _firestore.collection('users').doc(user.uid).update({
        'grievances': FieldValue.arrayUnion([complaintId]),
      });

      return complaintId;
    } catch (e) {
      debugPrint('Error submitting complaint: $e');
      throw Exception('Failed to submit complaint: ${e.toString()}');
    }
  }

  // Upload image to Firebase Storage
  Future<String> _uploadImage(File imageFile, String complaintId) async {
    try {
      // Create reference to storage location
      final storageRef = _storage.ref().child(
        'complaint_images/$complaintId.jpg',
      );

      // Upload file
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'complaintId': complaintId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  // Get user's complaints
  Future<List<ComplaintModel>> getUserComplaints() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('complaints')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting user complaints: $e');
      throw Exception('Failed to get complaints: ${e.toString()}');
    }
  }

  // Get complaint by ID
  Future<ComplaintModel?> getComplaintById(String complaintId) async {
    try {
      final doc = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .get();

      if (doc.exists) {
        return ComplaintModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting complaint: $e');
      return null;
    }
  }

  // Update complaint status (for admin)
  Future<void> updateComplaintStatus(
    String complaintId,
    String newStatus,
  ) async {
    try {
      await _firestore.collection('complaints').doc(complaintId).update({
        'status': newStatus,
      });
    } catch (e) {
      debugPrint('Error updating complaint status: $e');
      throw Exception('Failed to update status: ${e.toString()}');
    }
  }

  // Get complaints by status
  Future<List<ComplaintModel>> getComplaintsByStatus(String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('complaints')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting complaints by status: $e');
      throw Exception('Failed to get complaints: ${e.toString()}');
    }
  }

  // Get complaint statistics
  Future<Map<String, int>> getComplaintStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('complaints')
          .where('userId', isEqualTo: user.uid)
          .get();

      int total = querySnapshot.docs.length;
      int pending = 0;
      int inProgress = 0;
      int resolved = 0;

      for (var doc in querySnapshot.docs) {
        final status = doc.data()['status'] as String;
        if (status == 'Pending') {
          pending++;
        } else if (status == 'In Progress') {
          inProgress++;
        } else if (status == 'Resolved') {
          resolved++;
        }
      }

      return {
        'total': total,
        'pending': pending,
        'inProgress': inProgress,
        'resolved': resolved,
      };
    } catch (e) {
      debugPrint('Error getting complaint stats: $e');
      return {'total': 0, 'pending': 0, 'inProgress': 0, 'resolved': 0};
    }
  }

  // Delete complaint (optional - if you want users to delete their complaints)
  Future<void> deleteComplaint(String complaintId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Delete image from storage
      try {
        final imageRef = _storage.ref().child(
          'complaint_images/$complaintId.jpg',
        );
        await imageRef.delete();
      } catch (e) {
        debugPrint('Image not found or already deleted');
      }

      // Delete from Firestore
      await _firestore.collection('complaints').doc(complaintId).delete();

      // Remove from user's grievances array
      await _firestore.collection('users').doc(user.uid).update({
        'grievances': FieldValue.arrayRemove([complaintId]),
      });
    } catch (e) {
      debugPrint('Error deleting complaint: $e');
      throw Exception('Failed to delete complaint: ${e.toString()}');
    }
  }
}
