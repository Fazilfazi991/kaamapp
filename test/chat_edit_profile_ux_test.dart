import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/chat/chat_conversation_controller.dart';
import 'package:kaam_perfect_match/features/candidate/profile/candidate_profile_completion.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('chat ordering and edit profile UX', () {
    late String chatThreadSource;
    late String chatConversationSource;
    late String candidateChatSource;
    late String employerChatSource;
    late String editProfileSource;
    late String completionSource;
    late String backendSource;
    late String chatListSource;
    late String matchesSource;
    late String requestsSource;
    late String dashboardSource;
    late String profileSource;

    setUpAll(() {
      chatThreadSource = File(
        'lib/core/widgets/chat_thread_view.dart',
      ).readAsStringSync();
      chatConversationSource = File(
        'lib/core/widgets/chat_conversation_view.dart',
      ).readAsStringSync();
      candidateChatSource = File(
        'lib/features/candidate/chat/private_chat_screen.dart',
      ).readAsStringSync();
      employerChatSource = File(
        'lib/features/employer/chat/employer_chat_screens.dart',
      ).readAsStringSync();
      editProfileSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      completionSource = File(
        'lib/features/candidate/profile/candidate_profile_completion.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      chatListSource = File(
        'lib/features/candidate/chat/chat_list_screen.dart',
      ).readAsStringSync();
      matchesSource = File(
        'lib/features/candidate/matches/matches_screen.dart',
      ).readAsStringSync();
      requestsSource = File(
        'lib/features/candidate/requests/interest_requests_screen.dart',
      ).readAsStringSync();
      dashboardSource = File(
        'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
      ).readAsStringSync();
      profileSource = File(
        'lib/features/candidate/profile/candidate_profile_screen.dart',
      ).readAsStringSync();
    });

    test('chat renders oldest to newest in a normal non-reversed list', () {
      expect(chatThreadSource, contains('reverse: false'));
      expect(chatThreadSource, contains('position.maxScrollExtent'));
      expect(chatThreadSource, contains('_scrollToBottom'));
    });

    test('chat sends and realtime updates append near the bottom only', () {
      expect(chatThreadSource, contains('wasNearBottom'));
      expect(chatThreadSource, contains('showJumpToLatest'));
      expect(chatThreadSource, contains('New messages'));
      expect(chatThreadSource, contains('animateTo'));
      expect(candidateChatSource, contains('ChatConversationView'));
      expect(employerChatSource, contains('ChatConversationView'));
      expect(chatConversationSource, contains('ChatThreadView'));
    });

    test('duplicate realtime events are merged by message id', () {
      expect(backendSource, contains("stream(primaryKey: ['id'])"));
      final merged = mergeChatMessages(const [], [
        {
          'id': 'message-1',
          'body': 'first',
          'created_at': '2026-01-01T00:00:00Z'
        },
        {
          'id': 'message-1',
          'body': 'updated',
          'created_at': '2026-01-01T00:00:00Z'
        },
      ]);
      expect(merged, hasLength(1));
      expect(merged.single['body'], 'updated');
    });

    test('documents and identity documents route to separate screens', () {
      expect(editProfileSource, contains('CandidateProfileSection.documents'));
      expect(editProfileSource, contains('AppRoutes.profileMedia'));
      expect(
        editProfileSource,
        contains('CandidateProfileSection.identityDocuments'),
      );
      expect(editProfileSource, contains('AppRoutes.documentsUpload'));
    });

    test(
      'document type mapping keeps identity and professional files separate',
      () {
        expect(
          CandidateDocumentTypeMapping.isIdentityDocument('passport'),
          isTrue,
        );
        expect(CandidateDocumentTypeMapping.isIdentityDocument('visa'), isTrue);
        expect(
          CandidateDocumentTypeMapping.isProfessionalDocument('cv'),
          isTrue,
        );
        expect(
          CandidateDocumentTypeMapping.isProfessionalDocument(
            'education_certificate',
          ),
          isTrue,
        );
        expect(
          CandidateDocumentTypeMapping.isProfessionalDocument('passport'),
          isFalse,
        );
        expect(CandidateDocumentTypeMapping.isIdentityDocument('cv'), isFalse);
        expect(completionSource, contains('identityTypes'));
        expect(completionSource, contains('professionalTypes'));
      },
    );

    test('complete section shows green check state', () {
      final completion = CandidateProfileCompletion.calculate(
        const CandidateProfileData(
          fullName: 'A Candidate',
          phone: '+971500000000',
          email: 'candidate@example.com',
          nationality: 'India',
          currentCountry: 'UAE',
          currentCity: 'Dubai',
        ),
      );
      final basic = completion.sections[CandidateProfileSection.basicDetails]!;
      expect(basic.state, CandidateSectionCompletionState.complete);
      expect(basic.statusLabel, 'Complete');
    });

    test('incomplete section does not show green check state', () {
      final completion = CandidateProfileCompletion.calculate(
        const CandidateProfileData(fullName: 'A Candidate'),
      );
      final basic = completion.sections[CandidateProfileSection.basicDetails]!;
      expect(basic.state, CandidateSectionCompletionState.incomplete);
      expect(basic.statusLabel, contains('missing'));
    });

    test('rejected and pending identity documents show correct status', () {
      final rejected = CandidateProfileCompletion.calculate(
        const CandidateProfileData(),
        identity: const CandidateIdentityDocumentData(
          passportFileUrl: 'front.jpg',
          passportBackFileUrl: 'back.jpg',
          passportStatus: 'rejected',
        ),
      ).sections[CandidateProfileSection.identityDocuments]!;
      expect(rejected.state, CandidateSectionCompletionState.actionRequired);
      expect(rejected.statusLabel, 'Action required');

      final pending = CandidateProfileCompletion.calculate(
        const CandidateProfileData(),
        identity: const CandidateIdentityDocumentData(
          passportFileUrl: 'front.jpg',
          passportBackFileUrl: 'back.jpg',
          passportStatus: 'pending_verification',
        ),
      ).sections[CandidateProfileSection.identityDocuments]!;
      expect(pending.state, CandidateSectionCompletionState.underReview);
      expect(pending.statusLabel, 'Passport verification pending');
    });

    test('profile strength uses the same section completion model', () {
      final completion = CandidateProfileCompletion.calculate(
        const CandidateProfileData(),
      );
      expect(completion.sections.length, 7);
      expect(completion.percentage, 14);
      expect(completionSource, contains('sections.values'));
      expect(editProfileSource, contains('completion.sections'));
    });

    test(
        'passport-derived fields are owned by identity documents, not Basic Details',
        () {
      expect(completionSource, contains("label: 'Basic Details'"));
      expect(completionSource,
          isNot(contains("_CompletionCheck('passport number'")));
      expect(completionSource, contains("label: 'Identity Documents'"));
    });

    test('messages use conversation summaries instead of match cards', () {
      expect(chatListSource, contains('candidateConversations()'));
      expect(chatListSource, contains('Start a conversation'));
      expect(chatListSource, contains('_ConversationTile'));
      expect(chatListSource, isNot(contains('MatchCard(match: match)')));
      expect(backendSource, contains(".inFilter('match_id', matchIds)"));
      expect(matchesSource, contains('MatchCard(match: match)'));
    });

    test(
        'requests prioritize actionable pending items and retain history by status',
        () {
      expect(requestsSource, contains("_withStatus(requests, 'pending')"));
      expect(requestsSource, contains("_withStatus(requests, 'accepted')"));
      expect(requestsSource, contains("_withStatus(requests, 'rejected')"));
    });

    test('profile strength opens the same edit overview from home and profile',
        () {
      expect(dashboardSource, contains('AppRoutes.editProfile'));
      expect(profileSource, contains('AppRoutes.editProfile'));
      expect(
        File('lib/core/widgets/candidate_widgets.dart').readAsStringSync(),
        contains('Improve Profile'),
      );
    });

    test('passport readiness is explicit without changing Basic Details', () {
      final completion = CandidateProfileCompletion.calculate(
        const CandidateProfileData(
          fullName: 'A Candidate',
          phone: '+971500000000',
          email: 'candidate@example.com',
          nationality: 'India',
          currentCountry: 'UAE',
          currentCity: 'Dubai',
        ),
      );
      expect(
        completion.sections[CandidateProfileSection.basicDetails]!.statusLabel,
        'Complete',
      );
      expect(
        completion
            .sections[CandidateProfileSection.identityDocuments]!.statusLabel,
        'Passport required',
      );
      expect(completion.priorityActions.first.title, 'Passport required');
      expect(editProfileSource, contains('_ProfileCompletionSummary'));
      expect(editProfileSource, contains("label: 'Upload Passport'"));
    });
  });
}
