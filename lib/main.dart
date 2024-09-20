import 'package:server/chat_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final chatServer = ChatServer();

  final handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(chatServer.handleHttpRequest);

  final server = await io.serve(handler, '192.168.1.6', 8080);
  print('Server running on ${server.address}:${server.port}');
}
