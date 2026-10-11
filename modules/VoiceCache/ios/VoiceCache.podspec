Pod::Spec.new do |s|
  s.name = 'VoiceCache'
  s.version = '1.0.0'
  s.summary = 'Temporary bounded cache for voice assets'
  s.description = 'Expires assets after 50 minutes and clears cache above 20 MB.'
  s.author = 'VoiceDubAI'
  s.homepage = 'https://example.invalid/voicedubai'
  s.license = { :type => 'MIT' }
  s.platforms = { :ios => '15.0' }
  s.source = { :git => 'https://example.invalid/voicedubai.git', :tag => s.version.to_s }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.swift_version = '5.9'
  s.source_files = '**/*.{h,m,mm,swift}'
end