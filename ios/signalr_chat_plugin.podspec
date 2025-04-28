Pod::Spec.new do |s|
  s.name             = 'signalr_chat_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for SignalR chat functionality.'
  s.description      = <<-DESC
A Flutter plugin that provides SignalR chat functionality for both Android and iOS platforms.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'SwiftSignalRClient', '~> 0.9.0'  # Changed from SignalR-ObjC to SwiftSignalRClient
  s.platform = :ios, '9.0'
  s.swift_version = '5.0'
end