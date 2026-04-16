#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ferrostar_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ferrostar_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter bindings for the Ferrostar navigation SDK.'
  s.description      = <<-DESC
Flutter bindings for the Ferrostar navigation SDK.
                       DESC
  s.homepage         = 'https://github.com/cafca/beebeebike'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vincent Ahrend' => 'cafca@001.land' }
  s.source           = { :path => '.' }
  s.source_files     = 'ferrostar_flutter/Sources/ferrostar_flutter/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.resource_bundles = {
    'ferrostar_flutter_privacy' => ['ferrostar_flutter/Sources/ferrostar_flutter/PrivacyInfo.xcprivacy'],
  }

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
