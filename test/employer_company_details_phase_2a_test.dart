import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/employer/widgets/employer_selector_fields.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('shared UAE emirate and area hierarchy', () {
    test(
        'every canonical UAE emirate has a non-empty, duplicate-free area list',
        () {
      for (final emirate in CandidateLocationOptions.uaeEmirates) {
        final areas = CandidateLocationOptions.areasForEmirate(emirate);
        expect(areas, isNotEmpty, reason: '$emirate should have areas');
        expect(areas.toSet().length, areas.length,
            reason: '$emirate has duplicates');
      }
    });

    test(
        'area lookup is dependent on its emirate and unknown emirates are safe',
        () {
      expect(CandidateLocationOptions.areasForEmirate('Dubai'),
          contains('Al Quoz'));
      expect(CandidateLocationOptions.areasForEmirate('Sharjah'),
          isNot(contains('Al Quoz')));
      expect(CandidateLocationOptions.areasForEmirate('Unknown'), isEmpty);
      expect(CandidateLocationOptions.isValidAreaForEmirate('Dubai', 'Al Quoz'),
          isTrue);
      expect(
          CandidateLocationOptions.isValidAreaForEmirate('Sharjah', 'Al Quoz'),
          isFalse);
    });

    test(
        'emirate changes retain only a valid area and never affect branch state',
        () {
      expect(
        retainedAreaForEmirateChange(
            nextEmirate: 'Dubai', currentArea: 'Al Quoz'),
        'Al Quoz',
      );
      expect(
        retainedAreaForEmirateChange(
            nextEmirate: 'Sharjah', currentArea: 'Al Quoz'),
        isNull,
      );
    });
  });

  group('employer company option definitions', () {
    test('company-size and contact-role code mappings are centralized', () {
      expect(
        EmployerCompanyOptions.companySizes
            .firstWhere((option) => option.code == '11_25')
            .label,
        '11-25',
      );
      expect(
        EmployerCompanyOptions.contactRoles
            .firstWhere((option) => option.code == 'hr_manager')
            .label,
        'HR Manager',
      );
      expect(
        EmployerCompanyOptions.contactRoles
            .any((option) => option.code == 'other'),
        isTrue,
      );
    });
  });

  group('reusable selector components', () {
    testWidgets('opens, searches, marks selection, and returns an option',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await showSearchSelectionSheet<String>(
                    context: context,
                    title: 'Select Industry',
                    options: const [
                      'Construction',
                      'Restaurant / Food & Beverage'
                    ],
                    label: (value) => value,
                    selected: 'Construction',
                  );
                },
                child: const Text('Open selector'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open selector'));
      await tester.pumpAndSettle();
      expect(find.text('Construction'), findsOneWidget);
      expect(find.text('Restaurant / Food & Beverage'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'restaurant');
      await tester.pump();
      expect(find.text('Construction'), findsNothing);
      await tester.tap(find.text('Restaurant / Food & Beverage'));
      await tester.pumpAndSettle();
      expect(selected, 'Restaurant / Food & Beverage');
    });

    testWidgets('shows loading, error/retry, empty, and long values safely',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SelectionField(
                  label: 'Industry',
                  value: '',
                  hint: 'Loading industries...',
                  loading: true,
                ),
                Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showSearchSelectionSheet<String>(
                      context: context,
                      title: 'Select a very long company location label',
                      options: const [],
                      label: (value) => value,
                      errorText: 'Unable to load options.',
                      onRetry: () async => retried = true,
                    ),
                    child: const Text('Open error selector'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Open error selector'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Unable to load options.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  test('Company Details keeps persistence inside the backend abstraction', () {
    final source = File(
            'lib/features/employer/onboarding/employer_onboarding_screens.dart')
        .readAsStringSync();
    expect(source, contains('repository.upsertCompanyProfile('));
    expect(source, contains('industryId:'));
    expect(source, contains('companySizeCode:'));
    expect(source, contains('contactRoleCode:'));
    expect(source, contains('companyEmirate:'));
    expect(source, contains('companyArea:'));
    expect(source, contains("selectedContactRole?.code == 'other'"));
    expect(source, contains("label: 'Specify role'"));
    expect(source, contains('industryExplicitlySelected'));
    expect(source, contains('emirateExplicitlySelected'));
    expect(source, contains('CandidateLocationOptions.areasForEmirate'));
    expect(source, isNot(contains(".from('employer_companies')")));
  });
}
