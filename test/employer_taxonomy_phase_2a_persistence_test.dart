import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/employer/models/employer_models.dart';
import 'package:kaam_perfect_match/features/employer/models/employer_taxonomy_persistence.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

const _industryId = '11111111-1111-4111-8111-111111111111';
const _roleId = '22222222-2222-4222-8222-222222222222';
const _skillA = '33333333-3333-4333-8333-333333333333';
const _skillB = '44444444-4444-4444-8444-444444444444';
const _skillC = '55555555-5555-4555-8555-555555555555';

EmployerHiringRequirement _requirement({
  String? id = 'requirement-1',
  String? jobRoleId,
  List<String> skillIds = const [],
}) {
  return EmployerHiringRequirement(
    id: id,
    role: 'Electrician',
    jobRoleId: jobRoleId,
    competencySkillIds: skillIds,
    openings: 1,
    salaryRange: 'AED 1,500',
    workLocation: 'Dubai',
    workingHours: '8 hours',
    accommodationProvided: false,
    transportProvided: false,
    visaProvided: false,
    immediateJoining: false,
  );
}

void main() {
  group('Phase 2A employer company model', () {
    test('keeps legacy-only production rows intact', () {
      final company = EmployerCompanyData.fromRow({
        'id': 'company-1',
        'company_name': 'Legacy Electrical LLC',
        'industry': 'Construction',
        'company_size': '11-50',
        'city': 'Dubai',
        'office_area': 'Al Quoz',
        'contact_person': 'Amina',
        'contact_role': 'Manager',
      });

      expect(company.industry, 'Construction');
      expect(company.companySize, '11-50');
      expect(company.location, 'Dubai');
      expect(company.industryId, isNull);
      expect(company.companySizeCode, isNull);
      expect(company.contactRoleCode, isNull);
      expect(company.contactRoleOther, isNull);
      expect(company.companyEmirate, isNull);
      expect(company.companyArea, isNull);
      expect(company.branchName, isNull);
    });

    test('parses all structured employer company fields', () {
      final company = EmployerCompanyData.fromRow({
        'industry_id': _industryId,
        'company_size_code': '11_50',
        'contact_role_code': 'other',
        'contact_role_other': 'Recruitment lead',
        'company_emirate': 'Dubai',
        'company_area': 'Business Bay',
        'branch_name': 'Downtown branch',
      });

      expect(company.industryId, _industryId);
      expect(company.companySizeCode, '11_50');
      expect(company.contactRoleCode, 'other');
      expect(company.contactRoleOther, 'Recruitment lead');
      expect(company.companyEmirate, 'Dubai');
      expect(company.companyArea, 'Business Bay');
      expect(company.branchName, 'Downtown branch');
    });

    test('keeps legacy and structured company representations in mixed rows',
        () {
      final company = EmployerCompanyData.fromRow({
        'industry': 'Restaurant / Food & Beverage',
        'industry_id': _industryId,
        'company_size': '51-200',
        'company_size_code': '51_200',
        'city': 'Dubai',
        'company_emirate': 'Dubai',
        'office_area': 'Deira',
        'company_area': 'Deira',
      });

      expect(company.industry, 'Restaurant / Food & Beverage');
      expect(company.industryId, _industryId);
      expect(company.companySize, '51-200');
      expect(company.companySizeCode, '51_200');
      expect(company.location, 'Dubai');
      expect(company.companyEmirate, 'Dubai');
      expect(company.officeArea, 'Deira');
      expect(company.companyArea, 'Deira');
    });
  });

  group('Phase 2A company payloads', () {
    test('dual-writes supplied structured fields and compatible labels', () {
      final payload = employerCompanyProfilePayload(
        ownerId: 'owner-1',
        industry: 'Restaurant / Food & Beverage',
        industryId: _industryId,
        companySize: '11-50',
        companySizeCode: '11_50',
        contactRole: 'Other',
        contactRoleCode: 'other',
        contactRoleOther: 'Recruitment lead',
        location: 'Dubai',
        branch: 'Business Bay',
        companyEmirate: 'Dubai',
        companyArea: 'Business Bay',
        branchName: 'HQ',
      );

      expect(payload['industry'], 'Restaurant / Food & Beverage');
      expect(payload['industry_id'], _industryId);
      expect(payload['company_size'], '11-50');
      expect(payload['company_size_code'], '11_50');
      expect(payload['contact_role'], 'Other');
      expect(payload['contact_role_code'], 'other');
      expect(payload['contact_role_other'], 'Recruitment lead');
      expect(payload['city'], 'Dubai');
      expect(payload['office_area'], 'Business Bay');
      expect(payload['company_emirate'], 'Dubai');
      expect(payload['company_area'], 'Business Bay');
      expect(payload['branch_name'], 'HQ');
    });

    test('omitted structured fields are absent instead of accidental nulls',
        () {
      final payload = employerCompanyProfilePayload(
        ownerId: 'owner-1',
        description: 'Updated description only',
      );

      expect(payload['description'], 'Updated description only');
      for (final field in [
        'industry_id',
        'company_size_code',
        'contact_role_code',
        'contact_role_other',
        'company_emirate',
        'company_area',
        'branch_name',
      ]) {
        expect(payload.containsKey(field), isFalse,
            reason: '$field is omitted');
      }
      expect(payload.containsKey('industry'), isFalse);
      expect(payload.containsKey('city'), isFalse);
    });

    test('an explicitly supplied empty structured field requests a clear', () {
      final payload = employerCompanyProfilePayload(
        ownerId: 'owner-1',
        contactRoleOther: '',
      );

      expect(payload, containsPair('contact_role_other', isNull));
    });
  });

  group('Phase 2A hiring requirement persistence', () {
    test('parses legacy and canonical requirements and copies selected skills',
        () {
      final legacy = EmployerHiringRequirement.fromRow({
        'role': 'Electrician',
      });
      final canonical = legacy.copyWith(
        jobRoleId: _roleId,
        competencySkillIds: const [_skillA, _skillB],
      );

      expect(legacy.jobRoleId, isNull);
      expect(legacy.competencySkillIds, isEmpty);
      expect(canonical.role, 'Electrician');
      expect(canonical.jobRoleId, _roleId);
      expect(canonical.competencySkillIds, [_skillA, _skillB]);
    });

    test('requirement payload dual-writes canonical ID and legacy role label',
        () {
      final payload = employerHiringRequirementPayload(
        employerId: 'employer-1',
        companyId: 'company-1',
        requirement: _requirement(jobRoleId: _roleId).copyWith(
          role: 'Porotta Maker',
        ),
      );

      expect(payload['job_role_id'], _roleId);
      expect(payload['role'], 'Porotta Maker');
    });

    test('loads zero, one, and many requirement skills without duplicates', () {
      final requirements = [
        _requirement(id: 'zero'),
        _requirement(id: 'one'),
        _requirement(id: 'many'),
      ];
      final loaded = attachRequirementSkills(
        requirements: requirements,
        skillRows: const [
          {'requirement_id': 'one', 'competency_skill_id': _skillA},
          {'requirement_id': 'many', 'competency_skill_id': _skillA},
          {'requirement_id': 'many', 'competency_skill_id': _skillB},
          {'requirement_id': 'many', 'competency_skill_id': _skillA},
        ],
      );

      expect(loaded[0].competencySkillIds, isEmpty);
      expect(loaded[1].competencySkillIds, [_skillA]);
      expect(loaded[2].competencySkillIds, [_skillA, _skillB]);
    });

    test('reconciliation calculates additions and removals for all cases', () {
      expect(
        reconcileRequirementSkills(
            existing: [_skillA, _skillB],
            selected: [_skillA, _skillB, _skillC]).toInsert,
        {_skillC},
      );
      expect(
        reconcileRequirementSkills(
            existing: [_skillA, _skillB, _skillC],
            selected: [_skillA, _skillC]).toDelete,
        {_skillB},
      );
      final replacement = reconcileRequirementSkills(
        existing: [_skillA, _skillB],
        selected: [_skillB, _skillC],
      );
      expect(replacement.toInsert, {_skillC});
      expect(replacement.toDelete, {_skillA});
      expect(
        reconcileRequirementSkills(existing: [_skillA], selected: const [])
            .toDelete,
        {_skillA},
      );
      expect(
        reconcileRequirementSkills(
            existing: const [], selected: [_skillA, _skillA]).toInsert,
        {_skillA},
      );
    });

    test('fake persistence receives each duplicate-safe reconciliation action',
        () async {
      final inserted = <Set<String>>[];
      final deleted = <Set<String>>[];
      await synchronizeRequirementSkills(
        loadExisting: () async => [_skillA, _skillB],
        insert: (ids) async => inserted.add(ids),
        delete: (ids) async => deleted.add(ids),
        selected: [_skillB, _skillC, _skillC],
      );

      expect(inserted, [
        {_skillC}
      ]);
      expect(deleted, [
        {_skillA}
      ]);
    });

    test('fake synchronization failure reaches the caller', () async {
      await expectLater(
        synchronizeRequirementSkills(
          loadExisting: () async => const [],
          delete: (_) async {},
          insert: (_) async => throw StateError('insert failed'),
          selected: [_skillA],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
