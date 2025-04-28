import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'signalr_chat_plugin_platform_interface.dart';
import 'connection_options.dart';
import 'message.dart';

/// An implementation of [SignalrChatPluginPlatform] that uses method channels.
class MethodChannelSignalrChatPlugin extends SignalrChatPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('signalr_chat_plugin');

  final EventChannel _messageEventChannel = const EventChannel('signalr_chat_plugin/messages');
  final EventChannel _connectionStatusEventChannel = const EventChannel('signalr_chat_plugin/connection_status');
  final EventChannel _errorEventChannel = const EventChannel('signalr_chat_plugin/errors');

  // Cached streams
  Stream<ChatMessage>? _messagesStream;
  Stream<ConnectionStatus>? _connectionStatusStream;
  Stream<String>? _errorStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initializeSignalR(SignalRConnectionOptions options) async {
    try {
      await methodChannel.invokeMethod<void>('initializeSignalR', {
        'serverUrl': options.serverUrl,
        'accessToken': options.accessToken,
        'autoReconnect': options.autoReconnect,
        'maxRetryAttempts': options.maxRetryAttempts,
        'reconnectIntervalMs': options.reconnectInterval.inMilliseconds,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to initialize SignalR: ${e.message}');
    }
  }

  @override
  Future<void> sendMessage(String sender, String content, String? messageId) async {
    try {
      await methodChannel.invokeMethod<void>('sendMessage', {
        'sender': sender,
        'content': content,
        'messageId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to send message: ${e.message}');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await methodChannel.invokeMethod<void>('disconnect');
    } on PlatformException catch (e) {
      throw Exception('Failed to disconnect: ${e.message}');
    }
  }

  @override
  Stream<ChatMessage> get messagesStream {
    _messagesStream ??= _messageEventChannel
        .receiveBroadcastStream()
        .map<ChatMessage>((dynamic event) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(event);
      return ChatMessage(
        sender: data['sender'] as String,
        content: data['content'] as String,
        messageId: data['messageId'] as String?,
        status: _parseMessageStatus(data['status'] as String?),
      );
    });
    return _messagesStream!;
  }

  @override
  Stream<ConnectionStatus> get connectionStatusStream {
    _connectionStatusStream ??= _connectionStatusEventChannel
        .receiveBroadcastStream()
        .map<ConnectionStatus>((dynamic event) {
      return _parseConnectionStatus(event as String);
    });
    return _connectionStatusStream!;
  }

  @override
  Stream<String> get errorStream {
    _errorStream ??= _errorEventChannel
        .receiveBroadcastStream()
        .map<String>((dynamic event) => event as String);
    return _errorStream!;
  }

  // Helper methods to parse enums
  MessageStatus _parseMessageStatus(String? status) {
    switch (status) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  ConnectionStatus _parseConnectionStatus(String status) {
    switch (status) {
      case 'connected':
        return ConnectionStatus.connected;
      case 'connecting':
        return ConnectionStatus.connecting;
      case 'reconnecting':
        return ConnectionStatus.reconnecting;
      case 'disconnected':
        return ConnectionStatus.disconnected;
      default:
        return ConnectionStatus.disconnected;
    }
  }
}