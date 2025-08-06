import 'dart:async';
import 'dart:developer' as developer;

import 'package:signalr_core/signalr_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

import 'connection_options.dart';
import 'message.dart';
import 'user_room_connection.dart';

class SignalRChatPlugin {
  // ============================================================================
  // SINGLETON PATTERN
  // ============================================================================
  static final SignalRChatPlugin _instance = SignalRChatPlugin._internal();

  factory SignalRChatPlugin() {
    return _instance;
  }

  SignalRChatPlugin._internal();

  // ============================================================================
  // PRIVATE FIELDS
  // ============================================================================
  late HubConnection _connection;
  bool _isInitialized = false;
  int _retryCount = 0;
  final List<ChatMessage> _messageQueue = [];
  SignalRConnectionOptions? _options;
  UserRoomConnection? _currentConnection;

  // ============================================================================
  // RXDART SUBJECTS
  // ============================================================================
  final BehaviorSubject<ChatMessage> _messageSubject = BehaviorSubject<ChatMessage>();
  final BehaviorSubject<List<String>> _connectedUsersSubject = BehaviorSubject<List<String>>();
  final BehaviorSubject<ConnectionStatus> _connectionStateSubject = BehaviorSubject<ConnectionStatus>();
  final PublishSubject<String> _errorSubject = PublishSubject<String>();
  final BehaviorSubject<bool> _isConnectedSubject = BehaviorSubject<bool>.seeded(false);

  // ============================================================================
  // PUBLIC STREAMS
  // ============================================================================
  Stream<ChatMessage> get messagesStream => _messageSubject.stream;
  Stream<List<String>> get connectedUsersStream => _connectedUsersSubject.stream;
  Stream<ConnectionStatus> get connectionStateStream => _connectionStateSubject.stream;
  Stream<String> get errorStream => _errorSubject.stream;
  Stream<bool> get isConnectedStream => _isConnectedSubject.stream;

  // ============================================================================
  // LATEST VALUES (GETTERS)
  // ============================================================================
  ChatMessage? get lastMessage => _messageSubject.valueOrNull;
  List<String> get currentConnectedUsers => _connectedUsersSubject.valueOrNull ?? [];
  ConnectionStatus get currentConnectionStatus => _connectionStateSubject.valueOrNull ?? ConnectionStatus.disconnected;
  bool get isConnected => _isConnectedSubject.value;

<<<<<<< Updated upstream
    // Check network connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      developer.log(
        'No network available. Waiting 3 seconds to retry reconnect...',
      );
      _errorStreamController.add('No network available. Waiting to retry...');
      await Future.delayed(const Duration(seconds: 3));
      return reconnect(); // Try again later
    }
=======
  // ============================================================================
  // ADVANCED STREAMS
  // ============================================================================
  Stream<Map<String, dynamic>> get connectionInfoStream => Rx.combineLatest3(
    connectionStateStream,
    isConnectedStream,
    connectedUsersStream,
    (ConnectionStatus status, bool connected, List<String> users) => {
      'status': status,
      'connected': connected,
      'users': users,
      'timestamp': DateTime.now(),
    },
  );
