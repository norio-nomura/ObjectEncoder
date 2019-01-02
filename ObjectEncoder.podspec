Pod::Spec.new do |s|
  s.name         = 'ObjectEncoder'
  s.version      = '0.1.0'
  s.summary      = 'Swift Encoders implementation using `[String: Any]`, `[Any]` or `Any` as payload.'
  s.description  = 'SE-0167 Swift Encoders implementation using [String: Any], [Any] or Any as payload.'

  s.homepage     = 'https://github.com/norio-nomura/ObjectEncoder'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = 'Norio Nomura'
  s.source       = { :git => 'https://github.com/norio-nomura/ObjectEncoder.git', :tag => "#{s.version}" }
  s.source_files = 'Sources/ObjectEncoder/*.swift'
  s.osx.deployment_target = '10.9'
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'
  
  s.cocoapods_version = '>= 1.4.0'
  s.swift_version = '4.0'
end
