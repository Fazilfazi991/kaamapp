import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../documents/document_status_service.dart';

enum CandidateProfileSection {
  basicDetails,
  workPreferences,
  skills,
  experience,
  documents,
  identityDocuments,
  privacy,
}

enum CandidateSectionCompletionState {
  complete,
  incomplete,
  underReview,
  actionRequired,
}

class CandidateProfileCompletion {
  const CandidateProfileCompletion({
    required this.percentage,
    required this.missingFields,
    required this.helperText,
    required this.sections,
  });

  final int percentage;
  final List<String> missingFields;
  final String helperText;
  final Map<CandidateProfileSection, CandidateSectionCompletion> sections;

  List<CandidateProfileAction> get priorityActions {
    final actions = <CandidateProfileAction>[];
    final identity = sections[CandidateProfileSection.identityDocuments]!;
    if (identity.state != CandidateSectionCompletionState.complete) {
      actions.add(CandidateProfileAction(
        section: CandidateProfileSection.identityDocuments,
        title: identity.statusLabel,
        detail: identity.state == CandidateSectionCompletionState.underReview
            ? 'Your passport verification is being reviewed.'
            : 'Upload and verify your passport to complete your profile.',
      ));
    }
    for (final section in [
      CandidateProfileSection.skills,
      CandidateProfileSection.experience,
      CandidateProfileSection.documents,
    ]) {
      final status = sections[section]!;
      if (status.state == CandidateSectionCompletionState.incomplete) {
        actions.add(CandidateProfileAction(
          section: section,
          title: 'Complete ${status.label}',
          detail: status.missingFields.join(', '),
        ));
      }
    }
    return actions;
  }

  static CandidateProfileCompletion calculate(
    CandidateProfileData profile, {
    List<VerificationDocumentData> documents = const [],
    CandidateIdentityDocumentData? identity,
  }) {
    final identityDocuments = identity ?? const CandidateIdentityDocumentData();
    final sections = <CandidateProfileSection, CandidateSectionCompletion>{
      CandidateProfileSection.basicDetails: _section(
        label: 'Basic Details',
        checks: [
          _CompletionCheck('full name', profile.fullName.trim().isNotEmpty),
          _CompletionCheck(
            'nationality',
            profile.nationality.trim().isNotEmpty,
          ),
          _CompletionCheck(
            'current location',
            CandidateLocationOptions.isComplete(
              profile.currentCountry,
              profile.currentCity,
            ),
          ),
          _CompletionCheck('phone number', profile.phone.trim().isNotEmpty),
          _CompletionCheck('email', profile.email.trim().isNotEmpty),
        ],
      ),
      CandidateProfileSection.workPreferences: _section(
        label: 'Work Preferences',
        checks: [
          _CompletionCheck(
            'preferred work location',
            CandidateLocationOptions.isComplete(
              profile.preferredCountry,
              profile.preferredCity,
            ),
          ),
          _CompletionCheck(
            'job hierarchy',
            CandidateJobHierarchy.profileIsComplete(profile),
          ),
          _CompletionCheck(
            'availability',
            profile.availability.trim().isNotEmpty,
          ),
          _CompletionCheck(
            'expected salary',
            profile.expectedSalaryMin != null ||
                profile.expectedSalaryMax != null,
          ),
        ],
      ),
      CandidateProfileSection.skills: _section(
        label: 'Skills',
        checks: [
          _CompletionCheck(
            'skills',
            CandidateSkillLimits.isValidCount(profile.skills.length),
          ),
          _CompletionCheck(
            'experience for every skill',
            CandidateSkillExperience.allSelectedHaveExperience(
              selectedSkillCount: profile.skills.length,
              bySkillId: profile.skillExperiences,
            ),
          ),
          _CompletionCheck('languages', profile.languages.isNotEmpty),
        ],
      ),
      CandidateProfileSection.experience: _section(
        label: 'Experience',
        checks: [
          _CompletionCheck(
            'years of experience',
            profile.experienceYears != null,
          ),
          _CompletionCheck(
            'current employment status',
            profile.currentEmploymentStatus.trim().isNotEmpty,
          ),
          _CompletionCheck(
            'driving licence status',
            profile.drivingLicenses.isNotEmpty,
          ),
          if (CandidateVisaExpiry.requiresExpiry(profile.visaStatus))
            _CompletionCheck(
              'valid visa expiry date',
              CandidateVisaExpiry.isValidForStatus(
                profile.visaStatus,
                profile.visaExpiryDate,
              ),
            ),
        ],
      ),
      CandidateProfileSection.documents: _documentsSection(profile, documents),
      CandidateProfileSection.identityDocuments: _identitySection(
        identityDocuments,
      ),
      CandidateProfileSection.privacy: const CandidateSectionCompletion(
        label: 'Privacy',
        state: CandidateSectionCompletionState.complete,
      ),
    };

    final completed = sections.values
        .where(
          (section) =>
              section.state == CandidateSectionCompletionState.complete,
        )
        .length;
    final percentage = ((completed / sections.length) * 100).round().clamp(
          0,
          100,
        );
    final missing = sections.values
        .where(
          (section) =>
              section.state == CandidateSectionCompletionState.incomplete,
        )
        .expand((section) => section.missingFields)
        .toList();

    return CandidateProfileCompletion(
      percentage: percentage,
      missingFields: missing,
      helperText: percentage >= 90
          ? 'Your profile looks strong.'
          : 'Add skills, experience, and documents to improve your profile.',
      sections: sections,
    );
  }
}

