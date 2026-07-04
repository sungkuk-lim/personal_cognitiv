import 'dart:math' as math;

/// 관계망·기억 스레드와 동일한 의미 유사도 기준.
const double graphEmbeddingSimilarityThreshold = 0.55;

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}

bool embeddingsAreSimilar(
  List<double>? a,
  List<double>? b, {
  double threshold = graphEmbeddingSimilarityThreshold,
}) {
  if (a == null || b == null || a.isEmpty || b.isEmpty) return false;
  return cosineSimilarity(a, b) >= threshold;
}

List<double>? parseEmbedding(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) {
    return raw.map((e) => (e as num).toDouble()).toList();
  }
  return null;
}
