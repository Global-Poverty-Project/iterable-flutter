#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint iterable_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'iterable_flutter'
  s.version          = '0.8.0'
  s.summary          = 'Flutter implementation for iterable.com Cross Channel Marketing Platform'
  s.description      = <<-DESC
  Flutter implementation for iterable.com Cross Channel Marketing Platform
                       DESC
  s.homepage         = 'https://github.com/la-haus/iterable-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'La Haus' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'iterable_flutter/Sources/iterable_flutter/**/*'
  s.dependency 'Flutter'
  s.dependency 'Iterable-iOS-SDK', '~> 6.7.5'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
