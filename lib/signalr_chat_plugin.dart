import 'dart:async';
import 'dart:developer' as developer;

import 'package:signalr_core/signalr_core.dart';

import 'connection_options.dart';
import 'message.dart';
import 'user_room_connection.dart';

class SignalRChatPlugin {
  static final SignalRChatPlugin _instance = SignalRChatPlugin._internal();
  late HubConnection _connection;
  bool _isInitialized = false;
  int _retryCount = 0;
  final List<ChatMessage> _messageQueue = [];

  final StreamController<ChatMessage> _messageStreamController =
  StreamController.broadcast();
  final StreamController<List<String>> _connectedUsersStreamController =
  StreamController.broadcast();

  Stream<ChatMessage> get messagesStream => _messageStreamController.stream;
  Stream<List<String>> get connectedUsersStream => _connectedUsersStreamController.stream;

  final StreamController<ConnectionStatus> _connectionStateController =
  StreamController.broadcast();

  Stream<ConnectionStatus> get connectionStateStream =>
      _connectionStateController.stream;

  final StreamController<String> _errorStreamController =
  StreamController.broadcast();

  Stream<String> get errorStream => _errorStreamController.stream;

  SignalRConnectionOptions? _options;
  UserRoomConnection? _currentConnection;

  factory SignalRChatPlugin() {
    return _instance;
  }

  SignalRChatPlugin._internal();

  Future<void> _processMessageQueue() async {
    if (_messageQueue.isEmpty) return;

    while (_messageQueue.isNotEmpty &&
        _connection.state == HubConnectionState.connected) {
      final message = _messageQueue.first;
      try {
        await sendMessage(message.content);
        _messageQueue.removeAt(0);
      } catch (e) {
        _errorStreamController.add('Failed to process queued message: $e');
        break;
      }
    }
  }

  Future<void> reconnect() async {
    if (_options == null || !_options!.autoReconnect) return;

    while (_connection.state != HubConnectionState.connected &&
        _retryCount < _options!.maxRetryAttempts) {
      try {
        _connectionStateController.add(ConnectionStatus.reconnecting);
        await _connection.start();
        _connectionStateController.add(ConnectionStatus.connected);
        _retryCount = 0;
        if (_currentConnection != null) {
          await joinRoom(_currentConnection!);
        }
        await _processMessageQueue();
        break;
      } catch (e) {
        _retryCount++;
        _errorStreamController.add(
          'Reconnection attempt $_retryCount failed: $e',
        );
        if (_retryCount < _options!.maxRetryAttempts) {
          await Future.delayed(_options!.reconnectInterval);
        }
      }
    }

    if (_retryCount >= _options!.maxRetryAttempts) {
      _connectionStateController.add(ConnectionStatus.disconnected);
      _errorStreamController.add('Max reconnection attempts reached');
    }
  }

  Future<void> initSignalR(SignalRConnectionOptions options) async {
    try {
      if (_isInitialized) {
        _errorStreamController.add('SignalR already initialized');
        return;
      }

      _options = options;
      _connectionStateController.add(ConnectionStatus.connecting);

      _connection =
          HubConnectionBuilder()
              .withUrl(
            options.serverUrl,
            HttpConnectionOptions(
              transport: HttpTransportType.longPolling,
              skipNegotiation: false,
              accessTokenFactory:
              options.accessToken != null
                  ? () async => options.accessToken!
                  : null,
              logging:
                  (level, message) =>
                  developer.log('SignalR Log: $message'),
            ),
          )
              .withAutomaticReconnect()
              .build();

      _setupConnectionHandlers();
      _setupMessageHandlers();

      await _connection.start();
      _isInitialized = true;
      _connectionStateController.add(ConnectionStatus.connected);
    } catch (e, stackTrace) {
      _connectionStateController.add(ConnectionStatus.disconnected);
      _errorStreamController.add('Initialization error: $e\n$stackTrace');
      rethrow;
    }
  }

  void _setupConnectionHandlers() {
    _connection.onclose((error) {
      _connectionStateController.add(ConnectionStatus.disconnected);
      if (_options?.autoReconnect ?? false) {
        reconnect();
      }
    });

    _connection.onreconnecting((error) {
      _connectionStateController.add(ConnectionStatus.reconnecting);
    });

    _connection.onreconnected((connectionId) {
      _connectionStateController.add(ConnectionStatus.connected);
      _processMessageQueue();
    });
  }

  void _setupMessageHandlers() {
    _connection.on('ReceiveMessage', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 3) {
        try {
          final message = ChatMessage(
            sender: arguments[0] as String,
            content: arguments[1] as String,
            timestamp: DateTime.parse(arguments[2] as String),
            status: MessageStatus.delivered,
          );
          _messageStreamController.add(message);
        } catch (e) {
          _errorStreamController.add('Error processing received message: $e');
        }
      }
    });

    _connection.on('ConnectedUser', (List<Object?>? arguments) {
      if (arguments != null) {
        try {
          final users =
          (arguments[0] as List<dynamic>)
              .map((user) => user as String)
              .toList();
          _connectedUsersStreamController.add(users);
        } catch (e) {
          _errorStreamController.add('Error processing connected users: $e');
        }
      }
    });
  }

  Future<void> joinRoom(UserRoomConnection userConnection) async {
    _currentConnection = userConnection;
    try {
      await _connection.invoke('JoinRoom', args: [userConnection.toJson()]);
    } catch (e) {
      _errorStreamController.add('Failed to join room: $e');
      rethrow;
    }
  }

  Future<void> sendMessage(String content) async {
    if (_connection.state != HubConnectionState.connected) {
      _messageQueue.add(
        ChatMessage(
          sender: _currentConnection?.user ?? 'Unknown',
          content: content,
          timestamp: DateTime.now(),
        ),
      );
      _errorStreamController.add('Message queued for later delivery');
      return;
    }

    try {
      await _connection.invoke('SendMessage', args: [content]);
    } catch (e) {
      developer.log('Error sending message: $e');
      _messageQueue.add(
        ChatMessage(
          sender: _currentConnection?.user ?? 'Unknown',
          content: content,
          timestamp: DateTime.now(),
        ),
      );
      _errorStreamController.add('Failed to send message: $e');

      final failedMessage = ChatMessage(
        sender: _currentConnection?.user ?? 'Unknown',
        content: content,
        timestamp: DateTime.now(),
        status: MessageStatus.failed,
      );
      _messageStreamController.add(failedMessage);
    }
  }

  Future<void> disconnect() async {
    if (_isInitialized) {
      await _connection.stop();
      _isInitialized = false;
      _currentConnection = null;
      _connectionStateController.add(ConnectionStatus.disconnected);
    }
  }

  Future<bool> clearMessageQueue() async {
    _messageQueue.clear();
    return true;
  }

  void dispose() {
    _messageStreamController.close();
    _connectionStateController.close();
    _errorStreamController.close();
    _connectedUsersStreamController.close();
  }
}
