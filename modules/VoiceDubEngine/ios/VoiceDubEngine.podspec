Pod::Spec.new do |s|
  s.name = 'VoiceDubEngine'
  s.version = '1.0.0'
  s.summary = 'On-device voice cloning and synthesis for VoiceDubAI'
  s.description = 'Uses FluidAudio PocketTTS for local voice cloning and speech synthesis.'
  s.author = 'VoiceDubAI'
  s.homepage = 'https://github.com/arnaupq2/appletest'
  s.license = { :type => 'MIT' }
  s.platforms = { :ios => '17.0' }
  s.source = { :git => 'https://github.com/arnaupq2/appletest.git', :tag => s.version.to_s }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.dependency 'FluidAudio', '~> 0.17.1'
  s.swift_version = '5.9'
  s.source_files = '**/*.{h,m,mm,swift}'
end