class CandidateDashboardEligibilityStatus {
  const CandidateDashboardEligibilityStatus({
    required this.profileComplete,
    required this.documentsVerified,
    required this.passportVerified,
    required this.visaVerified,
    required this.membershipActive,
    required this.visibleToEmployers,
    required this.chatUnlocked,
    required this.actionRequired,
    required this.underReview,
    required this.visibilityReason,
    required this.primaryActionLabel,
    required this.primaryActionSection,
  });

  final bool profileComplete;
  final bool documentsVerified;
  final bool passportVerified;
  final bool visaVerified;
  final bool membershipActive;
  final bool visibleToEmployers;
  final bool chatUnlocked;
  final bool actionRequired;
  final bool underReview;
  final String visibilityReason;
  final String primaryActionLabel;
  final CandidateProfileSection primaryActionSection;

  int get profileStrengthPercentage {
    final checks = [
      profileComplete,
      documentsVerified,
      visibleToEmployers,
      chatUnlocked,
    ];
    return ((checks.where((check) => check).length / checks.length) * 100)
        .round()
        .clamp(0, 100);
  }

  String get helperText => visibleToEmployers
      ? 'Your profile is visible to employers.'
      : visibilityReason;

  factory CandidateDashboardEligibilityStatus.fromLiveData({
    required CandidateProfileData profile,
    required CandidateIdentityDocumentData identity,
    required CandidateMembershipData membership,
    bool? visibleToEmployersOverride,
  }) {
    final profileComplete = visibleToEmployersOverride == true ||
        _requiredEmployerSearchProfileComplete(profile);
    final passportStatus = DocumentStatusService.normalized(
      identity.passportStatus,
      uploaded: identity.hasPassport,
      expiry: identity.passportExpiryDate,
    );
    final visaStatus = DocumentStatusService.normalized(
      identity.visaStatus,
      uploaded: identity.hasVisa,
      expiry: identity.visaExpiryDate,
    );
    final passportVerified =
        visibleToEmployersOverride == true || _isApprovedStatus(passportStatus);
    final visaVerified = visibleToEmployersOverride == true ||
        !identity.hasVisa ||
        _isApprovedStatus(visaStatus);
    final documentsVerified = passportVerified && visaVerified;
    final actionRequired = _isActionRequiredStatus(passportStatus) ||
        (identity.hasVisa && _isActionRequiredStatus(visaStatus));
    final underReview = !actionRequired &&
        (_isUnderReviewStatus(passportStatus) ||
            (identity.hasVisa && _isUnderReviewStatus(visaStatus)));
    final localVisibility = CandidateEmployerVisibility(
      profileCompleted: profileComplete,
      documentsVerified: documentsVerified,
      membershipActive: membership.isActive,
      profileVisible: profile.isVisible,
    ).visibleToEmployers;
    final visibleToEmployers = visibleToEmployersOverride ?? localVisibility;

    if (visibleToEmployers) {
      return CandidateDashboardEligibilityStatus(
        profileComplete: true,
        documentsVerified: true,
        passportVerified: true,
        visaVerified: true,
        membershipActive: membership.isActive,
        visibleToEmployers: true,
        chatUnlocked: membership.isActive,
        actionRequired: false,
        underReview: false,
        visibilityReason:
            'Employers can now discover and send you interest requests.',
        primaryActionLabel: 'View Profile',
        primaryActionSection: CandidateProfileSection.basicDetails,
      );
    }

    if (!profile.isVisible) {
      return CandidateDashboardEligibilityStatus(
        profileComplete: profileComplete,
        documentsVerified: documentsVerified,
        passportVerified: passportVerified,
        visaVerified: visaVerified,
        membershipActive: membership.isActive,
        visibleToEmployers: false,
        chatUnlocked: membership.isActive,
        actionRequired: false,
        underReview: false,
        visibilityReason: 'Turn on profile visibility to appear in search.',
        primaryActionLabel: 'Edit Privacy',
        primaryActionSection: CandidateProfileSection.privacy,
      );
    }

    if (!profileComplete) {
      return CandidateDashboardEligibilityStatus(
        profileComplete: false,
        documentsVerified: documentsVerified,
        passportVerified: passportVerified,
        visaVerified: visaVerified,
        membershipActive: membership.isActive,
        visibleToEmployers: false,
        chatUnlocked: membership.isActive,
        actionRequired: false,
        underReview: false,
        visibilityReason:
            'Complete your profile to become visible to employers.',
        primaryActionLabel: 'Complete Profile',
        primaryActionSection: CandidateProfileSection.basicDetails,
      );
    }

    if (actionRequired) {
      return CandidateDashboardEligibilityStatus(
        profileComplete: profileComplete,
        documentsVerified: false,
        passportVerified: passportVerified,
        visaVerified: visaVerified,
        membershipActive: membership.isActive,
        visibleToEmployers: false,
        chatUnlocked: membership.isActive,
        actionRequired: true,
        underReview: false,
        visibilityReason: 'Please update your identity documents.',
        primaryActionLabel: 'Update Documents',
        primaryActionSection: CandidateProfileSection.identityDocuments,
      );
    }

    if (underReview) {
      return CandidateDashboardEligibilityStatus(
        profileComplete: profileComplete,
        documentsVerified: false,
        passportVerified: passportVerified,
        visaVerified: visaVerified,
        membershipActive: membership.isActive,
        visibleToEmployers: false,
        chatUnlocked: membership.isActive,
        actionRequired: false,
        underReview: true,
        visibilityReason: 'Your documents are under review.',
        primaryActionLabel: 'View Documents',
        primaryActionSection: CandidateProfileSection.identityDocuments,
      );
    }

    return CandidateDashboardEligibilityStatus(
      profileComplete: profileComplete,
      documentsVerified: documentsVerified,
      passportVerified: passportVerified,
      visaVerified: visaVerified,
      membershipActive: membership.isActive,
      visibleToEmployers: false,
      chatUnlocked: membership.isActive,
      actionRequired: false,
      underReview: false,
      visibilityReason: 'Upload your required identity documents.',
      primaryActionLabel: 'Upload Documents',
      primaryActionSection: CandidateProfileSection.identityDocuments,
    );
  }
}