>>>>>>> Stashed changes

  Stream<ConnectionStatus> get connectionStateChanges => connectionStateStream
      .distinct()
      .where((status) => status != ConnectionStatus.disconnected || _isInitialized);

  Stream<String> get errorStreamWithRetry => _errorSubject.stream
      .where((error) => error.contains('Failed to send message') || error.contains('Connection'))
      .debounceTime(const Duration(seconds: 2))
      .distinct();

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================
  Future<void> initSignalR(SignalRConnectionOptions options) async {
    try {
      if (_isInitialized) {
        developer.log('SignalR already initialized, disconnecting first...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _options = options;
      _connectionStateSubject.add(ConnectionStatus.connecting);
      _isConnectedSubject.add(false);

      developer.log('Building SignalR connection to: ${options.serverUrl}');

      _connection =
          HubConnectionBuilder()
              .withUrl(
                options.serverUrl,
                HttpConnectionOptions(
                  transport: options.transport,
                  skipNegotiation: options.skipNegotiation,
                  accessTokenFactory:
                      options.accessToken != null
                          ? () async => options.accessToken!
                          : null,
                  logging:
                      (level, message) =>
                          developer.log('SignalR: [$level] $message'),
                ),
              )
              .withAutomaticReconnect([0, 2000, 5000, 10000, 30000])
              .build();

      // Setup handlers before starting connection
      _setupConnectionHandlers();
      _setupMessageHandlers();

      developer.log('Starting SignalR connection...');
      await _connection.start();

      // Wait a bit to ensure connection is stable
      await Future.delayed(const Duration(milliseconds: 300));

      developer.log('SignalR connection started successfully');
      developer.log('Connection state: ${_connection.state}');
      developer.log('Connection ID: ${_connection.connectionId}');

      _isInitialized = true;
      _connectionStateSubject.add(ConnectionStatus.connected);
      _isConnectedSubject.add(true);
    } catch (e, stackTrace) {
      developer.log('Failed to initialize SignalR: $e');
      developer.log('Stack trace: $stackTrace');
      _connectionStateSubject.add(ConnectionStatus.disconnected);
      _isConnectedSubject.add(false);
      _errorSubject.add('Initialization error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CONNECTION HANDLERS SETUP
  // ============================================================================
  void _setupConnectionHandlers() {
    _connection.onclose((error) {
      developer.log('Connection closed: $error');
      _connectionStateSubject.add(ConnectionStatus.disconnected);
      _isConnectedSubject.add(false);
      if (_options?.autoReconnect ?? false) {
        Future.delayed(const Duration(seconds: 1), () => reconnect());
      }
    });

    _connection.onreconnecting((error) {
      developer.log('Connection reconnecting: $error');
      _connectionStateSubject.add(ConnectionStatus.reconnecting);
      _isConnectedSubject.add(false);
    });

    _connection.onreconnected((connectionId) async {
      developer.log('Connection reconnected: $connectionId');
      _connectionStateSubject.add(ConnectionStatus.connected);
      _isConnectedSubject.add(true);
      if (_currentConnection != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await joinRoom(_currentConnection!);
      }
      _processMessageQueue();
    });
  }

  void _setupMessageHandlers() {
    _connection.on('ReceiveMessage', (List<Object?>? arguments) {
      developer.log('ReceiveMessage handler called with arguments: $arguments');

      if (arguments != null && arguments.length >= 3) {
        try {
          final sender = arguments[0]?.toString() ?? 'Unknown';
          final content = arguments[1]?.toString() ?? '';
          final timestamp =
              arguments[2]?.toString() ?? DateTime.now().toIso8601String();

          final message = ChatMessage(
            sender: sender,
            content: content,
            timestamp: DateTime.parse(timestamp),
            status: MessageStatus.delivered,
          );

          developer.log('Parsed message from $sender: $content');
          _messageSubject.add(message);
        } catch (e) {
          developer.log('Error processing received message: $e');
          _errorSubject.add('Error processing received message: $e');
        }
      } else {
        developer.log('Invalid message format received');
      }
    });

    _connection.on('ConnectedUser', (List<Object?>? arguments) {
      developer.log('ConnectedUser handler called with arguments: $arguments');

      if (arguments != null && arguments.isNotEmpty) {
        try {
          final users =
              (arguments[0] as List<dynamic>)
                  .map((user) => user.toString())
                  .toList();
          developer.log('Connected users: $users');
          _connectedUsersSubject.add(users);
        } catch (e) {
          developer.log('Error processing connected users: $e');
          _errorSubject.add('Error processing connected users: $e');
        }
      }
    });

    // Add handler for join room confirmation
    _connection.on('UserJoined', (List<Object?>? arguments) {
      developer.log('User joined confirmation received: $arguments');
    });

    // Add handler for error messages from server
    _connection.on('Error', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final error = arguments[0]?.toString() ?? 'Unknown error';
        developer.log('Server error received: $error');
        _errorSubject.add('Server error: $error');
      }
    });
  }

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================
  Future<void> joinRoom(UserRoomConnection userConnection) async {
    if (_connection.state != HubConnectionState.connected) {
      throw Exception('Cannot join room: Not connected to server');
    }

    _currentConnection = userConnection;

    try {
      developer.log(
        'Joining room - User: ${userConnection.user}, Room: ${userConnection.room}',
      );

      // Try different invoke patterns based on what your server expects
      await _connection.invoke('JoinRoom', args: [userConnection.toJson()]);

      developer.log('JoinRoom invoked successfully');
    } catch (e) {
      developer.log('Failed to join room: $e');

      // Try alternative invoke pattern
      try {
        developer.log('Trying alternative invoke pattern...');
        await _connection.invoke(
          'JoinRoom',
          args: [userConnection.user, userConnection.room],
        );
        developer.log('Alternative JoinRoom invoked successfully');
      } catch (altError) {
        developer.log('Alternative invoke also failed: $altError');
        _errorSubject.add('Failed to join room: $e');
        rethrow;
      }
    }
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  Future<void> sendMessage(String content) async {
    if (_connection.state != HubConnectionState.connected) {
      developer.log(
        'Cannot send message: Not connected (state: ${_connection.state})',
      );

      _messageQueue.add(
        ChatMessage(
          sender: _currentConnection?.user ?? 'Unknown',
          content: content,
          timestamp: DateTime.now(),
        ),
      );
      _errorSubject.add('Message queued for later delivery');
      return;
    }

    try {
      developer.log('Sending message: $content');

      // Try to send with content only first
      await _connection.invoke('SendMessage', args: [content]);

      developer.log('Message sent successfully');
    } catch (e) {
      developer.log('Error sending message: $e');

      // Try alternative patterns
      try {
        developer.log('Trying to send with room info...');
        await _connection.invoke(
          'SendMessage',
          args: [_currentConnection?.room ?? '', content],
        );
        developer.log('Alternative send successful');
      } catch (altError) {
        developer.log('Alternative send also failed: $altError');

        _messageQueue.add(
          ChatMessage(
            sender: _currentConnection?.user ?? 'Unknown',
            content: content,
            timestamp: DateTime.now(),
          ),
        );

        _errorSubject.add('Failed to send message: $e');

        final failedMessage = ChatMessage(
          sender: _currentConnection?.user ?? 'Unknown',
          content: content,
          timestamp: DateTime.now(),
          status: MessageStatus.failed,
        );
        _messageSubject.add(failedMessage);
      }
    }
  }

  Future<void> _processMessageQueue() async {
    if (_messageQueue.isEmpty) return;

    while (_messageQueue.isNotEmpty && _connection.state == HubConnectionState.connected) {
      final message = _messageQueue.first;
      try {
        await sendMessage(message.content);
        _messageQueue.removeAt(0);
      } catch (e) {
        _errorSubject.add('Failed to process queued message: $e');
        break;
      }
    }
  }

  Future<bool> clearMessageQueue() async {
    _messageQueue.clear();
    return true;
  }

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================
  Future<void> reconnect() async {
    if (_options == null || !_options!.autoReconnect) return;

    // Wait a bit after resume to allow network stack to recover
    developer.log('Waiting 2 seconds before attempting reconnection...');
    await Future.delayed(const Duration(seconds: 2));

    // Check network connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      developer.log(
        'No network available. Waiting 3 seconds to retry reconnect...',
      );
      _errorSubject.add('No network available. Waiting to retry...');
      await Future.delayed(const Duration(seconds: 3));
      return reconnect(); // Try again later
    }

    // Check and fix URL if it contains port :0
    if (_options != null && _options!.serverUrl.contains(':0')) {
      final fixedUrl = _options!.serverUrl.replaceAll(':0', '');
      developer.log(
        'Detected invalid port :0 in URL. Fixing URL from ${_options!.serverUrl} to $fixedUrl',
      );
      // Update the options with the corrected URL
      _options = SignalRConnectionOptions(
        serverUrl: fixedUrl,
        accessToken: _options!.accessToken,
        reconnectInterval: _options!.reconnectInterval,
        maxRetryAttempts: _options!.maxRetryAttempts,
        autoReconnect: _options!.autoReconnect,
        onError: _options!.onError,
        useSecureConnection: _options!.useSecureConnection,
        transport: _options!.transport,
        skipNegotiation: _options!.skipNegotiation,
      );
    }

    while (_connection.state != HubConnectionState.connected &&
        _retryCount < _options!.maxRetryAttempts) {
      try {
        developer.log('Attempting to reconnect to: ${_options!.serverUrl}');
        _connectionStateSubject.add(ConnectionStatus.reconnecting);
        _isConnectedSubject.add(false);
        
        await _connection.start();
        
        _connectionStateSubject.add(ConnectionStatus.connected);
        _isConnectedSubject.add(true);
        _retryCount = 0;

        // Rejoin room after reconnection if we were in one
        if (_currentConnection != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          await joinRoom(_currentConnection!);
        }

        await _processMessageQueue();
        break;
      } catch (e) {
        _retryCount++;
        developer.log(
          'Reconnection attempt $_retryCount failed: ${e.toString()}',
        );
        _errorSubject.add(
          'Reconnection attempt $_retryCount failed: ${e.toString()}',
        );
        // If DNS error, wait longer before retrying
        if (e.toString().contains('Failed host lookup')) {
          developer.log(
            'DNS error detected. Waiting 5 seconds before retrying...',
          );
          _errorSubject.add(
            'DNS error: Unable to resolve server address. Waiting to retry...',
          );
          await Future.delayed(const Duration(seconds: 5));
        } else if (_retryCount < _options!.maxRetryAttempts) {
          await Future.delayed(_options!.reconnectInterval);
        }
      }
    }

    if (_retryCount >= _options!.maxRetryAttempts) {
      _connectionStateSubject.add(ConnectionStatus.disconnected);
      _isConnectedSubject.add(false);
      _errorSubject.add('Max reconnection attempts reached');
    }
  }

  Future<void> disconnect() async {
    if (_isInitialized) {
      developer.log('Disconnecting SignalR...');

      try {
        if (_currentConnection != null) {
          // Try to leave room before disconnecting
          await _connection.invoke('LeaveRoom').catchError((e) {
            developer.log('Failed to leave room: $e');
          });
        }
      } catch (e) {
        developer.log('Error during leave room: $e');
      }

      await _connection.stop();
      _isInitialized = false;
      _currentConnection = null;
      _messageQueue.clear();
      _retryCount = 0;
      _connectionStateSubject.add(ConnectionStatus.disconnected);
      _isConnectedSubject.add(false);
      developer.log('SignalR disconnected');
    }
  }

  // ============================================================================
  // ADVANCED STREAM OPERATIONS
  // ============================================================================
  Stream<ChatMessage> getMessagesBySender(String sender) {
    return messagesStream.where((message) => message.sender == sender);
  }

  Stream<ChatMessage> getRecentMessages({int count = 10}) {
    return messagesStream
        .bufferTime(const Duration(seconds: 1))
        .where((messages) => messages.isNotEmpty)
        .map((messages) => messages.last);
  }

  Stream<List<ChatMessage>> getMessageHistory({int windowSize = 50}) {
    return messagesStream
        .bufferCount(windowSize)
        .map((messages) => messages.toList());
  }

  Stream<ConnectionStatus> getConnectionStateChanges() {
    return connectionStateStream.distinct();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================
  void dispose() {
    _messageSubject.close();
    _connectionStateSubject.close();
    _errorSubject.close();
    _connectedUsersSubject.close();
    _isConnectedSubject.close();
  }
}
