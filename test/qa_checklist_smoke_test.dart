import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_event_layout.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/features/legal/legal_document_screen.dart';
import 'package:personal_cognitive/features/timeline/memory_timeline.dart';
import 'package:personal_cognitive/l10n/translations.dart' as l10n;
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/providers/app_providers.dart';
import 'package:personal_cognitive/providers/memory_notifier.dart';
import 'package:personal_cognitive/services/connectivity_service.dart';
import 'package:personal_cognitive/services/local_memory_store.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_content_edit.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';
import 'package:personal_cognitive/utils/memory_theme_tags.dart';
import 'package:personal_cognitive/widgets/network_status_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA_CHECKLIST.md 미체크 항목 — 자동 검증 (2026-07-06).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  group('P0 편집→관계망 신뢰', () {
    test('본문 편집 후 철수 제거·민수 반영', () {
      var memory = Memory(
        id: 'qa_edit',
        content: '철수와 카페에서 이야기',
        summary: '카페',
        entities: ['철수', '카페'],
        createdAt: DateTime(2026, 6, 10),
        isLocalOnly: true,
      );
      memory = applyMemoryContentEdit(
        memory: memory,
        newMainText: '민수와 카페에서 이야기',
        previousBodyText: '철수와 카페에서 이야기',
        graphMarkerLabel: '관계망',
      );
      memory = enrichMemoryGraphSemantics(memory, localeCode: 'ko');
      final visible = userVisibleEntityLabels(memory);
      expect(visible, contains('민수'));
      expect(visible, contains('카페'));
      expect(visible, isNot(contains('철수')));

      final layout = buildEventGraphLayout([memory], localeCode: 'ko');
      expect(layout.nodes.where((n) => n.title == '철수'), isEmpty);
      expect(layout.nodes.any((n) => n.title.contains('민수') || n.title.contains('카페')), isTrue);
    });
  });

  group('검색·로컬', () {
    test('searchLocalMemories 키워드 응답', () {
      final memories = [
        Memory(
          id: '1',
          content: '민수와 카페에서 이야기',
          summary: '카페',
          entities: ['민수', '카페'],
          createdAt: DateTime(2026, 6, 1),
          isLocalOnly: true,
        ),
      ];
      final hits = searchLocalMemories(memories, '민수');
      expect(hits, isNotEmpty);
      expect(hits.first.content, contains('민수'));
    });
  });

  group('UI 구성요소', () {
    testWidgets('타임라인 RefreshIndicator 존재', (tester) async {
      SharedPreferences.setMockInitialValues({
        'guest_mode': true,
        'onboarding_complete': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final sample = Memory(
        id: 'qa1',
        content: '테스트 기억',
        summary: '테스트',
        entities: const [],
        createdAt: DateTime(2026, 6, 1),
        isLocalOnly: true,
      );
      await LocalMemoryStore(prefs).saveAll([sample]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: MemoryTimeline())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('오프라인 배너 표시', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
            translationsProvider.overrideWith((ref) => l10n.translationsData['ko']!),
          ],
          child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
        ),
      );
      await tester.pump();
      expect(find.textContaining('오프라인'), findsOneWidget);
    });

    test('법적 문서 에셋 로드', () async {
      await rootBundle.load(LegalDocumentScreen.privacyAsset);
      await rootBundle.load(LegalDocumentScreen.termsAsset);
    });
  });
}
