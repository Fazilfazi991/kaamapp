import 'package:flutter_test/flutter_test.dart';

import 'package:kaam_perfect_match/app.dart';

void main() {
  testWidgets('Kaam always opens welcome before journey selection',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KaamApp());

    expect(find.text('Kaam'), findsOneWidget);
    expect(find.text('Perfect Match'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Find the right opportunity in the UAE'), findsNothing);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text("Let's start your journey"), findsOneWidget);
    expect(find.text('KAAM'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
  });
}
