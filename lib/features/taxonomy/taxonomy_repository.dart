import 'package:supabase_flutter/supabase_flutter.dart';

class TaxonomyIndustry {
  const TaxonomyIndustry({required this.id, required this.name});
  final String id;
  final String name;
  factory TaxonomyIndustry.fromRow(Map<String, dynamic> r) =>
      TaxonomyIndustry(id: r['id'] as String, name: r['name'] as String);
}

class TaxonomyRole {
  const TaxonomyRole(
      {required this.id,
      required this.name,
      this.category = '',
      this.industry = '',
      this.alias});
  final String id, name, category, industry;
  final String? alias;
  factory TaxonomyRole.fromRow(Map<String, dynamic> r) => TaxonomyRole(
      id: r['job_role_id'] as String? ?? r['id'] as String,
      name: r['role_name'] as String? ?? r['name'] as String,
      category: r['category_name'] as String? ?? '',
      industry: r['industry_name'] as String? ?? '',
      alias: r['matched_alias'] as String?);
}

class CompetencySkill {
  const CompetencySkill({required this.id, required this.name});
  final String id, name;
  factory CompetencySkill.fromRow(Map<String, dynamic> r) =>
      CompetencySkill(id: r['id'] as String, name: r['name'] as String);
}

class TaxonomyRepository {
  TaxonomyRepository(this._client);
  final SupabaseClient _client;
  List<TaxonomyIndustry>? _industries;
  Future<List<TaxonomyIndustry>> getIndustries() => industries();
  Future<List<TaxonomyIndustry>> industries() async =>
      _industries ??= (await _client
              .from('industries')
              .select('id,name')
              .eq('active', true)
              .order('sort_order'))
          .map((r) => TaxonomyIndustry.fromRow(Map<String, dynamic>.from(r)))
          .toList();
  Future<List<TaxonomyRole>> searchRoles(
    String query, {
    int limit = 20,
  }) async {
    final rows = await _client.rpc(
      'search_job_roles',
      params: {'search_text': query, 'result_limit': limit},
    ) as List<dynamic>;
    return rows
        .map<TaxonomyRole>(
          (row) => TaxonomyRole.fromRow(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<TaxonomyRole>> roles(String categoryId) async => (await _client
              .from('job_roles')
              .select(
                  'id,name,job_categories!inner(name,industries!inner(name))')
              .eq('category_id', categoryId)
              .eq('active', true)
              .order('sort_order'))
          .map((r) {
        final c = Map<String, dynamic>.from(r['job_categories'] as Map);
        final i = Map<String, dynamic>.from(c['industries'] as Map);
        return TaxonomyRole(
            id: r['id'] as String,
            name: r['name'] as String,
            category: c['name'] as String,
            industry: i['name'] as String);
      }).toList();
  Future<TaxonomyRole?> role(String id) async {
    final r = await _client
        .from('job_roles')
        .select('id,name,job_categories!inner(name,industries!inner(name))')
        .eq('id', id)
        .maybeSingle();
    if (r == null) return null;
    final c = Map<String, dynamic>.from(r['job_categories'] as Map);
    final i = Map<String, dynamic>.from(c['industries'] as Map);
    return TaxonomyRole(
        id: r['id'] as String,
        name: r['name'] as String,
        category: c['name'] as String,
        industry: i['name'] as String);
  }

  Future<TaxonomyRole?> findRoleByExactName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final rows = await _client
        .from('job_roles')
        .select('id,name,job_categories!inner(name,industries!inner(name))')
        .ilike('name', trimmed)
        .eq('active', true)
        .limit(2);
    for (final row in rows) {
      final value = Map<String, dynamic>.from(row);
      if ((value['name'] as String? ?? '').toLowerCase() !=
          trimmed.toLowerCase()) {
        continue;
      }
      final category = Map<String, dynamic>.from(
        value['job_categories'] as Map,
      );
      final industry = Map<String, dynamic>.from(
        category['industries'] as Map,
      );
      return TaxonomyRole(
        id: value['id'] as String,
        name: value['name'] as String,
        category: category['name'] as String,
        industry: industry['name'] as String,
      );
    }
    return null;
  }

  Future<List<CompetencySkill>> suggestedSkills(String roleId) async =>
      (await _client
              .from('job_role_skills')
              .select('competency_skills!inner(id,name,active)')
              .eq('job_role_id', roleId)
              .eq('competency_skills.active', true)
              .order('sort_order'))
          .map((r) => CompetencySkill.fromRow(
              Map<String, dynamic>.from(r['competency_skills'] as Map)))
          .toList();
  Future<List<CompetencySkill>> searchSkills(String q) async => (await _client
          .from('competency_skills')
          .select('id,name')
          .eq('active', true)
          .ilike('name', '%$q%')
          .order('name')
          .limit(30))
      .map((r) => CompetencySkill.fromRow(Map<String, dynamic>.from(r)))
      .toList();

  Future<List<CompetencySkill>> skillsByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];
    final rows = await _client
        .from('competency_skills')
        .select('id,name')
        .inFilter('id', unique)
        .order('name');
    return rows
        .map((row) => CompetencySkill.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }
}
