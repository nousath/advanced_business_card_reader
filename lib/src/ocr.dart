import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_script.dart';

class BusinessCardOcr {
  BusinessCardOcr._();

  /// Extract raw text from an image file.
  ///
  /// [script] defaults to Latin (best for English/Tanglish).
  static Future<String> extractRawTextFromFile(
    String filePath, {
    OcrScript script = OcrScript.latin,
  }) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final recognizer = TextRecognizer(script: script.toMlKit());

    try {
      final result = await recognizer.processImage(inputImage);
      return result.text.trim();
    } finally {
      recognizer.close();
    }
  }
}
