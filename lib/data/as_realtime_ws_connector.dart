import 'package:web_socket_channel/web_socket_channel.dart';

import 'as_realtime_ws_connector_stub.dart'
    if (dart.library.io) 'as_realtime_ws_connector_io.dart'
    if (dart.library.js_interop) 'as_realtime_ws_connector_web.dart'
    as platform;

WebSocketChannel connectAsRealtimeWebSocket(Uri uri) {
  return platform.connectAsRealtimeWebSocket(uri);
}
