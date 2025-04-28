import Flutter
import UIKit
import SignalR_ObjC

public class SignalrChatPlugin: NSObject, FlutterPlugin {
    private var hubConnection: SRHubConnection?
    private var hubProxy: SRHubProxy?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SignalrChatPlugin()

        // Method channel for method calls
        let methodChannel = FlutterMethodChannel(name: "signalr_chat_plugin", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        instance.methodChannel = methodChannel

        // Event channel for streaming events
        let eventChannel = FlutterEventChannel(name: "signalr_chat_plugin/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        instance.eventChannel = eventChannel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String {
                initializeConnection(url: url, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Invalid arguments for initialize",
                                  details: nil))
            }

        case "sendMessage":
            if let args = call.arguments as? [String: Any],
               let message = args["message"] as? String {
                sendMessage(message: message, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Invalid arguments for sendMessage",
                                  details: nil))
            }

        case "disconnect":
            disconnect(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeConnection(url: String, result: @escaping FlutterResult) {
        // Create the connection
        hubConnection = SRHubConnection(URLString: url)

        // Create the hub proxy
        hubProxy = hubConnection?.createHubProxy("chatHub")

        // Setup event handlers
        hubProxy?.on("ReceiveMessage", perform: { [weak self] args in
            if let message = args?[0] as? String {
                self?.eventSink?(["type": "message", "data": message])
            }
        })

        hubProxy?.on("UserJoined", perform: { [weak self] args in
            if let username = args?[0] as? String {
                self?.eventSink?(["type": "userJoined", "data": username])
            }
        })

        hubProxy?.on("UserLeft", perform: { [weak self] args in
            if let username = args?[0] as? String {
                self?.eventSink?(["type": "userLeft", "data": username])
            }
        })

        // Connect
        hubConnection?.start(withHeaders: nil) { [weak self] error in
            if let error = error {
                result(FlutterError(code: "CONNECTION_ERROR",
                                  message: "Failed to start connection: \(error.localizedDescription)",
                                  details: nil))
            } else {
                self?.eventSink?(["type": "connected"])
                result(nil)
            }
        }
    }

    private func sendMessage(message: String, result: @escaping FlutterResult) {
        hubProxy?.invoke("SendMessage", with: [message]) { error in
            if let error = error {
                result(FlutterError(code: "SEND_ERROR",
                                  message: "Failed to send message: \(error.localizedDescription)",
                                  details: nil))
            } else {
                result(nil)
            }
        }
    }

    private func disconnect(result: @escaping FlutterResult) {
        hubConnection?.stop()
        eventSink?(["type": "disconnected"])
        result(nil)
    }
}

extension SignalrChatPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}