class CandidateSectionCompletion {
  const CandidateSectionCompletion({
    required this.label,
    required this.state,
    this.missingFields = const [],
    this.statusLabelOverride,
  });

  final String label;
  final CandidateSectionCompletionState state;
  final List<String> missingFields;
  final String? statusLabelOverride;

  int get missingCount => missingFields.length;

  String get statusLabel =>
      statusLabelOverride ??
      switch (state) {
        CandidateSectionCompletionState.complete => 'Complete',
        CandidateSectionCompletionState.incomplete =>
          missingCount > 0 ? '$missingCount missing' : 'Incomplete',
        CandidateSectionCompletionState.underReview => 'Under review',
        CandidateSectionCompletionState.actionRequired => 'Action required',
      };

  IconData get icon => switch (state) {
        CandidateSectionCompletionState.complete => Icons.check_circle_rounded,
        CandidateSectionCompletionState.incomplete =>
          Icons.info_outline_rounded,
        CandidateSectionCompletionState.underReview =>
          Icons.pending_actions_rounded,
        CandidateSectionCompletionState.actionRequired =>
          Icons.warning_amber_rounded,
      };

  Color get color => switch (state) {
        CandidateSectionCompletionState.complete => AppColors.success,
        CandidateSectionCompletionState.incomplete => AppColors.warning,
        CandidateSectionCompletionState.underReview => AppColors.warning,
        CandidateSectionCompletionState.actionRequired => AppColors.error,
      };
}

class CandidateProfileAction {
  const CandidateProfileAction({
    required this.section,
    required this.title,
    required this.detail,
  });

  final CandidateProfileSection section;
  final String title;
  final String detail;
}

class _CompletionCheck {
  const _CompletionCheck(this.label, this.complete);

  final String label;
  final bool complete;
}

CandidateSectionCompletion _section({
  required String label,
  required List<_CompletionCheck> checks,
}) {
  final missing = checks
      .where((check) => !check.complete)
      .map((check) => check.label)
      .toList();
  return CandidateSectionCompletion(
    label: label,
    state: missing.isEmpty
        ? CandidateSectionCompletionState.complete
        : CandidateSectionCompletionState.incomplete,
    missingFields: missing,
  );
}

