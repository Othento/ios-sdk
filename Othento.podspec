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
