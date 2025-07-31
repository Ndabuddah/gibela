import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Send a message to a chat
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String? type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    // Get chat document to verify participants
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      throw Exception('Chat does not exist');
    }

    final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    if (!participants.contains(userId)) {
      throw Exception('User is not a participant in this chat');
    }

    // Add message to the chat
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': userId,
      'text': text,
      'type': type,
      'metadata': metadata ?? {},
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Update chat metadata and unread counts
    final unreadMap = Map<String, dynamic>.from(chatDoc.data()?['unread'] ?? {});
    for (final participantId in participants) {
      if (participantId != userId) {
        unreadMap[participantId] = (unreadMap[participantId] ?? 0) + 1;
      }
    }

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId,
      'unread': unreadMap,
    });

    // Send notification to other participants
    await _sendChatNotifications(chatId, userId, participants, text);
  }

  // Send notifications to chat participants
  Future<void> _sendChatNotifications(
    String chatId,
    String senderId,
    List<String> participants,
    String message,
  ) async {
    try {
      // Get sender's name
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] ?? 'Unknown User';

      // Send notifications to all other participants
      for (final participantId in participants) {
        if (participantId != senderId) {
          await _notificationService.sendChatNotification(
            recipientId: participantId,
            senderName: senderName,
            message: message,
            chatId: chatId,
          );
        }
      }
    } catch (e) {
      print('Error sending chat notifications: $e');
    }
  }

  // Send a system message about ride status
  Future<void> sendRideStatusMessage({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String message,
    String? type = 'system',
    Map<String, dynamic>? metadata,
  }) async {
    // Get or create chat between driver and passenger
    final chatId = await _getOrCreateChat(driverId, passengerId);
    
    // Send the status message
    await sendMessage(
      chatId: chatId,
      text: message,
      type: type,
      metadata: {
        ...?metadata,
        'rideId': rideId,
        'isSystemMessage': true,
      },
    );
  }

  // Send driver arrival notification
  Future<void> sendDriverArrivalMessage({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String message,
  }) async {
    await sendRideStatusMessage(
      rideId: rideId,
      driverId: driverId,
      passengerId: passengerId,
      message: message,
      type: 'arrival',
      metadata: {
        'eventType': 'driver_arrived',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );
  }

  // Get or create a chat between two users
  Future<String> _getOrCreateChat(String user1Id, String user2Id) async {
    // Sort IDs to ensure consistency
    final participants = [user1Id, user2Id]..sort();
    final chatId = participants.join('_');
    
    // Check if chat already exists
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!chatDoc.exists) {
      // Create new chat with proper structure
      await _firestore.collection('chats').doc(chatId).set({
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unread': {
          user1Id: 0,
          user2Id: 0,
        },
      });
    }
    
    return chatId;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    // Update unread count
    batch.update(_firestore.collection('chats').doc(chatId), {
      'unreadCount.$userId': 0,
    });

    await batch.commit();
  }

  // Get stream of messages for a chat
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get stream of chats for a user
  Stream<QuerySnapshot> getUserChatsStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}
