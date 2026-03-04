import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ocr_script.dart';

class BusinessCardOcr {
  BusinessCardOcr._();

  static const MethodChannel _channel = MethodChannel('advanced_business_card_reader');

  /// Extract raw text from an image file.
  ///
  /// [script] defaults to Latin (best for English/Tanglish).
  static Future<String> extractRawTextFromFile(
    String filePath, {
    OcrScript script = OcrScript.latin,
  }) async {
    _ensureSupportedPlatform();
    final response = await _channel.invokeMethod<Object?>(
      'ocrFromFile',
      <String, Object?>{
        'path': filePath,
        'script': script.channelValue,
      },
    );

    if (response is! Map) {
      return '';
    }

    final text = response['text']?.toString() ?? '';
    return text.trim();
  }

  static Future<EntityExtractionResult> extractEntities(
    String text, {
    String? language,
  }) async {
    _ensureSupportedPlatform();
    final response = await _channel.invokeMethod<Object?>(
      'extractEntities',
      <String, Object?>{
        'text': text,
        if (language != null && language.trim().isNotEmpty) 'language': language,
      },
    );

    if (response is! Map) {
      return const EntityExtractionResult(languageUsed: 'en', entities: <ExtractedEntity>[]);
    }

    final languageUsed = response['languageUsed']?.toString() ?? 'en';
    final entities = <ExtractedEntity>[];
    final rawEntities = response['entities'];
    if (rawEntities is List) {
      for (final raw in rawEntities) {
        if (raw is Map) {
          entities.add(ExtractedEntity.fromMap(raw));
        }
      }
    }

    return EntityExtractionResult(
      languageUsed: languageUsed,
      entities: entities,
    );
  }

  static void _ensureSupportedPlatform() {
    if (kIsWeb) {
      throw UnsupportedError(
        'advanced_business_card_reader supports only Android and iOS.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        throw UnsupportedError(
          'advanced_business_card_reader supports only Android and iOS.',
        );
    }
  }
}

class EntityExtractionResult {
  final String languageUsed;
  final List<ExtractedEntity> entities;

  const EntityExtractionResult({
    required this.languageUsed,
    required this.entities,
  });
}

class ExtractedEntity {
  final String type;
  final String text;
  final int start;
  final int end;
  final Map<String, dynamic> meta;

  const ExtractedEntity({
    required this.type,
    required this.text,
    required this.start,
    required this.end,
    required this.meta,
  });

  factory ExtractedEntity.fromMap(Map<dynamic, dynamic> map) {
    return ExtractedEntity(
      type: map['type']?.toString() ?? 'unknown',
      text: map['text']?.toString() ?? '',
      start: _toInt(map['start']),
      end: _toInt(map['end']),
      meta: _toStringDynamicMap(map['meta']),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'text': text,
        'start': start,
        'end': end,
        'meta': meta,
      };

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _toStringDynamicMap(Object? v) {
    if (v is Map) {
      return v.map((k, value) => MapEntry(k.toString(), value));
    }
    return const <String, dynamic>{};
  }
}
