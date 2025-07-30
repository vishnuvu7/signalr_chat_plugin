# SignalR Chat Plugin for Flutter

A Flutter plugin that provides real-time chat functionality using SignalR. This plugin offers a robust, feature-rich implementation for real-time messaging in Flutter applications with automatic reconnection handling, message queuing, and connection state management.

## Features

- 🔄 Real-time bi-directional communication
- 📱 Cross-platform support (iOS, Android, Web)
- 🔐 Secure WebSocket connections with optional authentication
- 🔁 Automatic reconnection handling
- 📤 Message queuing for offline/disconnected scenarios
- 📊 Connection state management and monitoring
- 🚦 Comprehensive error handling and reporting
- 📨 Message delivery status tracking
- 📤 Chat Room

## 📦 Installation

### Installation

Add this to your package's `pubspec.yaml` file: [https://pub.dev/packages/signalr_chat_plugin](https://pub.dev/packages/signalr_chat_plugin)

```yaml
dependencies:
  signalr_chat_plugin: ^1.0.0
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
await chatPlugin.sendMessage('user123', 'Hello, world!');
```

### Connection State Management

Monitor the connection state:

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

### Error Handling

Listen for errors:

```dart
chatPlugin.errorStream.listen((error) {
  print('Error occurred: $error');
});
```

### Advanced Configuration

Configure the connection with advanced options:

```dart
final options = SignalRConnectionOptions(
  serverUrl: 'https://your-server.com/chathub',
  accessToken: 'your-auth-token',
  reconnectInterval: Duration(seconds: 5),
  maxRetryAttempts: 5,
  autoReconnect: true,
  useSecureConnection: true,
  onError: (error) => print('Connection error: $error'),
);

await chatPlugin.initSignalR(options);
```

### Message Structure

The plugin uses a `ChatMessage` class to handle messages:

```dart
final message = ChatMessage(
  sender: 'user123',
  content: 'Hello!',
  messageId: 'unique-id',  // Optional
  status: MessageStatus.sent,  // sent, delivered, or failed
);
```

## Features Detail

### Automatic Reconnection
- Configurable retry attempts and intervals
- Automatic message queue processing upon reconnection
- Connection state monitoring

### Message Queuing
- Automatic queuing of messages during disconnection
- Guaranteed message delivery attempt when connection is restored
- Message status tracking (sent, delivered, failed)

### Security
- Secure WebSocket connections
- Optional authentication token support
- HTTPS/WSS protocol support

## Error Handling

The plugin provides comprehensive error handling:
- Connection failures
- Message delivery failures
- Server disconnections
- Authentication errors

## API Reference

### Main Classes

#### SignalRChatPlugin
- `initSignalR(SignalRConnectionOptions options)`: Initialize the chat connection
- `sendMessage(String sender, String content)`: Send a chat message
- `disconnect()`: Disconnect from the server
- `reconnect()`: Manually trigger reconnection
- `clearMessageQueue()`: Clear pending messages
- `dispose()`: Clean up resources

#### SignalRConnectionOptions
- `serverUrl`: SignalR hub URL
- `accessToken`: Optional authentication token
- `reconnectInterval`: Time between reconnection attempts
- `maxRetryAttempts`: Maximum reconnection attempts
- `autoReconnect`: Enable/disable automatic reconnection
- `useSecureConnection`: Enable/disable WSS/HTTPS

#### Streams
- `messagesStream`: Receive incoming messages
- `connectionStateStream`: Monitor connection state
- `errorStream`: Listen for errors

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
