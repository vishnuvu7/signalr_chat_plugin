# SignalR Chat Plugin for Flutter

A Flutter plugin that provides SignalR chat functionality for both Android and iOS platforms.

## Features

- Connect to SignalR hub
- Send and receive messages
- Handle user join/leave events
- Automatic reconnection
- Cross-platform support (Android & iOS)

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  signalr_chat_plugin:
    git:
      url: https://github.com/yourusername/signalr_chat_plugin.git
      ref: main
```

## Usage

### Initialize the plugin

```dart
import 'package:signalr_chat_plugin/signalr_chat_plugin.dart';

final SignalrChatPlugin _signalrChatPlugin = SignalrChatPlugin();

// Initialize the connection
await _signalrChatPlugin.initialize('https://your-signalr-hub-url.com/chat');
```

### Send a message

```dart
await _signalrChatPlugin.sendMessage('Hello, world!');
```

### Listen to events

```dart
_signalrChatPlugin.onEvent.listen((event) {
  switch (event['type']) {
    case 'message':
      print('Received message: ${event['message']}');
      break;
    case 'userJoined':
      print('User joined: ${event['username']}');
      break;
    case 'userLeft':
      print('User left: ${event['username']}');
      break;
    case 'connectionStatus':
      print('Connection status: ${event['status']}');
      break;
  }
});
```

### Disconnect

```dart
await _signalrChatPlugin.disconnect();
```

## Platform Setup

### Android

No additional setup required. The plugin automatically adds the necessary SignalR dependencies.

### iOS

1. Add the following to your `ios/Podfile`:

```ruby
platform :ios, '9.0'
```

2. Run `pod install` in the `ios` directory.

## Error Handling

The plugin provides error handling through the event stream. Common errors include:

- Connection failures
- Message sending failures
- Disconnection errors

Check the event stream for error messages and handle them appropriately in your application.

## License

This project is licensed under the MIT License - see the LICENSE file for details.