import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/employer/widgets/employer_taxonomy_search_sheets.dart';
import 'package:kaam_perfect_match/features/taxonomy/taxonomy_repository.dart';

const _porotta = TaxonomyRole(
  id: 'role-porotta',
  name: 'Porotta Maker',
  category: 'Kitchen',
  industry: 'Restaurant / Food & Beverage',
);

void main() {
  testWidgets(
      'job role search debounces, renders taxonomy context, and returns selection',
      (tester) async {
    String? requested;
    TaxonomyRole? picked;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => ElevatedButton(
                    onPressed: () async {
                      picked = await showJobRoleSearchSheet(
                        context: context,
                        search: (query) async {
                          requested = query;
                          return [_porotta];
                        },
                      );
                    },
                    child: const Text('Select role'))))));
    await tester.tap(find.text('Select role'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'parotta');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(requested, 'parotta');
    expect(find.text('Porotta Maker'), findsOneWidget);
    expect(find.text('Kitchen • Restaurant / Food & Beverage'), findsOneWidget);
    await tester.tap(find.text('Porotta Maker'));
    await tester.pumpAndSettle();
    expect(picked, _porotta);
  });

  testWidgets('stale role search responses cannot overwrite the latest query',
      (tester) async {
    final oldResponse = Completer<List<TaxonomyRole>>();
    TaxonomyRole? picked;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => ElevatedButton(
                    onPressed: () async {
                      picked = await showJobRoleSearchSheet(
                        context: context,
                        search: (query) => query == 'po'
                            ? oldResponse.future
                            : Future.value([_porotta]),
                      );
                    },
                    child: const Text('Select role'))))));
    await tester.tap(find.text('Select role'));
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, 'po');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, 'poro');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    oldResponse.complete(const [TaxonomyRole(id: 'old', name: 'Old Role')]);
    await tester.pump();
    expect(find.text('Porotta Maker'), findsOneWidget);
    expect(find.text('Old Role'), findsNothing);
    await tester.tap(find.text('Porotta Maker'));
    await tester.pumpAndSettle();
    expect(picked?.id, 'role-porotta');
  });

  testWidgets(
      'competency sheet supports duplicate-safe multi-selection and Done',
      (tester) async {
    List<CompetencySkill>? picked;
    const safety = CompetencySkill(id: 'safety', name: 'Food safety');
    const hygiene = CompetencySkill(id: 'hygiene', name: 'Kitchen hygiene');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => ElevatedButton(
                    onPressed: () async {
                      picked = await showCompetencySkillSearchSheet(
                        context: context,
                        selected: const [safety],
                        search: (_) async => const [safety, hygiene],
                      );
                    },
                    child: const Text('Add skills'))))));
    await tester.tap(find.text('Add skills'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'food');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Food safety'), findsOneWidget);
    await tester.tap(find.text('Kitchen hygiene'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked?.map((skill) => skill.id).toSet(), {'safety', 'hygiene'});
  });

  test(
      'hiring form uses live taxonomy and backend persistence, without old role chips',
      () {
    final source = File(
            'lib/features/employer/hiring/employer_hiring_requirement_screens.dart')
        .readAsStringSync();
    expect(source, contains('showJobRoleSearchSheet'));
    expect(source, contains('showCompetencySkillSearchSheet'));
    expect(source, contains('taxonomy.searchRoles'));
    expect(source, contains('taxonomy.suggestedSkills'));
    expect(
        source, contains('competencySkillIds: selectedSkills.keys.toList()'));
    expect(source, contains('jobRoleId:'));
    expect(source, contains('repository.saveHiringRequirement('));
    expect(source, isNot(contains("'Warehouse Helper'")));
    expect(source, isNot(contains("'Restaurant Staff'")));
  });
}
