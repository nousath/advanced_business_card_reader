# 📇 advanced_business_card_reader

Business/visiting card reader for Flutter using **Google ML Kit Text Recognition**.

✅ OCR (image → text)  
✅ Best‑effort parsing: **Name / Company / Phone / Email / Website**  
✅ Works offline (on‑device)  
✅ Includes **example app** (Camera + Gallery + File picker)

> Status: Currently **tested mostly with India business cards**, but the package is designed to work in **other countries** too (UAE / USA / Saudi / etc.) via `defaultIsoCountry`.

---

## 🌍 Country support (Phones)

Phone extraction uses `phone_numbers_parser` and supports country‑aware parsing:

- If the card contains an international number like **+971… / +1… / +91…**, it parses correctly.
- If the card contains **local format** numbers (no `+countryCode`), set `defaultIsoCountry`.

### Examples

**India**
```dart
final r = await BusinessCardReader.scanAutoFromFile(
  path,
  preferredScripts: const [OcrScript.latin, OcrScript.devanagari],
  defaultIsoCountry: 'IN',
);
```

**UAE**
```dart
final r = await BusinessCardReader.scanFromFile(
  path,
  script: OcrScript.latin,
  defaultIsoCountry: 'AE',
);
```

**USA**
```dart
final r = await BusinessCardReader.scanFromFile(
  path,
  script: OcrScript.latin,
  defaultIsoCountry: 'US',
);
```

**Saudi Arabia**
```dart
final r = await BusinessCardReader.scanFromFile(
  path,
  script: OcrScript.latin,
  defaultIsoCountry: 'SA',
);
```

> Tip: If your users are in multiple regions, set `defaultIsoCountry` from a **user profile / app setting**.

---

## 🔤 OCR language/script support

ML Kit Text Recognition v2 is **script‑based** and supports:

- **Latin** (English, most cards worldwide)
- **Devanagari** (Hindi/Marathi/Nepali)
- **Chinese / Japanese / Korean**

### Important limitation (Arabic / Tamil scripts)
Google ML Kit **Text Recognition v2** (used by `google_mlkit_text_recognition`) does **not** provide an Arabic or Tamil script recognizer in this API.
- UAE / Saudi cards written in **English** → ✅ works (Latin)
- UAE / Saudi cards written mainly in **Arabic script** → ⚠️ not supported by this ML Kit recognizer (you would need another OCR engine)

---

## 📦 Install

```yaml
dependencies:
  advanced_business_card_reader: ^1.0.0
```

---

## ⚙️ Platform setup (optional scripts)

### Android

If you need non‑Latin scripts, add only what you need in your **app**:

`android/app/build.gradle` (Groovy)
```gradle
dependencies {
  implementation "com.google.mlkit:text-recognition-devanagari:16.0.1"
  implementation "com.google.mlkit:text-recognition-chinese:16.0.1"
  implementation "com.google.mlkit:text-recognition-japanese:16.0.1"
  implementation "com.google.mlkit:text-recognition-korean:16.0.1"
}
```

`android/app/build.gradle.kts` (Kotlin DSL)
```kotlin
dependencies {
  implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
  implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
  implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
  implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
```

> Latin works by default; add only the extra scripts you truly need (APK size increases).

### iOS

In your **app** `ios/Podfile` (add only required pods):

```ruby
pod 'GoogleMLKit/TextRecognitionDevanagari', '~> 9.0.0'
pod 'GoogleMLKit/TextRecognitionChinese', '~> 9.0.0'
pod 'GoogleMLKit/TextRecognitionJapanese', '~> 9.0.0'
pod 'GoogleMLKit/TextRecognitionKorean', '~> 9.0.0'
```

Then:

```bash
cd ios
pod install
```

---

## ✅ Usage

### Selected script

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
```

### Auto script (recommended)

For India:
```dart
final result = await BusinessCardReader.scanAutoFromFile(
  filePath,
  preferredScripts: const [OcrScript.latin, OcrScript.devanagari],
  defaultIsoCountry: 'IN',
);
```

For most other countries (English cards):
```dart
final result = await BusinessCardReader.scanAutoFromFile(
  filePath,
  preferredScripts: const [OcrScript.latin],
  defaultIsoCountry: 'AE', // or US / SA / etc.
);
```

---

## 🧪 Example app

```bash
cd example
flutter run
```

Example includes:
- Camera scan
- Gallery pick
- File pick (image)
- Script dropdown (Auto + scripts)
- Parsed fields + raw text view

---

## 🧠 Tips for accuracy

- Good lighting, no blur
- Keep the card flat and fill the frame
- Cropping before OCR improves results a lot
- Always show a confirmation/edit screen (cards vary)

---

## 🗺️ Roadmap ideas (future)

- Country auto‑detect (based on +country code / address keywords)
- Region presets (IN / AE / US / SA)
- Better name/company heuristics for different card styles

---

## ☕ Sponsor a cup of tea

If this package saves you time, you can sponsor:

https://github.com/sponsors/nousath

---

## 📄 License

MIT
