Pod::Spec.new do |s|
  s.name = 'AppleFoundationTranslator'
  s.version = '1.0.0'
  s.summary = 'On-device translation using Apple Foundation Models'
  s.description = 'A local Expo module using Foundation Models.'
  s.author = 'VoiceDubAI'
  s.homepage = 'https://example.invalid/voicedubai'
  s.license = { :type => 'MIT' }
  s.platforms = { :ios => '26.0' }
  s.source = { :git => 'https://example.invalid/voicedubai.git', :tag => s.version.to_s }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.swift_version = '5.9'
  s.source_files = '**/*.{h,m,mm,swift}'
end