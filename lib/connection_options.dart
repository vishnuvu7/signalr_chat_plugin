import 'package:signalr_core/signalr_core.dart';

class SignalRConnectionOptions {
  final String serverUrl;
  final String? accessToken;
  final Duration reconnectInterval;
  final int maxRetryAttempts;
  final bool autoReconnect;
  final Function(String)? onError;
  final bool useSecureConnection;
  final HttpTransportType transport;
  final bool skipNegotiation;

  SignalRConnectionOptions({
    required this.serverUrl,
    this.accessToken,
    this.reconnectInterval = const Duration(seconds: 5),
    this.maxRetryAttempts = 5,
    this.autoReconnect = true,
    this.onError,
    this.useSecureConnection = true,
    this.transport = HttpTransportType.webSockets,
    this.skipNegotiation = false,
  });
}
