import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'signalr_chat_plugin_method_channel.dart';
import 'connection_options.dart';
import 'message.dart';

abstract class SignalrChatPluginPlatform extends PlatformInterface {
  /// Constructs a SignalrChatPluginPlatform.
  SignalrChatPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static SignalrChatPluginPlatform _instance = MethodChannelSignalrChatPlugin();

  /// The default instance of [SignalrChatPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelSignalrChatPlugin].
  static SignalrChatPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SignalrChatPluginPlatform] when
  /// they register themselves.
  static set instance(SignalrChatPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  // Add iOS-specific methods
  Future<void> initializeSignalR(SignalRConnectionOptions options) {
    throw UnimplementedError('initializeSignalR() has not been implemented.');
  }

  Future<void> sendMessage(String sender, String content, String? messageId) {
    throw UnimplementedError('sendMessage() has not been implemented.');
  }

  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Stream<ChatMessage> get messagesStream {
    throw UnimplementedError('messagesStream has not been implemented.');
  }

  Stream<ConnectionStatus> get connectionStatusStream {
    throw UnimplementedError('connectionStatusStream has not been implemented.');
  }

  Stream<String> get errorStream {
    throw UnimplementedError('errorStream has not been implemented.');
  }
}