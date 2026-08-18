import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('Matching and Chat QA Fix Batch 1', () {
    late final String searchSource;
    late final String backendSource;
    late final String candidateRequestDetailsSource;
    late final String candidateRequestListSource;
    late final String employerInterestSource;
    late final String employerWidgetSource;
    late final String candidateChatSource;
    late final String employerChatSource;
    late final String chatThreadSource;
    late final String chatConversationSource;
    late final String chatControllerSource;
    late final String migrationSource;
    late final String rlsSource;

    setUpAll(() {
      searchSource = File(
        'lib/features/employer/search/employer_search_screens.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      candidateRequestDetailsSource = File(
        'lib/features/candidate/requests/interest_request_details_screen.dart',
      ).readAsStringSync();
      candidateRequestListSource = File(
        'lib/features/candidate/requests/interest_requests_screen.dart',
      ).readAsStringSync();
      employerInterestSource = File(
        'lib/features/employer/interests/employer_interest_screens.dart',
      ).readAsStringSync();
      employerWidgetSource = File(
        'lib/features/employer/widgets/employer_widgets.dart',
      ).readAsStringSync();
      candidateChatSource = File(
        'lib/features/candidate/chat/private_chat_screen.dart',
      ).readAsStringSync();
      employerChatSource = File(
        'lib/features/employer/chat/employer_chat_screens.dart',
      ).readAsStringSync();
      chatThreadSource = File(
        'lib/core/widgets/chat_thread_view.dart',
      ).readAsStringSync();
      chatConversationSource = File(
        'lib/core/widgets/chat_conversation_view.dart',
      ).readAsStringSync();
      chatControllerSource = File(
        'lib/core/chat/chat_conversation_controller.dart',
      ).readAsStringSync();
      migrationSource = File(
        'supabase/021_matching_chat_qa_batch_1.sql',
      ).readAsStringSync();
      rlsSource = File(
        'supabase/012_employer_match_contact_rules.sql',
      ).readAsStringSync();
    });

    test('search submit reveals the candidate review with progress', () {
      expect(searchSource, contains('searchSubmitted = true'));
      expect(searchSource, contains("'Match Candidates'"));
      expect(searchSource, contains('candidateIndex + 1'));
      expect(searchSource, contains('const _CandidateSkeletonCard()'));
    });

    test('empty and error search states are safe and actionable', () {
      expect(searchSource, contains('No strong matches yet'));
      expect(searchSource, contains('Try expanding the location'));
      expect(searchSource, contains('Could not load candidates'));
      expect(searchSource, contains('Adjust Filters'));
      expect(searchSource, contains('Try Again'));
    });

    test(
        'legacy all labels remain no-op while Candidate Search uses canonical roles',
        () {
      const filters = EmployerCandidateSearchFilters(
        category: 'All Categories',
        location: 'All Locations',
        skill: 'All Skills',
      );

      expect(filters.effectiveCategories, isEmpty);
      expect(filters.effectiveLocations, isEmpty);
      expect(filters.effectiveSkills, isEmpty);
      expect(searchSource, contains('All Locations'));
      expect(searchSource, contains('selectedJobRole'));
    });

    test('Clear Filters restores all/default filter state', () {
      final clearBlock = searchSource.substring(
        searchSource.indexOf('void _clearFilters()'),
        searchSource.indexOf(
          '@override',
          searchSource.indexOf('void _clearFilters()'),
        ),
      );

      expect(clearBlock, contains('selectedJobRole = null'));
      expect(clearBlock, contains("legacyRoleFilter = ''"));
      expect(clearBlock, contains('locations.clear()'));
      expect(clearBlock, contains('verifiedOnly = false'));
      expect(clearBlock, contains('searchSubmitted = false'));
      expect(clearBlock, contains('candidateIndex = 0'));
      expect(clearBlock, contains('minimumSalaryController.clear()'));
    });

    test('candidate and employer names are loaded without UUID fragments', () {
      expect(backendSource, contains('_displayCandidateName'));
      expect(backendSource, contains('_displayEmployerName'));
      expect(backendSource, contains("from('public_candidate_search')"));
      expect(employerWidgetSource, contains('request.candidateName'));
      expect(employerInterestSource, contains('request.candidateName'));
      expect(backendSource, isNot(contains("'Candidate #' || left")));
    });

    test('request details render clean non-duplicated fields', () {
      expect(candidateRequestDetailsSource, contains("_Line('Role'"));
      expect(candidateRequestDetailsSource, contains("_Line('Salary'"));
      expect(candidateRequestDetailsSource, contains("_Line('Location'"));
      expect(candidateRequestDetailsSource, contains("_Line('Working hours'"));
      expect(
        candidateRequestDetailsSource,
        isNot(contains('Accommodation / transport')),
      );
      expect(candidateRequestDetailsSource, contains('optional = false'));
      expect(employerInterestSource, contains("_DetailLine('Job Role'"));
      expect(employerInterestSource, contains("_DetailLine('Visa Support'"));
    });

    test('job details are saved as structured interest fields', () {
      expect(backendSource, contains("'job_title': _nullable(jobTitle)"));
      expect(backendSource, contains("'salary_range': _nullable(salaryRange)"));
      expect(backendSource, contains("'work_location': _nullable(location)"));
      expect(
        backendSource,
        contains("'working_hours': _nullable(workingHours)"),
      );
      expect(
        backendSource,
        contains("'accommodation_provided': accommodationProvided"),
      );
      expect(
        backendSource,
        contains("'transport_provided': transportProvided"),
      );
      expect(backendSource, contains("'visa_support': visaSupport"));
      expect(
        migrationSource,
        contains('add column if not exists job_title text'),
      );
    });

    test('candidate and employer resolve the same match id source', () {
      expect(backendSource, contains("row['match_id'] as String?"));
      expect(candidateChatSource, contains('final matchId = match?.id'));
      expect(employerChatSource, contains('final matchId = match?.matchId'));
      expect(
        migrationSource,
        contains('left join public.interest_requests ir'),
      );
    });

    test('existing chat messages load without relying on realtime', () {
      expect(
        backendSource,
        contains('Future<List<Map<String, dynamic>>> loadMessages'),
      );
      expect(backendSource, contains(".from('chat_messages')"));
      expect(
        backendSource,
        contains(".select('id,match_id,sender_id,body,is_read,created_at')"),
      );
      expect(candidateChatSource, contains('ChatConversationView'));
      expect(employerChatSource, contains('ChatConversationView'));
      expect(
        chatControllerSource,
        contains('await gateway.loadMessages(matchId)'),
      );
    });

    test(
      'chat realtime subscription is configured and failure keeps messages visible',
      () {
        expect(backendSource, contains('realtimeMessages'));
        expect(backendSource, contains(".stream(primaryKey: ['id'])"));
        expect(
          migrationSource,
          contains(
            'alter publication supabase_realtime add table public.chat_messages',
          ),
        );
        expect(
          chatControllerSource,
          contains('gateway.realtimeMessages(matchId).listen'),
        );
        expect(
          chatConversationSource,
          contains('initialRows: conversation.messages'),
        );
        expect(chatThreadSource, contains('Live updates are unavailable'));
        expect(chatThreadSource, contains('widget.initialRows.isEmpty'));
      },
    );

    test('RLS keeps chat access participant-only', () {
      expect(rlsSource, contains('public.match_chat_enabled(match_id)'));
      expect(rlsSource, contains('sender_id = auth.uid()'));
      expect(rlsSource, isNot(contains('with check (true)')));
      expect(rlsSource, isNot(contains('using (true)')));
    });

    test('empty messages and duplicate taps are blocked', () {
      expect(backendSource, contains('body.trim().isEmpty'));
      expect(chatControllerSource, contains('sendInProgress ||'));
      expect(chatControllerSource, contains('trimmed.isEmpty'));
      expect(
        chatConversationSource,
        contains('conversation.sendInProgress'),
      );
      expect(
        chatConversationSource,
        contains('controller.text.trim().isNotEmpty'),
      );
    });

    test('raw Supabase exception text is not shown to users', () {
      expect(
        chatConversationSource,
        contains('Unable to load chat right now. Please try again.'),
      );
      expect(candidateRequestListSource, contains('Please try again.'));
      expect(employerInterestSource, contains('Please try again.'));
      expect(candidateChatSource, isNot(contains('snapshot.error')));
      expect(employerChatSource, isNot(contains('snapshot.error')));
      expect(
        candidateChatSource,
        isNot(contains('RealtimeSubscribeException')),
      );
      expect(employerChatSource, isNot(contains('RealtimeSubscribeException')));
    });
  });
}
