import 'ocr.dart';
import 'ocr_script.dart';
import 'parser.dart';
import 'business_card_data.dart';

class BusinessCardScanResult {
  final OcrScript scriptUsed;
  final BusinessCardData data;

  const BusinessCardScanResult({
    required this.scriptUsed,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'scriptUsed': scriptUsed.name,
        'data': data.toJson(),
      };
}

class BusinessCardSidesResult {
  final BusinessCardScanResult front;
  final BusinessCardScanResult back;
  final BusinessCardScanResult merged;

  const BusinessCardSidesResult({
    required this.front,
    required this.back,
    required this.merged,
  });

  Map<String, dynamic> toJson() => {
        'front': front.toJson(),
        'back': back.toJson(),
        'merged': merged.toJson(),
      };
}

class BusinessCardReader {
  BusinessCardReader._();

  /// Optional helper: extract address entities from OCR/raw text.
  ///
  /// This does not change [BusinessCardData] shape and is safe for existing users.
  static Future<List<String>> extractAddressesFromText(
    String text, {
    String language = 'en',
  }) async {
    try {
      final entities = await BusinessCardOcr.extractEntities(
        text,
        language: language,
      );
      final addresses = <String>{};
      for (final entity in entities.entities) {
        if (entity.type == 'address') {
          final value = entity.text.trim();
          if (value.isNotEmpty) {
            addresses.add(value);
          }
        }
      }
      return addresses.toList();
    } catch (_) {
      return const <String>[];
    }
  }

  /// OCR using a chosen [script], then parse best-effort fields.
  static Future<BusinessCardScanResult> scanFromFile(
    String filePath, {
    OcrScript script = OcrScript.latin,
    String defaultIsoCountry = 'IN',
  }) async {
    final raw = await BusinessCardOcr.extractRawTextFromFile(filePath, script: script);
    final parsed = BusinessCardParser.parse(raw, defaultIsoCountry: defaultIsoCountry);
    final merged = await _mergeEntityData(
      parsed,
      script: script,
      defaultIsoCountry: defaultIsoCountry,
    );
    return BusinessCardScanResult(scriptUsed: script, data: merged);
  }

  /// Auto OCR: tries multiple scripts and picks the best-scoring output.
  static Future<BusinessCardScanResult> scanAutoFromFile(
    String filePath, {
    List<OcrScript> preferredScripts = const [
      OcrScript.latin,
      OcrScript.devanagari,
      OcrScript.chinese,
      OcrScript.japanese,
      OcrScript.korean,
    ],
    String defaultIsoCountry = 'IN',
  }) async {
    BusinessCardScanResult? best;

    for (final s in preferredScripts) {
      try {
        final raw = await BusinessCardOcr.extractRawTextFromFile(filePath, script: s);
        if (raw.trim().isEmpty) continue;

        final score = _scoreText(raw);
        final parsed = BusinessCardParser.parse(raw, defaultIsoCountry: defaultIsoCountry);

        final candidate = _Scored(
          score: score,
          result: BusinessCardScanResult(scriptUsed: s, data: parsed),
        );

        if (best == null || candidate.score > _scoreText(best.data.rawText)) {
          best = candidate.result;
        }
      } catch (_) {
        // likely missing native dependency for that script - ignore and continue
      }
    }

    if (best != null) {
      final merged = await _mergeEntityData(
        best.data,
        script: best.scriptUsed,
        defaultIsoCountry: defaultIsoCountry,
      );
      return BusinessCardScanResult(scriptUsed: best.scriptUsed, data: merged);
    }

    return scanFromFile(
      filePath,
      script: OcrScript.latin,
      defaultIsoCountry: defaultIsoCountry,
    );
  }

  /// Scan front and back card images with the same [script] and return side + merged results.
  static Future<BusinessCardSidesResult> scanFromFilesFrontBack({
    required String frontPath,
    required String backPath,
    OcrScript script = OcrScript.latin,
    String defaultIsoCountry = 'IN',
  }) async {
    final front = await scanFromFile(
      frontPath,
      script: script,
      defaultIsoCountry: defaultIsoCountry,
    );
    final back = await scanFromFile(
      backPath,
      script: script,
      defaultIsoCountry: defaultIsoCountry,
    );

    final merged = _mergeFrontBackResults(front: front, back: back);
    return BusinessCardSidesResult(front: front, back: back, merged: merged);
  }

