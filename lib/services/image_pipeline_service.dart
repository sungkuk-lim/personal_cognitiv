import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/ocr_config.dart';
import '../core/prefs.dart';
import '../models/image_memory_analysis.dart';
import '../providers/app_providers.dart';
import '../services/ai_service.dart';
import '../services/local_memory_store.dart';
import '../utils/memory_id.dart';
import '../utils/ocr_utils.dart';
import 'memory_image_storage_service.dart';

const int thumbnailMaxSide = 320;
const int mlKitMaxSide = 384;
const int computeMaxBytes = 800 * 1024;

class _OcrEncodeRequest {
  final Uint8List bytes;
  final int maxSide;
  final int jpegQuality;

  const _OcrEncodeRequest(this.bytes, this.maxSide, this.jpegQuality);
}

Uint8List? _encodeOcrJpegRequest(_OcrEncodeRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    if (request.bytes.length >= 2 && request.bytes[0] == 0xFF && request.bytes[1] == 0xD8) {
      return request.bytes;
    }
    return null;
  }

  final oriented = img.bakeOrientation(decoded);
  final maxSide = request.maxSide;
  final resized = oriented.width > maxSide || oriented.height > maxSide
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? maxSide : null,
          height: oriented.height > oriented.width ? maxSide : null,
        )
      : oriented;

  return Uint8List.fromList(img.encodeJpg(resized, quality: request.jpegQuality));
}

Future<Uint8List?> prepareOcrImageBytes(
  XFile image, {
  required int maxSide,
  int jpegQuality = 85,
}) async {
  late final Uint8List bytes;
  if (image.path.isNotEmpty) {
    final file = File(image.path);
    if (await file.exists()) {
      bytes = await file.readAsBytes();
    } else {
      bytes = await image.readAsBytes();
    }
  } else {
    bytes = await image.readAsBytes();
  }
  if (bytes.isEmpty) return null;

  final request = _OcrEncodeRequest(bytes, maxSide, jpegQuality);
  if (bytes.length > computeMaxBytes) {
    return _encodeOcrJpegRequest(request);
  }
  try {
    final encoded = await compute(_encodeOcrJpegRequest, request);
    return encoded ?? _encodeOcrJpegRequest(request);
  } catch (e) {
    debugPrint('Image encode isolate error: $e');
    return _encodeOcrJpegRequest(request);
  }
}

Future<String?> writeTempJpeg(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/mlkit_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> recognizeTextWithMlKit(String imagePath) async {
  if (!File(imagePath).existsSync()) return '';

  TextRecognizer? koreanRecognizer;
  TextRecognizer? fallbackRecognizer;
  try {
    koreanRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
    final koreanText = (await koreanRecognizer.processImage(InputImage.fromFilePath(imagePath))).text.trim();
    if (koreanText.isNotEmpty) return koreanText;
  } catch (e) {
    debugPrint('ML Kit Korean OCR error: $e');
  } finally {
    await koreanRecognizer?.close();
  }

  try {
    fallbackRecognizer = TextRecognizer();
    return (await fallbackRecognizer.processImage(InputImage.fromFilePath(imagePath))).text.trim();
  } catch (e) {
    debugPrint('ML Kit fallback OCR error: $e');
    return '';
  } finally {
    await fallbackRecognizer?.close();
  }
}

Future<ImageMemoryAnalysis> analyzeImageMemoryViaOpenAI({
  required Uint8List jpegBytes,
  required String localeCode,
  required OcrVisionQuality visionQuality,
}) async {
  final langName = localeCode == 'ko' ? 'Korean' : 'English';
  final subCategoryExamples = localeCode == 'ko'
      ? "'책 표지', '여행 사진', '친구와 식사', '명함', '영수증'"
      : "'Book Cover', 'Travel Photo', 'Meal with Friends', 'Business Card', 'Receipt'";
  final prompt = '''Analyze this photo and respond with JSON only.

Tasks:
1. extracted_text: transcribe every visible printed/handwritten character exactly. Use "" if there is no text (e.g. travel photos, friends, scenery).
2. summary: one short sentence in $langName describing the photo. For text photos summarize the text meaning; for scene photos describe who/where/what (friends, travel, food, etc.).
3. entities: up to 5 short nouns (max 12 characters each) — people, places, brands, landmarks, book titles. Use [] if none.
4. category: one of Food|Social|Study|Work|Health|Travel|Finance|Other
5. sub_category: a specific label in $langName (e.g. $subCategoryExamples)

Rules:
- Photos without text are valid — describe the scene in summary and pick Travel or Social when appropriate.
- Never say you cannot see, read, or access the image.
- extracted_text must be literal text only, not a description.''';

  final detail = visionQuality == OcrVisionQuality.high ? 'high' : 'low';
  final data = await AiService.instance.analyzeImageVision(
    jpegBytes: jpegBytes,
    prompt: prompt,
    detail: detail,
    maxTokens: visionQuality == OcrVisionQuality.high ? 2000 : 1200,
  );

  final extractedText = readVisionExtractedText(data);
  return ImageMemoryAnalysis(
    extractedText: extractedText,
    summary: (data['summary'] as String? ?? '').trim(),
    entities: sanitizeEntities(List<String>.from(data['entities'] ?? [])),
    category: data['category'] as String? ?? 'Other',
    subCategory: data['sub_category'] as String? ?? '',
  );
}

Future<Directory> getMemoryImagesDirectory() async {
  final dir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory('${dir.path}/memory_images');
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }
  return imagesDir;
}

Uint8List? createThumbnailBytes(Uint8List jpegBytes) {
  return _encodeOcrJpegRequest(_OcrEncodeRequest(jpegBytes, thumbnailMaxSide, 75));
}

Future<void> persistMemoryThumbnail({
  required WidgetRef ref,
  required String memoryId,
  required Uint8List jpegBytes,
}) async {
  final id = ensureMemoryId(memoryId);
  final thumbnail = createThumbnailBytes(jpegBytes);
  if (thumbnail == null) return;

  final imagesDir = await getMemoryImagesDirectory();
  final file = File('${imagesDir.path}/$id.jpg');
  await file.writeAsBytes(thumbnail, flush: true);

  final prefs = ref.read(preferencesProvider);
  final paths = {...ref.read(memoryImagePathsProvider), id: file.path};
  ref.read(memoryImagePathsProvider.notifier).state = paths;
  await saveMemoryImagePaths(prefs, paths);

  if (!readGuestMode(prefs) && !readPrivacyLocalMode(prefs)) {
    await MemoryImageStorageService.instance.uploadThumbnail(id, jpegBytes);
  }
}

Future<void> deleteLocalMemoryImage(WidgetRef ref, String memoryId) async {
  final paths = ref.read(memoryImagePathsProvider);
  final path = paths[memoryId];
  if (path != null) {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Delete local image error: $e');
    }
  }
  final updated = Map<String, String>.from(paths)..remove(memoryId);
  ref.read(memoryImagePathsProvider.notifier).state = updated;
  await saveMemoryImagePaths(ref.read(preferencesProvider), updated);
}
