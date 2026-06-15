import '../utils/ocr_utils.dart';

class ImageMemoryAnalysis {
  final String extractedText;
  final String summary;
  final List<String> entities;
  final String category;
  final String subCategory;

  const ImageMemoryAnalysis({
    required this.extractedText,
    required this.summary,
    required this.entities,
    required this.category,
    required this.subCategory,
  });
}

String readVisionExtractedText(Map<String, dynamic> data) {
  for (final key in ['extracted_text', 'extractedText', 'text', 'ocr_text']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String resolveImageMemoryContent(ImageMemoryAnalysis analysis) {
  for (final candidate in [analysis.extractedText, analysis.summary]) {
    final value = candidate.trim();
    if (value.isNotEmpty && !isJunkOcrMetaResponse(value)) return value;
  }
  return '';
}
