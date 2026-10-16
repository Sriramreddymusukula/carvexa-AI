import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Finds the Carvexa API by asking for it over the local IPv4 broadcast.
///
/// This intentionally uses Dart's socket library so the app needs no extra
/// network-discovery package. The backend replies directly to this socket,
/// which gives us its reachable LAN address without guessing the PC's IP.
class BackendDiscovery {
  BackendDiscovery._();

  static const int discoveryPort = 4001;
  static const String _request = 'CARVEXA_DISCOVER_V1';

  static Future<String> discover({required Duration timeout}) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? timer;
    final Completer<String> result = Completer<String>();

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      subscription = socket.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        Datagram? datagram;
        while ((datagram = socket!.receive()) != null) {
          try {
            final Object? decoded = jsonDecode(utf8.decode(datagram!.data));
            if (decoded is! Map<String, dynamic> ||
                decoded['service'] != 'carvexa-api' ||
                decoded['port'] is! int) {
              continue;
            }
            final int port = decoded['port'] as int;
            if (port < 1 || port > 65535) continue;
            if (!result.isCompleted) {
              result.complete('http://${datagram.address.address}:$port/api');
            }
          } on FormatException {
            // Ignore unrelated or malformed packets on the broadcast port.
          }
        }
      });
      timer = Timer(timeout, () {
        if (!result.isCompleted) {
          result.completeError(const BackendDiscoveryException());
        }
      });
      socket.send(
        utf8.encode(_request),
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
      return await result.future;
    } on BackendDiscoveryException {
      rethrow;
    } on SocketException catch (error) {
      throw BackendDiscoveryException(debugDetail: error.message);
    } finally {
      timer?.cancel();
      await subscription?.cancel();
      socket?.close();
    }
  }
}

class BackendDiscoveryException implements Exception {
  const BackendDiscoveryException({this.debugDetail});

  final String? debugDetail;

  @override
  String toString() => 'BackendDiscoveryException(${debugDetail ?? 'timeout'})';
}
