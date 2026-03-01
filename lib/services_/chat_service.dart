// lib/designs/services/chat_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Message model ──────────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isError = false,
  });

  /// Converts to format the backend expects in history[]
  Map<String, dynamic> toHistoryMap() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': text,
      };
}

// ── Chat Service ───────────────────────────────────────────────────────────────

class ChatService {
  // ⚠️ IMPORTANT: Replace with your machine's local IP when testing on a
  // real Android device. Use 10.0.2.2 for Android emulator.
  // Find your IP: run `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
  static const String _baseUrl = 'http://localhost:8000'; // emulator
  //static const String _baseUrl = 'http://192.168.1.44:8000'; // real device

  static const Duration _timeout = Duration(seconds: 120);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Send message ─────────────────────────────────────────────────────────────

  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final userId = _auth.currentUser?.uid ?? 'anonymous';

    // Build history list (exclude error messages and limit to last 10)
    final historyMaps = history
        .where((m) => !m.isError)
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((m) => m.toHistoryMap())
        .toList();

    final body = jsonEncode({
      'user_id': userId,
      'message': message,
      'history': historyMaps,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['response'] as String;

        // Save to Firestore (fire-and-forget, don't await)
        _saveChatToFirestore(
          userId: userId,
          userMessage: message,
          botResponse: reply,
        );

        return reply;
      } else if (response.statusCode == 503) {
        throw ChatException(
          'Ollama is not running on the server. Please contact support.',
          isOllamaDown: true,
        );
      } else {
        final data = jsonDecode(response.body);
        throw ChatException(data['detail'] ?? 'Server error occurred.');
      }
    } on ChatException {
      rethrow;
    } catch (e) {
      debugPrint('ChatService error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw ChatException(
          'Cannot connect to server. Make sure the backend is running.',
          isNetworkError: true,
        );
      }
      if (e.toString().contains('TimeoutException')) {
        throw ChatException(
          'Response is taking too long. LLaMA model may still be loading.',
          isTimeout: true,
        );
      }
      throw ChatException('Something went wrong. Please try again.');
    }
  }

  // ── Firestore ─────────────────────────────────────────────────────────────────

  Future<void> _saveChatToFirestore({
    required String userId,
    required String userMessage,
    required String botResponse,
  }) async {
    try {
      await _firestore.collection('chat_messages').add({
        'userId': userId,
        'message': userMessage,
        'response': botResponse,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore save error: $e');
      // Don't throw — saving to Firestore is optional, chat still works
    }
  }

  /// Load previous chat history for the current user from Firestore
  Future<List<ChatMessage>> loadChatHistory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('chat_messages')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: false)
          .limitToLast(20)
          .get();

      final messages = <ChatMessage>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Add user message
        messages.add(ChatMessage(
          id: '${doc.id}_user',
          role: MessageRole.user,
          text: data['message'] ?? '',
          timestamp: ts,
        ));

        // Add bot response
        messages.add(ChatMessage(
          id: '${doc.id}_bot',
          role: MessageRole.assistant,
          text: data['response'] ?? '',
          timestamp: ts.add(const Duration(seconds: 1)),
        ));
      }
      return messages;
    } catch (e) {
      debugPrint('Load history error: $e');
      return [];
    }
  }

  /// Check if the backend server is reachable
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/chat/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ── Custom exception ───────────────────────────────────────────────────────────

class ChatException implements Exception {
  final String message;
  final bool isNetworkError;
  final bool isOllamaDown;
  final bool isTimeout;

  ChatException(
    this.message, {
    this.isNetworkError = false,
    this.isOllamaDown = false,
    this.isTimeout = false,
  });

  @override
  String toString() => message;
}