  /// Auto scan front and back card images (script chosen per side) and return side + merged results.
  static Future<BusinessCardSidesResult> scanAutoFromFilesFrontBack({
    required String frontPath,
    required String backPath,
    List<OcrScript> preferredScripts = const [
      OcrScript.latin,
      OcrScript.devanagari,
      OcrScript.chinese,
      OcrScript.japanese,
      OcrScript.korean,
    ],
    String defaultIsoCountry = 'IN',
  }) async {
    final front = await scanAutoFromFile(
      frontPath,
      preferredScripts: preferredScripts,
      defaultIsoCountry: defaultIsoCountry,
    );
    final back = await scanAutoFromFile(
      backPath,
      preferredScripts: preferredScripts,
      defaultIsoCountry: defaultIsoCountry,
    );

    final merged = _mergeFrontBackResults(front: front, back: back);
    return BusinessCardSidesResult(front: front, back: back, merged: merged);
  }

  static int _scoreText(String t) {
    final cleaned = t.replaceAll(RegExp(r'\s+'), '');
    // count "useful" chars (latin + digits + supported CJK + devanagari + kana + hangul)
    final useful = cleaned.replaceAll(
      RegExp(r'[^A-Za-z0-9\u0900-\u097F\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]'),
      '',
    );
    return (useful.length * 2) + t.length;
  }

  static Future<BusinessCardData> _mergeEntityData(
    BusinessCardData base, {
    required OcrScript script,
    required String defaultIsoCountry,
  }) async {
    try {
      final entities = await BusinessCardOcr.extractEntities(
        base.rawText,
        language: _languageForScript(script),
      );
      if (entities.entities.isEmpty) {
        return base;
      }
      return BusinessCardParser.mergeEntityContacts(
        base,
        entities.entities.map((e) => e.toMap()),
        defaultIsoCountry: defaultIsoCountry,
      );
    } catch (_) {
      // Entity extraction is optional. Regex parser output remains the fallback.
      return base;
    }
  }

  static String _languageForScript(OcrScript script) {
    switch (script) {
      case OcrScript.latin:
        return 'en';
      case OcrScript.devanagari:
        return 'hi';
      case OcrScript.chinese:
        return 'zh';
      case OcrScript.japanese:
        return 'ja';
      case OcrScript.korean:
        return 'ko';
    }
  }

  static BusinessCardScanResult _mergeFrontBackResults({
    required BusinessCardScanResult front,
    required BusinessCardScanResult back,
  }) {
    final frontData = front.data;
    final backData = back.data;
    final mergedRawText = _mergeRawText(frontData.rawText, backData.rawText);

    final mergedPhones = _mergePhones(frontData.phones, backData.phones);
    final mergedEmails = _mergeEmails(frontData.emails, backData.emails);
    final mergedWebsites = _mergeWebsites(frontData.websites, backData.websites);

    final mergedData = BusinessCardData(
      rawText: mergedRawText,
      name: frontData.name ?? backData.name,
      company: frontData.company ?? backData.company,
      phones: mergedPhones,
      emails: mergedEmails,
      websites: mergedWebsites,
    );

    final mergedScript = frontData.rawText.trim().isNotEmpty ? front.scriptUsed : back.scriptUsed;
    return BusinessCardScanResult(scriptUsed: mergedScript, data: mergedData);
  }

  static String _mergeRawText(String frontText, String backText) {
    return '---- FRONT ----\n${frontText.trim()}\n\n---- BACK ----\n${backText.trim()}';
  }

  static List<String> _mergePhones(List<String> frontPhones, List<String> backPhones) {
    final out = <String, String>{};
    for (final phone in [...frontPhones, ...backPhones]) {
      final normalized = BusinessCardParser.normalizePhoneForMerge(phone);
      if (normalized.isEmpty) continue;
      out.putIfAbsent(normalized, () => normalized);
    }
    return out.values.toList();
  }

  static List<String> _mergeEmails(List<String> frontEmails, List<String> backEmails) {
    final out = <String, String>{};
    for (final email in [...frontEmails, ...backEmails]) {
      final normalized = BusinessCardParser.normalizeEmailForMerge(email);
      if (normalized.isEmpty) continue;
      out.putIfAbsent(normalized, () => normalized);
    }
    return out.values.toList();
  }

  static List<String> _mergeWebsites(List<String> frontWebsites, List<String> backWebsites) {
    final out = <String, String>{};
    for (final website in [...frontWebsites, ...backWebsites]) {
      final normalized = BusinessCardParser.normalizeWebsiteForMerge(website);
      if (normalized.isEmpty) continue;
      final dedupeKey = normalized.toLowerCase();
      out.putIfAbsent(dedupeKey, () => normalized);
    }
    return out.values.toList();
  }
}

class _Scored {
  final int score;
  final BusinessCardScanResult result;
  const _Scored({required this.score, required this.result});
}
