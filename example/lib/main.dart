import 'package:flutter/material.dart';
import 'package:signalr_chat_plugin/signalr_plugin.dart';
import 'dart:developer' as developer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatApp());
}

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
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SignalrChatPlugin _chatPlugin = SignalrChatPlugin();
  final List<ChatMessage> _messages = [];
  final Set<String> _processedMessageIds = {};
  late String _username;
  ConnectionStatus _connectionState = ConnectionStatus.connecting;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      developer.log('Initializing SignalR connection...');

      // Initialize SignalR with configuration
      await _chatPlugin.initializeSignalR(
        SignalRConnectionOptions(
          serverUrl: 'http://your-server/chathub',
          reconnectInterval: const Duration(seconds: 3),
          maxRetryAttempts: 5,
          autoReconnect: true,
          onError: (error) {
            developer.log('SignalR error: $error');
            _handleError(error);
          },
        ),
      );

      developer.log('SignalR initialized, setting up listeners...');

      // Set a random username for demo purposes
      _username = 'User${DateTime.now().millisecondsSinceEpoch % 1000}';
      developer.log('Username set to: $_username');

      // Listen to messages
      _chatPlugin.messagesStream.listen(
        _handleNewMessage,
        onError: (error) {
          developer.log('Message stream error: $error');
          _handleError(error.toString());
        },
      );

      // Listen to connection state changes
      _chatPlugin.connectionStatusStream.listen(
        (state) {
          developer.log('Connection state changed to: $state');
          _handleConnectionState(state);
        },
        onError: (error) {
          developer.log('Connection state stream error: $error');
          _handleError(error.toString());
        },
      );

      // Listen to errors
      _chatPlugin.errorStream.listen(
        (error) {
          developer.log('Error stream received: $error');
          _handleError(error);
        },
        onError: (error) {
          developer.log('Error stream error: $error');
          _handleError(error.toString());
        },
      );

      // Explicitly set the connection state to connected since we know the connection is established
      if (mounted) {
        setState(() {
          _connectionState = ConnectionStatus.connected;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to chat'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      developer.log('All listeners set up successfully');
    } catch (e, stackTrace) {
      developer.log('Error initializing chat: $e');
      developer.log('Stack trace: $stackTrace');
      _handleError('Failed to initialize chat: $e');
    }
  }

  // void _handleNewMessage(ChatMessage message) {
  //   // Skip if we've already processed this message
  //   if (message.messageId != null &&
  //       _processedMessageIds.contains(message.messageId)) {
  //     developer.log('Skipping duplicate message: ${message.messageId}');
  //     return;
  //   }

  //   // Add message ID to processed set
  //   if (message.messageId != null) {
  //     _processedMessageIds.add(message.messageId!);
  //   }

  //   setState(() {
  //     // If this is our own message, update the existing message instead of adding a new one
  //     if (message.sender == _username) {
  //       final index =
  //           _messages.indexWhere((m) => m.messageId == message.messageId);
  //       if (index != -1) {
  //         _messages[index] = message;
  //       } else {
  //         _messages.insert(0, message);
  //       }
  //     } else {
  //       _messages.insert(0, message);
  //     }
  //   });
  //   _scrollToBottom();
  // }

// Option 1: Fixed handleNewMessage to better detect and handle duplicates
  void _handleNewMessage(ChatMessage message) {
    // Skip if we've already processed this message by ID
    if (message.messageId != null &&
        _processedMessageIds.contains(message.messageId)) {
      developer.log('Skipping duplicate message by ID: ${message.messageId}');
      return;
    }

    // Add message ID to processed set if it has one
    if (message.messageId != null) {
      _processedMessageIds.add(message.messageId!);
    }

    setState(() {
      // If this is our own message, check if we already have a similar message in the list
      if (message.sender == _username) {
        // Look for an existing message with the same content from the same sender
        final existingMsgIndex = _messages.indexWhere(
            (m) => m.sender == _username && m.content == message.content);

        if (existingMsgIndex != -1) {
          // Update the existing message status if needed
          _messages[existingMsgIndex] = message;
          developer.log('Updated existing message instead of adding duplicate');
          return;
        }
      }

      // If not our message or no existing message found, add as new
      _messages.insert(0, message);
    });
    _scrollToBottom();
  }

  void _handleConnectionState(ConnectionStatus state) {
    developer.log('Handling connection state: $state');
    if (!mounted) return;

    setState(() {
      _connectionState = state;
    });

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

    developer.log('Showing connection state snackbar: $message');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      developer.log('Attempting to send message: $message');
      _messageController.clear();

      // Log the current connection state
      developer.log('Current connection state: $_connectionState');

      // Check if we're connected before sending
      if (_connectionState != ConnectionStatus.connected) {
        developer.log('Cannot send message: Not connected to server');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot send message: Not connected to server'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create a temporary message to show in UI while sending
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final tempMessage = ChatMessage(
        sender: _username,
        content: message,
        messageId: messageId,
        status: MessageStatus.sent,
      );

      // Add the temporary message to UI
      setState(() {
        _messages.insert(0, tempMessage);
        _processedMessageIds.add(messageId);
      });
      _scrollToBottom();

      // Try to send the message
      await _chatPlugin.sendMessage(_username, message);
      developer.log('Message sent successfully');
    } catch (e, stackTrace) {
      developer.log('Error sending message: $e');
      developer.log('Stack trace: $stackTrace');

      String errorMessage = 'Failed to send message';
      if (e.toString().contains('SendMessage')) {
        errorMessage =
            'Server rejected the message. Please check the message format.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildConnectionStatus() {
    Color color;
    IconData icon;
    String text;

    switch (_connectionState) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isMyMessage = message.sender == _username;

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMyMessage ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                fontSize: 12,
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
      case MessageStatus.sent:
        icon = Icons.check;
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SignalR Chat'),
        actions: [_buildConnectionStatus()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessageItem(_messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
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
    _messageController.dispose();
    _scrollController.dispose();
    _chatPlugin.disconnect();
    _processedMessageIds.clear();
    super.dispose();
  }
}
