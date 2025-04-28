import 'dart:async';
import 'package:flutter/services.dart';

import 'signalr_chat_plugin_platform_interface.dart';
import 'connection_options.dart';
import 'message.dart';

class SignalrChatPlugin {
  /// Get platform version.
  Future<String?> getPlatformVersion() {
    return SignalrChatPluginPlatform.instance.getPlatformVersion();
  }

  /// Initialize SignalR connection
  Future<void> initializeSignalR(SignalRConnectionOptions options) {
    return SignalrChatPluginPlatform.instance.initializeSignalR(options);
  }

  /// Send a message through the SignalR connection
  Future<void> sendMessage(String sender, String content, {String? messageId}) {
    return SignalrChatPluginPlatform.instance.sendMessage(
        sender,
        content,
        messageId ?? DateTime.now().millisecondsSinceEpoch.toString()
    );
  }

  /// Disconnect from the SignalR hub
  Future<void> disconnect() {
    return SignalrChatPluginPlatform.instance.disconnect();
  }

  /// Stream of incoming messages
  Stream<ChatMessage> get messagesStream {
    return SignalrChatPluginPlatform.instance.messagesStream;
  }

  /// Stream of connection status updates
  Stream<ConnectionStatus> get connectionStatusStream {
    return SignalrChatPluginPlatform.instance.connectionStatusStream;
  }

  /// Stream of error messages
  Stream<String> get errorStream {
    return SignalrChatPluginPlatform.instance.errorStream;
  }
}


