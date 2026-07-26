import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/widgets/app_empty_state.dart';

void main() {
  testWidgets('AppEmptyState shows title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.inbox_outlined,
            title: '기억이 없습니다',
            subtitle: '마이크로 저장해 보세요',
          ),
        ),
      ),
    );

    expect(find.text('기억이 없습니다'), findsOneWidget);
    expect(find.text('마이크로 저장해 보세요'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });
}
