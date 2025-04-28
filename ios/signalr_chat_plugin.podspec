#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
<<<<<<< Updated upstream
# Run `pod lib lint signalr_chat_plugin.podspec` to validate before publishing.
=======
>>>>>>> Stashed changes
#
Pod::Spec.new do |s|
  s.name             = 'signalr_chat_plugin'
  s.version          = '0.0.1'
<<<<<<< Updated upstream
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
=======
  s.summary          = 'Flutter plugin for SignalR chat functionality'
  s.description      = <<-DESC
A Flutter plugin implementing SignalR chat functionality with iOS native integration.
>>>>>>> Stashed changes
                       DESC
  s.homepage         = 'https://github.com/go2hyder/signalr_chat_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hyder' => 'go2hyder@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
<<<<<<< Updated upstream
  s.platform = :ios, '12.0'
=======
  s.dependency 'SwiftSignalRClient', '~> 0.9.0'
  s.platform = :ios, '11.0'
>>>>>>> Stashed changes

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'signalr_chat_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
