import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'signalr_chat_plugin.dart';
import 'connection_options.dart';
import 'message.dart';
import 'user_room_connection.dart';

/// Example class demonstrating advanced RxDart usage with SignalR Chat Plugin
class SignalRRxExample {
  final SignalRChatPlugin _chatPlugin = SignalRChatPlugin();
  
  // Stream subscriptions for reactive UI updates
  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<List<String>>? _usersSubscription;
  StreamSubscription<Map<String, dynamic>>? _connectionInfoSubscription;

  // Reactive state management
  final BehaviorSubject<List<ChatMessage>> _messagesSubject = BehaviorSubject<List<ChatMessage>>();
  final BehaviorSubject<ConnectionStatus> _connectionStatusSubject = BehaviorSubject<ConnectionStatus>();
  final BehaviorSubject<List<String>> _usersSubject = BehaviorSubject<List<String>>();
  final PublishSubject<String> _errorsSubject = PublishSubject<String>();

  // Public streams for UI consumption
  Stream<List<ChatMessage>> get messagesStream => _messagesSubject.stream;
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusSubject.stream;
  Stream<List<String>> get usersStream => _usersSubject.stream;
  Stream<String> get errorsStream => _errorsSubject.stream;

  // Latest values for immediate access
  List<ChatMessage> get currentMessages => _messagesSubject.valueOrNull ?? [];
  ConnectionStatus get currentConnectionStatus => _connectionStatusSubject.valueOrNull ?? ConnectionStatus.disconnected;
  List<String> get currentUsers => _usersSubject.valueOrNull ?? [];

  /// Initialize the chat plugin with reactive streams
  Future<void> initializeChat({
    required String serverUrl,
    String? accessToken,
    bool autoReconnect = true,
  }) async {
    try {
      // Setup connection options
      final options = SignalRConnectionOptions(
        serverUrl: serverUrl,
        accessToken: accessToken,
        autoReconnect: autoReconnect,
        maxRetryAttempts: 5,
        reconnectInterval: const Duration(seconds: 3),
        onError: (error) => _errorsSubject.add(error),
      );

      // Initialize SignalR
      await _chatPlugin.initSignalR(options);

      // Setup reactive stream subscriptions
      _setupReactiveStreams();

      // Setup advanced RxDart operations
      _setupAdvancedRxOperations();

    } catch (e) {
      _errorsSubject.add('Failed to initialize chat: $e');
      rethrow;
    }
  }

  /// Setup reactive stream subscriptions
  void _setupReactiveStreams() {
    // Subscribe to messages with reactive processing
    _messageSubscription = _chatPlugin.messagesStream
        .bufferTime(const Duration(milliseconds: 100))
        .where((messages) => messages.isNotEmpty)
        .listen((messages) {
          final currentMessages = _messagesSubject.valueOrNull ?? [];
          final updatedMessages = [...currentMessages, ...messages];
          _messagesSubject.add(updatedMessages);
        });

    // Subscribe to connection status changes
    _connectionSubscription = _chatPlugin.connectionStateStream
        .distinct()
        .listen((status) {
          _connectionStatusSubject.add(status);
        });

    // Subscribe to connected users
    _usersSubscription = _chatPlugin.connectedUsersStream
        .listen((users) {
          _usersSubject.add(users);
        });

    // Subscribe to errors with retry logic
    _errorSubscription = _chatPlugin.errorStreamWithRetry
        .listen((error) {
          _errorsSubject.add(error);
        });

    // Subscribe to combined connection info
    _connectionInfoSubscription = _chatPlugin.connectionInfoStream
        .listen((info) {
          print('Connection Info: $info');
        });
  }

  /// Setup advanced RxDart operations
  void _setupAdvancedRxOperations() {
    // Create a stream that emits when connection is stable
    final stableConnectionStream = _chatPlugin.connectionStateStream
        .where((status) => status == ConnectionStatus.connected)
        .debounceTime(const Duration(seconds: 2));

    // Create a stream for message rate limiting
    final rateLimitedMessages = _chatPlugin.messagesStream
        .throttleTime(const Duration(milliseconds: 500))
        .listen((message) {
          print('Rate limited message: ${message.content}');
        });

    // Create a stream for error recovery
    final errorRecoveryStream = _chatPlugin.errorStream
        .where((error) => error.contains('Connection'))
        .delay(const Duration(seconds: 1))
        .listen((error) {
          print('Attempting error recovery for: $error');
        });
  }

  /// Join a room with reactive feedback
  Future<void> joinRoom(String user, String room) async {
    try {
      final userConnection = UserRoomConnection(user: user, room: room);
      await _chatPlugin.joinRoom(userConnection);

      // Wait for connection to be stable before proceeding
      await _chatPlugin.connectionStateStream
          .where((status) => status == ConnectionStatus.connected)
          .timeout(const Duration(seconds: 10))
          .first;

    } catch (e) {
      _errorsSubject.add('Failed to join room: $e');
      rethrow;
    }
  }

