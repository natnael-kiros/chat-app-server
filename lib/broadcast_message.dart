import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  final String host = '192.168.1.6'; // Change to your server's host
  final int port = 8080; // Change to your server's WebSocket port

  try {
    // Connect to the server via WebSocket
    final socket =
        await IOWebSocketChannel.connect('ws://$host:$port/websocket');

    // Define the message to send
    final Map<String, dynamic> message = {
      'type': 'message',
      'messageId': generateUniqueId(),
      'senderUsername': 'admin',
      'recipientUsername': 'all',
      'content': 'second message from broadcast',
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
      'isSent': false,
    };
    //second message from broadcast
    // Convert the message to JSON and send it
    socket.sink.add(jsonEncode(message));

    // Listen for responses from the server
    socket.stream.listen((dynamic response) {
      print('Received from server: $response');
    }, onError: (error) {
      print('Error: $error');
    }, onDone: () {
      print('Connection closed');
    });
  } catch (e) {
    print('Error connecting to the server: $e');
  }
}

String generateUniqueId() {
  return DateTime.now().millisecondsSinceEpoch.toString();
}
