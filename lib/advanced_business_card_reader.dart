/// Public API for advanced_business_card_reader.
///
/// Provides:
/// - OCR (image -> raw text) via Google ML Kit
/// - Best-effort parsing to {name, company, phones, emails, websites}
library advanced_business_card_reader;

export 'src/business_card_data.dart';
export 'src/ocr_script.dart';
export 'src/reader.dart';
