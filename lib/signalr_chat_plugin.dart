import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import 'dart:async';
import 'dart:convert'; // Import this for JSON encoding

class SignalRChatPlugin {
  static final SignalRChatPlugin _instance = SignalRChatPlugin._internal();
  late HubConnection _connection;
  bool _isInitialized = false;

  final StreamController<String> _messageStreamController =
      StreamController.broadcast();
  Stream<String> get messagesStream => _messageStreamController.stream;

  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast(); // 🔹 New stream
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream; // 🔹 Expose status stream

  factory SignalRChatPlugin() {
    return _instance;
  }

  SignalRChatPlugin._internal();

  Future<void> reconnect() async {
    while (_connection.state != HubConnectionState.connected) {
      try {
        print("🔄 Attempting to reconnect...");
        await _connection.start();
        print("✅ Reconnected!");
        _connectionStatusController.add("Online");
        break;
      } catch (e) {
        print("❌ Reconnection failed. Retrying in 5 seconds...");
        await Future.delayed(Duration(seconds: 5));
      }
    }
  }

  /// Initialize SignalR connection
  Future<void> initSignalR(
      {required String serverUrl, String? accessToken}) async {
    try {
      if (_isInitialized) {
        print("✅ SignalR already initialized.");
        return;
      }
      Future<void> checkConnection() async {
        try {
          await _connection.invoke("CheckConnection", args: []);
          print("✅ CheckConnection event sent!");
        } catch (e) {
          print("❌ Failed to send CheckConnection event: $e");
        }
      }

      _connection = HubConnectionBuilder()
          .withUrl(
            serverUrl,
            HttpConnectionOptions(
              transport: HttpTransportType.longPolling,
              accessTokenFactory:
                  accessToken != null ? () async => accessToken : null,
              logging: (level, message) => print("🔍 SignalR Log: $message"),
            ),
          )
          .withAutomaticReconnect()
          .build();

      _connection.onclose((error) {
        _connectionStatusController.add("Disconnected");
        print("⚠️ SignalR Disconnected: $error");
        print("⚠️ SignalR Disconnected: $error");
        Future.delayed(Duration(seconds: 3), () {
          // _connection.start(); // Try reconnecting after a short delay
          // _connectionStatusController.add("Reconnecting...");
          reconnect();
        });
      });

      _connection.onreconnecting((error) {
        // _connectionStatusController.add("Reconnecting...");
        print("🔄 SignalR Reconnecting...");
      });

      _connection.onreconnected((connectionId) {
        Future.delayed(Duration(milliseconds: 500), () {
          _connectionStatusController.add("Online");
        });
        print("✅ SignalR Reconnected!");
      });

      _connection.on("CheckConnection", (args) {
        print("✅ Received CheckConnection event.");
        Future.delayed(Duration(milliseconds: 500), () {
          _connectionStatusController
              .add("Online"); // Ensure it's updated AFTER start()
        });
      });

      // Listen for incoming messages
      _connection.on("ReceiveMessage", (List<Object?>? arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          String sender =
              arguments[0] is String ? arguments[0] as String : "Unknown";
          String message = arguments.length > 1 && arguments[1] is String
              ? arguments[1] as String
              : "No message";

          print("📩 Message received from $sender: $message");

          // 🔹 Convert Map to JSON string
          _messageStreamController
              .add(jsonEncode({"sender": sender, "message": message}));
        }
      });

      print("🔄 Connecting to SignalR...");
      try {
        await _connection.start();
        Future.delayed(Duration(milliseconds: 500), () {
          _connectionStatusController
              .add("Online"); // Ensure it's updated AFTER start()
        });
        await checkConnection(); // 🔹 Ensure this runs
        print("✅ SignalR Connected!!!");
      } catch (e) {
        _connectionStatusController.add("Connection Failed");
        print("❌ SignalR Connection Error: $e");
      }
      _isInitialized = true;
      print("✅ SignalR Connected!");
    } catch (e, stackTrace) {
      print("❌ SignalR Connection Error: ${e.runtimeType} - ${e.toString()}");
      print(stackTrace);
    }
  }

  /// Send a message
  Future<void> sendMessage(String user, String message) async {
    if (!_isInitialized || _connection.state != HubConnectionState.connected) {
      print("⚠️ Cannot send message, SignalR not connected!");
      return;
    }
    try {
      print("📤 Sending message: $message");
      await _connection.invoke("SendMessage", args: [user, message]);
      print("✅ Message sent successfully.");
    } catch (e, stackTrace) {
      print("❌ Send Message Error: ${e.runtimeType} - ${e.toString()}");
      print(stackTrace);
    }
  }

  /// Disconnect from SignalR
  Future<void> disconnect() async {
    if (_isInitialized) {
      await _connection.stop();
      _isInitialized = false;
      print("🔌 SignalR Disconnected.");
    }
  }

  /// Dispose StreamController when not in use
  void dispose() {
    _messageStreamController.close();
    _connectionStatusController.close();
  }
}
