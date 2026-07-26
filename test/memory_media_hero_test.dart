import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/memory/memory_media_hero.dart';

void main() {
  testWidgets('MemoryMediaHeroImage handles infinite width without crashing', (tester) async {
    // 전체화면 뷰어는 width: double.infinity 를 넘긴다. cacheWidth 계산에서
    // double.infinity.round() 예외가 나면 흰 배경만 보이므로 회귀 방지.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MemoryMediaHeroImage(
              memoryId: 'm1',
              photoIndex: 0,
              path: '/nonexistent/photo.jpg',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              useHero: false,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(MemoryMediaHeroImage), findsOneWidget);
  });
}
