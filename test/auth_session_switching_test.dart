import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('auth session switching policy', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      KaamAuthSessionCoordinator.resetForTesting();
    });

    tearDown(KaamAuthSessionCoordinator.resetForTesting);

    test(
      'Account A logout clears pending OTP and explicit logout state',
      () async {
        KaamAuthSessionCoordinator.setPendingOtp(
          email: 'candidate@example.com',
          role: KaamRole.candidate,
        );

        await KaamAuthSessionCoordinator.beginExplicitLogout();
        await KaamAuthSessionCoordinator.finishExplicitLogout();

        expect(KaamAuthSessionCoordinator.pendingOtp, isNull);
        expect(KaamAuthSessionCoordinator.explicitLogoutInProgress, isFalse);
        expect(KaamAuthSessionCoordinator.explicitLogoutCompleted, isTrue);
        expect(KaamAuthSessionCoordinator.blocksSessionRestore, isTrue);
      },
    );

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

    test(
      'different entered email starts OTP instead of restoring old session',
      () {
        expect(
          KaamAuthSessionPolicy.shouldStartOtpForEnteredEmail(
            hasCurrentSession: true,
            enteredEmail: 'account-b@example.com',
            currentSessionEmail: 'account-a@example.com',
          ),
          isTrue,
        );
      },
    );

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

    test(
      'candidate logout then employer login should use employer pending OTP',
      () {
        KaamAuthSessionCoordinator.markAuthenticatedUser('candidate-a');
        KaamAuthSessionCoordinator.clearUserScopedState();
        KaamAuthSessionCoordinator.setPendingOtp(
          email: 'employer@example.com',
          role: KaamRole.employer,
        );

        expect(KaamAuthSessionCoordinator.pendingOtp?.role, KaamRole.employer);
      },
    );

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
      },
    );

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

    test('fresh authentication clears explicit logout restore block', () async {
      await KaamAuthSessionCoordinator.beginExplicitLogout();
      await KaamAuthSessionCoordinator.finishExplicitLogout();

      KaamAuthSessionCoordinator.markAuthenticatedUser('account-b');

      expect(KaamAuthSessionCoordinator.explicitLogoutCompleted, isFalse);
      expect(KaamAuthSessionCoordinator.blocksSessionRestore, isFalse);
    });

    test(
      'logout epoch changes so delayed profile fetches can be discarded',
      () async {
        final beforeLogout = KaamAuthSessionCoordinator.sessionEpoch;

        await KaamAuthSessionCoordinator.beginExplicitLogout();
        final duringLogout = KaamAuthSessionCoordinator.sessionEpoch;
        await KaamAuthSessionCoordinator.finishExplicitLogout();

        expect(duringLogout, greaterThan(beforeLogout));
        expect(
          KaamAuthSessionCoordinator.sessionEpoch,
          greaterThan(duringLogout),
        );
      },
    );

    test('explicit logout survives startup restoration', () async {
      await KaamAuthSessionCoordinator.beginExplicitLogout();
      await KaamAuthSessionCoordinator.finishExplicitLogout();
      KaamAuthSessionCoordinator.resetForTesting();

      await KaamAuthSessionCoordinator.restorePersistentLogoutState();

      expect(KaamAuthSessionCoordinator.explicitLogoutCompleted, isTrue);
      expect(KaamAuthSessionCoordinator.blocksSessionRestore, isTrue);
    });

    test('safe logout message hides backend errors', () {
      expect(
        KaamSafeErrorMessages.logout,
        'We could not log you out. Please try again.',
      );
      expect(KaamSafeErrorMessages.logout, isNot(contains('Supabase')));
    });

    test('fresh registration forces account reset before OTP', () {
      final backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();

      expect(backendSource, contains('bool freshRegistration = false'));
      expect(backendSource, contains('freshRegistration ||'));
      expect(backendSource, contains('prepareFreshRegistration'));
    });

  });

  group('shared profile bootstrap and login resolution', () {
    late final String backendSource;
    late final String bootstrapSql;

    setUpAll(() {
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      bootstrapSql = File(
        'supabase/018_bootstrap_user_profile.sql',
      ).readAsStringSync();
    });

    test('new candidate and employer flows bootstrap by auth user ID', () {
      expect(backendSource, contains("rpc('bootstrap_user_profile'"));
      expect(bootstrapSql, contains('v_user_id uuid := auth.uid()'));
      expect(
        bootstrapSql,
        contains("selected_role not in ('candidate', 'employer')"),
      );
      expect(bootstrapSql, contains("'active'::public.profile_status"));
      expect(bootstrapSql, contains('insert into public.profiles'));
      expect(bootstrapSql, contains('on conflict (id) do nothing'));
    });

    test('profile lookup uses profiles.id, not email ownership matching', () {
      final authRepositoryStart = backendSource.indexOf(
        'class KaamAuthRepository',
      );
      final authRepositoryEnd = backendSource.indexOf(
        'class QaToolsRepository',
      );
      final authRepositorySource = backendSource.substring(
        authRepositoryStart,
        authRepositoryEnd,
      );

      expect(authRepositorySource, contains(".eq('id', user.id)"));
      expect(authRepositorySource, isNot(contains(".eq('email'")));
    });

    test('login with missing profile signs out and shows create account', () {
      expect(
        KaamSafeErrorMessages.accountNotFound,
        'No account found with this email. Please create an account first.',
      );
      expect(backendSource, contains('KaamAccountNotFoundException'));
      expect(
        backendSource,
        contains('shouldCreateUser: freshRegistration || role != null'),
      );
      expect(
        backendSource,
        contains('throw const KaamAccountNotFoundException()'),
      );
    });

    test('existing account role cannot be silently changed by bootstrap', () {
      expect(bootstrapSql, contains('if v_existing.role <> v_role then'));
      expect(
        bootstrapSql,
        contains('Existing KAAM profile uses a different role'),
      );
      expect(
        backendSource,
        isNot(
          contains('await signOut();\n        throw KaamRoleMismatchException'),
        ),
      );
    });

    test('session is cleared during missing-profile login', () {
      final missingProfileBlockStart = backendSource.indexOf(
        'if (existingProfile == null)',
      );
      final missingProfileBlock = backendSource.substring(
        missingProfileBlockStart,
        backendSource.indexOf('await bootstrapProfile(role: role);'),
      );

      expect(missingProfileBlock, contains('await signOut()'));
      expect(missingProfileBlock, contains('KaamAccountNotFoundException'));
    });
  });

  group('OTP route and navigation source guards', () {
    test('OTP route is registered as a public app route', () {
      final appSource = File('lib/app.dart').readAsStringSync();
      final employerRoutes = File(
        'lib/features/employer/employer_routes.dart',
      ).readAsStringSync();

      expect(
        appSource,
        contains('AppRoutes.otp: (_) => const OtpVerificationScreen()'),
      );
      expect(
        employerRoutes,
        contains('AppRoutes.employerOtp: (_) => const EmployerOtpScreen()'),
      );
      expect(appSource, isNot(contains('AppRoutes.otp: (_) => _candidate')));
      expect(
        employerRoutes,
        isNot(contains('AppRoutes.employerOtp: (_) => _employer')),
      );
    });

    test('OTP request success uses replacement navigation to OTP screen', () {
      final candidateLogin = File(
        'lib/features/auth/login_screen.dart',
      ).readAsStringSync();
      final employerLogin = File(
        'lib/features/employer/auth/employer_auth_screens.dart',
      ).readAsStringSync();

      expect(candidateLogin, contains('pushReplacementNamed'));
      expect(candidateLogin, contains('AppRoutes.otp'));
      expect(
        candidateLogin,
        isNot(contains('pushNamedAndRemoveUntil(\n              _routeFor')),
      );
      expect(employerLogin, contains('pushReplacementNamed'));
      expect(employerLogin, contains('AppRoutes.employerOtp'));
      expect(employerLogin, isNot(contains('_routeForSession')));
    });

    test('OTP verification failure remains on OTP screen', () {
      final otpSource = File(
        'lib/features/auth/otp_verification_screen.dart',
      ).readAsStringSync();
      final employerOtpSource = File(
        'lib/features/employer/auth/employer_auth_screens.dart',
      ).readAsStringSync();

      expect(otpSource, contains('We could not verify that code'));
      expect(
        otpSource,
        isNot(
          contains('catch (_) {\n      if (!mounted) return;\n      Navigator'),
        ),
      );
      expect(employerOtpSource, contains('We could not verify that code'));
      expect(
        employerOtpSource,
        isNot(
          contains('catch (_) {\n      if (!mounted) return;\n      Navigator'),
        ),
      );
    });

    test('push-device registration moves by FCM token upsert', () {
      final repository = File(
        'lib/features/notifications/notification_repository.dart',
      ).readAsStringSync();

      expect(repository, contains("onConflict: 'fcm_token'"));
      expect(repository, contains("'user_id': user.id"));
      expect(repository, contains("'is_active': true"));
    });

    test('push-device registration ignores stale auth during logout', () {
      final pushService = File(
        'lib/features/notifications/push_notification_service.dart',
      ).readAsStringSync();

      expect(
        pushService,
        contains('KaamAuthSessionCoordinator.blocksSessionRestore'),
      );
      expect(pushService, contains('if (state.event == AuthChangeEvent'));
    });

    test('journey selection preserves employer choice after logout', () {
      final roleSelection = File(
        'lib/features/auth/role_selection_screen.dart',
      ).readAsStringSync();

      expect(
        roleSelection,
        contains('KaamAuthSessionCoordinator.blocksSessionRestore'),
      );
      expect(roleSelection, contains('_freshRegistration'));
      expect(roleSelection, contains('AppRoutes.employerLogin'));
      expect(roleSelection, contains("'role': selectedRole"));
      expect(
        roleSelection,
        contains("'freshRegistration': _freshRegistration"),
      );
    });

    test('welcome opens neutral account access before registration', () {
      final welcome = File(
        'lib/features/auth/welcome_screen.dart',
      ).readAsStringSync();
      final accountAccess = File(
        'lib/features/auth/account_access_screen.dart',
      ).readAsStringSync();
      final appSource = File('lib/app.dart').readAsStringSync();

      expect(welcome, contains('AppRoutes.accountAccess'));
      expect(
        appSource,
        contains('AppRoutes.accountAccess: (_) => const AccountAccessScreen()'),
      );
      expect(accountAccess, contains('Login'));
      expect(accountAccess, contains('Register'));
      expect(accountAccess, contains('prepareFreshRegistration'));
      expect(accountAccess, contains("'freshRegistration': true"));
    });

    test('candidate and employer OTP requests preserve fresh registration', () {
      final candidateLogin = File(
        'lib/features/auth/login_screen.dart',
      ).readAsStringSync();
      final employerLogin = File(
        'lib/features/employer/auth/employer_auth_screens.dart',
      ).readAsStringSync();

      expect(candidateLogin, contains('freshRegistration: _freshRegistration'));
      expect(
        candidateLogin,
        contains("'freshRegistration': _freshRegistration"),
      );
      expect(employerLogin, contains('freshRegistration: _freshRegistration'));
      expect(
        employerLogin,
        contains("'freshRegistration': _freshRegistration"),
      );
    });

    test('login screen can switch to register without keeping login state', () {
      final candidateLogin = File(
        'lib/features/auth/login_screen.dart',
      ).readAsStringSync();
      final roleSelection = File(
        'lib/features/auth/role_selection_screen.dart',
      ).readAsStringSync();

      expect(candidateLogin, contains('Not registered yet?'));
      expect(candidateLogin, contains('Create an account'));
      expect(candidateLogin, contains('prepareFreshRegistration'));
      expect(candidateLogin, contains('pushReplacementNamed'));
      expect(roleSelection, contains('Already have an account?'));
      expect(roleSelection, contains('pushReplacementNamed(AppRoutes.login)'));
    });

    test(
      'unregistered login shows account not found and create account action',
      () {
        final candidateLogin = File(
          'lib/features/auth/login_screen.dart',
        ).readAsStringSync();

        expect(candidateLogin, contains('accountNotFound'));
        expect(
          candidateLogin,
          contains('KaamSafeErrorMessages.accountNotFound'),
        );
        expect(candidateLogin, contains('Create an account'));
        expect(candidateLogin, contains('contactController.clear()'));
        expect(candidateLogin, contains('prepareFreshRegistration'));
      },
    );

    test('registration OTP success is shown only for fresh registration', () {
      final candidateOtp = File(
        'lib/features/auth/otp_verification_screen.dart',
      ).readAsStringSync();
      final employerOtp = File(
        'lib/features/employer/auth/employer_auth_screens.dart',
      ).readAsStringSync();

      expect(candidateOtp, contains('otpContext.freshRegistration'));
      expect(employerOtp, contains('freshRegistration'));
      expect(candidateOtp, contains('Registration successful'));
      expect(
        candidateOtp,
        contains('Your KAAM account has been created successfully.'),
      );
      expect(employerOtp, contains('Registration successful'));
    });

    test('OTP screens show the email being verified', () {
      final candidateOtp = File(
        'lib/features/auth/otp_verification_screen.dart',
      ).readAsStringSync();
      final employerOtp = File(
        'lib/features/employer/auth/employer_auth_screens.dart',
      ).readAsStringSync();

      expect(candidateOtp, contains(r'code sent to $email'));
      expect(employerOtp, contains(r'code sent to $email'));
    });

    test('Android backup restore is disabled for QA auth isolation', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
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

  group('passport front and back document upload', () {
    late final String uploadSource;
    late final String reviewSource;
    late final String backendSource;
    late final String migrationSource;

    setUpAll(() {
      uploadSource = File(
        'lib/features/candidate/onboarding/documents_upload_screen.dart',
      ).readAsStringSync();
      reviewSource = File(
        'lib/features/candidate/documents/identity_document_review_screen.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      migrationSource = File(
        'supabase/019_passport_front_back_documents.sql',
      ).readAsStringSync();
    });

    test('passport requires separate front and back uploads before review', () {
      expect(uploadSource, contains('Passport Front'));
      expect(uploadSource, contains('Passport Back'));
      expect(uploadSource, contains('passportFrontUpload'));
      expect(uploadSource, contains('passportBackUpload'));
      expect(uploadSource, contains('frontReady && backReady'));
      expect(uploadSource, contains('Passport images ready to review'));
    });

    test('passport review saves both file paths without fake back OCR', () {
      expect(
        reviewSource,
        contains("'passport_file_url': currentArgs.upload.path"),
      );
      expect(
        reviewSource,
        contains("'passport_back_file_url': currentArgs.backUpload!.path"),
      );
      expect(uploadSource, contains("side == _PassportSide.front"));
      expect(uploadSource, isNot(contains('extractBack')));
    });

    test('candidate model and version history record front and back paths', () {
      expect(backendSource, contains('passportBackFileUrl'));
      expect(backendSource, contains('hasPassportFront'));
      expect(backendSource, contains('hasPassportBack'));
      // The server RPC owns version-history serialization so that it can
      // atomically consume the hash-bound validation records.
      expect(backendSource, contains("'p_front_path': frontPath"));
      expect(backendSource, contains("'p_back_path': backPath"));
      expect(
        backendSource,
        contains("rpc('submit_candidate_identity_documents'"),
      );
    });

    test('database migration is additive for passport back support', () {
      expect(
        migrationSource,
        contains('add column if not exists passport_back_file_url'),
      );
      expect(migrationSource, contains('add column if not exists file_paths'));
      expect(
        migrationSource,
        contains("jsonb_build_object('front', file_path)"),
      );
    });
  });
}
