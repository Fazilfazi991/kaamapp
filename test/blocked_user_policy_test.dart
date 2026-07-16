import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('blocked user policy', () {
    test('blocked candidate cannot open candidate dashboard', () {
      final access = KaamAccountStatusPolicy.protectedAccess(
        actualRole: KaamRole.candidate,
        status: 'blocked',
        expectedRole: KaamRole.candidate,
      );

      expect(access, KaamProtectedAccess.blocked);
    });

    test('blocked employer cannot open employer dashboard', () {
      final access = KaamAccountStatusPolicy.protectedAccess(
        actualRole: KaamRole.employer,
        status: 'blocked',
        expectedRole: KaamRole.employer,
      );

      expect(access, KaamProtectedAccess.blocked);
    });

    test('blocked user is routed to sign-out capable blocked destination', () {
      expect(
        KaamAccountStatusPolicy.blockedDestination('blocked'),
        KaamAuthDestination.blocked,
      );
      expect(KaamAccountStatusPolicy.isBlocked('blocked'), isTrue);
    });

    test('blocked state is checked after session restore', () {
      final restoredSessionAccess = KaamAccountStatusPolicy.protectedAccess(
        actualRole: KaamRole.candidate,
        status: 'blocked',
        expectedRole: KaamRole.candidate,
      );

      expect(restoredSessionAccess, KaamProtectedAccess.blocked);
    });

    test('unblocked user can route normally', () {
      final access = KaamAccountStatusPolicy.protectedAccess(
        actualRole: KaamRole.employer,
        status: 'active',
        expectedRole: KaamRole.employer,
      );

      expect(access, KaamProtectedAccess.allowed);
      expect(KaamAccountStatusPolicy.blockedDestination('active'), isNull);
    });

    test('stale role state is cleared by denying wrong-role access', () {
      final access = KaamAccountStatusPolicy.protectedAccess(
        actualRole: KaamRole.candidate,
        status: 'active',
        expectedRole: KaamRole.employer,
      );

      expect(access, KaamProtectedAccess.wrongRole);
    });
  });
}
