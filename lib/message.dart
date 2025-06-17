// message.dart
class ChatMessage {
  final String sender;
  final String content;
  final DateTime timestamp;
  final String? messageId;
  final MessageStatus status;

  ChatMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.messageId,
    this.status = MessageStatus.sending,
  });

  Map<String, dynamic> toJson() => {
    'sender': sender,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'messageId': messageId,
    'status': status.toString(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageId: json['messageId'] as String?,
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => MessageStatus.sending,
      ),
    );
  }
}

enum MessageStatus { sending, delivered, failed }

enum ConnectionStatus { connecting, connected, disconnected, reconnecting }
