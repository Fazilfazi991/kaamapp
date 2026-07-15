import '../../supabase_backend/kaam_backend.dart';

class CandidateProfileCompletion {
  const CandidateProfileCompletion({
    required this.percentage,
    required this.missingFields,
    required this.helperText,
  });

  final int percentage;
  final List<String> missingFields;
  final String helperText;

  static CandidateProfileCompletion calculate(
    CandidateProfileData profile, {
    List<VerificationDocumentData> documents = const [],
    CandidateIdentityDocumentData? identity,
  }) {
    final identityDocuments = identity ?? const CandidateIdentityDocumentData();
    final checks = <_CompletionCheck>[
      _CompletionCheck('full name', profile.fullName.isNotEmpty, required: true),
      _CompletionCheck('nationality', profile.nationality.isNotEmpty, required: true),
      _CompletionCheck('current location', profile.currentCity.isNotEmpty, required: true),
      _CompletionCheck(
        'preferred work location',
        profile.preferredCity.isNotEmpty,
        required: true,
      ),
      _CompletionCheck(
        'work category',
        profile.jobCategories.isNotEmpty,
        required: true,
      ),
      _CompletionCheck('preferred job role', profile.headline.isNotEmpty, required: true),
      _CompletionCheck('availability', profile.availability.isNotEmpty, required: true),
      _CompletionCheck('phone number', profile.phone.isNotEmpty),
      _CompletionCheck(
        'expected salary',
        profile.expectedSalaryMin != null || profile.expectedSalaryMax != null,
      ),
      _CompletionCheck('bio/about', profile.bio.isNotEmpty),
      _CompletionCheck('years of experience', profile.experienceYears != null),
      _CompletionCheck('skills', profile.skills.isNotEmpty),
      _CompletionCheck('languages', profile.languages.isNotEmpty),
      _CompletionCheck('profile photo', profile.profilePhotoUrl.isNotEmpty),
      _CompletionCheck('CV/resume', profile.resumeUrl.isNotEmpty),
      _CompletionCheck('ID document', documents.isNotEmpty),
      _CompletionCheck('passport uploaded', identityDocuments.hasPassport, required: true),
      _CompletionCheck('visa uploaded', identityDocuments.hasVisa),
      _CompletionCheck(
        'document verification status',
        identityDocuments.hasPassport &&
            identityDocuments.passportStatus.trim().isNotEmpty &&
            identityDocuments.passportStatus != 'not_uploaded',
      ),
    ];

    final completed = checks.where((check) => check.complete).length;
    final percentage = ((completed / checks.length) * 100).round().clamp(0, 100);
    final missing = checks
        .where((check) => check.required && !check.complete)
        .map((check) => check.label)
        .toList();

    return CandidateProfileCompletion(
      percentage: percentage,
      missingFields: missing,
      helperText: percentage >= 90
          ? 'Your profile looks strong.'
          : 'Add skills, experience, and documents to improve your profile.',
    );
  }
}

class _CompletionCheck {
  const _CompletionCheck(this.label, this.complete, {this.required = false});

  final String label;
  final bool complete;
  final bool required;
}
