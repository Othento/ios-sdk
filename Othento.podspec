# CocoaPods does not carry AWS Rekognition Face Liveness.
#
# `amplify-ui-swift-liveness` ships no podspec
# (aws-amplify/amplify-ui-swift-liveness#110), so the Pods artifact is built
# without the FaceLiveness module. A workflow configured for
# `rekognition_light` / `rekognition_movement` lands on the SDK's
# "Update Required" screen for Pods integrators. Every other capability —
# document capture, passive liveness, OTP — is unaffected.
#
# Use Swift Package Manager to get Rekognition liveness.
#
# THIS SPEC IS DELIBERATELY FROZEN at the last version CocoaPods could carry.
# It does NOT track the Swift Package version. Release with
# `scripts/release.sh --skip-podspec` so the bump skips this file and the
# README's `~>` pod pin. See dist/RELEASING.md.
Pod::Spec.new do |s|
  s.name             = 'Othento'
  s.version          = '0.1.1'
  s.summary          = 'Othento identity verification SDK for iOS.'
  s.homepage         = 'https://github.com/Othento/ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Othento'
  s.platform         = :ios, '15.0'
  s.source           = { :http => 'https://github.com/Othento/ios-sdk/releases/download/0.1.1/Othento.xcframework.zip' }
  s.vendored_frameworks = 'Othento.xcframework'
end
