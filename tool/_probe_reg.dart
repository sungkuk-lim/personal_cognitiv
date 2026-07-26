import "package:personal_cognitive/utils/graph_meaning.dart";
import "package:personal_cognitive/utils/voice_memory_format.dart";
import "package:personal_cognitive/utils/memory_entity_extract.dart";
import "package:personal_cognitive/models/memory.dart";
import "dart:io";

void main() {
  const text = "어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.";
  final composed = composeMemoryHubTitle(text, localeCode: "ko");
  final inferred = inferHubTitleFromContent(text);
  stdout.writeln("compose=$composed");
  stdout.writeln("infer=$inferred");
  final stale = Memory(id: "t", content: text, summary: "피자 삶아 먹음", entities: const [], createdAt: DateTime(2026, 7, 5));
  stdout.writeln("eventTitle=${extractMemoryEntities(stale, localeCode: "ko").eventTitle}");

  final fields = buildVoiceMemoryFields(
    speechText: "월영교에서 황해순이하고 놀러왔다. 바람이 너무시원해",
    capturedAt: DateTime(2026, 6, 16, 14, 30),
    localeCode: "ko",
    gpsPlace: "안동댐",
  );
  stdout.writeln("voice.summary=${fields.summary}");
  stdout.writeln("voice.entities=${fields.entities}");

  final merged = mergeVoiceFieldsWithAi(
    localFields: fields,
    aiData: {"summary": "시원한 바람", "entities": ["바람", "여행"], "category": "Travel", "sub_category": "야외"},
  );
  stdout.writeln("merged.summary=${merged.summary}");
  stdout.writeln("merged.entities=${merged.entities}");
}