CandidateSectionCompletion _documentsSection(
  CandidateProfileData profile,
  List<VerificationDocumentData> documents,
) {
  final workDocuments = documents
      .where(
        (document) => CandidateDocumentTypeMapping.isProfessionalDocument(
          document.documentType,
        ),
      )
      .toList();
  final hasCv = profile.resumeUrl.trim().isNotEmpty ||
      workDocuments.any(
        (document) =>
            CandidateDocumentTypeMapping.normalize(document.documentType) ==
            'cv',
      );
  final needsAttention = workDocuments.any(
    (document) => _isActionRequiredStatus(document.status),
  );
  if (needsAttention) {
    return const CandidateSectionCompletion(
      label: 'Documents',
      state: CandidateSectionCompletionState.actionRequired,
    );
  }
  return _section(
    label: 'Documents',
    checks: [_CompletionCheck('CV/resume', hasCv)],
  );
}

CandidateSectionCompletion _identitySection(
  CandidateIdentityDocumentData identity,
) {
  final passportStatus = DocumentStatusService.normalized(
    identity.passportStatus,
    uploaded: identity.hasPassport,
    expiry: identity.passportExpiryDate,
  );
  final visaStatus = DocumentStatusService.normalized(
    identity.visaStatus,
    uploaded: identity.hasVisa,
    expiry: identity.visaExpiryDate,
  );
  final statuses = [passportStatus, if (identity.hasVisa) visaStatus];
  if (statuses.any(_isActionRequiredStatus)) {
    return const CandidateSectionCompletion(
      label: 'Identity Documents',
      state: CandidateSectionCompletionState.actionRequired,
    );
  }
  if (!identity.hasPassport) {
    return const CandidateSectionCompletion(
      label: 'Identity Documents',
      state: CandidateSectionCompletionState.incomplete,
      missingFields: ['passport front and back'],
      statusLabelOverride: 'Passport required',
    );
  }
  if (_isUnderReviewStatus(passportStatus) ||
      (identity.hasVisa && _isUnderReviewStatus(visaStatus))) {
    return const CandidateSectionCompletion(
      label: 'Identity Documents',
      state: CandidateSectionCompletionState.underReview,
      statusLabelOverride: 'Passport verification pending',
    );
  }
  final passportComplete = _isApprovedStatus(passportStatus);
  final visaComplete = !identity.hasVisa || _isApprovedStatus(visaStatus);
  return CandidateSectionCompletion(
    label: 'Identity Documents',
    state: passportComplete && visaComplete
        ? CandidateSectionCompletionState.complete
        : CandidateSectionCompletionState.incomplete,
    missingFields: passportComplete && visaComplete
        ? const []
        : const ['verified identity document'],
  );
}

bool _isApprovedStatus(String status) =>
    status == DocumentStatusService.approved ||
    status == DocumentStatusService.verified;

bool _isUnderReviewStatus(String status) =>
    status == DocumentStatusService.pending ||
    status == DocumentStatusService.pendingVerification ||
    status == DocumentStatusService.underReview;

bool _isActionRequiredStatus(String status) =>
    status == DocumentStatusService.rejected ||
    status == DocumentStatusService.reuploadRequired ||
    status == 'expired';

bool _requiredEmployerSearchProfileComplete(CandidateProfileData profile) =>
    profile.nationality.trim().isNotEmpty &&
    CandidateLocationOptions.isComplete(
      profile.currentCountry,
      profile.currentCity,
    ) &&
    CandidateLocationOptions.isComplete(
      profile.preferredCountry,
      profile.preferredCity,
    ) &&
    CandidateJobHierarchy.profileIsComplete(profile) &&
    profile.availability.trim().isNotEmpty;

class CandidateDocumentTypeMapping {
  const CandidateDocumentTypeMapping._();

  static const identityTypes = {
    'passport',
    'visa',
    'emirates_id',
    'national_id',
    'driving_licence',
    'driving_license',
  };

  static const professionalTypes = {
    'cv',
    'resume',
    'education_certificate',
    'experience_certificate',
    'training_certificate',
    'professional_certificate',
    'professional_licence',
    'trade_certificate',
    'other_document',
  };

  static String normalize(String type) =>
      type.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static bool isIdentityDocument(String type) =>
      identityTypes.contains(normalize(type));

  static bool isProfessionalDocument(String type) {
    final normalized = normalize(type);
    return professionalTypes.contains(normalized) ||
        normalized.contains('certificate') ||
        normalized.contains('resume');
  }
}
