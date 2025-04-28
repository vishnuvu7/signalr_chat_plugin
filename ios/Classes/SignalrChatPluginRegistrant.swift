import Flutter
import UIKit

class SignalrChatPluginRegistrant: NSObject {
    static func register(with registry: FlutterPluginRegistry) {
        if let registrar = registry.registrar(forPlugin: "SignalrChatPlugin") {
            SignalrChatPlugin.register(with: registrar)
        }
    }
} 