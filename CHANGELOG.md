## 1.1.0
- Replaced Dart-side OCR wrapper with direct native Google ML Kit integration via `MethodChannel` on Android and iOS.
- Added native ML Kit Text Recognition v2 support for Latin, Devanagari, Chinese, Japanese, and Korean.
- Added native ML Kit Entity Extraction (model download + annotation) and merged extracted phones/emails/websites with regex parser output.
- Removed `google_mlkit_text_recognition` dependency from Dart package dependencies.
- Kept existing public Dart API intact (`BusinessCardReader`, `BusinessCardScanResult`, `BusinessCardData`, `OcrScript` values).
- Added plugin platform declarations in `pubspec.yaml` and native plugin implementations for Android/iOS.
- Updated example/config docs for current platform requirements (Android minSdk 26, iOS deployment target 15.5).

## 1.0.0
- Initial release
- OCR + parser + auto script scan
- Example app (camera/gallery/file)
