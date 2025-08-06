# SignalR Chat Plugin for Flutter

A Flutter plugin that provides real-time chat functionality using SignalR with **RxDart** for reactive programming. This plugin offers a robust, feature-rich implementation for real-time messaging in Flutter applications with automatic reconnection handling, message queuing, connection state management, and advanced reactive stream operations.

## ✨ Features

- 🔄 Real-time bi-directional communication
- 📱 Cross-platform support (iOS, Android, Web)
- 🔐 Secure WebSocket connections with optional authentication
- 🔁 Automatic reconnection handling
- 📤 Message queuing for offline/disconnected scenarios
- 📊 Connection state management and monitoring
- 🚦 Comprehensive error handling and reporting
- 📨 Message delivery status tracking
<<<<<<< Updated upstream
- 📤 Chat Room
=======
- ⚡ **RxDart integration for reactive programming**
- 🎯 **Advanced stream operations (debouncing, throttling, buffering)**
- 🔗 **Combined streams for complex state management**
- 📈 **Latest value access without subscriptions**
- 🛡️ **Reactive error handling with retry logic**
>>>>>>> Stashed changes

## 📦 Installation

### Dependencies

Add this to your package's `pubspec.yaml` file: [https://pub.dev/packages/signalr_chat_plugin](https://pub.dev/packages/signalr_chat_plugin)

```yaml
dependencies:
  signalr_chat_plugin: ^1.0.1
  rxdart: ^0.27.7
```

### Basic Usage

1. Initialize the plugin with your SignalR hub URL:

```dart
final chatPlugin = SignalRChatPlugin();

await chatPlugin.initSignalR(
  SignalRConnectionOptions(
    serverUrl: 'https://your-server.com/chathub',
    accessToken: 'optional-auth-token',
  ),
);
```

2. Listen for incoming messages:

```dart
chatPlugin.messagesStream.listen((message) {
  print('Received message from ${message.sender}: ${message.content}');
});
```

3. Send messages:

```dart
await chatPlugin.sendMessage('Hello, world!');
```

## 🚀 RxDart Enhanced Features

### Reactive State Management

The plugin now uses RxDart subjects for better state management:

```dart
// Get latest values without subscribing
ChatMessage? lastMessage = chatPlugin.lastMessage;
ConnectionStatus currentStatus = chatPlugin.currentConnectionStatus;
bool isConnected = chatPlugin.isConnected;
List<String> currentUsers = chatPlugin.currentConnectedUsers;
```

### Advanced Stream Operations

#### Message Filtering
```dart
// Get messages from a specific user
chatPlugin.getMessagesBySender('John')
    .listen((message) => print('Message from John: ${message.content}'));

// Get recent messages with time window
chatPlugin.getRecentMessages(count: 10)
    .listen((message) => print('Recent message: ${message.content}'));

// Get message history with buffering
chatPlugin.getMessageHistory(windowSize: 50)
    .listen((messages) => print('Message history: ${messages.length} messages'));
```

#### Connection State Monitoring
```dart
// Get connection state changes only
chatPlugin.connectionStateChanges
    .listen((status) => print('Connection changed to: $status'));

// Monitor connection health
Rx.combineLatest2(
  chatPlugin.connectionStateStream,
  chatPlugin.isConnectedStream,
  (status, connected) => status == ConnectionStatus.connected && connected,
).listen((isHealthy) => print('Connection healthy: $isHealthy'));
```

#### Combined Streams
```dart
// Get comprehensive connection info
chatPlugin.connectionInfoStream.listen((info) {
  print('Status: ${info['status']}');
  print('Connected: ${info['connected']}');
  print('Users: ${info['users']}');
  print('Timestamp: ${info['timestamp']}');
});
```

### Reactive Error Handling

```dart
// Error stream with retry logic
chatPlugin.errorStreamWithRetry.listen((error) {
  print('Error with retry: $error');
});

// Basic error stream
chatPlugin.errorStream.listen((error) {
  print('Error: $error');
});
```

## 🎯 Flutter Widget Integration

### Reactive Chat Widget

```dart
class ReactiveChatWidget extends StatelessWidget {
  final SignalRChatPlugin chatPlugin;

  const ReactiveChatWidget({super.key, required this.chatPlugin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection status
        StreamBuilder<ConnectionStatus>(
          stream: chatPlugin.connectionStateStream,
          builder: (context, snapshot) {
            final status = snapshot.data ?? ConnectionStatus.disconnected;
            return Container(
              color: status == ConnectionStatus.connected ? Colors.green : Colors.red,
              child: Text('Status: $status'),
            );
          },
        ),

        // Messages list
        Expanded(
          child: StreamBuilder<ChatMessage>(
            stream: chatPlugin.messagesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              
              final message = snapshot.data!;
              return ListTile(
                title: Text(message.sender),
                subtitle: Text(message.content),
              );
            },
          ),
        ),

        // Connected users
        StreamBuilder<List<String>>(
          stream: chatPlugin.connectedUsersStream,
          builder: (context, snapshot) {
            final users = snapshot.data ?? [];
            return Text('Connected Users: ${users.join(', ')}');
          },
        ),
      ],
    );
  }
}
```

### Advanced Reactive UI

