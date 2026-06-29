import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectAsRealtimeWebSocket(Uri uri) {
  return IOWebSocketChannel.connect(uri);
}
