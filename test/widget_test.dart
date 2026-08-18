import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaam_perfect_match/app.dart';
import 'package:kaam_perfect_match/core/constants/app_routes.dart';
import 'package:kaam_perfect_match/core/remote_config/app_remote_config.dart';
import 'package:kaam_perfect_match/features/auth/account_access_screen.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  testWidgets('signed-out launch opens Welcome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(KaamApp(
      initialRoute: AppRoutes.welcome,
      remoteConfig: AppRemoteConfigService(),
    ));

    expect(find.text('Kaam'), findsOneWidget);
    expect(find.text('Perfect Match'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Find the right opportunity in the UAE'), findsNothing);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Account access'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('session gate routes a candidate to its resolved destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      routes: {
        AppRoutes.welcome: (_) => const Text('Welcome'),
        AppRoutes.dashboard: (_) => const Text('Candidate dashboard'),
      },
      home: SessionRoutingScreen(
        resolveDestination: () async => KaamAuthDestination.candidateDashboard,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Candidate dashboard'), findsOneWidget);
  });

  testWidgets('session gate routes an absent session to Welcome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      routes: {AppRoutes.welcome: (_) => const Text('Welcome')},
      home: SessionRoutingScreen(resolveDestination: () async => null),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
  });
}
