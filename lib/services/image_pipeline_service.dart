import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ocr_config.dart';
import '../core/prefs.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/image_memory_analysis.dart';
import '../providers/app_providers.dart';
import '../models/memory.dart';
import '../providers/memory_notifier.dart';
import '../services/ai_service.dart';
import '../utils/photo_memo_format.dart';
import '../utils/photo_memory_format.dart';
import '../services/place_lookup_service.dart';
import '../services/recall_anchor_service.dart';
import '../services/local_memory_store.dart';
import '../utils/memory_id.dart';
import '../utils/ocr_utils.dart';
import '../utils/memory_image_memos.dart';
import '../utils/memory_image_paths.dart';
import 'memory_image_storage_service.dart';

const int thumbnailMaxSide = 320;
const int cardThumbMaxSide = 1080;
const int fullImageMaxSide = 4096;
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
1. photo_type: one of landscape|portrait|document|food|other
   - landscape: scenery, mountains, rivers, beaches, streets, bridges, travel without a clear single person focus
   - portrait: photo focused on one or more people (faces visible)
2. place_name: the primary place name in $langName — landmark, mountain, river, beach, street (e.g. 종성로, 월영교), building, or city/area. Use "" only if truly unknown.
3. landmarks: up to 4 specific place names visible or inferable (mountains, bridges, beaches, roads, tourist spots). $langName.
4. people_names: up to 4 person names if portrait or people are identifiable; use [] if none or unknown.
5. extracted_text: transcribe every visible sign/text exactly. Use "" if no text.
6. summary: one short sentence in $langName describing the scene (not the title).
7. entities: up to 6 short nouns for the graph — MUST include place_name and people_names when known; add brands/objects. Max 12 chars each.
8. category: Food|Social|Study|Work|Health|Travel|Finance|Other
9. sub_category: specific label in $langName (e.g. $subCategoryExamples)

