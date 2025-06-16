import 'dart:async';
import 'dart:developer' as developer;

import 'package:signalr_core/signalr_core.dart';

import 'connection_options.dart';
import 'message.dart';

class SignalRChatPlugin {
  static final SignalRChatPlugin _instance = SignalRChatPlugin._internal();
  late HubConnection _connection;
  bool _isInitialized = false;
  int _retryCount = 0;
  final List<ChatMessage> _messageQueue = [];
  final Set<String> _joinedRooms = {};

  final StreamController<ChatMessage> _messageStreamController =
      StreamController.broadcast();

  Stream<ChatMessage> get messagesStream => _messageStreamController.stream;

  final StreamController<ConnectionStatus> _connectionStateController =
      StreamController.broadcast();

  Stream<ConnectionStatus> get connectionStateStream =>
      _connectionStateController.stream;

  final StreamController<String> _errorStreamController =
      StreamController.broadcast();

  Stream<String> get errorStream => _errorStreamController.stream;

  final StreamController<String> _roomStreamController =
      StreamController.broadcast();

  Stream<String> get roomStream => _roomStreamController.stream;

  SignalRConnectionOptions? _options;

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
        await sendMessage(message.sender, message.content, roomId: message.roomId);
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
                  transport: HttpTransportType.webSockets,
                  skipNegotiation: true,
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
            roomId: arguments[2] as String,
            messageId: arguments.length > 3 ? arguments[3] as String? : null,
            status: MessageStatus.delivered,
          );
          _messageStreamController.add(message);
        } catch (e) {
          _errorStreamController.add('Error processing received message: $e');
        }
      }
    });

    _connection.on('RoomJoined', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final roomId = arguments[0] as String;
        _joinedRooms.add(roomId);
        _roomStreamController.add('Joined room: $roomId');
      }
    });

    _connection.on('RoomLeft', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final roomId = arguments[0] as String;
        _joinedRooms.remove(roomId);
        _roomStreamController.add('Left room: $roomId');
      }
    });
  }

  Future<void> joinRoom(String roomId) async {
    if (!_isInitialized) {
      throw Exception('SignalR not initialized');
    }

    try {
      await _connection.invoke('JoinRoom', args: [roomId]);
    } catch (e) {
      _errorStreamController.add('Failed to join room: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomId) async {
    if (!_isInitialized) {
      throw Exception('SignalR not initialized');
    }

    try {
      await _connection.invoke('LeaveRoom', args: [roomId]);
    } catch (e) {
      _errorStreamController.add('Failed to leave room: $e');
      rethrow;
    }
  }

  Future<void> sendMessage(String sender, String content, {String? roomId}) async {
    final message = ChatMessage(
      sender: sender,
      content: content,
      roomId: roomId,
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    if (_connection.state != HubConnectionState.connected) {
      _messageQueue.add(message);
      _errorStreamController.add('Message queued for later delivery');
      return;
    }

    try {
      if (roomId != null) {
        if (!_joinedRooms.contains(roomId)) {
          throw Exception('Not joined to room: $roomId');
        }
        await _connection.invoke(
          'SendMessageToRoom',
          args: [message.sender, message.content, message.roomId, message.messageId],
        );
      } else {
        await _connection.invoke(
          'SendMessage',
          args: [message.sender, message.content, message.messageId],
        );
      }
    } catch (e) {
      developer.log('Error sending message: $e');
      _messageQueue.add(message);
      _errorStreamController.add('Failed to send message: $e');

      final failedMessage = ChatMessage(
        sender: message.sender,
        content: message.content,
        roomId: message.roomId,
        messageId: message.messageId,
        status: MessageStatus.failed,
      );
      _messageStreamController.add(failedMessage);
    }
  }

  Future<void> disconnect() async {
    if (_isInitialized) {
      await _connection.stop();
      _isInitialized = false;
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
    _roomStreamController.close();
  }

  Set<String> get joinedRooms => Set.unmodifiable(_joinedRooms);
}
