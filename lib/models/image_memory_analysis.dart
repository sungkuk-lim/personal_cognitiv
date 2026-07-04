import '../utils/ocr_utils.dart';

class ImageMemoryAnalysis {
  final String extractedText;
  final String summary;
  final List<String> entities;
  final String category;
  final String subCategory;
  final String photoType;
  final String placeName;
  final List<String> peopleNames;
  final List<String> landmarks;

  const ImageMemoryAnalysis({
    required this.extractedText,
    required this.summary,
    required this.entities,
    required this.category,
    required this.subCategory,
    this.photoType = 'other',
    this.placeName = '',
    this.peopleNames = const [],
    this.landmarks = const [],
  });

  factory ImageMemoryAnalysis.fromVisionMap(Map<String, dynamic> data) {
    return ImageMemoryAnalysis(
      extractedText: readVisionExtractedText(data),
      summary: (data['summary'] as String? ?? '').trim(),
      entities: List<String>.from(data['entities'] ?? []),
      category: data['category'] as String? ?? 'Other',
      subCategory: (data['sub_category'] as String? ?? data['subCategory'] as String? ?? '').trim(),
      photoType: (data['photo_type'] as String? ?? 'other').trim().toLowerCase(),
      placeName: (data['place_name'] as String? ?? '').trim(),
      peopleNames: List<String>.from(data['people_names'] ?? data['peopleNames'] ?? []),
      landmarks: List<String>.from(data['landmarks'] ?? []),
    );
  }
}

String readVisionExtractedText(Map<String, dynamic> data) {
  for (final key in ['extracted_text', 'extractedText', 'text', 'ocr_text']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String resolveImageMemoryContent(ImageMemoryAnalysis analysis) {
  if (hasPhotoMemoryPayload(analysis)) {
    for (final candidate in [analysis.extractedText, analysis.summary, analysis.placeName]) {
      final value = candidate.trim();
      if (value.isNotEmpty && !isJunkOcrMetaResponse(value)) return value;
    }
    if (analysis.landmarks.isNotEmpty) return analysis.landmarks.first;
  }
  for (final candidate in [analysis.extractedText, analysis.summary]) {
    final value = candidate.trim();
    if (value.isNotEmpty && !isJunkOcrMetaResponse(value)) return value;
  }
  return '';
}

bool hasPhotoMemoryPayload(ImageMemoryAnalysis analysis) {
  if (analysis.extractedText.trim().isNotEmpty) return true;
  if (analysis.summary.trim().isNotEmpty && !isJunkOcrMetaResponse(analysis.summary)) return true;
  if (analysis.placeName.trim().isNotEmpty) return true;
  if (analysis.landmarks.isNotEmpty) return true;
  if (analysis.peopleNames.isNotEmpty) return true;
  return false;
}
