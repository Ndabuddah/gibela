/*
// lib/screens/messages/message_list.dart
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  MessagesListScreenState createState() => MessagesListScreenState();
}

class MessagesListScreenState extends State<MessagesListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text('Messages'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserSearchScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserSearchScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Recent users row
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RECENT', style: TextStyle(color: AppTheme.greyText, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)), const SizedBox(height: 10), _buildRecentUsersRow()]),
          ),

          const SizedBox(height: 20),

          // Chats list
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              child: Container(
                decoration: BoxDecoration(color: AppTheme.darkerBackground),
                child: StreamBuilder<List<ChatModel>>(
                  stream: _databaseService.getChats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading chats', style: AppTheme.subTitleStyle));
                    }

                    final chats = snapshot.data ?? [];

                    if (chats.isEmpty) {
                      return Center(child: Text('No conversations yet', style: AppTheme.subTitleStyle));
                    }

                    return ListView.builder(
                      padding: EdgeInsets.only(top: 10),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        // Get other user's ID from participants
                        final otherUserId = chat.participants.firstWhere((id) => id != _databaseService.currentUserId, orElse: () => '');

                        return FutureBuilder<UserModel?>(
                          future: _databaseService.getUserById(otherUserId),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return SizedBox.shrink();
                            }

                            final user = userSnapshot.data!;
                            final isCurrentUserLastSender = chat.lastMessageSenderId == _databaseService.currentUserId;

                            return InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id, receiver: user)));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        UserAvatar(userModel: user, size: 56),
                                        if (user.isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: AppTheme.darkerBackground, width: 2)))),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(user.name, style: AppTheme.nameStyle), Text(_formatTime(chat.lastMessageTime), style: AppTheme.timeStyle)]),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (isCurrentUserLastSender) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.check, size: 14, color: chat.hasUnreadMessages ? AppTheme.greyText : Colors.blue)),
                                              Expanded(
                                                child: Text(
                                                  chat.lastMessage ?? '',
                                                  style: TextStyle(color: chat.hasUnreadMessages && !isCurrentUserLastSender ? Colors.white : AppTheme.greyText, fontWeight: chat.hasUnreadMessages && !isCurrentUserLastSender ? FontWeight.w600 : FontWeight.normal, fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (chat.hasUnreadMessages && !isCurrentUserLastSender)
                                                Container(
                                                  margin: EdgeInsets.only(left: 4),
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                                                  child: Center(child: Text('${chat.unreadCount}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
          }
        },
      ),
    );
  }

  Widget _buildRecentUsersRow() {
    return StreamBuilder<List<UserModel>>(
      stream: _firestoreService.getUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(height: 84, child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
        }

        final users = snapshot.data ?? [];

        return SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return GestureDetector(
                onTap: () async {
                  // Get or create chat with this user
                  final chatId = await _firestoreService.getOrCreateChat(user.uid);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, receiver: user)));
                },
                child: Container(
                  margin: EdgeInsets.only(right: 20),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(userModel: user, size: 60),
                          if (user.isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: AppTheme.darkBackground, width: 2)))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_getFirstName(user.name), style: AppTheme.recentNameStyle, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return timeago.format(time, locale: 'en_short');
  }

  String _getFirstName(String fullName) {
    return fullName.split(' ').first;
  }
}
*/
