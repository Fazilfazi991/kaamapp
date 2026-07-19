import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('auth session switching policy', () {
    tearDown(KaamAuthSessionCoordinator.resetForTesting);

    test('Account A logout clears pending OTP and explicit logout state',
        () async {
      KaamAuthSessionCoordinator.setPendingOtp(
        email: 'candidate@example.com',
        role: KaamRole.candidate,
      );

      await KaamAuthSessionCoordinator.beginExplicitLogout();
      KaamAuthSessionCoordinator.finishExplicitLogout();

      expect(KaamAuthSessionCoordinator.pendingOtp, isNull);
      expect(KaamAuthSessionCoordinator.explicitLogoutInProgress, isFalse);
    });

    test('Account B login invalidates Account A user-scoped state', () {
      KaamAuthSessionCoordinator.markAuthenticatedUser('account-a');
      KaamAuthSessionCoordinator.setPendingOtp(
        email: 'candidate@example.com',
        role: KaamRole.candidate,
      );

      KaamAuthSessionCoordinator.markAuthenticatedUser('account-b');

      expect(KaamAuthSessionCoordinator.pendingOtp, isNull);
    });

    test('same user ID does not clear current pending OTP state', () {
      KaamAuthSessionCoordinator.markAuthenticatedUser('account-a');
      KaamAuthSessionCoordinator.setPendingOtp(
        email: 'candidate@example.com',
        role: KaamRole.candidate,
      );

      KaamAuthSessionCoordinator.markAuthenticatedUser('account-a');

      expect(KaamAuthSessionCoordinator.pendingOtp?.role, KaamRole.candidate);
    });

    test('different entered email starts OTP instead of restoring old session',
        () {
      expect(
        KaamAuthSessionPolicy.shouldStartOtpForEnteredEmail(
          hasCurrentSession: true,
          enteredEmail: 'account-b@example.com',
          currentSessionEmail: 'account-a@example.com',
        ),
        isTrue,
      );
    });

    test('same entered email can continue existing session', () {
      expect(
        KaamAuthSessionPolicy.shouldStartOtpForEnteredEmail(
          hasCurrentSession: true,
          enteredEmail: 'USER@example.com',
          currentSessionEmail: 'user@example.com',
        ),
        isFalse,
      );
    });

    test('candidate logout then employer login should use employer pending OTP',
        () {
      KaamAuthSessionCoordinator.markAuthenticatedUser('candidate-a');
      KaamAuthSessionCoordinator.clearUserScopedState();
      KaamAuthSessionCoordinator.setPendingOtp(
        email: 'employer@example.com',
        role: KaamRole.employer,
      );

      expect(KaamAuthSessionCoordinator.pendingOtp?.role, KaamRole.employer);
    });

    test(
        'employer logout then candidate login should use candidate pending OTP',
        () {
      KaamAuthSessionCoordinator.markAuthenticatedUser('employer-a');
      KaamAuthSessionCoordinator.clearUserScopedState();
      KaamAuthSessionCoordinator.setPendingOtp(
        email: 'candidate@example.com',
        role: KaamRole.candidate,
      );

      expect(KaamAuthSessionCoordinator.pendingOtp?.role, KaamRole.candidate);
    });

    test('existing candidate choosing employer shows role mismatch copy', () {
      expect(
        KaamAuthSessionPolicy.roleMismatchMessage(
          actualRole: KaamRole.candidate,
          requestedRole: KaamRole.employer,
        ),
        contains('Continue with Find Work or use another account'),
      );
    });

    test('existing employer choosing candidate shows role mismatch copy', () {
      expect(
        KaamAuthSessionPolicy.roleMismatchMessage(
          actualRole: KaamRole.employer,
          requestedRole: KaamRole.candidate,
        ),
        contains('Continue with Hire Talent or use another account'),
      );
    });
  });

  group('shared profile bootstrap and login resolution', () {
    late final String backendSource;
    late final String bootstrapSql;

    setUpAll(() {
      backendSource = File('lib/features/supabase_backend/kaam_backend.dart')
          .readAsStringSync();
      bootstrapSql =
          File('supabase/018_bootstrap_user_profile.sql').readAsStringSync();
    });

    test('new candidate and employer flows bootstrap by auth user ID', () {
      expect(backendSource, contains("rpc('bootstrap_user_profile'"));
      expect(bootstrapSql, contains('v_user_id uuid := auth.uid()'));
      expect(bootstrapSql,
          contains("selected_role not in ('candidate', 'employer')"));
      expect(bootstrapSql, contains("'active'::public.profile_status"));
      expect(bootstrapSql, contains('insert into public.profiles'));
      expect(bootstrapSql, contains('on conflict (id) do nothing'));
    });

    test('profile lookup uses profiles.id, not email ownership matching', () {
      final authRepositoryStart =
          backendSource.indexOf('class KaamAuthRepository');
      final authRepositoryEnd =
          backendSource.indexOf('class QaToolsRepository');
      final authRepositorySource =
          backendSource.substring(authRepositoryStart, authRepositoryEnd);

      expect(authRepositorySource, contains(".eq('id', user.id)"));
      expect(authRepositorySource, isNot(contains(".eq('email'")));
    });

    test('login with missing profile enters recoverable role selection', () {
      expect(
        KaamMissingProfileRecovery.message,
        contains('profile setup is incomplete'),
      );
      expect(backendSource, contains('KaamMissingProfileRecovery.message'));
      expect(backendSource,
          isNot(contains('We could not find a KAAM profile for this email')));
    });

    test('existing account role cannot be silently changed by bootstrap', () {
      expect(bootstrapSql, contains('if v_existing.role <> v_role then'));
      expect(bootstrapSql,
          contains('Existing KAAM profile uses a different role'));
      expect(
          backendSource,
          isNot(contains(
              'await signOut();\n        throw KaamRoleMismatchException')));
    });

    test('session remains valid during missing-profile recovery', () {
      final missingProfileBlockStart =
          backendSource.indexOf('if (existingProfile == null)');
      final missingProfileBlock = backendSource.substring(
        missingProfileBlockStart,
        backendSource.indexOf('await bootstrapProfile(role: role);'),
      );

      expect(
          missingProfileBlock, contains('KaamMissingProfileRecovery.message'));
      expect(missingProfileBlock, isNot(contains('signOut')));
    });
  });

  group('OTP route and navigation source guards', () {
    test('OTP route is registered as a public app route', () {
      final appSource = File('lib/app.dart').readAsStringSync();
      final employerRoutes =
          File('lib/features/employer/employer_routes.dart').readAsStringSync();

      expect(appSource,
          contains('AppRoutes.otp: (_) => const OtpVerificationScreen()'));
      expect(employerRoutes,
          contains('AppRoutes.employerOtp: (_) => const EmployerOtpScreen()'));
      expect(appSource, isNot(contains('AppRoutes.otp: (_) => _candidate')));
      expect(employerRoutes,
          isNot(contains('AppRoutes.employerOtp: (_) => _employer')));
    });

    test('OTP request success uses replacement navigation to OTP screen', () {
      final candidateLogin =
          File('lib/features/auth/login_screen.dart').readAsStringSync();
      final employerLogin =
          File('lib/features/employer/auth/employer_auth_screens.dart')
              .readAsStringSync();

      expect(candidateLogin, contains('pushReplacementNamed'));
      expect(candidateLogin, contains('AppRoutes.otp'));
      expect(candidateLogin,
          isNot(contains('pushNamedAndRemoveUntil(\n              _routeFor')));
      expect(employerLogin, contains('pushReplacementNamed'));
      expect(employerLogin, contains('AppRoutes.employerOtp'));
      expect(employerLogin, isNot(contains('_routeForSession')));
    });

    test('OTP verification failure remains on OTP screen', () {
      final otpSource = File('lib/features/auth/otp_verification_screen.dart')
          .readAsStringSync();
      final employerOtpSource =
          File('lib/features/employer/auth/employer_auth_screens.dart')
              .readAsStringSync();

      expect(otpSource, contains('We could not verify that code'));
      expect(
          otpSource,
          isNot(contains(
              'catch (_) {\n      if (!mounted) return;\n      Navigator')));
      expect(employerOtpSource, contains('We could not verify that code'));
      expect(
          employerOtpSource,
          isNot(contains(
              'catch (_) {\n      if (!mounted) return;\n      Navigator')));
    });

    test('push-device registration moves by FCM token upsert', () {
      final repository =
          File('lib/features/notifications/notification_repository.dart')
              .readAsStringSync();

      expect(repository, contains("onConflict: 'fcm_token'"));
      expect(repository, contains("'user_id': user.id"));
      expect(repository, contains("'is_active': true"));
    });
  });

  test('protected routes still reject role mismatch', () {
    expect(
      KaamAccountStatusPolicy.protectedAccess(
        actualRole: KaamRole.candidate,
        status: 'active',
        expectedRole: KaamRole.employer,
      ),
      KaamProtectedAccess.wrongRole,
    );
  });
}