// import 'dart:async';
// import 'dart:developer' as developer;
//
// import 'package:signalr_core/signalr_core.dart';
//
// import 'connection_options.dart';
// import 'message.dart';
//
// class SignalRChatPlugin {
//   static final SignalRChatPlugin _instance = SignalRChatPlugin._internal();
//   late HubConnection _connection;
//   bool _isInitialized = false;
//   int _retryCount = 0;
//   final List<ChatMessage> _messageQueue = [];
//
//   final StreamController<ChatMessage> _messageStreamController =
//       StreamController.broadcast();
//
//   Stream<ChatMessage> get messagesStream => _messageStreamController.stream;
//
//   final StreamController<ConnectionStatus> _connectionStateController =
//       StreamController.broadcast();
//
//   Stream<ConnectionStatus> get connectionStateStream =>
//       _connectionStateController.stream;
//
//   final StreamController<String> _errorStreamController =
//       StreamController.broadcast();
//
//   Stream<String> get errorStream => _errorStreamController.stream;
//
//   SignalRConnectionOptions? _options;
//
//   factory SignalRChatPlugin() {
//     return _instance;
//   }
//
//   SignalRChatPlugin._internal();
//
//   Future<void> _processMessageQueue() async {
//     if (_messageQueue.isEmpty) return;
//
//     while (_messageQueue.isNotEmpty &&
//         _connection.state == HubConnectionState.connected) {
//       final message = _messageQueue.first;
//       try {
//         await sendMessage(message.sender, message.content);
//         _messageQueue.removeAt(0);
//       } catch (e) {
//         _errorStreamController.add('Failed to process queued message: $e');
//         break;
//       }
//     }
//   }
//
//   Future<void> reconnect() async {
//     if (_options == null || !_options!.autoReconnect) return;
//
//     while (_connection.state != HubConnectionState.connected &&
//         _retryCount < _options!.maxRetryAttempts) {
//       try {
//         _connectionStateController.add(ConnectionStatus.reconnecting);
//         await _connection.start();
//         _connectionStateController.add(ConnectionStatus.connected);
//         _retryCount = 0;
//         await _processMessageQueue();
//         break;
//       } catch (e) {
//         _retryCount++;
//         _errorStreamController.add(
//           'Reconnection attempt $_retryCount failed: $e',
//         );
//         if (_retryCount < _options!.maxRetryAttempts) {
//           await Future.delayed(_options!.reconnectInterval);
//         }
//       }
//     }
//
//     if (_retryCount >= _options!.maxRetryAttempts) {
//       _connectionStateController.add(ConnectionStatus.disconnected);
//       _errorStreamController.add('Max reconnection attempts reached');
//     }
//   }
//
//   Future<void> initSignalR(SignalRConnectionOptions options) async {
//     try {
//       if (_isInitialized) {
//         _errorStreamController.add('SignalR already initialized');
//         return;
//       }
//
//       _options = options;
//       _connectionStateController.add(ConnectionStatus.connecting);
//
//       _connection =
//           HubConnectionBuilder()
//               .withUrl(
//                 options.serverUrl,
//                 HttpConnectionOptions(
//                   transport: HttpTransportType.webSockets,
//                   skipNegotiation: true,
//                   accessTokenFactory:
//                       options.accessToken != null
//                           ? () async => options.accessToken!
//                           : null,
//                   logging:
//                       (level, message) =>
//                           developer.log('SignalR Log: $message'),
//                 ),
//               )
//               .withAutomaticReconnect()
//               .build();
//
//       _setupConnectionHandlers();
//       _setupMessageHandlers();
//
//       await _connection.start();
//       _isInitialized = true;
//       _connectionStateController.add(ConnectionStatus.connected);
//     } catch (e, stackTrace) {
//       _connectionStateController.add(ConnectionStatus.disconnected);
//       _errorStreamController.add('Initialization error: $e\n$stackTrace');
//       rethrow;
//     }
//   }
//
//   void _setupConnectionHandlers() {
//     _connection.onclose((error) {
//       _connectionStateController.add(ConnectionStatus.disconnected);
//       if (_options?.autoReconnect ?? false) {
//         reconnect();
//       }
//     });
//
//     _connection.onreconnecting((error) {
//       _connectionStateController.add(ConnectionStatus.reconnecting);
//     });
//
//     _connection.onreconnected((connectionId) {
//       _connectionStateController.add(ConnectionStatus.connected);
//       _processMessageQueue();
//     });
//   }
//
//   void _setupMessageHandlers() {
//     _connection.on('ReceiveMessage', (List<Object?>? arguments) {
//       if (arguments != null && arguments.length >= 2) {
//         try {
//           final message = ChatMessage(
//             sender: arguments[0] as String,
//             content: arguments[1] as String,
//             messageId: arguments.length > 2 ? arguments[2] as String? : null,
//             status: MessageStatus.delivered,
//           );
//           _messageStreamController.add(message);
//         } catch (e) {
//           _errorStreamController.add('Error processing received message: $e');
//         }
//       }
//     });
//   }
//
//   Future<void> sendMessage(String sender, String content) async {
//     final message = ChatMessage(
//       sender: sender,
//       content: content,
//       messageId: DateTime.now().millisecondsSinceEpoch.toString(),
//     );
//
//     if (_connection.state != HubConnectionState.connected) {
//       _messageQueue.add(message);
//       _errorStreamController.add('Message queued for later delivery');
//       return;
//     }
//
//     try {
//       // Try different method names and parameter formats that might be expected by the server
//       try {
//         // First try with the original format
//         await _connection.invoke(
//           'SendMessage',
//           args: [message.sender, message.content, message.messageId],
//         );
//       } catch (e) {
//         developer.log('First attempt failed, trying alternative format...');
//         // Try with just sender and content
//         await _connection.invoke(
//           'SendMessage',
//           args: [message.sender, message.content],
//         );
//       }
//
//       // Don't add the message to the stream here - let the server's response handle it
//       // The server will send back the message through the ReceiveMessage handler
//     } catch (e) {
//       developer.log('Error sending message: $e');
//       _messageQueue.add(message);
//       _errorStreamController.add('Failed to send message: $e');
//
//       final failedMessage = ChatMessage(
//         sender: message.sender,
//         content: message.content,
//         messageId: message.messageId,
//         status: MessageStatus.failed,
//       );
//       _messageStreamController.add(failedMessage);
//     }
//   }
//
//   Future<void> disconnect() async {
//     if (_isInitialized) {
//       await _connection.stop();
//       _isInitialized = false;
//       _connectionStateController.add(ConnectionStatus.disconnected);
//     }
//   }
//
//   Future<bool> clearMessageQueue() async {
//     _messageQueue.clear();
//     return true;
//   }
//
//   void dispose() {
//     _messageStreamController.close();
//     _connectionStateController.close();
//     _errorStreamController.close();
//   }
// }
