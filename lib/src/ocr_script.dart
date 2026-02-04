import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Supported ML Kit scripts.
///
/// IMPORTANT:
/// - ML Kit v2 supports: Latin, Chinese, Devanagari, Japanese, Korean.
/// - For non-Latin scripts you MUST add native dependencies (see README).
enum OcrScript {
  latin,
  devanagari,
  chinese,
  japanese,
  korean,
}

extension OcrScriptX on OcrScript {
  TextRecognitionScript toMlKit() {
    switch (this) {
      case OcrScript.latin:
        return TextRecognitionScript.latin;
      case OcrScript.devanagari:
        // Spelling in the plugin is `devanagiri` (ML Kit enum), keep this mapping.
        return TextRecognitionScript.devanagiri;
      case OcrScript.chinese:
        return TextRecognitionScript.chinese;
      case OcrScript.japanese:
        return TextRecognitionScript.japanese;
      case OcrScript.korean:
        return TextRecognitionScript.korean;
    }
  }

  String get label {
    switch (this) {
      case OcrScript.latin:
        return 'Latin';
      case OcrScript.devanagari:
        return 'Devanagari';
      case OcrScript.chinese:
        return 'Chinese';
      case OcrScript.japanese:
        return 'Japanese';
      case OcrScript.korean:
        return 'Korean';
    }
  }
}
