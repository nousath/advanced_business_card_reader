package com.nh97.advanced_business_card_reader

import android.content.Context
import android.net.Uri
import com.google.mlkit.nl.entityextraction.Entity
import com.google.mlkit.nl.entityextraction.EntityAnnotation
import com.google.mlkit.nl.entityextraction.EntityExtraction
import com.google.mlkit.nl.entityextraction.EntityExtractionParams
import com.google.mlkit.nl.entityextraction.EntityExtractor
import com.google.mlkit.nl.entityextraction.EntityExtractorOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class AdvancedBusinessCardReaderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private val recognizerCache = mutableMapOf<String, TextRecognizer>()
    private val extractorCache = mutableMapOf<String, EntityExtractor>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_OCR_FROM_FILE -> handleOcrFromFile(call, result)
            METHOD_EXTRACT_ENTITIES -> handleExtractEntities(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        recognizerCache.values.forEach { recognizer ->
            runCatching { recognizer.close() }
        }
        recognizerCache.clear()

        extractorCache.values.forEach { extractor ->
            runCatching { extractor.close() }
        }
        extractorCache.clear()
    }

    private fun handleOcrFromFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")?.trim()
        if (path.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Missing required argument: path", null)
            return
        }

        val script = normalizeScript(call.argument<String>("script"))
        val image = try {
            InputImage.fromFilePath(context, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            result.error("OCR_ERROR", e.message ?: "Failed to read image file", null)
            return
        }

        val recognizer = try {
            getOrCreateRecognizer(script)
        } catch (e: Exception) {
            result.error("OCR_ERROR", e.message ?: "Failed to initialize recognizer", null)
            return
        }

        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                val blocks = visionText.textBlocks.map { block ->
                    val box = block.boundingBox
                    mapOf(
                        "text" to block.text,
                        "boundingBox" to if (box == null) {
                            null
                        } else {
                            mapOf(
                                "left" to box.left,
                                "top" to box.top,
                                "right" to box.right,
                                "bottom" to box.bottom,
                            )
                        },
                    )
                }

                result.success(
                    mapOf(
                        "text" to visionText.text.trim(),
                        "blocks" to blocks,
                    ),
                )
            }
            .addOnFailureListener { e ->
                result.error("OCR_ERROR", e.message ?: "OCR processing failed", null)
            }
    }

    private fun handleExtractEntities(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.trim()
        if (text.isNullOrEmpty()) {
            result.success(
                mapOf(
                    "languageUsed" to "en",
                    "entities" to emptyList<Map<String, Any>>(),
                ),
            )
            return
        }

        val requestedLanguage = call.argument<String>("language")?.trim()
        val modelIdentifier = resolveModelIdentifier(requestedLanguage)
        val languageUsed = languageTagForModel(modelIdentifier)
        val extractor = getOrCreateExtractor(modelIdentifier)

        extractor.downloadModelIfNeeded()
            .onSuccessTask {
                extractor.annotate(
                    EntityExtractionParams.Builder(text).build(),
                )
            }
            .addOnSuccessListener { annotations ->
                result.success(
                    mapOf(
                        "languageUsed" to languageUsed,
                        "entities" to toEntityMaps(annotations, text),
                    ),
                )
            }
            .addOnFailureListener {
                // Entity extraction is best-effort only.
                result.success(
                    mapOf(
                        "languageUsed" to languageUsed,
                        "entities" to emptyList<Map<String, Any>>(),
                    ),
                )
            }
    }

    private fun getOrCreateRecognizer(script: String): TextRecognizer {
        return recognizerCache.getOrPut(script) {
            when (script) {
                "chinese" -> TextRecognition.getClient(
                    ChineseTextRecognizerOptions.Builder().build(),
                )

                "devanagari" -> TextRecognition.getClient(
                    DevanagariTextRecognizerOptions.Builder().build(),
                )

                "japanese" -> TextRecognition.getClient(
                    JapaneseTextRecognizerOptions.Builder().build(),
                )

                "korean" -> TextRecognition.getClient(
                    KoreanTextRecognizerOptions.Builder().build(),
                )

                else -> TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            }
        }
    }

    private fun getOrCreateExtractor(modelIdentifier: String): EntityExtractor {
        return extractorCache.getOrPut(modelIdentifier) {
            EntityExtraction.getClient(
                EntityExtractorOptions.Builder(modelIdentifier).build(),
            )
        }
    }

    private fun resolveModelIdentifier(language: String?): String {
        val normalized = language
            ?.trim()
            ?.lowercase(Locale.ROOT)
            ?.replace('_', '-')
            ?.takeIf { it.isNotEmpty() }

        if (normalized != null) {
            runCatching { EntityExtractorOptions.fromLanguageTag(normalized) }
                .getOrNull()
                ?.let { return it }

            val base = normalized.substringBefore('-')
            runCatching { EntityExtractorOptions.fromLanguageTag(base) }
                .getOrNull()
                ?.let { return it }
        }

        return EntityExtractorOptions.ENGLISH
    }

    private fun languageTagForModel(modelIdentifier: String): String {
        return runCatching { EntityExtractorOptions.toLanguageTag(modelIdentifier) }
            .getOrDefault("en")
    }

    private fun toEntityMaps(annotations: List<EntityAnnotation>, text: String): List<Map<String, Any>> {
        val entities = mutableListOf<Map<String, Any>>()
        for (annotation in annotations) {
            val start = annotation.start.coerceAtLeast(0)
            val end = annotation.end.coerceIn(start, text.length)
            val snippet = safeSubstring(text, start, end)
            for (entity in annotation.entities) {
                val mapped = mutableMapOf<String, Any>(
                    "type" to mapEntityType(entity.type),
                    "text" to snippet,
                    "start" to start,
                    "end" to end,
                )
                val meta = mapEntityMeta(entity)
                if (meta.isNotEmpty()) {
                    mapped["meta"] = meta
                }
                entities.add(mapped)
            }
        }
        return entities
    }

    private fun safeSubstring(text: String, start: Int, end: Int): String {
        if (text.isEmpty()) return ""
        val safeStart = start.coerceIn(0, text.length)
        val safeEnd = end.coerceIn(safeStart, text.length)
        return text.substring(safeStart, safeEnd)
    }

    private fun mapEntityType(type: Int): String {
        return when (type) {
            Entity.TYPE_PHONE -> "phone"
            Entity.TYPE_EMAIL -> "email"
            Entity.TYPE_URL -> "url"
            Entity.TYPE_ADDRESS -> "address"
            Entity.TYPE_DATE_TIME -> "datetime"
            Entity.TYPE_FLIGHT_NUMBER -> "flight_number"
            Entity.TYPE_IBAN -> "iban"
            Entity.TYPE_ISBN -> "isbn"
            Entity.TYPE_MONEY -> "money"
            Entity.TYPE_PAYMENT_CARD -> "payment_card"
            Entity.TYPE_TRACKING_NUMBER -> "tracking_number"
            else -> "unknown"
        }
    }

    private fun mapEntityMeta(entity: Entity): Map<String, Any> {
        val meta = mutableMapOf<String, Any>()

        when (entity.type) {
            Entity.TYPE_DATE_TIME -> {
                runCatching {
                    val dateTimeEntity = entity.asDateTimeEntity()
                    if (dateTimeEntity != null) {
                        meta["timestampMillis"] = dateTimeEntity.timestampMillis
                        meta["granularity"] = dateTimeEntity.dateTimeGranularity
                    }
                }
            }

            Entity.TYPE_MONEY -> {
                runCatching {
                    val money = entity.asMoneyEntity()
                    if (money != null) {
                        meta["currency"] = money.unnormalizedCurrency
                        meta["integerPart"] = money.integerPart
                        meta["fractionalPart"] = money.fractionalPart
                    }
                }
            }
        }

        return meta
    }

    private fun normalizeScript(script: String?): String {
        return script
            ?.trim()
            ?.lowercase(Locale.ROOT)
            ?.takeIf { it in SUPPORTED_SCRIPTS }
            ?: "latin"
    }

    companion object {
        private const val CHANNEL_NAME = "advanced_business_card_reader"
        private const val METHOD_OCR_FROM_FILE = "ocrFromFile"
        private const val METHOD_EXTRACT_ENTITIES = "extractEntities"

        private val SUPPORTED_SCRIPTS = setOf(
            "latin",
            "devanagari",
            "chinese",
            "japanese",
            "korean",
        )
    }
}
