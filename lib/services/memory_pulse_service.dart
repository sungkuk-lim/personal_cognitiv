import '../features/graph/graph_chat_save.dart';
import '../features/replay/replay_insight_cards.dart';
import '../models/memory.dart';
import '../utils/memory_keyword_ui.dart';

enum MemoryPulseKind { onThisDay, personSpotlight }

/// 오늘의 기억 펄스 — 푸시·회상 탭용.
class MemoryPulseOffer {
  const MemoryPulseOffer({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.memories,
    this.yearsAgo = 0,
    this.entityLabel,
  });

  final MemoryPulseKind kind;
  final String title;
  final String subtitle;
  final List<Memory> memories;
  final int yearsAgo;
  final String? entityLabel;

  String get primaryMemoryId => memories.first.id;

  String notificationPayload() {
    return switch (kind) {
      MemoryPulseKind.onThisDay => 'pulse:today:${memories.first.id}',
      MemoryPulseKind.personSpotlight => 'pulse:entity:${entityLabel ?? ''}',
    };
  }
}

List<Memory> memoriesOnThisDay(List<Memory> all, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return all
      .where(isUserFacingMemory)
      .where((m) =>
          m.createdAt.month == today.month &&
          m.createdAt.day == today.day &&
          m.createdAt.year < today.year)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

MemoryPulseOffer? buildDailyMemoryPulse(
  List<Memory> allMemories, {
  DateTime? now,
  String localeCode = 'ko',
}) {
  final today = now ?? DateTime.now();
  final onThisDay = memoriesOnThisDay(allMemories, now: today);
  if (onThisDay.isNotEmpty) {
    final memory = onThisDay.first;
    final years = today.year - memory.createdAt.year;
    final title = localeCode == 'ko' ? '$years년 전 오늘' : '$years years ago today';
    final summary = memory.summary.trim().isNotEmpty ? memory.summary.trim() : memory.content.trim();
    final subtitle = summary.length > 80 ? '${summary.substring(0, 77)}…' : summary;
    return MemoryPulseOffer(
      kind: MemoryPulseKind.onThisDay,
      title: title,
      subtitle: subtitle,
      memories: onThisDay,
      yearsAgo: years,
    );
  }

  final cards = buildReplayInsightCards(
    allMemories.where(isUserFacingMemory).toList(),
    localeCode: localeCode,
    maxCards: 8,
  );
  for (final card in cards) {
    if (card.kind != ReplayInsightKind.person && card.kind != ReplayInsightKind.place) continue;
    final related = allMemories
        .where(isUserFacingMemory)
        .where((m) => memoryMatchesKeyword(m, card.focusKeyword))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (related.isEmpty) continue;
    final title = localeCode == 'ko' ? '「${card.title}」 하이라이트' : '"${card.title}" highlight';
    final subtitle = localeCode == 'ko'
        ? '함께한 기억 ${related.length}건 · 사진·동영상 몽타주'
        : '${related.length} memories · photo montage';
    return MemoryPulseOffer(
      kind: MemoryPulseKind.personSpotlight,
      title: title,
      subtitle: subtitle,
      memories: related,
      entityLabel: card.focusKeyword,
    );
  }

  return null;
}

bool parsePulsePayload(String payload, {required void Function(MemoryPulseKind kind, String? memoryId, String? entity) onParsed}) {
  if (!payload.startsWith('pulse:')) return false;
  final parts = payload.split(':');
  if (parts.length < 2) return false;
  if (parts[1] == 'today' && parts.length >= 3) {
    onParsed(MemoryPulseKind.onThisDay, parts[2], null);
    return true;
  }
  if (parts[1] == 'entity' && parts.length >= 3) {
    onParsed(MemoryPulseKind.personSpotlight, null, parts.sublist(2).join(':'));
    return true;
  }
  return false;
}
