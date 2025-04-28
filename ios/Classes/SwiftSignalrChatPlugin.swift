import Flutter
import UIKit
import SignalRClient

public class SwiftSignalrChatPlugin: NSObject, FlutterPlugin {
  private var connection: HubConnection?
  private var messageStreamHandler = StreamHandler()
  private var connectionStatusStreamHandler = StreamHandler()
  private var errorStreamHandler = StreamHandler()

  private var messageQueue: [[String: Any]] = []
  private var options: [String: Any]?
  private var retryCount = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "signalr_chat_plugin", binaryMessenger: registrar.messenger())
    let instance = SwiftSignalrChatPlugin()

    // Set up event channels
    let messageEventChannel = FlutterEventChannel(name: "signalr_chat_plugin/messages", binaryMessenger: registrar.messenger())
    messageEventChannel.setStreamHandler(instance.messageStreamHandler)

    let connectionStatusEventChannel = FlutterEventChannel(name: "signalr_chat_plugin/connection_status", binaryMessenger: registrar.messenger())
    connectionStatusEventChannel.setStreamHandler(instance.connectionStatusStreamHandler)

    let errorEventChannel = FlutterEventChannel(name: "signalr_chat_plugin/errors", binaryMessenger: registrar.messenger())
    errorEventChannel.setStreamHandler(instance.errorStreamHandler)

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initializeSignalR":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are invalid", details: nil))
        return
      }
      initializeSignalR(options: args, result: result)
    case "sendMessage":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are invalid", details: nil))
        return
      }
      sendMessage(args: args, result: result)
    case "disconnect":
      disconnect(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeSignalR(options: [String: Any], result: @escaping FlutterResult) {
    self.options = options

    guard let serverUrl = options["serverUrl"] as? String else {
      result(FlutterError(code: "INVALID_URL", message: "Server URL is required", details: nil))
      return
    }

    connectionStatusStreamHandler.send("connecting")

    do {
      // Create connection
      connection = HubConnectionBuilder(url: URL(string: serverUrl)!)
        .withLogging(minLogLevel: .debug)
        .build()

      // Set up message handler
      connection?.on(method: "ReceiveMessage") { arguments in
        if arguments.count >= 2 {
          if let sender = arguments[0] as? String,
             let content = arguments[1] as? String {
            var messageId: String? = nil
            if arguments.count > 2 {
              messageId = arguments[2] as? String
            }

            let message: [String: Any] = [
              "sender": sender,
              "content": content,
              "messageId": messageId ?? "",
              "status": "delivered"
            ]

            self.messageStreamHandler.send(message)
          }
        }
      }

      // Set up connection handlers
      connection?.onreconnecting { error in
        self.connectionStatusStreamHandler.send("reconnecting")
      }

      connection?.onreconnected { connectionId in
        self.connectionStatusStreamHandler.send("connected")
        self.processMessageQueue()
      }

      connection?.onclosed { error in
        self.connectionStatusStreamHandler.send("disconnected")
        if let opts = self.options, let autoReconnect = opts["autoReconnect"] as? Bool, autoReconnect {
          self.reconnect()
        }
      }

      // Start the connection
      connection?.start { error in
        if let error = error {
          self.connectionStatusStreamHandler.send("disconnected")
          self.errorStreamHandler.send("Failed to connect: \(error.localizedDescription)")
          result(FlutterError(code: "CONNECTION_ERROR", message: error.localizedDescription, details: nil))
        } else {
          self.connectionStatusStreamHandler.send("connected")
          self.retryCount = 0
          result(nil)
        }
      }
    } catch {
      connectionStatusStreamHandler.send("disconnected")
      errorStreamHandler.send("Initialization error: \(error.localizedDescription)")
      result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func sendMessage(args: [String: Any], result: @escaping FlutterResult) {
    guard let sender = args["sender"] as? String,
          let content = args["content"] as? String,
          let messageId = args["messageId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Sender, content, and messageId are required", details: nil))
      return
    }

    let message: [String: Any] = [
      "sender": sender,
      "content": content,
      "messageId": messageId,
      "status": "sent"
    ]

    if connection?.state != .connected {
      messageQueue.append(message)
      errorStreamHandler.send("Message queued for later delivery")
      result(nil)
      return
    }

    // Try to send the message
    connection?.invoke(method: "SendMessage", arguments: [sender, content, messageId]) { error in
      if let error = error {
        // Try an alternative format
        self.connection?.invoke(method: "SendMessage", arguments: [sender, content]) { secondError in
          if let secondError = secondError {
            // Both attempts failed
            self.messageQueue.append(message)
            self.errorStreamHandler.send("Failed to send message: \(secondError.localizedDescription)")

            var failedMessage = message
            failedMessage["status"] = "failed"
            self.messageStreamHandler.send(failedMessage)

            result(FlutterError(code: "SEND_ERROR", message: secondError.localizedDescription, details: nil))
          } else {
            // Second attempt succeeded
            result(nil)
          }
        }
      } else {
        // First attempt succeeded
        result(nil)
      }
    }
  }

  private func disconnect(result: @escaping FlutterResult) {
    connection?.stop { error in
      if let error = error {
        self.errorStreamHandler.send("Disconnect error: \(error.localizedDescription)")
        result(FlutterError(code: "DISCONNECT_ERROR", message: error.localizedDescription, details: nil))
      } else {
        self.connectionStatusStreamHandler.send("disconnected")
        result(nil)
      }
    }
  }

  private func reconnect() {
    guard let opts = options,
          let maxRetryAttempts = opts["maxRetryAttempts"] as? Int,
          let reconnectIntervalMs = opts["reconnectIntervalMs"] as? Int else {
      return
    }

    if retryCount >= maxRetryAttempts {
      connectionStatusStreamHandler.send("disconnected")
      errorStreamHandler.send("Max reconnection attempts reached")
      return
    }

    retryCount += 1
    connectionStatusStreamHandler.send("reconnecting")

    connection?.start { error in
      if let error = error {
        self.errorStreamHandler.send("Reconnection attempt \(self.retryCount) failed: \(error.localizedDescription)")

        // Schedule next attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(reconnectIntervalMs)) {
          self.reconnect()
        }
      } else {
        self.connectionStatusStreamHandler.send("connected")
        self.retryCount = 0
        self.processMessageQueue()
      }
    }
  }

  private func processMessageQueue() {
    guard !messageQueue.isEmpty else { return }

    // Process queued messages
    var processedMessages = [[String: Any]]()

    for message in messageQueue {
      if connection?.state == .connected,
         let sender = message["sender"] as? String,
         let content = message["content"] as? String,
         let messageId = message["messageId"] as? String {

        connection?.invoke(method: "SendMessage", arguments: [sender, content, messageId]) { error in
          if error == nil {
            // Message sent successfully
            processedMessages.append(message)
          } else {
            // Try alternative format
            self.connection?.invoke(method: "SendMessage", arguments: [sender, content]) { secondError in
              if secondError == nil {
                processedMessages.append(message)
              }
            }
          }
        }
      }
    }

    // Remove processed messages from the queue
    messageQueue.removeAll { message in
      processedMessages.contains { $0["messageId"] as? String == message["messageId"] as? String }
    }
  }
}

// Stream handler for event channels
class StreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func send(_ event: Any) {
    if let eventSink = eventSink {
      DispatchQueue.main.async {
        eventSink(event)
      }
    }
  }
}