```dart
class AdvancedChatWidget extends StatelessWidget {
  final SignalRChatPlugin chatPlugin;

  const AdvancedChatWidget({super.key, required this.chatPlugin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: chatPlugin.connectionInfoStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        
        final info = snapshot.data!;
        final isConnected = info['connected'] as bool;
        final users = info['users'] as List<String>;
        
        return Column(
          children: [
            // Connection indicator
            Container(
              color: isConnected ? Colors.green : Colors.red,
              child: Text('${users.length} users connected'),
            ),
            
            // Messages with filtering
            Expanded(
              child: StreamBuilder<ChatMessage>(
                stream: chatPlugin.getMessagesBySender('Admin'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final message = snapshot.data!;
                  return Card(
                    child: ListTile(
                      title: Text('Admin: ${message.content}'),
                      subtitle: Text(message.timestamp.toString()),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
```

## 🔧 Connection State Management

Monitor the connection state reactively:

```dart
chatPlugin.connectionStateStream.listen((status) {
  switch (status) {
    case ConnectionStatus.connected:
      print('Connected to the chat server');
      break;
    case ConnectionStatus.disconnected:
      print('Disconnected from the chat server');
      break;
    case ConnectionStatus.reconnecting:
      print('Attempting to reconnect...');
      break;
    case ConnectionStatus.connecting:
      print('Establishing initial connection...');
      break;
  }
});
```

## 🛠️ Advanced Configuration

Configure the connection with advanced options:

```dart
final options = SignalRConnectionOptions(
  serverUrl: 'https://your-server.com/chathub',
  accessToken: 'your-auth-token',
  reconnectInterval: Duration(seconds: 5),
  maxRetryAttempts: 5,
  autoReconnect: true,
  useSecureConnection: true,
  transport: HttpTransportType.webSockets,
  skipNegotiation: true,
  onError: (error) => print('Connection error: $error'),
);

await chatPlugin.initSignalR(options);
```

## 📊 Message Structure

The plugin uses a `ChatMessage` class to handle messages:

```dart
final message = ChatMessage(
  sender: 'user123',
  content: 'Hello!',
  messageId: 'unique-id',  // Optional
  status: MessageStatus.delivered,  // sending, delivered, or failed
  timestamp: DateTime.now(),
);
```

## 🎯 RxDart Benefits

### 1. **Reactive Programming**
- Declarative stream transformations
- Automatic state management
- Reduced boilerplate code

### 2. **Better Performance**
- Efficient stream operations
- Automatic memory management
- Optimized subscription handling

### 3. **Advanced Features**
- Debouncing and throttling
- Stream combining and filtering
- Error recovery mechanisms

### 4. **Type Safety**
- Strongly typed streams
- Compile-time error checking
- Better IDE support

## 🔄 Features Detail

### Automatic Reconnection
- Configurable retry attempts and intervals
- Automatic message queue processing upon reconnection
- Connection state monitoring with reactive updates

### Message Queuing
- Automatic queuing of messages during disconnection
- Guaranteed message delivery attempt when connection is restored
- Message status tracking (sending, delivered, failed)

### Security
- Secure WebSocket connections
- Optional authentication token support
- HTTPS/WSS protocol support

### Reactive Error Handling
- Centralized error management
- Automatic retry logic with debouncing
- Error recovery mechanisms

## 📚 API Reference

### Main Classes

#### SignalRChatPlugin
- `initSignalR(SignalRConnectionOptions options)`: Initialize the chat connection
- `sendMessage(String content)`: Send a chat message
- `disconnect()`: Disconnect from the server
- `reconnect()`: Manually trigger reconnection
- `clearMessageQueue()`: Clear pending messages
- `dispose()`: Clean up resources

#### Reactive Streams
- `messagesStream`: Receive incoming messages
- `connectionStateStream`: Monitor connection state
- `errorStream`: Listen for errors
- `connectedUsersStream`: Monitor connected users
- `isConnectedStream`: Connection status boolean
- `errorStreamWithRetry`: Error stream with retry logic

#### Latest Values
- `lastMessage`: Get the most recent message
- `currentConnectionStatus`: Get current connection status
- `isConnected`: Check if connected
- `currentConnectedUsers`: Get current user list

#### Advanced Stream Operations
- `getMessagesBySender(String sender)`: Filter messages by sender
- `getRecentMessages({int count})`: Get recent messages
- `getMessageHistory({int windowSize})`: Get message history
- `connectionStateChanges`: Connection state changes only
- `connectionInfoStream`: Combined connection information

#### SignalRConnectionOptions
- `serverUrl`: SignalR hub URL
- `accessToken`: Optional authentication token
- `reconnectInterval`: Time between reconnection attempts
- `maxRetryAttempts`: Maximum reconnection attempts
- `autoReconnect`: Enable/disable automatic reconnection
- `useSecureConnection`: Enable/disable WSS/HTTPS
- `transport`: Transport type (WebSockets, Server-Sent Events, etc.)
- `skipNegotiation`: Skip negotiation step

## 🚀 Example Usage

Check out the complete example in the `example/` directory, which demonstrates:

- Reactive UI updates
- Connection state management
- Message handling
- Error handling
- Advanced stream operations

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Related

- [SignalR Core](https://github.com/dotnet/aspnetcore/tree/main/src/SignalR)
- [RxDart](https://github.com/ReactiveX/rxdart)
- [Flutter](https://flutter.dev/)
