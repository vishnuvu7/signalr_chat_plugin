import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:signalr_chat_plugin/signalr_chat_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SignalR plugin
  SignalRChatPlugin chatPlugin = SignalRChatPlugin();
  //await chatPlugin.initSignalR(serverUrl: "http://192.168.90.250:8080/chathub");

  runApp(MyApp(chatPlugin: chatPlugin));
}

class MyApp extends StatelessWidget {
  final SignalRChatPlugin chatPlugin;
  MyApp({required this.chatPlugin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatScreen(chatPlugin: chatPlugin),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final SignalRChatPlugin chatPlugin;
  ChatScreen({required this.chatPlugin});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  String _connectionStatus = "Connecting..."; // 🔹 Default status

  @override
  void initState() {
    super.initState();

    // 🔹 Listen for connection status changes
    widget.chatPlugin
        .initSignalR(serverUrl: "http://your-chathub-url/chathub")
        .then((_) {
      widget.chatPlugin.connectionStatusStream.listen((status) {
        print("🔄 main.dart Connection Status: $status");
        setState(() {
          _connectionStatus = status; // Update UI
        });
      });
    });

    // Listen to incoming messages from SignalR
    widget.chatPlugin.messagesStream.listen((data) {
      print("📩 Message received: $data");

      try {
        Map<String, dynamic> decodedData =
            jsonDecode(data); // 🔹 Decode JSON string

        setState(() {
          _messages.insert(0, {
            "sender": decodedData["sender"] ?? "Unknown",
            "message": decodedData["message"] ?? "No message"
          }); // ✅ Add message properly
        });

        print("✅ Updated messages list: $_messages");
      } catch (e) {
        print("❌ Error decoding message: $e");
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    String message = _messageController.text.trim();
    String userName = "User1"; // Replace with the actual user

    widget.chatPlugin.sendMessage(userName, message);

    setState(() {
      _messages.insert(0, {"sender": "You", "message": message});
    });

    _messageController.clear(); // Clear input field after sending
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tamimah Chat ($_connectionStatus)",
              style: TextStyle(fontSize: 15),
            ),
            Text(
              "Status $_connectionStatus", // 🔹 Show live connection status
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<String>(
              stream: widget.chatPlugin.messagesStream,
              builder: (context, snapshot) {
                return ListView.builder(
                  reverse: true, // Show newest messages at the bottom
                  padding: EdgeInsets.all(10),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final messageData = _messages[index];
                    final sender = messageData["sender"] ?? "Unknown";
                    final message = messageData["message"] ?? "";

                    return Align(
                      alignment: sender == "You"
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: sender == "You"
                              ? Colors.blueAccent
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: sender == "You"
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              sender, // Show username
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sender == "You"
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              message, // Show message text
                              style: TextStyle(
                                color: sender == "You"
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 15),
              ),
            ),
          ),
          SizedBox(width: 10),
          ElevatedButton(
            onPressed: _sendMessage,
            child: Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
