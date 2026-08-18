import 'employer_models.dart';

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Builds an employer-company write payload without turning omitted fields into
/// database nulls. Supplying an empty string is an explicit request to clear a
/// field; supplying null leaves it untouched on an update.
Map<String, dynamic> employerCompanyProfilePayload({
  required String ownerId,
  String? companyName,
  String? industry,
  String? companySize,
  String? location,
  String? branch,
  String? contactName,
  String? contactRole,
  String? description,
  List<String>? hiringNeeds,
  String? industryId,
  String? companySizeCode,
  String? contactRoleCode,
  String? contactRoleOther,
  String? companyEmirate,
  String? companyArea,
  String? branchName,
  String? status,
}) {
  final values = <String, dynamic>{'owner_id': ownerId};

  void addText(String column, String? value) {
    if (value != null) values[column] = _nullableText(value);
  }

  addText('company_name', companyName);
  addText('industry', industry);
  addText('company_size', companySize);
  addText('city', location);
  addText('office_area', branch);
  addText('contact_person', contactName);
  addText('contact_role', contactRole);
  addText('description', description);
  addText('industry_id', industryId);
  addText('company_size_code', companySizeCode);
  addText('contact_role_code', contactRoleCode);
  addText('contact_role_other', contactRoleOther);
  addText('company_emirate', companyEmirate);
  addText('company_area', companyArea);
  addText('branch_name', branchName);
  addText('status', status);
  if (hiringNeeds != null) values['hiring_needs'] = hiringNeeds;
  return values;
}

Map<String, dynamic> employerHiringRequirementPayload({
  required String employerId,
  required String companyId,
  required EmployerHiringRequirement requirement,
}) {
  return {
    'employer_id': employerId,
    'company_id': companyId,
    // Keep the existing label during the transition, even when a canonical
    // taxonomy role has been selected.
    'role': requirement.role,
    'job_role_id': requirement.jobRoleId,
    'custom_role': _nullableText(requirement.customRole),
    'openings': requirement.openings,
    'salary_range': requirement.salaryRange,
    'work_location': requirement.workLocation,
    'working_hours': requirement.workingHours,
    'accommodation_provided': requirement.accommodationProvided,
    'transport_provided': requirement.transportProvided,
    'visa_provided': requirement.visaProvided,
    'immediate_joining': requirement.immediateJoining,
    'description': _nullableText(requirement.description),
    'status': requirement.status,
  };
}

class RequirementSkillReconciliation {
  const RequirementSkillReconciliation({
    required this.toInsert,
    required this.toDelete,
  });

  final Set<String> toInsert;
  final Set<String> toDelete;
}

RequirementSkillReconciliation reconcileRequirementSkills({
  required Iterable<String> existing,
  required Iterable<String> selected,
}) {
  final existingIds = existing.toSet();
  final selectedIds = selected.toSet();
  return RequirementSkillReconciliation(
    toInsert: selectedIds.difference(existingIds),
    toDelete: existingIds.difference(selectedIds),
  );
}

/// Runs the two safe reconciliation operations. Errors intentionally propagate
/// so a requirement save is never reported as fully successful when its skills
/// failed to persist.
Future<void> synchronizeRequirementSkills({
  required Future<Iterable<String>> Function() loadExisting,
  required Future<void> Function(Set<String> skillIds) insert,
  required Future<void> Function(Set<String> skillIds) delete,
  required Iterable<String> selected,
}) async {
  final plan = reconcileRequirementSkills(
    existing: await loadExisting(),
    selected: selected,
  );
  if (plan.toDelete.isNotEmpty) await delete(plan.toDelete);
  if (plan.toInsert.isNotEmpty) await insert(plan.toInsert);
}

List<EmployerHiringRequirement> attachRequirementSkills({
  required Iterable<EmployerHiringRequirement> requirements,
  required Iterable<Map<String, dynamic>> skillRows,
}) {
  final skillsByRequirement = <String, List<String>>{};
  for (final row in skillRows) {
    final requirementId = row['requirement_id'] as String?;
    final skillId = row['competency_skill_id'] as String?;
    if (requirementId == null || skillId == null) continue;
    final skills = skillsByRequirement.putIfAbsent(requirementId, () => []);
    if (!skills.contains(skillId)) skills.add(skillId);
  }
  return requirements
      .map(
        (requirement) => requirement.copyWith(
          competencySkillIds: skillsByRequirement[requirement.id] ?? const [],
        ),
      )
      .toList(growable: false);
}
