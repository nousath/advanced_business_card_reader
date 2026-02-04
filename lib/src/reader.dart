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

class BusinessCardReader {
  BusinessCardReader._();

  /// OCR using a chosen [script], then parse best-effort fields.
  static Future<BusinessCardScanResult> scanFromFile(
    String filePath, {
    OcrScript script = OcrScript.latin,
    String defaultIsoCountry = 'IN',
  }) async {
    final raw = await BusinessCardOcr.extractRawTextFromFile(filePath, script: script);
    final parsed = BusinessCardParser.parse(raw, defaultIsoCountry: defaultIsoCountry);
    return BusinessCardScanResult(scriptUsed: script, data: parsed);
  }

  /// Auto OCR: tries multiple scripts and picks the best-scoring output.
  ///
  /// NOTE: For non-Latin scripts you must add native dependencies, otherwise those scripts may throw.
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

    return best ??
        await scanFromFile(
          filePath,
          script: OcrScript.latin,
          defaultIsoCountry: defaultIsoCountry,
        );
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
}

class _Scored {
  final int score;
  final BusinessCardScanResult result;
  const _Scored({required this.score, required this.result});
}