  /// Send message with reactive feedback
  Future<void> sendMessage(String content) async {
    try {
      await _chatPlugin.sendMessage(content);
    } catch (e) {
      _errorsSubject.add('Failed to send message: $e');
      rethrow;
    }
  }

  /// Get messages filtered by sender
  Stream<ChatMessage> getMessagesFromUser(String sender) {
    return _chatPlugin.getMessagesBySender(sender);
  }

  /// Get recent messages with time window
  Stream<ChatMessage> getRecentMessages({int count = 10}) {
    return _chatPlugin.getRecentMessages(count: count);
  }

  /// Get message history with buffer
  Stream<List<ChatMessage>> getMessageHistory({int windowSize = 50}) {
    return _chatPlugin.getMessageHistory(windowSize: windowSize);
  }

  /// Create a reactive message counter
  Stream<int> getMessageCount() {
    return _chatPlugin.messagesStream
        .scan((count, message, index) => count + 1, 0);
  }

  /// Create a reactive user activity stream
  Stream<Map<String, int>> getUserActivity() {
    return _chatPlugin.messagesStream
        .bufferTime(const Duration(minutes: 1))
        .map((messages) {
          final activity = <String, int>{};
          for (final message in messages) {
            activity[message.sender] = (activity[message.sender] ?? 0) + 1;
          }
          return activity;
        });
  }

  /// Create a connection health monitor
  Stream<bool> getConnectionHealth() {
    return Rx.combineLatest2(
      _chatPlugin.connectionStateStream,
      _chatPlugin.isConnectedStream,
      (status, connected) => status == ConnectionStatus.connected && connected,
    );
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    try {
      await _chatPlugin.disconnect();
    } finally {
      _cleanup();
    }
  }

  /// Cleanup all subscriptions
  void _cleanup() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _errorSubscription?.cancel();
    _usersSubscription?.cancel();
    _connectionInfoSubscription?.cancel();

    _messagesSubject.close();
    _connectionStatusSubject.close();
    _usersSubject.close();
    _errorsSubject.close();
  }

  /// Get a reactive stream for UI updates
  Stream<Map<String, dynamic>> getUIStateStream() {
    return Rx.combineLatest4(
      messagesStream,
      connectionStatusStream,
      usersStream,
      errorsStream.startWith(''),
      (messages, status, users, error) => {
        'messages': messages,
        'connectionStatus': status,
        'users': users,
        'lastError': error,
        'timestamp': DateTime.now(),
      },
    );
  }
}

/// Example Flutter widget using the reactive SignalR chat
class ReactiveChatWidget extends StatefulWidget {
  const ReactiveChatWidget({super.key});

  @override
  State<ReactiveChatWidget> createState() => _ReactiveChatWidgetState();
}

class _ReactiveChatWidgetState extends State<ReactiveChatWidget> {
  final SignalRRxExample _chatExample = SignalRRxExample();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      await _chatExample.initializeChat(
        serverUrl: 'https://your-signalr-server.com/chat',
        autoReconnect: true,
      );
    } catch (e) {
      print('Failed to initialize chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reactive SignalR Chat'),
      ),
      body: Column(
        children: [
          // Connection status
          StreamBuilder<ConnectionStatus>(
            stream: _chatExample.connectionStatusStream,
            builder: (context, snapshot) {
              final status = snapshot.data ?? ConnectionStatus.disconnected;
              return Container(
                padding: const EdgeInsets.all(8),
                color: status == ConnectionStatus.connected ? Colors.green : Colors.red,
                child: Text(
                  'Status: $status',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),

          // Connected users
          StreamBuilder<List<String>>(
            stream: _chatExample.usersStream,
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              return Container(
                padding: const EdgeInsets.all(8),
                child: Text('Connected Users: ${users.join(', ')}'),
              );
            },
          ),

          // Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatExample.messagesStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return ListTile(
                      title: Text(message.sender),
                      subtitle: Text(message.content),
                      trailing: Text(message.timestamp.toString()),
                    );
                  },
                );
              },
            ),
          ),

          // Error display
          StreamBuilder<String>(
            stream: _chatExample.errorsStream,
            builder: (context, snapshot) {
              final error = snapshot.data;
              if (error == null || error.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red,
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),

          // Input controls
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _roomController,
                        decoration: const InputDecoration(
                          labelText: 'Room',
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_userController.text.isNotEmpty && _roomController.text.isNotEmpty) {
                          await _chatExample.joinRoom(_userController.text, _roomController.text);
                        }
                      },
                      child: const Text('Join Room'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_messageController.text.isNotEmpty) {
                          await _chatExample.sendMessage(_messageController.text);
                          _messageController.clear();
                        }
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatExample.disconnect();
    _messageController.dispose();
    _userController.dispose();
    _roomController.dispose();
    super.dispose();
  }
} 