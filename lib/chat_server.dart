import 'dart:async';
import 'dart:convert';
import 'package:server/broadcast_message.dart';
import 'package:server/database.dart';
import 'package:server/group.dart';
import 'package:server/handle_requests.dart';
import 'package:server/message.dart';
import 'package:server/user.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_web_socket/shelf_web_socket.dart' as shelf_web_socket;
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatServer {
  late DatabaseManager _databaseManager;
  final _handleRequest = HandleRequest();

  final Map<String, WebSocketChannel> _userChannels = {};

  ChatServer() {
    _databaseManager = DatabaseManager();
  }

  void sendAllMessagesForUser(String username, String type) {
    final List<Message> allMessages =
        _databaseManager.getAllMessagesForUser(username);

    final recipientChannel = _userChannels[username];
    if (recipientChannel != null) {
      for (final Message message in allMessages) {
        final messageData = {
          'type': type,
          'messageId': message.messageId,
          'senderUsername': message.senderUsername,
          'recipientUsername': message.recipientUsername,
          'content': message.content,
          'timestamp': message.timestamp,
          'isRead': message.isRead,
          'isSent': (message.senderUsername == username),
        };

        recipientChannel.sink.add(jsonEncode(messageData));
      }
    }
  }

  void sendAllGroupMessagesForUser(
    String username,
    int userId,
    String type,
  ) async {
    try {
      final List<Map<String, dynamic>> allGroupMessages =
          await _databaseManager.getAllGroupMessagesForUser(userId);

      print('Retrieved group messages for user $userId:');
      print(allGroupMessages);

      final userChannel = _userChannels[username];
      print('User channel: $userChannel');

      if (userChannel == null) {
        print('Error: WebSocket channel for user $username is null.');
        return;
      }

      print('Sending group messages to user $username...');
      for (final Map<String, dynamic> message in allGroupMessages) {
        final messageData = {
          'type': 'group_message',
          'messageId': message['messageId'],
          'groupId': message['groupId'],
          'groupName': message['groupName'],
          'senderId': message['senderId'],
          'senderName': message['senderName'],
          'messageContent': message['messageContent'],
          'timestamp': message['timestamp'],
        };

        print('Sending message: $messageData');

        userChannel.sink.add(jsonEncode(messageData));
      }

      print('All group messages sent to user $username.');
    } catch (e) {
      print('Error sending group messages: $e');
    }
  }

  void sendGroupNamesToUser(String username) async {
    try {
      final List<String> groupNames =
          await _databaseManager.getGroupNamesForUser(username);
      final Map<String, dynamic> data = {
        'type': 'group_names',
        'username': username,
        'group_names': groupNames,
      };
      final String jsonData = jsonEncode(data);
      final recipientChannel = _userChannels[username];
      recipientChannel!.sink.add(jsonData);
      ;
    } catch (e) {
      print('Error sending group names to user: $e');
    }
  }

  void handleWebSocket(WebSocketChannel webSocket) {
    String? username = null;

    webSocket.stream.listen((message) async {
      if (message != null) {
        final Map<String, dynamic> data = jsonDecode(message);

        if (data['type'] == 'connect') {
          username = data['username'];
          _userChannels[username ?? 'def'] = webSocket;
          User? userId = await _databaseManager.getUserByUsername(username!);
          sendAllGroupMessagesForUser(username!, userId!.id, 'group_message');
          sendAllMessagesForUser(username!, 'chat_message');

          sendGroupNamesToUser(username!);
        } else if (data['type'] == 'message') {
          // Handle incoming messages
          final String messageId = data['messageId'];
          final String senderUsername = data['senderUsername'];
          final String recipientUsername = data['recipientUsername'];
          final String messageContent = data['content'];
          final String timestamp = data['timestamp'];
          final bool isRead = data['isRead'];
          final bool isSent = data['isSent'];

          if (recipientUsername == 'all') {
            print("reached here ****\n****************");
            List users = await _databaseManager.getAllUsernames();
            print(users);
            print('xxx');
            // Iterate through your users and send the message to each of them

            for (var user in users) {
              final messageToSave = Message(
                generateUniqueId(),
                senderUsername,
                user, // Assuming username is the key for username in your user data
                messageContent,
                timestamp,
                isRead,
                isSent,
              );
              _databaseManager.saveMessage(messageToSave);

              final recipientChannel = _userChannels[
                  user]; // Assuming username is the key for username in your user data

              print('brodacasted to:$recipientChannel');
              final messageData = {
                'type': 'chat_message',
                'messageId': messageId,
                'senderUsername': senderUsername,
                'recipientUsername':
                    user, // Assuming username is the key for username in your user data
                'content': messageContent,
                'timestamp': timestamp,
                'isRead': isRead,
                'isSent': false,
              };
              if (recipientChannel != null) {
                recipientChannel.sink.add(jsonEncode(messageData));
              } else {
                print('User is offline');
              }
            }
          } else {
            final messageToSave = Message(
              messageId,
              senderUsername,
              recipientUsername,
              messageContent,
              timestamp,
              isRead,
              isSent,
            );
            _databaseManager.saveMessage(messageToSave);

            if (username != null && senderUsername == username) {
              _databaseManager.updateMessageSentStatus(messageId);
            }
            final recipientChannel = _userChannels[recipientUsername];
            if (recipientChannel != null) {
              final messageData = {
                'type': 'chat_message',
                'messageId': messageId,
                'senderUsername': senderUsername,
                'recipientUsername': recipientUsername,
                'content': messageContent,
                'timestamp': timestamp,
                'isRead': isRead,
                'isSent': false,
              };

              recipientChannel.sink.add(jsonEncode(messageData));
            } else {
              print("Channel not found, user $recipientUsername is offline");
            }
          }
        } else if (data['type'] == 'group_message') {
          print(
              'hhhhhhhhh\nhhhhhhhhhhhhh\nhhhhhhhhhhhh\nhhhhhhhhhhhhhh\nhhhhhhhhhhhhhhhh');
          // Handle incoming group messages
          final int messageId = data['messageId'];

          final String groupName = data['groupName'];
          print(groupName);
          print('xxxxxxxxx');
          final int? groupId =
              await _databaseManager.getGroupIdByGroupName(groupName);
          final String senderId = data['senderId'];
          final String senderName = data['senderName'];
          final String messageContent = data['messageContent'];
          final String timestamp = data['timestamp'];

          // Save the incoming group message
          final messageToSave = GroupMessage(
            messageId,
            groupId!,
            groupName,
            senderId,
            senderName,
            messageContent,
            timestamp,
          );
          _databaseManager.saveGroupMessage(messageToSave);
          User? user = await _databaseManager.getUserByUsername(senderName);
          // If the current user sent the message, update its status to 'sent'

          // Broadcast the group message to all members of the group
          final List<int> groupMembers =
              await _databaseManager.getGroupMembers(groupName);

          print(groupMembers);
          print('group memeberssssssssssss');
          for (final int memberId in groupMembers) {
            if (memberId != user!.id) {
              User? member = await _databaseManager.getUserById(memberId);
              final recipientChannel = _userChannels[member!.username];
              if (recipientChannel != null) {
                final messageData = {
                  'type': 'group_message',
                  'messageId': messageId,
                  'groupId': groupId,
                  'groupName': groupName,
                  'senderId': senderId,
                  'senderName': senderName,
                  'messageContent': messageContent,
                  'timestamp': timestamp,
                };
                recipientChannel.sink.add(jsonEncode(messageData));

                print("message broadcasted successfully");
              } else {
                print(
                    "Channel not found for user $memberId. User may be offline.");
              }
            }
          }
        } else if (data['type'] == 'delete') {
          // Handle delete messages
          final String messageId = data['messageId'];

          if (username != null) {
            // Check if the user has the right to delete the message
            final result = _databaseManager.checkMessageExists(messageId);
            if (await result) {
              // Delete the message from the database
              await _databaseManager.deleteMessage(messageId);
            } else {
              print('message not found on server');
            }
          }
        }
      } else {
        // Handle null message
      }
    }, onError: (error) {
      // Handle WebSocket error
      if (username != null) {
        _userChannels.remove(username!); // Remove user channel on error
      }
    }, onDone: () {
      // WebSocket connection closed
      if (username != null) {
        _userChannels
            .remove(username!); // Remove user channel when connection is closed
      }
    });
  }

  Future<shelf.Response> handleHttpRequest(shelf.Request request) async {
    if (request.method == 'POST') {
      if (request.url.path == 'login') {
        return _handleRequest.handleLoginRequest(request);
      } else if (request.url.path == 'register') {
        return _handleRequest.handleRegisterRequest(request);
      } else if (request.url.path == 'update-message') {
        _handleRequest.handleUpdateMessageRequest(request);
      } else if (request.url.path == 'add_contact') {
        return _handleRequest.handleAddContactRequest(request);
      } else if (request.url.path == 'get_contacts') {
        return _handleRequest.handleGetContactsRequest(request);
      } else if (request.url.path == 'update_contact') {
        return _handleRequest.handleUpdateContactRequest(request);
      } else if (request.url.path == 'remove_contact') {
        return _handleRequest.handleRemoveContactRequest(request);
      } else if (request.url.path == 'upload') {
        return _handleRequest.handleUploadImageRequest(request);
      } else if (request.url.path == 'create_group') {
        return _handleRequest.handleCreateGroupRequest(request);
      }
    } else if (request.method == 'GET') {
      if (request.url.pathSegments.first == 'profile_image') {
        return _handleRequest.handleGetProfileImageRequest(request);
      } else if (request.url.pathSegments.first == 'group_image') {
        return _handleRequest.handleGroupImageRequest(request);
      } else if (request.url.pathSegments.first == 'user') {
        return _handleRequest.handleGetUserExistsRequest(request);
      } else if (request.url.path == 'latest_messages') {
        return _handleRequest.handleGetLatestMessagesRequest(request);
      } else if (request.url.pathSegments.first == 'groups') {
        return _handleRequest.handleGetUserGroups(request);
      } else if (request.url.pathSegments.first == 'time') {
        return _handleRequest.handleTimeRequest(request);
      }
    }

    if (request.headers['upgrade']?.toLowerCase() == 'websocket') {
      return shelf_web_socket.webSocketHandler(handleWebSocket)(request);
    }

    return shelf.Response.notFound('Not Found');
  }
}
