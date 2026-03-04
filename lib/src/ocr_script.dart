/// Supported ML Kit scripts.
///
/// IMPORTANT:
/// - ML Kit v2 supports: Latin, Chinese, Devanagari, Japanese, Korean.
/// - Native recognizers are selected by script via platform channel.
enum OcrScript {
  latin,
  devanagari,
  chinese,
  japanese,
  korean,
}

extension OcrScriptX on OcrScript {
  String get channelValue {
    switch (this) {
      case OcrScript.latin:
        return 'latin';
      case OcrScript.devanagari:
        return 'devanagari';
      case OcrScript.chinese:
        return 'chinese';
      case OcrScript.japanese:
        return 'japanese';
      case OcrScript.korean:
        return 'korean';
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
