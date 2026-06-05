#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint in_app_update_plus.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'in_app_update_plus'
  s.version          = '1.0.0'
  s.summary          = 'Checks for app updates on Android and iOS.'
  s.description      = <<-DESC
Checks for app updates on Android and iOS using Play Core and App Store lookup.
                       DESC
  s.homepage         = 'https://pub.dev/packages/in_app_update_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'in_app_update_plus contributors' => 'https://pub.dev/packages/in_app_update_plus' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
