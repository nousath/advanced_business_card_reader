# advanced_business_card_reader

Business/visiting card reader plugin for Flutter.

- Native OCR with Google ML Kit Text Recognition v2 (Android/iOS)
- Native Entity Extraction (beta) for extra phone/email/url signals
- Dart-side fallback parsing for name/company/phones/emails/websites

## What changed

This plugin now uses direct native Google ML Kit through a Flutter `MethodChannel`:

- Channel: `advanced_business_card_reader`
- Methods:
  - `ocrFromFile`
  - `extractEntities`

The public Dart API remains the same:

- `BusinessCardReader.scanFromFile(...)`
- `BusinessCardReader.scanAutoFromFile(...)`
- `BusinessCardScanResult` / `BusinessCardData`
- `OcrScript` values (`latin`, `devanagari`, `chinese`, `japanese`, `korean`)

Additive API for double-side cards:

- `BusinessCardReader.scanFromFilesFrontBack(...)`
- `BusinessCardReader.scanAutoFromFilesFrontBack(...)`
- `BusinessCardSidesResult` (`front`, `back`, `merged`)

## Install

```yaml
dependencies:
  advanced_business_card_reader: ^1.0.0
```

## Platform requirements

### Android

- Minimum SDK: `26` (required because of ML Kit Entity Extraction)
- ML Kit dependencies are provided by the plugin:
  - `com.google.mlkit:text-recognition:16.0.1`
  - `com.google.mlkit:text-recognition-devanagari:16.0.1`
  - `com.google.mlkit:text-recognition-chinese:16.0.1`
  - `com.google.mlkit:text-recognition-japanese:16.0.1`
  - `com.google.mlkit:text-recognition-korean:16.0.1`
  - `com.google.mlkit:entity-extraction:16.0.0-beta6`

If you want a smaller binary, you can fork and remove script-specific recognizers you do not need.

### iOS

- iOS deployment target: `15.5`
- 64-bit devices only (Apple requirement)
- Pods used by this plugin:
  - `GoogleMLKit/TextRecognition` `8.0.0`
  - `GoogleMLKit/TextRecognitionChinese` `8.0.0`
  - `GoogleMLKit/TextRecognitionDevanagari` `8.0.0`
  - `GoogleMLKit/TextRecognitionJapanese` `8.0.0`
  - `GoogleMLKit/TextRecognitionKorean` `8.0.0`
  - `GoogleMLKit/EntityExtraction` `8.0.0`

Entity Extraction models are downloaded on-device with `downloadModelIfNeeded()` before annotation.

## Usage

```dart
import 'package:advanced_business_card_reader/advanced_business_card_reader.dart';

final result = await BusinessCardReader.scanFromFile(
  filePath,
  script: OcrScript.latin,
  defaultIsoCountry: 'IN',
);

print(result.data.name);
print(result.data.company);
print(result.data.phones);
print(result.data.emails);
print(result.data.websites);
print(result.data.rawText);
```

Auto script:

```dart
final result = await BusinessCardReader.scanAutoFromFile(
  filePath,
  preferredScripts: const [
    OcrScript.latin,
    OcrScript.devanagari,
    OcrScript.chinese,
    OcrScript.japanese,
    OcrScript.korean,
  ],
  defaultIsoCountry: 'IN',
);
```

Double-side card:

```dart
final sides = await BusinessCardReader.scanAutoFromFilesFrontBack(
  frontPath: frontImagePath,
  backPath: backImagePath,
  preferredScripts: const [
    OcrScript.latin,
    OcrScript.devanagari,
    OcrScript.chinese,
    OcrScript.japanese,
    OcrScript.korean,
  ],
  defaultIsoCountry: 'IN',
);

print('Front: ${sides.front.data.toJson()}');
print('Back: ${sides.back.data.toJson()}');
print('Merged: ${sides.merged.data.toJson()}');
```

## Parsing behavior

- OCR text is always parsed by regex + `phone_numbers_parser` fallback.
- Entity Extraction is best-effort enhancement only.
- `phones`, `emails`, and `websites` are merged as a union of:
  - parser results
  - extracted entities
- If entity extraction fails/model download fails, parser fallback output is still returned.

## Unsupported platforms

Web/desktop are not supported. Calls throw `UnsupportedError` with a clear message.

## Example app

The example app includes:

- Camera
- Gallery
- File picker
- Script selector (Auto + individual scripts)
- Single-side and double-side scan modes

Run:

```bash
cd example
flutter run
```

## License

MIT
