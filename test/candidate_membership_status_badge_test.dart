import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/widgets/candidate_widgets.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

const now = '2026-07-31T08:00:00.000Z';
const future = '2026-08-30T08:00:00.000Z';
const past = '2026-07-30T08:00:00.000Z';

CandidateMembershipData activeMembership({bool isTest = false}) =>
    CandidateMembershipData(
      id: 'membership-1',
      status: 'active',
      startedAt: past,
      expiresAt: future,
      isTest: isTest,
    );

CandidateMembershipPresentation present(CandidateMembershipData membership) =>
    CandidateMembershipPresentation.resolve(
      membership,
      now: DateTime.parse(now),
    );

Future<void> pumpBadge(
  WidgetTester tester,
  CandidateMembershipData membership,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: CandidateMembershipBadge(membership: membership)),
      ),
    ),
  );
}

void main() {
  test('1 inactive membership resolves to inactive', () {
    expect(
      present(const CandidateMembershipData()).state,
      CandidateMembershipState.inactive,
    );
  });

  test('2 inactive membership offers activation', () {
    final presentation = present(const CandidateMembershipData());
    expect(presentation.primaryLabel, 'Membership inactive');
    expect(presentation.primaryActionLabel, 'Activate Membership');
  });

  testWidgets('3 inactive badge never claims Active Member', (tester) async {
    await pumpBadge(tester, const CandidateMembershipData());
    expect(find.text('Membership inactive'), findsOneWidget);
    expect(find.text('Active Member'), findsNothing);
  });

  test('4 paid active membership uses the active state', () {
    final presentation = present(activeMembership());
    final notStarted = present(
      const CandidateMembershipData(
        id: 'membership-2',
        status: 'active',
        startedAt: future,
        expiresAt: '2026-09-30T08:00:00.000Z',
      ),
    );
    expect(presentation.state, CandidateMembershipState.activePaid);
    expect(presentation.primaryLabel, 'Active Member');
    expect(presentation.secondaryLabel, isEmpty);
    expect(notStarted.state, CandidateMembershipState.pending);
    expect(notStarted.isActive, isFalse);
  });

  test('5 test membership is identified without replacing active status', () {
    final presentation = present(activeMembership(isTest: true));
    expect(presentation.state, CandidateMembershipState.activeTest);
    expect(presentation.primaryLabel, 'Active Member');
    expect(presentation.secondaryLabel, 'Test Membership');
  });

  testWidgets('6 raw test and internal labels are never displayed',
      (tester) async {
    await pumpBadge(
      tester,
      const CandidateMembershipData(
        id: 'membership-1',
        status: 'active',
        startedAt: past,
        expiresAt: future,
        planCode: 'test_paid_user',
        isTest: true,
      ),
    );
    expect(find.text('Active Member'), findsOneWidget);
    expect(find.text('Test Membership'), findsOneWidget);
    expect(find.textContaining('test_paid_user'), findsNothing);
  });

  test('7 elapsed active membership resolves to expired', () {
    final presentation = present(
      const CandidateMembershipData(
        id: 'membership-1',
        status: 'active',
        startedAt: '2026-06-01T08:00:00.000Z',
        expiresAt: past,
      ),
    );
    expect(presentation.state, CandidateMembershipState.expired);
    expect(presentation.primaryLabel, 'Membership expired');
  });

  test('8 expired membership offers renewal', () {
    final presentation = present(
      const CandidateMembershipData(id: 'membership-1', status: 'expired'),
    );
    expect(presentation.primaryActionLabel, 'Renew Membership');
  });

  testWidgets('9 expired badge never claims Active Member', (tester) async {
    await pumpBadge(
      tester,
      const CandidateMembershipData(id: 'membership-1', status: 'expired'),
    );
    expect(find.text('Membership expired'), findsOneWidget);
    expect(find.text('Active Member'), findsNothing);
  });

  test('10 candidate dashboard and Profile agree', () {
    const paths = [
      'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
      'lib/features/candidate/profile/candidate_profile_screen.dart',
    ];
    for (final path in paths) {
      expect(
        File(path).readAsStringSync(),
        contains('CandidateMembershipBadge'),
      );
    }
  });

  test('11 Edit Profile and Membership screen agree', () {
    const paths = [
      'lib/features/candidate/profile/edit_profile_screen.dart',
      'lib/features/candidate/membership/membership_plans_screen.dart',
    ];
    for (final path in paths) {
      expect(
          File(path).readAsStringSync(), contains('CandidateMembershipBadge'));
    }
  });

  test('12 badge persists after restart simulation', () {
    final first = present(activeMembership());
    final reconstructed = present(
      CandidateMembershipData.fromRow({
        'id': 'membership-1',
        'status': 'active',
        'started_at': past,
        'expires_at': future,
        'is_test': false,
      }),
    );
    expect(reconstructed.state, first.state);
    expect(reconstructed.detailLabel, first.detailLabel);
  });

  test('13 badge restores after logout and login simulation', () {
    final loggedInAgain = CandidateMembershipData.fromRow({
      'id': 'membership-1',
      'status': 'active',
      'started_at': past,
      'expires_at': future,
      'is_test': true,
    });
    expect(present(loggedInAgain).state, CandidateMembershipState.activeTest);
  });

  test('14 activation refreshes persisted membership status', () {
    final dashboard = File(
      'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/candidate/profile/candidate_profile_screen.dart',
    ).readAsStringSync();
    final membership = File(
      'lib/features/candidate/membership/membership_plans_screen.dart',
    ).readAsStringSync();
    for (final source in [dashboard, membership]) {
      expect(source, contains('await repository.activateTestMembership();'));
      expect(source, contains('_reload();'));
    }
    expect(dashboard, contains('AppLifecycleState.resumed'));
    expect(profile, contains('membershipFuture = repository.loadMembership()'));
    expect(profile, contains('membershipFuture,'));
  });

  test('15 eligibility messaging does not claim visibility incorrectly', () {
    final visible = CandidateMembershipPresentation.resolve(
      const CandidateMembershipData(),
      now: DateTime.parse(now),
      visibleToEmployers: true,
    );
    final hidden = CandidateMembershipPresentation.resolve(
      activeMembership(),
      now: DateTime.parse(now),
      visibleToEmployers: false,
      eligibilityMessage: 'Complete document verification first.',
    );
    expect(visible.visibilityMessage, contains('visible to employers'));
    expect(hidden.visibilityMessage, 'Complete document verification first.');
  });

  testWidgets('16 unknown state does not show an active badge', (tester) async {
    const failed = CandidateMembershipData(loadFailed: true);
    final presentation = present(failed);
    await pumpBadge(tester, failed);
    expect(presentation.state, CandidateMembershipState.unknown);
    expect(presentation.primaryActionLabel, 'Retry');
    expect(find.text('Membership status unavailable'), findsOneWidget);
    expect(find.text('Active Member'), findsNothing);
  });

  testWidgets('17 no payment-sensitive data is exposed', (tester) async {
    const membership = CandidateMembershipData(
      id: 'membership-1',
      status: 'active',
      startedAt: past,
      expiresAt: future,
      paymentProvider: 'raw_provider_secret',
      amount: 98765,
    );
    await pumpBadge(tester, membership);
    expect(find.textContaining('raw_provider_secret'), findsNothing);
    expect(find.textContaining('98765'), findsNothing);
  });

  testWidgets('18 badge exposes meaningful accessibility semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBadge(tester, activeMembership(isTest: true));
    final node = tester.getSemantics(find.byType(CandidateMembershipBadge));
    expect(node.label, contains('Membership status: Active Member'));
    expect(node.label, contains('Test Membership'));
    semantics.dispose();
  });
}
