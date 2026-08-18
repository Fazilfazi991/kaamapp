import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260807151913_role_skills_taxonomy_phase_1_catalog.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migration.readAsStringSync();
  });

  test('adds an additive canonical taxonomy without touching legacy tables',
      () {
    for (final table in [
      'industries',
      'job_categories',
      'job_roles',
      'job_role_aliases',
      'competency_skills',
      'job_role_skills',
      'legacy_role_mappings',
    ]) {
      expect(sql, contains('create table if not exists public.$table'));
    }
    expect(sql, contains('from public.skills s join public.job_roles'));
    expect(sql, isNot(contains('drop table public.skills')));
    expect(sql, isNot(contains('alter table public.skills rename')));
  });

  test('protects catalog writes and permits authenticated catalog reads', () {
    expect(sql,
        contains('alter table public.job_roles enable row level security'));
    expect(sql, contains('"job_roles_catalog_read"'));
    expect(sql, contains('"job_roles_admin_manage"'));
    expect(sql, contains('grant select on public.industries'));
    expect(sql, contains('revoke all on function public.search_job_roles'));
    expect(sql, contains('grant execute on function public.search_job_roles'));
  });

  test('seeds a substantial searchable catalog and mapping guardrails', () {
    expect(sql, contains("('porotta-maker','Parotta Maker')"));
    expect(sql, contains("('porotta-maker','Paratha Maker')"));
    expect(sql, contains("('tile-mason','Tile Fixer')"));
    expect(sql,
        contains('create index if not exists job_roles_active_name_trgm_idx'));
    expect(sql, contains('Phase 1 taxonomy expected 394 roles'));
    expect(sql,
        contains('Phase 1 taxonomy expected 306 competency skills'));
    expect(sql,
        contains('Phase 1 taxonomy expected 2039 role-skill mappings'));
    expect(sql, contains('legacy_role_mapping_coverage'));
    expect(sql, contains('drop policy if exists "job_roles_catalog_read"'));
    expect(sql, contains('on conflict (category_id,slug) do update'));
    expect(sql,
        contains('on conflict (job_role_id,competency_skill_id) do update'));
    expect(sql,
        contains('from category_seed c join inserted_categories jc on jc.slug=c.slug'));
    expect(sql, isNot(contains('join public.job_categories jc on jc.industry_id=i.id')));
  });

  test('contains a clean, internally structured master catalog seed', () {
    expect(sql, isNot(contains('tokens truncated')));
    expect(sql, isNot(contains('Exit code:')));
    expect(sql, isNot(contains('Wall time:')));
    expect(sql, isNot(contains('Total output lines:')));

    final categoryRows = RegExp(
      r"^\s*\('([^']*)','([^']*)','([^']*)',\d+,'([^']*)'\),?$",
      multiLine: true,
    ).allMatches(sql).toList();
    final categoryKeys = <String>{};
    final roleNames = <String>{};
    for (final row in categoryRows) {
      expect(categoryKeys.add('${row.group(1)}:${row.group(2)}'), isTrue);
      for (final role in row.group(4)!.split('|')) {
        expect(roleNames.add(role.toLowerCase()), isTrue,
            reason: 'duplicate canonical role: $role');
      }
    }
    expect(categoryRows.length, greaterThanOrEqualTo(62));
    expect(roleNames.length, greaterThanOrEqualTo(350));
    expect(sql, contains("('porotta-maker','Parotta Maker')"));
    expect(sql, contains("('hvac-technician','Air Conditioning Technician')"));
    expect(sql, contains("('auto-mechanic','Car Mechanic')"));
  });
}
