Pod::Spec.new do |s|
  s.name             = 'advanced_business_card_reader'
  s.version          = '1.0.0'
  s.summary          = 'Business card OCR and parsing using native Google ML Kit.'
  s.description      = <<-DESC
Native OCR and entity extraction for advanced_business_card_reader using Google ML Kit.
                       DESC
  s.homepage         = 'https://github.com/nousath/advanced_business_card_reader'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'nousath' => 'nousath@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  s.dependency 'GoogleMLKit/TextRecognition', '8.0.0'
  s.dependency 'GoogleMLKit/TextRecognitionChinese', '8.0.0'
  s.dependency 'GoogleMLKit/TextRecognitionDevanagari', '8.0.0'
  s.dependency 'GoogleMLKit/TextRecognitionJapanese', '8.0.0'
  s.dependency 'GoogleMLKit/TextRecognitionKorean', '8.0.0'
  s.dependency 'GoogleMLKit/EntityExtraction', '8.0.0'

  s.platform = :ios, '15.5'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
