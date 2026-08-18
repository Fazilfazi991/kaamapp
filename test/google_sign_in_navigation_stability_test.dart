import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/constants/app_routes.dart';
import 'package:kaam_perfect_match/features/auth/login_screen.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: 'QA_MODE=false');

  const candidateResult = KaamGoogleSignInResult.success(
    KaamAuthRouteResult(
      destination: KaamAuthDestination.candidateDashboard,
      message: 'candidate',
    ),
  );
  const employerResult = KaamGoogleSignInResult.success(
    KaamAuthRouteResult(
      destination: KaamAuthDestination.employerDashboard,
      message: 'employer',
    ),
  );
  const setupResult = KaamGoogleSignInResult.success(
    KaamAuthRouteResult(
      destination: KaamAuthDestination.roleSelection,
      message: 'setup',
    ),
  );

  Future<void> pumpLogin(
    WidgetTester tester,
    Future<KaamGoogleSignInResult> Function() signIn, {
    NavigatorObserver? observer,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        home: LoginScreen(googleSignIn: signIn),
        routes: {
          AppRoutes.dashboard: (_) => const _Destination('candidate'),
          AppRoutes.employerDashboard: (_) => const _Destination('employer'),
          AppRoutes.roleSelection: (_) => const _Destination('setup'),
        },
      ),
    );
  }

  Finder googleButton() => find.widgetWithText(
        OutlinedButton,
        'Continue with Google',
      );

  group('Google sign-in navigation stability', () {
    testWidgets('1 Google button disables during sign-in', (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      await pumpLogin(tester, () => pending.future);

      await tester.tap(googleButton());
      await tester.pump();

      expect(find.text('Signing in…'), findsOneWidget);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
    });

    testWidgets('2 repeated taps create one sign-in attempt', (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      var attempts = 0;
      await pumpLogin(tester, () {
        attempts++;
        return pending.future;
      });

      await tester.tap(googleButton());
      await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
      await tester.pump();

      expect(attempts, 1);
    });

    testWidgets('3 cancellation keeps the login screen rendered',
        (tester) async {
      await pumpLogin(
        tester,
        () async => const KaamGoogleSignInResult.cancelled(),
      );

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(find.text('Continue to KAAM'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('4 cancellation clears the loading state', (tester) async {
      await pumpLogin(
        tester,
        () async => const KaamGoogleSignInResult.cancelled(),
      );
      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(find.text('Signing in…'), findsNothing);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull);
    });

    testWidgets(
        '5 Android Back cannot pop Flutter login while picker is active',
        (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const _Destination('under-login'),
          routes: {
            AppRoutes.login: (_) =>
                LoginScreen(googleSignIn: () => pending.future),
          },
        ),
      );
      navigatorKey.currentState!.pushNamed(AppRoutes.login);
      await tester.pumpAndSettle();
      await tester.tap(googleButton());
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Continue to KAAM'), findsOneWidget);
      expect(find.text('under-login'), findsNothing);
    });

    testWidgets('6 successful sign-in navigates exactly once', (tester) async {
      final observer = _CountingNavigatorObserver();
      await pumpLogin(tester, () async => candidateResult, observer: observer);

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(find.text('candidate'), findsOneWidget);
      expect(observer.replacements, 1);
    });

    test('7 auth listeners cannot independently navigate after callback', () {
      final loginSource = File(
        'lib/features/auth/login_screen.dart',
      ).readAsStringSync();
      final pushSource = File(
        'lib/features/notifications/push_notification_service.dart',
      ).readAsStringSync();
      expect(loginSource, contains('navigationCommitted'));
      expect(loginSource, contains('googleResolutionGeneration'));
      expect(loginSource, contains('duplicate_navigation_suppressed'));
      expect(pushSource, isNot(contains('pushReplacementNamed')));
      expect(pushSource, isNot(contains('pushNamedAndRemoveUntil')));
    });

    testWidgets('8 candidate resolves to the candidate destination',
        (tester) async {
      await pumpLogin(tester, () async => candidateResult);
      await tester.tap(googleButton());
      await tester.pumpAndSettle();
      expect(find.text('candidate'), findsOneWidget);
      expect(find.text('employer'), findsNothing);
    });

    testWidgets('9 employer resolves to the employer destination',
        (tester) async {
      await pumpLogin(tester, () async => employerResult);
      await tester.tap(googleButton());
      await tester.pumpAndSettle();
      expect(find.text('employer'), findsOneWidget);
      expect(find.text('candidate'), findsNothing);
    });

    testWidgets('10 missing role routes safely to account setup',
        (tester) async {
      await pumpLogin(tester, () async => setupResult);
      await tester.tap(googleButton());
      await tester.pumpAndSettle();
      expect(find.text('setup'), findsOneWidget);
    });

    testWidgets('11 network failure shows a safe error', (tester) async {
      await pumpLogin(
        tester,
        () async => const KaamGoogleSignInResult.failure(
          KaamGoogleSignInOutcome.networkFailure,
        ),
      );
      await tester.tap(googleButton());
      await tester.pump();
      expect(
          find.text(KaamSafeErrorMessages.googleSignInFailure), findsOneWidget);
    });

    testWidgets('12 raw Google or Supabase exceptions are never displayed',
        (tester) async {
      const rawSecret = 'AuthException: token=raw-secret-value';
      await pumpLogin(tester, () => Future.error(StateError(rawSecret)));
      await tester.tap(googleButton());
      await tester.pump();
      expect(find.textContaining(rawSecret), findsNothing);
      expect(
          find.text(KaamSafeErrorMessages.googleSignInFailure), findsOneWidget);
    });

    testWidgets('13 delayed callback after disposal does not navigate',
        (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      await pumpLogin(tester, () => pending.future);
      await tester.tap(googleButton());
      await tester.pump();
      await tester
          .pumpWidget(const MaterialApp(home: _Destination('disposed')));

      pending.complete(candidateResult);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('disposed'), findsOneWidget);
    });

    testWidgets('14 no loading overlay or dialog is left behind',
        (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      await pumpLogin(tester, () => pending.future);
      await tester.tap(googleButton());
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
      final loginSource = File(
        'lib/features/auth/login_screen.dart',
      ).readAsStringSync();
      expect(loginSource, isNot(contains('showDialog')));
      expect(find.text('Continue to KAAM'), findsOneWidget);
    });

    testWidgets('15 app resume does not restart sign-in', (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      var attempts = 0;
      await pumpLogin(tester, () {
        attempts++;
        return pending.future;
      });
      await tester.tap(googleButton());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(attempts, 1);
    });

    test('16 an old Supabase session is cleared before account selection', () {
      final backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      final methodStart = backendSource.indexOf('signInWithGoogle() async');
      final pickerStart = backendSource.indexOf('google.signIn()', methodStart);
      final beforePicker = backendSource.substring(methodStart, pickerStart);
      expect(beforePicker, contains('_client.auth.currentUser != null'));
      expect(beforePicker, contains('await signOut()'));
    });

    testWidgets('17 state resets after every non-success terminal outcome',
        (tester) async {
      final outcomes = <KaamGoogleSignInResult>[
        const KaamGoogleSignInResult.cancelled(),
        for (final outcome in KaamGoogleSignInOutcome.values)
          if (outcome != KaamGoogleSignInOutcome.success &&
              outcome != KaamGoogleSignInOutcome.cancelled)
            KaamGoogleSignInResult.failure(outcome),
      ];
      for (final outcome in outcomes) {
        await pumpLogin(tester, () async => outcome);
        await tester.tap(googleButton());
        await tester.pump();
        expect(find.text('Signing in…'), findsNothing,
            reason: outcome.outcome.name);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull,
          reason: outcome.outcome.name,
        );
      }
    });

    testWidgets('18 loading pushes no blank or temporary route',
        (tester) async {
      final pending = Completer<KaamGoogleSignInResult>();
      final observer = _CountingNavigatorObserver();
      await pumpLogin(tester, () => pending.future, observer: observer);
      final pushesBefore = observer.pushes;

      await tester.tap(googleButton());
      await tester.pump();

      expect(observer.pushes, pushesBefore);
      expect(observer.replacements, 0);
      expect(find.text('Continue to KAAM'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

class _Destination extends StatelessWidget {
  const _Destination(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;
  int replacements = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
