// message.dart
class ChatMessage {
  final String sender;
  final String content;
  final DateTime timestamp;
  final String? messageId;
  final String? roomId;
  final MessageStatus status;

  ChatMessage({
    required this.sender,
    required this.content,
    DateTime? timestamp,
    this.messageId,
    this.roomId,
    this.status = MessageStatus.sent,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageId: json['messageId'] as String?,
      roomId: json['roomId'] as String?,
      status: MessageStatus.values.firstWhere(
            (e) => e.toString() == json['status'],
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'messageId': messageId,
      'roomId': roomId,
      'status': status.toString(),
    };
  }
}

enum MessageStatus { sent, delivered, failed }
enum ConnectionStatus { connecting, connected, disconnected, reconnecting }
