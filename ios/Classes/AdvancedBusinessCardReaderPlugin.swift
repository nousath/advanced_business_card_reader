import Flutter
import UIKit
import MLKitVision
import MLKitTextRecognition
import MLKitTextRecognitionChinese
import MLKitTextRecognitionDevanagari
import MLKitTextRecognitionJapanese
import MLKitTextRecognitionKorean
import MLKitEntityExtraction

public class AdvancedBusinessCardReaderPlugin: NSObject, FlutterPlugin {
  private var recognizerCache: [String: TextRecognizer] = [:]
  private var extractorCache: [String: EntityExtractor] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "advanced_business_card_reader",
      binaryMessenger: registrar.messenger()
    )
    let instance = AdvancedBusinessCardReaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ocrFromFile":
      handleOcrFromFile(call, result: result)
    case "extractEntities":
      handleExtractEntities(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    recognizerCache.removeAll()
    extractorCache.removeAll()
  }

  private func handleOcrFromFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Missing required argument: path",
          details: nil
        )
      )
      return
    }

    guard let image = UIImage(contentsOfFile: path) else {
      result(
        FlutterError(
          code: "OCR_ERROR",
          message: "Failed to load image from file path.",
          details: nil
        )
      )
      return
    }

    let script = normalizeScript((args["script"] as? String) ?? "latin")
    let recognizer = getOrCreateRecognizer(script: script)
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    recognizer.process(visionImage) { recognizedText, error in
      if let error = error {
        result(
          FlutterError(
            code: "OCR_ERROR",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      guard let recognizedText = recognizedText else {
        result(
          FlutterError(
            code: "OCR_ERROR",
            message: "OCR returned no result.",
            details: nil
          )
        )
        return
      }

      let blocks: [[String: Any]] = recognizedText.blocks.map { block in
        let frame = block.frame
        return [
          "text": block.text,
          "boundingBox": [
            "left": Int(frame.minX.rounded()),
            "top": Int(frame.minY.rounded()),
            "right": Int(frame.maxX.rounded()),
            "bottom": Int(frame.maxY.rounded())
          ]
        ]
      }

      result([
        "text": recognizedText.text.trimmingCharacters(in: .whitespacesAndNewlines),
        "blocks": blocks
      ])
    }
  }

  private func handleExtractEntities(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let rawText = args["text"] as? String
    else {
      result([
        "languageUsed": "en",
        "entities": []
      ])
      return
    }

    let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty {
      result([
        "languageUsed": "en",
        "entities": []
      ])
      return
    }

    let requestedLanguage = (args["language"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let modelIdentifier = resolveModelIdentifier(language: requestedLanguage)
    let languageUsed = modelIdentifier.toLanguageTag()
    let extractor = getOrCreateExtractor(modelIdentifier: modelIdentifier)

    extractor.downloadModelIfNeeded { [weak self] downloadError in
      if downloadError != nil {
        result([
          "languageUsed": languageUsed,
          "entities": []
        ])
        return
      }

      extractor.annotateText(text) { annotations, extractionError in
        if extractionError != nil || annotations == nil {
          result([
            "languageUsed": languageUsed,
            "entities": []
          ])
          return
        }

        let entities = self?.toEntityMaps(annotations: annotations ?? [], text: text) ?? []
        result([
          "languageUsed": languageUsed,
          "entities": entities
        ])
      }
    }
  }

  private func getOrCreateRecognizer(script: String) -> TextRecognizer {
    if let cached = recognizerCache[script] {
      return cached
    }

    let recognizer: TextRecognizer
    switch script {
    case "chinese":
      recognizer = TextRecognizer.textRecognizer(options: ChineseTextRecognizerOptions())
    case "devanagari":
      recognizer = TextRecognizer.textRecognizer(options: DevanagariTextRecognizerOptions())
    case "japanese":
      recognizer = TextRecognizer.textRecognizer(options: JapaneseTextRecognizerOptions())
    case "korean":
      recognizer = TextRecognizer.textRecognizer(options: KoreanTextRecognizerOptions())
    default:
      recognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
    }

    recognizerCache[script] = recognizer
    return recognizer
  }

  private func getOrCreateExtractor(modelIdentifier: EntityExtractionModelIdentifier) -> EntityExtractor {
    let key = modelIdentifier.toLanguageTag()
    if let cached = extractorCache[key] {
      return cached
    }

    let options = EntityExtractorOptions(modelIdentifier: modelIdentifier)
    let extractor = EntityExtractor.entityExtractor(options: options)
    extractorCache[key] = extractor
    return extractor
  }

  private func resolveModelIdentifier(language: String?) -> EntityExtractionModelIdentifier {
    guard let language = language, !language.isEmpty else {
      return .english
    }

    let normalized = language.replacingOccurrences(of: "_", with: "-")
    if let identifier = EntityExtractionModelIdentifier.fromLanguageTag(normalized) {
      return identifier
    }

    if let baseIdentifier = EntityExtractionModelIdentifier.fromLanguageTag(
      normalized.components(separatedBy: "-").first ?? normalized
    ) {
      return baseIdentifier
    }

    return .english
  }

  private func toEntityMaps(annotations: [EntityAnnotation], text: String) -> [[String: Any]] {
    var items: [[String: Any]] = []
    let nsText = text as NSString

    for annotation in annotations {
      let start = max(0, annotation.range.location)
      let end = min(nsText.length, annotation.range.location + annotation.range.length)
      let safeRange = NSRange(location: start, length: max(0, end - start))
      let snippet = nsText.substring(with: safeRange)

      for entity in annotation.entities {
        var mapped: [String: Any] = [
          "type": mapEntityType(entity.entityType),
          "text": snippet,
          "start": safeRange.location,
          "end": safeRange.location + safeRange.length
        ]

        let meta = mapEntityMeta(entity)
        if !meta.isEmpty {
          mapped["meta"] = meta
        }
        items.append(mapped)
      }
    }

    return items
  }

  private func mapEntityType(_ type: EntityType) -> String {
    switch type {
    case .phone:
      return "phone"
    case .email:
      return "email"
    case .URL:
      return "url"
    case .address:
      return "address"
    case .dateTime:
      return "datetime"
    case .flightNumber:
      return "flight_number"
    case .IBAN:
      return "iban"
    case .ISBN:
      return "isbn"
    case .money:
      return "money"
    case .paymentCard:
      return "payment_card"
    case .trackingNumber:
      return "tracking_number"
    default:
      return "unknown"
    }
  }

  private func mapEntityMeta(_ entity: Entity) -> [String: Any] {
    var meta: [String: Any] = [:]

    if entity.entityType == .dateTime, let dateTimeEntity = entity.dateTimeEntity {
      meta["timestampMillis"] = Int(dateTimeEntity.dateTime.timeIntervalSince1970 * 1000.0)
      meta["granularity"] = Int(dateTimeEntity.dateTimeGranularity.rawValue)
    }

    if entity.entityType == .money, let moneyEntity = entity.moneyEntity {
      meta["currency"] = moneyEntity.unnormalizedCurrency
      meta["integerPart"] = Int(moneyEntity.integerPart)
      meta["fractionalPart"] = Int(moneyEntity.fractionalPart)
    }

    return meta
  }

  private func normalizeScript(_ script: String) -> String {
    let normalized = script.lowercased()
    let supported = ["latin", "devanagari", "chinese", "japanese", "korean"]
    return supported.contains(normalized) ? normalized : "latin"
  }
}