Rules:
- For Korean travel photos, prefer real place names (산, 강, 교, 로, 해수욕장) in place_name and landmarks.
- Never use generic labels like "사진", "기기", "photo", "image".
- Never say you cannot see the image.''';

  final detail = visionQuality == OcrVisionQuality.high ? 'high' : 'low';
  final data = await AiService.instance.analyzeImageVision(
    jpegBytes: jpegBytes,
    prompt: prompt,
    detail: detail,
    maxTokens: visionQuality == OcrVisionQuality.high ? 2000 : 1200,
  );

  final extractedText = readVisionExtractedText(data);
  final parsed = ImageMemoryAnalysis.fromVisionMap(data);
  return ImageMemoryAnalysis(
    extractedText: extractedText,
    summary: parsed.summary,
    entities: sanitizeEntities(parsed.entities),
    category: parsed.category,
    subCategory: parsed.subCategory,
    photoType: parsed.photoType,
    placeName: parsed.placeName,
    peopleNames: sanitizeEntities(parsed.peopleNames),
    landmarks: sanitizeEntities(parsed.landmarks),
  );
}

Future<Memory?> savePhotoMemoryToStore({
  required WidgetRef ref,
  required PhotoMemoryFields fields,
  required Uint8List jpegBytes,
  Position? position,
  String userMemo = '',
  BuildContext? context,
  String? capturePlaceLabel,
  String localeCode = 'ko',
}) async {
  final prefs = ref.read(preferencesProvider);
  final localOnly = isLocalOnlyMode(
    prefs,
    privacyMode: ref.read(privacyLocalModeProvider),
    guestMode: ref.read(guestModeProvider),
  );

  List<double>? embedding;
  if (!localOnly) {
    try {
      embedding = await AiService.instance.createEmbedding(fields.content);
    } catch (e, stack) {
      debugPrint('Photo embedding failed: $e\n$stack');
    }
  }

  var draft = Memory(
    id: '',
    content: fields.content,
    summary: fields.summary,
    entities: fields.entities,
    createdAt: DateTime.now(),
    category: fields.category,
    subCategory: fields.subCategory,
    embedding: embedding,
    type: 'image',
    lat: position?.latitude,
    lng: position?.longitude,
    userMemo: userMemo.trim(),
  );

  if (context != null && context.mounted) {
    draft = await resolveRecallAnchorForMemory(
      context,
      draft,
      localeCode: localeCode,
      capturePlaceLabel: capturePlaceLabel,
    );
  } else {
    if (position != null) {
      draft = draft.copyWith(
        recallLat: position.latitude,
        recallLng: position.longitude,
        recallEnabled: true,
      );
    }
  }

  final saved = await ref.read(memoryListProvider.notifier).addMemory(draft);

  if (saved != null) {
    await appendMemoryImage(ref: ref, memoryId: saved.id, jpegBytes: jpegBytes, uploadIfCloud: !localOnly);
    if (userMemo.trim().isNotEmpty) {
      final prefs = ref.read(preferencesProvider);
      final memos = {...ref.read(memoryImageMemosProvider)};
      await setPhotoMemoAtIndex(prefs, memos, saved.id, 0, userMemo);
      ref.read(memoryImageMemosProvider.notifier).state = memos;
    }
  }
  return saved;
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

Uint8List? createCardThumbBytes(Uint8List jpegBytes) {
  return _encodeOcrJpegRequest(_OcrEncodeRequest(jpegBytes, cardThumbMaxSide, 88));
}

Uint8List? createFullImageBytes(Uint8List jpegBytes) {
  return _encodeOcrJpegRequest(_OcrEncodeRequest(jpegBytes, fullImageMaxSide, 92)) ?? jpegBytes;
}

Future<List<String>> _imageListForMemory(SharedPreferences prefs, String memoryId) async {
  final paths = readMemoryImagePaths(prefs);
  var list = List<String>.from(paths[memoryId] ?? const []);
  if (list.isEmpty) {
    final imagesDir = await getMemoryImagesDirectory();
    final legacy = File('${imagesDir.path}/$memoryId.jpg');
    if (await legacy.exists()) {
      list = [legacy.path];
    }
  }
  return list.where((p) => File(p).existsSync()).toList();
}

Future<String?> appendMemoryImage({
  required WidgetRef ref,
  required String memoryId,
  required Uint8List jpegBytes,
  bool uploadIfCloud = false,
}) async {
  await warmMemoryImagesDirectoryCache();
  final id = ensureMemoryId(memoryId);
  final cardThumb = createCardThumbBytes(jpegBytes);
  final fullBytes = createFullImageBytes(jpegBytes);
  if (cardThumb == null || fullBytes == null) return null;

  final prefs = ref.read(preferencesProvider);
  final imagesDir = await getMemoryImagesDirectory();
  final pathsMap = ref.read(memoryImagePathsProvider);
  final prefsList = List<String>.from(pathsMap[id] ?? const []);

  var index = prefsList.length;
  while (await File('${imagesDir.path}/${id}_$index.jpg').exists()) {
    index++;
  }

  final file = File('${imagesDir.path}/${id}_$index.jpg');
  final fullFile = File('${imagesDir.path}/${id}_${index}_full.jpg');
  await fullFile.writeAsBytes(fullBytes, flush: true);
  await file.writeAsBytes(cardThumb, flush: true);

  final updatedList = [...prefsList, file.path];
  final paths = {...pathsMap, id: updatedList};
  ref.read(memoryImagePathsProvider.notifier).state = paths;
  await saveMemoryImagePaths(prefs, paths);

  if (uploadIfCloud && index == 0) {
    await MemoryImageStorageService.instance.uploadThumbnail(id, jpegBytes);
  }
  return file.path;
}

Future<void> persistMemoryThumbnail({
  required WidgetRef ref,
  required String memoryId,
  required Uint8List jpegBytes,
}) async {
  await appendMemoryImage(ref: ref, memoryId: memoryId, jpegBytes: jpegBytes);
}

Future<bool> appendPhotoToExistingMemory({
  required WidgetRef ref,
  required String memoryId,
  required Uint8List jpegBytes,
  String additionalMemo = '',
}) async {
  final memories = ref.read(memoryListProvider);
  Memory? memory;
  for (final m in memories) {
    if (m.id == memoryId) {
      memory = m;
      break;
    }
  }
  if (memory == null) return false;

  final path = await appendMemoryImage(ref: ref, memoryId: memoryId, jpegBytes: jpegBytes);
  if (path == null) return false;

  final prefs = ref.read(preferencesProvider);
  final paths = ref.read(memoryImagePathsProvider);
  final photoIndex = resolvedImagePathsForMemoryId(memoryId, paths).length - 1;
  if (additionalMemo.trim().isNotEmpty) {
    final memos = {...ref.read(memoryImageMemosProvider)};
    await setPhotoMemoAtIndex(prefs, memos, memoryId, photoIndex, additionalMemo);
    ref.read(memoryImageMemosProvider.notifier).state = memos;
  }

  var updated = memory;
  if (additionalMemo.trim().isNotEmpty) {
    updated = mergeEntitiesFromPhotoMemo(updated, additionalMemo);
  }
  if (updated.type != 'image' && !isGraphAnchorMediaStorage(updated)) {
    updated = updated.copyWith(type: 'image');
  }
  if (updated != memory) {
    await ref.read(memoryListProvider.notifier).updateMemory(updated);
  }
  return true;
}

Future<bool> removePhotoAtIndex({
  required WidgetRef ref,
  required String memoryId,
  required int index,
}) async {
  final id = ensureMemoryId(memoryId);
  final prefs = ref.read(preferencesProvider);
  final photos = List<String>.from(resolvedImagePathsForMemoryId(id, ref.read(memoryImagePathsProvider)));
  if (index < 0 || index >= photos.length) return false;

  try {
    final file = File(photos[index]);
    if (await file.exists()) await file.delete();
  } catch (e) {
    debugPrint('Delete photo error: $e');
  }

  photos.removeAt(index);
  final paths = {...ref.read(memoryImagePathsProvider)};
  if (photos.isEmpty) {
    paths.remove(id);
  } else {
    paths[id] = photos;
  }
  ref.read(memoryImagePathsProvider.notifier).state = paths;
  await saveMemoryImagePaths(prefs, paths);

  final memos = {...ref.read(memoryImageMemosProvider)};
  final memoList = List<String>.from(memos[id] ?? const []);
  if (index < memoList.length) {
    memoList.removeAt(index);
    if (memoList.isEmpty) {
      memos.remove(id);
    } else {
      memos[id] = memoList;
    }
    ref.read(memoryImageMemosProvider.notifier).state = memos;
    await saveMemoryImageMemos(prefs, memos);
  }

  return true;
}

Future<void> deleteLocalMemoryImage(WidgetRef ref, String memoryId) async {
  final prefs = ref.read(preferencesProvider);
  final paths = ref.read(memoryImagePathsProvider);
  final list = [...(paths[memoryId] ?? const [])];
  final imagesDir = await getMemoryImagesDirectory();
  list.add('${imagesDir.path}/$memoryId.jpg');
  for (final path in list.toSet()) {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Delete local image error: $e');
    }
  }
  final updated = Map<String, List<String>>.from(paths)..remove(memoryId);
  ref.read(memoryImagePathsProvider.notifier).state = updated;
  await saveMemoryImagePaths(prefs, updated);

  final memos = Map<String, List<String>>.from(ref.read(memoryImageMemosProvider))..remove(memoryId);
  ref.read(memoryImageMemosProvider.notifier).state = memos;
  await saveMemoryImageMemos(prefs, memos);
}
