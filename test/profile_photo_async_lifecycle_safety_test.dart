import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/storage/private_profile_photo_resolver.dart';
import 'package:kaam_perfect_match/core/widgets/private_profile_photo_avatar.dart';

void main() {
  const candidateId = '11111111-1111-4111-8111-111111111111';
  const firstPath = '$candidateId/candidate-profile-photos/first.jpg';
  const secondPath = '$candidateId/candidate-profile-photos/second.jpg';
  late String avatarSource;
  late String mediaSource;

  setUpAll(() {
    avatarSource = File(
      'lib/core/widgets/private_profile_photo_avatar.dart',
    ).readAsStringSync();
    mediaSource = File(
      'lib/features/candidate/onboarding/profile_media_screen.dart',
    ).readAsStringSync();
  });

  Widget avatarApp({
    required String path,
    required PrivateProfilePhotoResolve resolver,
    ValueNotifier<PrivateProfilePhotoChange?>? changes,
    Uint8List? localBytes,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PrivateProfilePhotoAvatar(
          path: path,
          candidateId: candidateId,
          initials: 'PE',
          resolvePhoto: resolver,
          photoChanges: changes,
          localBytes: localBytes,
        ),
      ),
    );
  }

  test('1 no setState closure returns a Future', () {
    expect(avatarSource, isNot(contains('setState(() async')));
    expect(avatarSource, isNot(contains('setState(() => _signedUrlFuture')));
    expect(mediaSource, isNot(contains('setState(() async')));
  });

  test('2 photo upload work happens outside setState', () {
    expect(mediaSource,
        contains('final upload = await storage.uploadPrivateFile'));
    expect(mediaSource,
        contains('final updated = await repository.updateProfilePhoto'));
    expect(
      RegExp(r'setState\s*\(\s*\(\)\s*async').hasMatch(mediaSource),
      isFalse,
    );
  });

  testWidgets('3 disposal during signed URL resolution is ignored', (
    tester,
  ) async {
    final pending = Completer<String>();
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        resolver: (_, {candidateId, forceRefresh = false}) => pending.future,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete('https://example.invalid/stale.jpg');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('4 disposal during upload has mounted guards on every failure path', () {
    expect(mediaSource, contains('if (!mounted) return;'));
    expect(
      RegExp(r'catch \([^)]*\) \{\s*setState', multiLine: true)
          .hasMatch(mediaSource),
      isFalse,
    );
  });

  testWidgets('5 Back navigation during photo resolution is safe', (
    tester,
  ) async {
    final pending = Completer<String>();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: PrivateProfilePhotoAvatar(
            path: firstPath,
            candidateId: candidateId,
            initials: 'PE',
            resolvePhoto: (_, {candidateId, forceRefresh = false}) =>
                pending.future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    pending.complete('https://example.invalid/stale.jpg');
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('6 Back stays available while upload callbacks are lifecycle-safe', () {
    expect(mediaSource, isNot(contains('PopScope(')));
    expect(mediaSource, contains('if (!mounted) return;'));
    expect(mediaSource, contains('uploadingPhoto = false'));
  });

  testWidgets('7 resolver listener is inactive after dispose', (tester) async {
    final changes = ValueNotifier<PrivateProfilePhotoChange?>(null);
    final pending = Completer<String>();
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        changes: changes,
        resolver: (_, {candidateId, forceRefresh = false}) => pending.future,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    changes.value = const PrivateProfilePhotoChange(
      previousPath: firstPath,
      nextPath: secondPath,
      revision: 1,
    );
    await tester.pump();
    pending.complete('');
    await tester.pump();
    expect(tester.takeException(), isNull);
    changes.dispose();
  });

  test('8 lifecycle observer is removed in dispose', () {
    expect(avatarSource, contains('WidgetsBinding.instance.addObserver(this)'));
    expect(
        avatarSource, contains('WidgetsBinding.instance.removeObserver(this)'));
    expect(
        avatarSource, contains('_changes.removeListener(_handlePhotoChange)'));
  });

  testWidgets('9 old resolution is ignored after path change', (tester) async {
    final first = Completer<String>();
    final second = Completer<String>();
    Future<String> resolver(
      String path, {
      String? candidateId,
      bool forceRefresh = false,
    }) =>
        path == firstPath ? first.future : second.future;
    await tester.pumpWidget(avatarApp(path: firstPath, resolver: resolver));
    await tester.pumpWidget(avatarApp(path: secondPath, resolver: resolver));
    first.complete('https://example.invalid/old.jpg');
    await tester.pump();
    expect(find.text('PE'), findsOneWidget);
    second.complete('');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('10 old resolution is ignored after photo removal', (
    tester,
  ) async {
    final changes = ValueNotifier<PrivateProfilePhotoChange?>(null);
    final pending = Completer<String>();
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        changes: changes,
        resolver: (_, {candidateId, forceRefresh = false}) => pending.future,
      ),
    );
    changes.value = const PrivateProfilePhotoChange(
      previousPath: firstPath,
      nextPath: '',
      revision: 2,
    );
    await tester.pump();
    pending.complete('https://example.invalid/removed.jpg');
    await tester.pump();
    expect(find.text('PE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    changes.dispose();
  });

  test('11 image retry is single-flight and capped at one', () {
    expect(avatarSource, contains('_retriedAfterImageError'));
    expect(avatarSource, contains('_retryInFlight'));
    expect(avatarSource, contains('if (_retriedAfterImageError ||'));
  });

  testWidgets('12 pending retry cannot update after dispose', (tester) async {
    final pending = Completer<String>();
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        resolver: (_, {candidateId, forceRefresh = false}) => pending.future,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.completeError(StateError('expired'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('13 replacement broadcast ignores disposed avatars', (
    tester,
  ) async {
    final changes = ValueNotifier<PrivateProfilePhotoChange?>(null);
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        changes: changes,
        resolver: (_, {candidateId, forceRefresh = false}) async => '',
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    changes.value = const PrivateProfilePhotoChange(
      previousPath: firstPath,
      nextPath: secondPath,
      revision: 3,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    changes.dispose();
  });

  testWidgets('14 removal broadcast ignores disposed avatars', (tester) async {
    final changes = ValueNotifier<PrivateProfilePhotoChange?>(null);
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        changes: changes,
        resolver: (_, {candidateId, forceRefresh = false}) async => '',
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    changes.value = const PrivateProfilePhotoChange(
      previousPath: firstPath,
      nextPath: '',
      revision: 4,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    changes.dispose();
  });

  testWidgets('15 local preview renders before remote resolution completes', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    var resolverCalls = 0;
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        localBytes: bytes,
        resolver: (_, {candidateId, forceRefresh = false}) async {
          resolverCalls++;
          return '';
        },
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(resolverCalls, 1);
    expect(tester.takeException(), isNull);
  });

  test('16 upload failure restores the previous local preview', () {
    expect(mediaSource, contains('final previousLocalBytes = localPhotoBytes'));
    expect(mediaSource, contains('localPhotoBytes = previousLocalBytes'));
    expect(mediaSource, contains('We could not upload your profile photo'));
  });

  testWidgets('17 resolution failure shows initials instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        resolver: (_, {candidateId, forceRefresh = false}) =>
            Future<String>.error(StateError('signing failed')),
      ),
    );
    await tester.pump();
    expect(find.text('PE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('18 rapid replacement followed by Back does not throw', (
    tester,
  ) async {
    final changes = ValueNotifier<PrivateProfilePhotoChange?>(null);
    final pending = Completer<String>();
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        changes: changes,
        resolver: (_, {candidateId, forceRefresh = false}) => pending.future,
      ),
    );
    changes.value = const PrivateProfilePhotoChange(
      previousPath: firstPath,
      nextPath: secondPath,
      revision: 5,
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete('');
    await tester.pump();
    expect(tester.takeException(), isNull);
    changes.dispose();
  });

  testWidgets('19 avatar can reopen after a failed resolution', (tester) async {
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        resolver: (_, {candidateId, forceRefresh = false}) =>
            Future<String>.error(StateError('failed')),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        resolver: (_, {candidateId, forceRefresh = false}) async => '',
      ),
    );
    await tester.pump();
    expect(find.text('PE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('20 framework errors are never rendered by the avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      avatarApp(
        path: firstPath,
        resolver: (_, {candidateId, forceRefresh = false}) async => '',
      ),
    );
    await tester.pump();
    expect(find.textContaining('setState() callback argument'), findsNothing);
    expect(find.textContaining('_dependents.isEmpty'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
