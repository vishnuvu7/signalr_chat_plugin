import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signalr_chat_plugin/signalr_plugin.dart';
import 'package:signalr_chat_plugin/user_room_connection.dart';
import 'dart:developer' as developer;
import 'package:signalr_core/signalr_core.dart';
import 'package:rxdart/rxdart.dart';

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatApp());
}

// ============================================================================
// APP CONFIGURATION
// ============================================================================
class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

// ============================================================================
// START SCREEN
// ============================================================================
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const ChatScreen(room: "UUUUU", userName: "Vishnu"),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            'Join Room',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT SCREEN
// ============================================================================
class ChatScreen extends StatefulWidget {
  final String room;
  final String userName;
  const ChatScreen({super.key, required this.room, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ============================================================================
  // CONTROLLERS
  // ============================================================================
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SignalRChatPlugin _chatPlugin = SignalRChatPlugin();
  
  // ============================================================================
  // RXDART SUBJECTS
  // ============================================================================
  final BehaviorSubject<List<ChatMessage>> _messagesSubject = BehaviorSubject<List<ChatMessage>>();
  final BehaviorSubject<ConnectionStatus> _connectionStateSubject = BehaviorSubject<ConnectionStatus>();
  final BehaviorSubject<bool> _isInitializedSubject = BehaviorSubject<bool>.seeded(false);
  final PublishSubject<String> _errorsSubject = PublishSubject<String>();
  
  // ============================================================================
  // STREAM SUBSCRIPTIONS
  // ============================================================================
  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _isConnectedSubscription;
  
  // ============================================================================
  // STATE VARIABLES
  // ============================================================================
  Stream<Map<String, dynamic>>? _uiStateStream;
  final Set<String> _processedMessageIds = {};
  late String _username;
  late String _room;

  // ============================================================================
  // PUBLIC STREAMS
  // ============================================================================
  Stream<List<ChatMessage>> get messagesStream => _messagesSubject.stream;
  Stream<ConnectionStatus> get connectionStateStream => _connectionStateSubject.stream;
  Stream<bool> get isInitializedStream => _isInitializedSubject.stream;
  Stream<String> get errorsStream => _errorsSubject.stream;

  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================
  @override
  void initState() {
    super.initState();
    _username = widget.userName;
    _room = widget.room;
    _setupReactiveStreams();
    _initializeChat();
  }

  @override
  void dispose() {
    developer.log('Disposing chat screen');
    _messageController.dispose();
    _scrollController.dispose();
    
    // Cancel all subscriptions
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _errorSubscription?.cancel();
    _isConnectedSubscription?.cancel();
    
    // Close all subjects
    _messagesSubject.close();
    _connectionStateSubject.close();
    _isInitializedSubject.close();
    _errorsSubject.close();
    
    _chatPlugin.disconnect();
    _processedMessageIds.clear();
    super.dispose();
  }

  // ============================================================================
  // STREAM SETUP
  // ============================================================================
  void _setupReactiveStreams() {
    // Subscribe to messages with reactive processing
    _messageSubscription = _chatPlugin.messagesStream
        .bufferTime(const Duration(milliseconds: 100))
        .where((messages) => messages.isNotEmpty)
        .listen((messages) {
          _handleNewMessages(messages);
        });

    // Subscribe to connection state changes
    _connectionSubscription = _chatPlugin.connectionStateStream
        .distinct()
        .listen((state) {
          _connectionStateSubject.add(state);
          _handleConnectionState(state);
        });

    // Subscribe to connection status
    _isConnectedSubscription = _chatPlugin.isConnectedStream
        .listen((connected) {
          if (connected && !_isInitializedSubject.value) {
            _isInitializedSubject.add(true);
          }
        });

    // Subscribe to errors with reactive handling
    _errorSubscription = _chatPlugin.errorStreamWithRetry
        .listen((error) {
          _errorsSubject.add(error);
          _handleError(error);
        });

    // Create combined UI state stream
    _uiStateStream = Rx.combineLatest4(
      messagesStream,
      connectionStateStream,
      isInitializedStream,
      errorsStream.startWith(''),
      (messages, status, initialized, error) => {
        'messages': messages,
        'status': status,
        'initialized': initialized,
        'error': error,
        'timestamp': DateTime.now(),
      },
    );
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  Future<void> _initializeChat() async {
    try {
      developer.log('Initializing SignalR connection...');

      // Initialize SignalR with configuration
      await _chatPlugin.initSignalR(
        SignalRConnectionOptions(
          serverUrl: 'https://your-signalR-endpoint',
          reconnectInterval: const Duration(seconds: 3),
          maxRetryAttempts: 5,
          autoReconnect: true,
          onError: (error) {
            developer.log('SignalR error: $error');
            _errorsSubject.add(error);
          },
          transport: HttpTransportType.webSockets,
          skipNegotiation: true,
        ),
      );

      developer.log('SignalR initialized successfully');

      // Add a small delay to ensure connection is fully established
      await Future.delayed(const Duration(milliseconds: 500));

      // Now join the room
      developer.log('Attempting to join room: $_room with username: $_username');

      await _chatPlugin.joinRoom(UserRoomConnection(
        user: _username,
        room: _room,
      ));

      developer.log('Successfully joined room');

      // Mark as initialized
      _isInitializedSubject.add(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to chat'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      developer.log('Error initializing chat: $e');
      developer.log('Stack trace: $stackTrace');

      _connectionStateSubject.add(ConnectionStatus.disconnected);
      _errorsSubject.add('Failed to initialize chat: $e');

      // Retry connection after a delay
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_isInitializedSubject.value) {
            _initializeChat();
          }
        });
      }
    }
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  void _handleNewMessages(List<ChatMessage> messages) {
    for (final message in messages) {
      developer.log('Received message from ${message.sender}: ${message.content}');

      // Skip if we've already processed this message by ID
      if (message.messageId != null && _processedMessageIds.contains(message.messageId)) {
        developer.log('Skipping duplicate message by ID: ${message.messageId}');
        continue;
      }

      // Add message ID to processed set if it has one
      if (message.messageId != null) {
        _processedMessageIds.add(message.messageId!);
      }

      final currentMessages = _messagesSubject.valueOrNull ?? [];
      
      // If this is our own message, check if we already have a similar message in the list
      if (message.sender == _username) {
        final now = DateTime.now();
        final existingMsgIndex = currentMessages.indexWhere((m) =>
            m.sender == _username &&
            m.content == message.content &&
            now.difference(m.timestamp).inSeconds < 5);

        if (existingMsgIndex != -1) {
          // Update the existing message status
          final updatedMessages = List<ChatMessage>.from(currentMessages);
          updatedMessages[existingMsgIndex] = message;
          _messagesSubject.add(updatedMessages);
          developer.log('Updated existing message instead of adding duplicate');
          continue;
        }
      }

      // Add new message
      final updatedMessages = [message, ...currentMessages];
      _messagesSubject.add(updatedMessages);
    }
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Check if initialized
    if (!_isInitializedSubject.value) {
      _handleError('Chat not initialized. Please wait...');
      return;
    }

    // Check connection state
    final currentStatus = _connectionStateSubject.valueOrNull;
    if (currentStatus != ConnectionStatus.connected) {
      _handleError('Not connected to server');
      return;
    }

    try {
      developer.log('Sending message: $message');
      _messageController.clear();

      // Create a temporary message to show in UI while sending
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final tempMessage = ChatMessage(
        sender: _username,
        content: message,
        timestamp: DateTime.now(),
        messageId: messageId,
        status: MessageStatus.sending,
      );

      // Add the temporary message to UI
      final currentMessages = _messagesSubject.valueOrNull ?? [];
      final updatedMessages = [tempMessage, ...currentMessages];
      _messagesSubject.add(updatedMessages);
      _processedMessageIds.add(messageId);
      _scrollToBottom();

      // Send the message
      await _chatPlugin.sendMessage(message);
      developer.log('Message sent successfully');
    } catch (e, stackTrace) {
      developer.log('Error sending message: $e');
      developer.log('Stack trace: $stackTrace');

      // Update the message status to failed
      final currentMessages = _messagesSubject.valueOrNull ?? [];
      final index = currentMessages.indexWhere((m) => m.content == message && m.sender == _username);
      if (index != -1) {
        final updatedMessages = List<ChatMessage>.from(currentMessages);
        updatedMessages[index] = ChatMessage(
          sender: _username,
          content: message,
          timestamp: updatedMessages[index].timestamp,
          messageId: updatedMessages[index].messageId,
          status: MessageStatus.failed,
        );
        _messagesSubject.add(updatedMessages);
      }

      _handleError('Failed to send message');
    }
  }

  // ============================================================================
  // CONNECTION HANDLING
  // ============================================================================
  void _handleConnectionState(ConnectionStatus state) {
    developer.log('Handling connection state: $state');
    if (!mounted) return;

    // Don't show snackbar for initial connecting state
    if (state == ConnectionStatus.connecting && !_isInitializedSubject.value) return;

    String message;
    Color backgroundColor;

    switch (state) {
      case ConnectionStatus.connected:
        message = 'Connected to chat';
        backgroundColor = Colors.green;
        break;
      case ConnectionStatus.connecting:
        message = 'Connecting to chat...';
        backgroundColor = Colors.orange;
        break;
      case ConnectionStatus.reconnecting:
        message = 'Reconnecting...';
        backgroundColor = Colors.orange;
        break;
      case ConnectionStatus.disconnected:
        message = 'Disconnected from chat';
        backgroundColor = Colors.red;
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // UI UTILITY METHODS
  // ============================================================================
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================================
  // UI WIDGETS
  // ============================================================================
  Widget _buildConnectionStatus() {
    return StreamBuilder<ConnectionStatus>(
      stream: connectionStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? ConnectionStatus.disconnected;
        
        Color color;
        IconData icon;
        String text;

        switch (state) {
          case ConnectionStatus.connected:
            color = Colors.green;
            icon = Icons.cloud_done;
            text = 'Connected';
            break;
          case ConnectionStatus.connecting:
            color = Colors.orange;
            icon = Icons.cloud_upload;
            text = 'Connecting';
            break;
          case ConnectionStatus.reconnecting:
            color = Colors.orange;
            icon = Icons.cloud_upload;
            text = 'Reconnecting';
            break;
          case ConnectionStatus.disconnected:
            color = Colors.red;
            icon = Icons.cloud_off;
            text = 'Disconnected';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isMyMessage = message.sender == _username;

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMyMessage ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMyMessage ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMyMessage ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isMyMessage ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
              style: TextStyle(
                color: isMyMessage ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMyMessage ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (isMyMessage) ...[
                  const SizedBox(width: 4),
                  _buildMessageStatus(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatus(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule;
        color = Colors.white70;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red[300]!;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  // ============================================================================
  // MAIN BUILD METHOD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SignalR Chat (RxDart)'),
            Text(
              'Room: $_room',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [_buildConnectionStatus()],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                final isInitialized = _isInitializedSubject.valueOrNull ?? false;
                
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      isInitialized
                          ? 'No messages yet. Start a conversation!'
                          : 'Connecting to chat...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessageItem(messages[index]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<bool>(
                    stream: Rx.combineLatest2(
                      isInitializedStream,
                      connectionStateStream,
                      (initialized, status) => initialized && status == ConnectionStatus.connected,
                    ),
                    builder: (context, snapshot) {
                      final isEnabled = snapshot.data ?? false;
                      
                      return TextField(
                        controller: _messageController,
                        enabled: isEnabled,
                        decoration: InputDecoration(
                          hintText: isEnabled ? 'Type a message...' : 'Connecting...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<bool>(
                  stream: Rx.combineLatest2(
                    isInitializedStream,
                    connectionStateStream,
                    (initialized, status) => initialized && status == ConnectionStatus.connected,
                  ),
                  builder: (context, snapshot) {
                    final isEnabled = snapshot.data ?? false;
                    
                    return FloatingActionButton(
                      onPressed: isEnabled ? _sendMessage : null,
                      backgroundColor: isEnabled
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                      child: const Icon(Icons.send),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
