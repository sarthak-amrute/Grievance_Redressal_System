import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String complaintId;
  final String userId;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String address;
  final String status;
  final DateTime createdAt;

  ComplaintModel({
    required this.complaintId,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    required this.createdAt,
  });

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory ComplaintModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ComplaintModel(
      complaintId: map['complaintId'] ?? documentId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      status: map['status'] ?? 'Pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with method for updates
  ComplaintModel copyWith({
    String? complaintId,
    String? userId,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? status,
    DateTime? createdAt,
  }) {
    return ComplaintModel(
      complaintId: complaintId ?? this.complaintId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}