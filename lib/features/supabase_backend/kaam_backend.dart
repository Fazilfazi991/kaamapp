import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_service.dart';
import '../../core/config/app_config.dart';
import '../candidate/models/candidate_models.dart';
import '../employer/models/employer_models.dart';

enum KaamRole { candidate, employer }

enum KaamAuthDestination {
  roleSelection,
  blocked,
  candidateOnboarding,
  candidateDashboard,
  employerOnboarding,
  employerDashboard,
}

enum KaamProtectedAccess { allowed, blocked, signedOut, wrongRole }

class KaamAccountStatusPolicy {
  const KaamAccountStatusPolicy._();

  static const blockedMessage =
      'Your Kaam account has been blocked. Please contact support if you believe this is a mistake.';

  static bool isBlocked(String? status) => status?.trim() == 'blocked';

  static KaamProtectedAccess protectedAccess({
    required KaamRole? actualRole,
    required String? status,
    required KaamRole expectedRole,
  }) {
    if (actualRole == null) return KaamProtectedAccess.signedOut;
    if (isBlocked(status)) return KaamProtectedAccess.blocked;
    if (actualRole != expectedRole) return KaamProtectedAccess.wrongRole;
    return KaamProtectedAccess.allowed;
  }

  static KaamAuthDestination? blockedDestination(String? status) {
    return isBlocked(status) ? KaamAuthDestination.blocked : null;
  }
}

class CandidateSkillLimits {
  const CandidateSkillLimits._();

  static const maxSkills = 3;

  static String get maxMessage =>
      'You can select a maximum of $maxSkills skills.';
}

class KaamAuthRouteResult {
  const KaamAuthRouteResult({
    required this.destination,
    required this.message,
  });

  final KaamAuthDestination destination;
  final String message;
}

class KaamStoredProfile {
  const KaamStoredProfile({required this.role, required this.status});

  final KaamRole role;
  final String status;
}

class CandidatePrivacySettings {
  const CandidatePrivacySettings({
    this.profileVisible = true,
    this.hidePhoneBeforeMatch = true,
    this.hideEmailBeforeMatch = true,
    this.requireApprovalBeforeChat = true,
    this.allowDocumentSharingAfterMatch = true,
  });

  final bool profileVisible;
  final bool hidePhoneBeforeMatch;
  final bool hideEmailBeforeMatch;
  final bool requireApprovalBeforeChat;
  final bool allowDocumentSharingAfterMatch;
}

class CandidateMembershipData {
  const CandidateMembershipData({
    this.id,
    this.planCode = '',
    this.status = 'inactive',
    this.startedAt = '',
    this.expiresAt = '',
    this.paymentProvider = '',
    this.amount,
    this.currency = 'AED',
    this.isTest = false,
  });

  final String? id;
  final String planCode;
  final String status;
  final String startedAt;
  final String expiresAt;
  final String paymentProvider;
  final num? amount;
  final String currency;
  final bool isTest;

  bool get isActive {
    final expiry = DateTime.tryParse(expiresAt);
    return status == 'active' &&
        expiry != null &&
        expiry.toUtc().isAfter(DateTime.now().toUtc());
  }

  bool get isExpired {
    final expiry = DateTime.tryParse(expiresAt);
    return status == 'expired' ||
        (status == 'active' &&
            expiry != null &&
            !expiry.toUtc().isAfter(DateTime.now().toUtc()));
  }

  factory CandidateMembershipData.fromRow(Map<String, dynamic>? row) {
    return CandidateMembershipData(
      id: row?['id'] as String?,
      planCode: row?['plan_code'] as String? ?? '',
      status: row?['status'] as String? ?? 'inactive',
      startedAt: row?['started_at'] as String? ?? '',
      expiresAt: row?['expires_at'] as String? ?? '',
      paymentProvider: row?['payment_provider'] as String? ?? '',
      amount: row?['amount'] as num?,
      currency: row?['currency'] as String? ?? 'AED',
      isTest: row?['is_test'] as bool? ?? false,
    );
  }
}

class CandidateEmployerVisibility {
  const CandidateEmployerVisibility({
    required this.profileCompleted,
    required this.documentsVerified,
    required this.membershipActive,
    required this.profileVisible,
    this.accountActive = true,
  });

  final bool profileCompleted;
  final bool documentsVerified;
  final bool membershipActive;
  final bool profileVisible;
  final bool accountActive;

  bool get visibleToEmployers =>
      profileCompleted && documentsVerified && profileVisible && accountActive;
}

class TestMembershipActivationAccess {
  const TestMembershipActivationAccess._();

  static bool isAvailable({required bool debugBuild}) => debugBuild;
}

class CandidateProfileData {
  const CandidateProfileData({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.headline = '',
    this.nationality = '',
    this.currentCountry = '',
    this.currentCity = '',
    this.preferredCountry = '',
    this.preferredCity = '',
    this.jobCategories = const [],
    this.skills = const [],
    this.languages = const [],
    this.experienceYears,
    this.expectedSalaryMin,
    this.expectedSalaryMax,
    this.currency = 'AED',
    this.availability = '',
    this.profilePhotoUrl = '',
    this.resumeUrl = '',
    this.bio = '',
    this.isVisible = true,
    this.hidePhoneBeforeMatch = true,
    this.hideEmailBeforeMatch = true,
    this.requireApprovalBeforeChat = true,
    this.allowDocumentSharingAfterMatch = true,
  });

  final String fullName;
  final String phone;
  final String email;
  final String headline;
  final String nationality;
  final String currentCountry;
  final String currentCity;
  final String preferredCountry;
  final String preferredCity;
  final List<String> jobCategories;
  final List<String> skills;
  final List<String> languages;
  final num? experienceYears;
  final int? expectedSalaryMin;
  final int? expectedSalaryMax;
  final String currency;
  final String availability;
  final String profilePhotoUrl;
  final String resumeUrl;
  final String bio;
  final bool isVisible;
  final bool hidePhoneBeforeMatch;
  final bool hideEmailBeforeMatch;
  final bool requireApprovalBeforeChat;
  final bool allowDocumentSharingAfterMatch;

  factory CandidateProfileData.fromRows({
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? candidate,
  }) {
    return CandidateProfileData(
      fullName: profile?['full_name'] as String? ?? '',
      phone: profile?['phone'] as String? ?? '',
      email: profile?['email'] as String? ?? '',
      headline: candidate?['headline'] as String? ?? '',
      nationality: candidate?['nationality'] as String? ?? '',
      currentCountry: candidate?['current_country'] as String? ?? '',
      currentCity: candidate?['current_city'] as String? ?? '',
      preferredCountry: candidate?['preferred_country'] as String? ?? '',
      preferredCity: candidate?['preferred_city'] as String? ?? '',
      jobCategories: _stringList(candidate?['job_categories']),
      skills: _stringList(candidate?['skills']),
      languages: _stringList(candidate?['languages']),
      experienceYears: candidate?['experience_years'] as num?,
      expectedSalaryMin: candidate?['expected_salary_min'] as int?,
      expectedSalaryMax: candidate?['expected_salary_max'] as int?,
      currency: candidate?['currency'] as String? ?? 'AED',
      availability: candidate?['availability'] as String? ?? '',
      profilePhotoUrl: candidate?['profile_photo_url'] as String? ?? '',
      resumeUrl: candidate?['resume_url'] as String? ?? '',
      bio: candidate?['bio'] as String? ?? '',
      isVisible: candidate?['is_visible'] as bool? ?? true,
      hidePhoneBeforeMatch:
          candidate?['hide_phone_before_match'] as bool? ?? true,
      hideEmailBeforeMatch:
          candidate?['hide_email_before_match'] as bool? ?? true,
      requireApprovalBeforeChat:
          candidate?['require_approval_before_chat'] as bool? ?? true,
      allowDocumentSharingAfterMatch:
          candidate?['allow_document_sharing_after_match'] as bool? ?? true,
    );
  }
}

class SkillCategoryData {
  const SkillCategoryData(
      {required this.id, required this.name, required this.iconName});

  final String id;
  final String name;
  final String iconName;

  factory SkillCategoryData.fromRow(Map<String, dynamic> row) =>
      SkillCategoryData(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        iconName: row['icon_name'] as String? ?? '',
      );
}

class SkillData {
  const SkillData(
      {required this.id, required this.categoryId, required this.name});

  final String id;
  final String categoryId;
  final String name;

  factory SkillData.fromRow(Map<String, dynamic> row) => SkillData(
        id: row['id'] as String,
        categoryId: row['category_id'] as String,
        name: row['name'] as String? ?? '',
      );
}

class CandidateSkillData {
  const CandidateSkillData({
    required this.skill,
    required this.category,
    this.isPrimary = false,
    this.experienceRange = '',
    this.skillLevel = '',
    this.uaeExperienceRange = '',
    this.availability = '',
    this.certificateTypes = const [],
    this.otherCertificateName = '',
  });

  final SkillData skill;
  final SkillCategoryData category;
  final bool isPrimary;
  final String experienceRange;
  final String skillLevel;
  final String uaeExperienceRange;
  final String availability;
  final List<String> certificateTypes;
  final String otherCertificateName;
}

class CandidateLocationOptions {
  const CandidateLocationOptions._();

  static const countries = ['UAE', 'India'];
  static const uaeEmirates = [
    'Abu Dhabi',
    'Dubai',
    'Sharjah',
    'Ajman',
    'Umm Al Quwain',
    'Ras Al Khaimah',
    'Fujairah',
  ];
  static const indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Puducherry',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Lakshadweep',
    'Andaman and Nicobar Islands',
  ];

  static List<String> regionsForCountry(String country) {
    return switch (country.trim()) {
      'UAE' => uaeEmirates,
      'India' => indianStates,
      _ => const [],
    };
  }

  static String normalizeRegionForCountry(String country, String region) {
    final trimmed = region.trim();
    if (trimmed.isEmpty) return '';
    final normalized = trimmed.toLowerCase();
    for (final option in regionsForCountry(country)) {
      if (option.toLowerCase() == normalized) return option;
    }
    return '';
  }
}

class CandidateBasicProfileLocationMapper {
  const CandidateBasicProfileLocationMapper._();

  static Map<String, dynamic> candidateProfileValues({
    required String nationality,
    required String currentCountry,
    required String currentLocation,
    required String preferredCountry,
    required String preferredLocation,
  }) {
    final currentCountryValue = _countryOrEmpty(currentCountry);
    final preferredCountryValue = _countryOrEmpty(preferredCountry);
    final currentCityValue = CandidateLocationOptions.normalizeRegionForCountry(
      currentCountryValue,
      currentLocation,
    );
    final preferredCityValue =
        CandidateLocationOptions.normalizeRegionForCountry(
      preferredCountryValue,
      preferredLocation,
    );
    return {
      'nationality': _nullable(nationality),
      'current_country': _nullable(currentCountryValue),
      'current_city': _nullable(currentCityValue),
      'preferred_country': _nullable(preferredCountryValue),
      'preferred_city': _nullable(preferredCityValue),
    };
  }

  static String _countryOrEmpty(String country) {
    final trimmed = country.trim();
    return CandidateLocationOptions.countries.contains(trimmed) ? trimmed : '';
  }
}

class EmployerCompanyData {
  const EmployerCompanyData({
    this.id,
    this.companyName = '',
    this.contactPerson = '',
    this.contactRole = '',
    this.industry = '',
    this.companySize = '',
    this.location = '',
    this.officeArea = '',
    this.hiringNeeds = const [],
    this.description = '',
    this.logoUrl = '',
    this.isVerified = false,
  });

  final String? id;
  final String companyName;
  final String contactPerson;
  final String contactRole;
  final String industry;
  final String companySize;
  final String location;
  final String officeArea;
  final List<String> hiringNeeds;
  final String description;
  final String logoUrl;
  final bool isVerified;

  factory EmployerCompanyData.fromRow(Map<String, dynamic>? row) {
    return EmployerCompanyData(
      id: row?['id'] as String?,
      companyName: row?['company_name'] as String? ?? '',
      contactPerson: row?['contact_person'] as String? ?? '',
      contactRole: row?['contact_role'] as String? ?? '',
      industry: row?['industry'] as String? ?? '',
      companySize: row?['company_size'] as String? ?? '',
      location: row?['city'] as String? ?? '',
      officeArea: row?['office_area'] as String? ?? '',
      hiringNeeds: _stringList(row?['hiring_needs']),
      description: row?['description'] as String? ?? '',
      logoUrl: row?['logo_url'] as String? ?? '',
      isVerified: row?['is_verified'] as bool? ?? false,
    );
  }
}

class EmployerCandidateSearchFilters {
  const EmployerCandidateSearchFilters({
    this.query = '',
    this.category = '',
    this.skill = '',
    this.location = '',
    this.experience = '',
    this.visaStatus = '',
    this.availability = '',
    this.nationality = '',
    this.language = '',
    this.categories = const [],
    this.skills = const [],
    this.locations = const [],
    this.experiences = const [],
    this.visaStatuses = const [],
    this.availabilities = const [],
    this.nationalities = const [],
    this.languages = const [],
    this.verifiedOnly = false,
  });

  final String query;
  final String category;
  final String skill;
  final String location;
  final String experience;
  final String visaStatus;
  final String availability;
  final String nationality;
  final String language;
  final List<String> categories;
  final List<String> skills;
  final List<String> locations;
  final List<String> experiences;
  final List<String> visaStatuses;
  final List<String> availabilities;
  final List<String> nationalities;
  final List<String> languages;
  final bool verifiedOnly;

  List<String> get effectiveCategories =>
      _uniqueValues([...categories, category]);
  List<String> get effectiveSkills => _uniqueValues([...skills, skill]);
  List<String> get effectiveLocations =>
      _uniqueValues([...locations, location]);
  List<String> get effectiveExperiences =>
      _uniqueValues([...experiences, experience]);
  List<String> get effectiveVisaStatuses =>
      _uniqueValues([...visaStatuses, visaStatus]);
  List<String> get effectiveAvailabilities =>
      _uniqueValues([...availabilities, availability]);
  List<String> get effectiveNationalities =>
      _uniqueValues([...nationalities, nationality]);
  List<String> get effectiveLanguages =>
      _uniqueValues([...languages, language]);

  bool get isEmpty =>
      query.trim().isEmpty &&
      effectiveCategories.isEmpty &&
      effectiveSkills.isEmpty &&
      effectiveLocations.isEmpty &&
      effectiveExperiences.isEmpty &&
      effectiveVisaStatuses.isEmpty &&
      effectiveAvailabilities.isEmpty &&
      effectiveNationalities.isEmpty &&
      effectiveLanguages.isEmpty &&
      !verifiedOnly;
}

List<String> _uniqueValues(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    final key = trimmed.toLowerCase();
    if (trimmed.isNotEmpty && seen.add(key)) result.add(trimmed);
  }
  return result;
}

class MultiSelectFilterGroup {
  MultiSelectFilterGroup([Iterable<String> initial = const []])
      : selected = _uniqueValues(initial).toSet();

  final Set<String> selected;

  void toggle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final existing = selected
        .where((item) => item.trim().toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;
    if (existing == null) {
      selected.add(trimmed);
    } else {
      selected.remove(existing);
    }
  }

  void clear() => selected.clear();
}

class KaamUploadResult {
  const KaamUploadResult({
    required this.bucket,
    required this.path,
    required this.displayName,
    this.publicUrl,
  });

  final String bucket;
  final String path;
  final String displayName;
  final String? publicUrl;
}

class VerificationDocumentData {
  const VerificationDocumentData({
    required this.id,
    required this.documentType,
    required this.bucketId,
    required this.filePath,
    required this.status,
  });

  final String id;
  final String documentType;
  final String bucketId;
  final String filePath;
  final String status;

  String get displayName => filePath.split('/').last;

  factory VerificationDocumentData.fromRow(Map<String, dynamic> row) {
    return VerificationDocumentData(
      id: row['id'] as String? ?? '',
      documentType: row['document_type'] as String? ?? '',
      bucketId: row['bucket_id'] as String? ?? '',
      filePath: row['file_path'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
    );
  }
}

class CandidateIdentityDocumentData {
  const CandidateIdentityDocumentData({
    this.id,
    this.passportFileUrl = '',
    this.visaFileUrl = '',
    this.passportNumber = '',
    this.passportIssueDate = '',
    this.passportExpiryDate = '',
    this.countryOfIssue = '',
    this.fullName = '',
    this.nationality = '',
    this.gender = '',
    this.dob = '',
    this.placeOfBirth = '',
    this.visaNumber = '',
    this.visaType = '',
    this.occupation = '',
    this.sponsor = '',
    this.uidNumber = '',
    this.emiratesId = '',
    this.visaIssueDate = '',
    this.visaExpiryDate = '',
    this.passportVerified = false,
    this.visaVerified = false,
    this.ocrCompleted = false,
    this.passportStatus = 'pending_verification',
    this.visaStatus = 'not_uploaded',
    this.passportUploadedAt = '',
    this.visaUploadedAt = '',
    this.passportVerifiedAt = '',
    this.visaVerifiedAt = '',
    this.passportVersion = 0,
    this.visaVersion = 0,
    this.passportIsActive = false,
    this.visaIsActive = false,
    this.passportArchived = false,
    this.visaArchived = false,
    this.passportExpiryNotificationSent = false,
    this.visaExpiryNotificationSent = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String? id;
  final String passportFileUrl;
  final String visaFileUrl;
  final String passportNumber;
  final String passportIssueDate;
  final String passportExpiryDate;
  final String countryOfIssue;
  final String fullName;
  final String nationality;
  final String gender;
  final String dob;
  final String placeOfBirth;
  final String visaNumber;
  final String visaType;
  final String occupation;
  final String sponsor;
  final String uidNumber;
  final String emiratesId;
  final String visaIssueDate;
  final String visaExpiryDate;
  final bool passportVerified;
  final bool visaVerified;
  final bool ocrCompleted;
  final String passportStatus;
  final String visaStatus;
  final String passportUploadedAt;
  final String visaUploadedAt;
  final String passportVerifiedAt;
  final String visaVerifiedAt;
  final int passportVersion;
  final int visaVersion;
  final bool passportIsActive;
  final bool visaIsActive;
  final bool passportArchived;
  final bool visaArchived;
  final bool passportExpiryNotificationSent;
  final bool visaExpiryNotificationSent;
  final String createdAt;
  final String updatedAt;

  bool get hasPassport => passportFileUrl.trim().isNotEmpty;
  bool get hasVisa => visaFileUrl.trim().isNotEmpty;

  factory CandidateIdentityDocumentData.fromRow(Map<String, dynamic>? row) {
    return CandidateIdentityDocumentData(
      id: row?['id'] as String?,
      passportFileUrl: row?['passport_file_url'] as String? ?? '',
      visaFileUrl: row?['visa_file_url'] as String? ?? '',
      passportNumber: row?['passport_number'] as String? ?? '',
      passportIssueDate: row?['passport_issue_date'] as String? ?? '',
      passportExpiryDate: row?['passport_expiry_date'] as String? ?? '',
      countryOfIssue: row?['country_of_issue'] as String? ?? '',
      fullName: row?['full_name'] as String? ?? '',
      nationality: row?['nationality'] as String? ?? '',
      gender: row?['gender'] as String? ?? '',
      dob: row?['dob'] as String? ?? '',
      placeOfBirth: row?['place_of_birth'] as String? ?? '',
      visaNumber: row?['visa_number'] as String? ?? '',
      visaType: row?['visa_type'] as String? ?? '',
      occupation: row?['occupation'] as String? ?? '',
      sponsor: row?['sponsor'] as String? ?? '',
      uidNumber: row?['uid_number'] as String? ?? '',
      emiratesId: row?['emirates_id'] as String? ?? '',
      visaIssueDate: row?['visa_issue_date'] as String? ?? '',
      visaExpiryDate: row?['visa_expiry_date'] as String? ?? '',
      passportVerified: row?['passport_verified'] as bool? ?? false,
      visaVerified: row?['visa_verified'] as bool? ?? false,
      ocrCompleted: row?['ocr_completed'] as bool? ?? false,
      passportStatus:
          row?['passport_status'] as String? ?? 'pending_verification',
      visaStatus: row?['visa_status'] as String? ?? 'not_uploaded',
      passportUploadedAt: row?['passport_uploaded_at'] as String? ?? '',
      visaUploadedAt: row?['visa_uploaded_at'] as String? ?? '',
      passportVerifiedAt: row?['passport_verified_at'] as String? ?? '',
      visaVerifiedAt: row?['visa_verified_at'] as String? ?? '',
      passportVersion: row?['passport_version'] as int? ?? 0,
      visaVersion: row?['visa_version'] as int? ?? 0,
      passportIsActive: row?['passport_is_active'] as bool? ?? false,
      visaIsActive: row?['visa_is_active'] as bool? ?? false,
      passportArchived: row?['passport_archived'] as bool? ?? false,
      visaArchived: row?['visa_archived'] as bool? ?? false,
      passportExpiryNotificationSent:
          row?['passport_expiry_notification_sent'] as bool? ?? false,
      visaExpiryNotificationSent:
          row?['visa_expiry_notification_sent'] as bool? ?? false,
      createdAt: row?['created_at'] as String? ?? '',
      updatedAt: row?['updated_at'] as String? ?? '',
    );
  }
}

class CandidateDocumentVersionData {
  const CandidateDocumentVersionData({
    required this.id,
    required this.documentType,
    required this.filePath,
    required this.versionNumber,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String documentType;
  final String filePath;
  final int versionNumber;
  final String status;
  final bool isActive;
  final String createdAt;

  String get displayName => filePath.split('/').last;

  factory CandidateDocumentVersionData.fromRow(Map<String, dynamic> row) {
    return CandidateDocumentVersionData(
      id: row['id'] as String? ?? '',
      documentType: row['document_type'] as String? ?? '',
      filePath: row['file_path'] as String? ?? '',
      versionNumber: row['version_number'] as int? ?? 1,
      status: row['status'] as String? ?? 'pending_verification',
      isActive: row['is_active'] as bool? ?? false,
      createdAt: row['created_at'] as String? ?? '',
    );
  }
}

class CandidateDocumentNotificationData {
  const CandidateDocumentNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.createdAt,
    this.scheduledFor = '',
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String notificationType;
  final String createdAt;
  final String scheduledFor;
  final bool isRead;

  factory CandidateDocumentNotificationData.fromRow(Map<String, dynamic> row) {
    return CandidateDocumentNotificationData(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      notificationType: row['notification_type'] as String? ?? '',
      createdAt: row['created_at'] as String? ?? '',
      scheduledFor: row['scheduled_for'] as String? ?? '',
      isRead: row['is_read'] as bool? ?? false,
    );
  }
}

class KaamAuthRepository {
  const KaamAuthRepository();

  SupabaseClient get _client => _requireClient();

  User? get currentUser => SupabaseService.maybeClient?.auth.currentUser;

  Future<bool> signInWithOtp({
    required String email,
    KaamRole? role,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ArgumentError('Email address is required.');
    }

    await _client.auth.signInWithOtp(
      email: trimmedEmail,
      shouldCreateUser: true,
      data: role == null ? null : {'role': role.name},
    );
    _debug(
        'Email OTP requested${role == null ? '' : ' for role ${role.name}'}');
    return true;
  }

  Future<KaamAuthRouteResult> verifyOtp({
    required String email,
    required String token,
    KaamRole? role,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.length != AppConfig.emailOtpLength) {
      throw ArgumentError(
          'Enter the ${AppConfig.emailOtpLength}-digit OTP code.');
    }

    await _client.auth.verifyOTP(
      email: email.trim(),
      token: trimmedToken,
      type: OtpType.email,
    );
    if (_client.auth.currentSession == null ||
        _client.auth.currentUser == null) {
      throw StateError('OTP verified but no Supabase session was created.');
    }
    final existingProfile = await _storedProfile();
    if (existingProfile == null) {
      if (role == null) {
        return const KaamAuthRouteResult(
          destination: KaamAuthDestination.roleSelection,
          message:
              'We could not find a KAAM profile for this email. Choose how you want to use KAAM to continue.',
        );
      }
      await ensureProfile(role: role);
      return resolvePostOtpDestination(fallbackRole: role);
    }
    if (KaamAccountStatusPolicy.isBlocked(existingProfile.status)) {
      await signOut();
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.blocked,
        message: KaamAccountStatusPolicy.blockedMessage,
      );
    }

    final result =
        await resolvePostOtpDestination(fallbackRole: existingProfile.role);
    if (role != null) {
      return KaamAuthRouteResult(
        destination: result.destination,
        message: result.destination == KaamAuthDestination.blocked
            ? result.message
            : 'This email is already registered as a ${existingProfile.role.name}. Continuing to your account.',
      );
    }
    return result;
  }

  Future<KaamStoredProfile?> _storedProfile() async {
    final client = _client;
    final user = _requireUser(client);
    final profile = await client
        .from('profiles')
        .select('role,status')
        .eq('id', user.id)
        .maybeSingle();
    final roleName = profile?['role'] as String?;
    if (roleName == null) return null;
    return KaamStoredProfile(
      role: _roleFromName(roleName),
      status: profile?['status'] as String? ?? 'draft',
    );
  }

  Future<KaamRole?> currentBackendRole() async =>
      (await _storedProfile())?.role;

  Future<KaamProtectedAccess> checkProtectedAccess(
      KaamRole expectedRole) async {
    final client = _client;
    await SupabaseService.waitForSessionRecovery();
    if (client.auth.currentUser == null) return KaamProtectedAccess.signedOut;
    final profile = await _storedProfile();
    final access = KaamAccountStatusPolicy.protectedAccess(
      actualRole: profile?.role,
      status: profile?.status,
      expectedRole: expectedRole,
    );
    if (access == KaamProtectedAccess.blocked) {
      await signOut();
    }
    return access;
  }

  Future<void> ensureProfile({required KaamRole role}) async {
    final client = _client;
    final user = _requireUser(client);
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    await client.from('profiles').upsert({
      'id': user.id,
      'role': role.name,
      'email': user.email,
      'phone': user.phone,
      'status': 'active',
    }, onConflict: 'id');
  }

  Future<KaamAuthRouteResult> resolvePostOtpDestination({
    required KaamRole fallbackRole,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await _ensureCurrentProfileNotBlocked(client);
    await _ensureCurrentProfileNotBlocked(client);
    final profile = await client
        .from('profiles')
        .select('role,status')
        .eq('id', user.id)
        .maybeSingle();
    final roleName = profile?['role'] as String?;
    final role = roleName == null ? fallbackRole : _roleFromName(roleName);
    final status = profile?['status'] as String?;

    if (profile == null) {
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.roleSelection,
        message: 'Account verified. Choose how you want to use KAAM.',
      );
    }
    if (KaamAccountStatusPolicy.isBlocked(status)) {
      await signOut();
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.blocked,
        message: KaamAccountStatusPolicy.blockedMessage,
      );
    }

    if (role == KaamRole.candidate) {
      final candidate = await client
          .from('candidate_profiles')
          .select(
            'id,headline,nationality,current_city,preferred_city,job_categories,availability',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (_candidateOnboardingComplete(candidate)) {
        return const KaamAuthRouteResult(
          destination: KaamAuthDestination.candidateDashboard,
          message: 'Welcome back. Continuing to your account.',
        );
      }
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.candidateOnboarding,
        message: 'Account verified. Let\'s create your profile.',
      );
    }

    final company = await client
        .from('employer_companies')
        .select('id,company_name')
        .eq('owner_id', user.id)
        .limit(1)
        .maybeSingle();
    if ((company?['company_name'] as String? ?? '').trim().isNotEmpty) {
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.employerDashboard,
        message: 'Welcome back. Continuing to your account.',
      );
    }
    return const KaamAuthRouteResult(
      destination: KaamAuthDestination.employerOnboarding,
      message: 'Account verified. Let\'s create your company profile.',
    );
  }

  Future<void> signOut() async {
    await SupabaseService.maybeClient?.auth.signOut(scope: SignOutScope.global);
  }
}

class QaToolsRepository {
  const QaToolsRepository();

  SupabaseClient get _client => _requireClient();

  User? get currentUser => SupabaseService.maybeClient?.auth.currentUser;

  Future<String> currentRole() async {
    final user = _requireUser(_client);
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return row?['role'] as String? ?? 'unknown';
  }

  Future<void> reset(String action) async {
    await _client.rpc('qa_reset', params: {
      'action': action,
      'build_version': 'flutter',
      'platform': defaultTargetPlatform.name,
    });
  }

  Future<void> signOut() async {
    await SupabaseService.maybeClient?.auth.signOut();
  }
}

class CandidateProfileRepository {
  const CandidateProfileRepository();

  SupabaseClient get _client => _requireClient();

  Future<CandidateProfileData> loadCurrentProfile() async {
    final client = _client;
    final user = _requireUser(client);

    final profile =
        await client.from('profiles').select().eq('id', user.id).maybeSingle();
    final candidate = await client
        .from('candidate_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return CandidateProfileData.fromRows(
        profile: profile, candidate: candidate);
  }

  Future<CandidateProfileData> upsertBasicProfile({
    required String fullName,
    required String phone,
    required String nationality,
    required String currentCountry,
    required String currentLocation,
    required String preferredCountry,
    required String preferredLocation,
  }) async {
    final client = _client;
    final user = _requireUser(client);

    await client.from('profiles').upsert({
      'id': user.id,
      'role': KaamRole.candidate.name,
      'email': user.email,
      'phone': _nullable(phone),
      'full_name': fullName.trim(),
      'status': 'active',
    }, onConflict: 'id');

    await client.from('candidate_profiles').upsert({
      'id': user.id,
      ...CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: nationality,
        currentCountry: currentCountry,
        currentLocation: currentLocation,
        preferredCountry: preferredCountry,
        preferredLocation: preferredLocation,
      ),
    }, onConflict: 'id');

    _debug('Candidate basic profile saved');
    return loadCurrentProfile();
  }

  Future<CandidateProfileData> updateWorkProfile(
      Map<String, dynamic> values) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);

    await client.from('candidate_profiles').upsert({
      'id': user.id,
      ...values,
    }, onConflict: 'id');

    _debug('Candidate work profile saved');
    return loadCurrentProfile();
  }

  Future<List<SkillCategoryData>> loadSkillCategories() async {
    final rows = await _client
        .from('skill_categories')
        .select('id,name,icon_name')
        .eq('is_active', true)
        .order('sort_order');
    return rows.map(SkillCategoryData.fromRow).toList();
  }

  Future<List<SkillData>> loadSkills(
      {Iterable<String> categoryIds = const []}) async {
    var query = _client
        .from('skills')
        .select('id,category_id,name')
        .eq('is_active', true)
        .eq('is_approved', true);
    final ids = categoryIds.toList();
    if (ids.isNotEmpty) query = query.inFilter('category_id', ids);
    final rows = await query.order('sort_order');
    return rows.map(SkillData.fromRow).toList();
  }

  Future<List<CandidateSkillData>> loadMySkills() async {
    final user = _requireUser(_client);
    final rows = await _client
        .from('candidate_skills')
        .select(
            'is_primary,experience_range,skill_level,uae_experience_range,availability,certificate_types,other_certificate_name,skills!inner(id,name,category_id,skill_categories!inner(id,name,icon_name))')
        .eq('candidate_id', user.id);
    return rows.map((row) {
      final skillRow = Map<String, dynamic>.from(row['skills'] as Map);
      final categoryRow =
          Map<String, dynamic>.from(skillRow['skill_categories'] as Map);
      return CandidateSkillData(
        skill: SkillData.fromRow(skillRow),
        category: SkillCategoryData.fromRow(categoryRow),
        isPrimary: row['is_primary'] as bool? ?? false,
        experienceRange: row['experience_range'] as String? ?? '',
        skillLevel: row['skill_level'] as String? ?? '',
        uaeExperienceRange: row['uae_experience_range'] as String? ?? '',
        availability: row['availability'] as String? ?? '',
        certificateTypes: _stringList(row['certificate_types']),
        otherCertificateName: row['other_certificate_name'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> saveSkills({
    required List<CandidateSkillData> selections,
  }) async {
    final user = _requireUser(_client);
    await _ensureCurrentProfileNotBlocked(_client);
    if (selections.isEmpty ||
        selections.length > CandidateSkillLimits.maxSkills) {
      throw ArgumentError(
          'Choose between 1 and ${CandidateSkillLimits.maxSkills} skills.');
    }
    if (selections.where((item) => item.isPrimary).length != 1) {
      throw ArgumentError('Choose exactly one main profession.');
    }
    final skillIds = selections.map((item) => item.skill.id).toSet();
    if (skillIds.length != selections.length) {
      throw ArgumentError('Duplicate skills are not allowed.');
    }
    final primary = selections.firstWhere((item) => item.isPrimary);
    if (primary.experienceRange.isEmpty || primary.skillLevel.isEmpty) {
      throw ArgumentError(
          'Add experience and skill level for your main profession.');
    }

    // Clear the old primary before assigning the replacement: the database
    // intentionally permits only one primary skill per candidate.
    await _client
        .from('candidate_skills')
        .update({'is_primary': false}).eq('candidate_id', user.id);
    await _client.from('candidate_skills').upsert([
      for (final item in selections)
        {
          'candidate_id': user.id,
          'skill_id': item.skill.id,
          'is_primary': false,
          'experience_range': _nullable(item.experienceRange),
          'skill_level': _nullable(item.skillLevel),
          'uae_experience_range': _nullable(item.uaeExperienceRange),
          'availability': _nullable(item.availability),
          'certificate_types': item.certificateTypes,
          'other_certificate_name': _nullable(item.otherCertificateName),
        },
    ], onConflict: 'candidate_id,skill_id');
    await _client
        .from('candidate_skills')
        .update({'is_primary': true})
        .eq('candidate_id', user.id)
        .eq('skill_id', primary.skill.id);
    await _client
        .from('candidate_skills')
        .delete()
        .eq('candidate_id', user.id)
        .not('skill_id', 'in', '(${skillIds.map((id) => '"$id"').join(',')})');
    await updateWorkProfile({
      'headline': primary.skill.name,
      'job_categories':
          selections.map((item) => item.category.name).toSet().toList(),
      'skills': selections.map((item) => item.skill.name).toList(),
      'availability':
          primary.availability.isEmpty ? null : primary.availability,
    });
  }

  Future<void> submitCustomSkill({
    required String categoryId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 50) {
      throw ArgumentError('Custom skill names must be 2 to 50 characters.');
    }
    final user = _requireUser(_client);
    await _ensureCurrentProfileNotBlocked(_client);
    final existing = await loadSkills(categoryIds: [categoryId]);
    if (existing
        .any((skill) => skill.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError(
          'That skill is already available. Select it from the list.');
    }
    await _client.from('candidate_custom_skills').upsert({
      'candidate_id': user.id,
      'category_id': categoryId,
      'skill_name': trimmed,
      'approval_status': 'pending',
    }, onConflict: 'candidate_id,category_id,skill_name');
  }

  Future<CandidateProfileData> updateProfilePhoto(String publicUrl) async {
    return updateWorkProfile({'profile_photo_url': publicUrl});
  }

  Future<CandidateProfileData> updateResumePath(String path) async {
    return updateWorkProfile({'resume_url': path});
  }

  Future<CandidateProfileData> updateVisibility(bool isVisible) async {
    return updateWorkProfile({'is_visible': isVisible});
  }

  Future<CandidatePrivacySettings> loadPrivacySettings() async {
    final profile = await loadCurrentProfile();
    return CandidatePrivacySettings(
      profileVisible: profile.isVisible,
      hidePhoneBeforeMatch: profile.hidePhoneBeforeMatch,
      hideEmailBeforeMatch: profile.hideEmailBeforeMatch,
      requireApprovalBeforeChat: profile.requireApprovalBeforeChat,
      allowDocumentSharingAfterMatch: profile.allowDocumentSharingAfterMatch,
    );
  }

  Future<CandidatePrivacySettings> updatePrivacySettings(
    CandidatePrivacySettings settings,
  ) async {
    final profile = await updateWorkProfile({
      'is_visible': settings.profileVisible,
      'hide_phone_before_match': settings.hidePhoneBeforeMatch,
      'hide_email_before_match': settings.hideEmailBeforeMatch,
      'require_approval_before_chat': settings.requireApprovalBeforeChat,
      'allow_document_sharing_after_match':
          settings.allowDocumentSharingAfterMatch,
    });
    return CandidatePrivacySettings(
      profileVisible: profile.isVisible,
      hidePhoneBeforeMatch: profile.hidePhoneBeforeMatch,
      hideEmailBeforeMatch: profile.hideEmailBeforeMatch,
      requireApprovalBeforeChat: profile.requireApprovalBeforeChat,
      allowDocumentSharingAfterMatch: profile.allowDocumentSharingAfterMatch,
    );
  }

  Future<CandidateIdentityDocumentData> loadIdentityDocuments() async {
    final client = _client;
    final user = _requireUser(client);
    final row = await client
        .from('candidate_documents')
        .select()
        .eq('candidate_id', user.id)
        .maybeSingle();
    return CandidateIdentityDocumentData.fromRow(row);
  }

  Future<CandidateMembershipData> loadMembership() async {
    final client = _client;
    final user = _requireUser(client);
    try {
      final row = await client
          .from('candidate_memberships')
          .select(
              'id,plan_code,status,started_at,expires_at,payment_provider,amount,currency,is_test')
          .eq('candidate_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (kDebugMode) {
        final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
        debugPrint(
            '[Membership] host=$host table_query=success has_record=${row != null}');
      }
      return CandidateMembershipData.fromRow(row);
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
        debugPrint(
            '[Membership] host=$host table_query=fallback code=${error.code ?? 'unknown'}');
      }
      return const CandidateMembershipData();
    } on Object catch (error) {
      if (kDebugMode) {
        final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
        debugPrint(
            '[Membership] host=$host table_query=fallback code=${error.runtimeType}');
      }
      return const CandidateMembershipData();
    }
  }

  Future<CandidateMembershipData> activateTestMembership() async {
    if (!TestMembershipActivationAccess.isAvailable(debugBuild: kDebugMode)) {
      throw StateError(
          'Test membership activation is only available in debug builds.');
    }
    await _client.rpc('activate_test_candidate_membership');
    return loadMembership();
  }

  Future<CandidateIdentityDocumentData> saveIdentityDocuments(
    Map<String, dynamic> values, {
    Map<String, dynamic> profileValues = const {},
    Map<String, dynamic> candidateValues = const {},
  }) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    var stage = 'candidate profile';
    try {
      // Document onboarding can happen before the basic profile form. Create
      // the minimal parent row first so candidate_documents never violates its
      // candidate_id foreign key.
      await client.from('candidate_profiles').upsert({
        'id': user.id,
      }, onConflict: 'id');
      stage = 'load existing document';
      final existing = await loadIdentityDocuments();
      final now = DateTime.now().toUtc().toIso8601String();
      final saveValues = Map<String, dynamic>.from(values);

      if (saveValues['passport_file_url'] != null) {
        final version = existing.passportVersion + 1;
        saveValues.addAll({
          'passport_status': 'pending_verification',
          'passport_uploaded_at': now,
          'passport_verified_at': null,
          'passport_version': version,
          'passport_is_active': true,
          'passport_archived': existing.hasPassport,
          'passport_verified': false,
          'passport_expiry_notification_sent': false,
        });
      }

      if (saveValues['visa_file_url'] != null) {
        final version = existing.visaVersion + 1;
        saveValues.addAll({
          'visa_status': 'pending_verification',
          'visa_uploaded_at': now,
          'visa_verified_at': null,
          'visa_version': version,
          'visa_is_active': true,
          'visa_archived': existing.hasVisa,
          'visa_verified': false,
          'visa_expiry_notification_sent': false,
        });
      }

      stage = 'save main document';
      if (kDebugMode) {
        debugPrint(
            '[IdentitySave] stage=$stage table=candidate_documents fields=${{
          for (final entry in saveValues.entries)
            entry.key: entry.value.runtimeType.toString(),
          'candidate_id': user.id.runtimeType.toString(),
        }}');
      }
      final row = await client
          .from('candidate_documents')
          .upsert({
            'candidate_id': user.id,
            ...saveValues,
          }, onConflict: 'candidate_id')
          .select()
          .single();

      final documentId = row['id'] as String?;
      if (documentId == null || documentId.isEmpty) {
        throw StateError('Main document save did not return an ID.');
      }
      if (saveValues['passport_file_url'] != null) {
        await _saveDocumentHistorySafely(
          client,
          candidateDocumentId: documentId,
          candidateId: user.id,
          documentType: 'passport',
          filePath: saveValues['passport_file_url'] as String? ?? '',
          versionNumber: saveValues['passport_version'] as int? ?? 1,
          extractedDetails: _documentVersionDetails(saveValues, 'passport'),
          replaced: existing.hasPassport,
          expiryDate: saveValues['passport_expiry_date'] as String? ??
              existing.passportExpiryDate,
        );
      }
      if (saveValues['visa_file_url'] != null) {
        await _saveDocumentHistorySafely(
          client,
          candidateDocumentId: documentId,
          candidateId: user.id,
          documentType: 'visa',
          filePath: saveValues['visa_file_url'] as String? ?? '',
          versionNumber: saveValues['visa_version'] as int? ?? 1,
          extractedDetails: _documentVersionDetails(saveValues, 'visa'),
          replaced: existing.hasVisa,
          expiryDate: saveValues['visa_expiry_date'] as String? ??
              existing.visaExpiryDate,
        );
      }

      if (profileValues.isNotEmpty) {
        stage = 'update profile';
        await client.from('profiles').update(profileValues).eq('id', user.id);
      }
      if (candidateValues.isNotEmpty) {
        stage = 'update candidate profile';
        await client.from('candidate_profiles').upsert({
          'id': user.id,
          ...candidateValues,
        }, onConflict: 'id');
      }

      return CandidateIdentityDocumentData.fromRow(row);
    } catch (error) {
      _debugIdentitySaveFailure(stage: stage, error: error);
      rethrow;
    }
  }

  Future<List<CandidateDocumentVersionData>> loadDocumentVersions({
    String? documentType,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    var query = client
        .from('candidate_document_versions')
        .select()
        .eq('candidate_id', user.id);
    if (documentType != null) {
      query = query.eq('document_type', documentType);
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.map(CandidateDocumentVersionData.fromRow).toList();
  }

  Future<List<CandidateDocumentNotificationData>>
      loadDocumentNotifications() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('candidate_document_notifications')
        .select()
        .eq('candidate_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(CandidateDocumentNotificationData.fromRow).toList();
  }

  Future<void> markDocumentNotificationRead(String id) async {
    if (id.trim().isEmpty) return;
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await client
        .from('candidate_document_notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('candidate_id', user.id);
  }

  Future<void> _archiveDocumentVersions(
    SupabaseClient client,
    String candidateId,
    String documentType,
  ) async {
    await client
        .from('candidate_document_versions')
        .update({'is_active': false})
        .eq('candidate_id', candidateId)
        .eq('document_type', documentType);
  }

  Future<void> _saveDocumentHistorySafely(
    SupabaseClient client, {
    required String candidateDocumentId,
    required String candidateId,
    required String documentType,
    required String filePath,
    required int versionNumber,
    required Map<String, dynamic> extractedDetails,
    required bool replaced,
    required String expiryDate,
  }) async {
    try {
      await _archiveDocumentVersions(client, candidateId, documentType);
      await _insertDocumentVersion(
        client,
        candidateDocumentId: candidateDocumentId,
        candidateId: candidateId,
        documentType: documentType,
        filePath: filePath,
        versionNumber: versionNumber,
        extractedDetails: extractedDetails,
      );
      await _createDocumentNotifications(
        client,
        candidateId: candidateId,
        documentType: documentType,
        replaced: replaced,
        expiryDate: expiryDate,
      );
    } catch (error) {
      _debugIdentitySaveFailure(
          stage: 'document history ($documentType)', error: error);
    }
  }

  void _debugIdentitySaveFailure(
      {required String stage, required Object error}) {
    if (!kDebugMode) return;
    final postgrest = error is PostgrestException ? error : null;
    debugPrint(
      '[IdentitySave] failed stage=$stage type=${error.runtimeType} '
      'code=${postgrest?.code ?? 'unknown'} '
      'message=${postgrest?.message ?? error.runtimeType} '
      'details=${postgrest?.details ?? ''} hint=${postgrest?.hint ?? ''}',
    );
  }

  Future<void> _insertDocumentVersion(
    SupabaseClient client, {
    required String? candidateDocumentId,
    required String candidateId,
    required String documentType,
    required String filePath,
    required int versionNumber,
    required Map<String, dynamic> extractedDetails,
  }) async {
    if (filePath.trim().isEmpty) return;
    await client.from('candidate_document_versions').insert({
      'candidate_document_id': candidateDocumentId,
      'candidate_id': candidateId,
      'document_type': documentType,
      'file_path': filePath,
      'version_number': versionNumber,
      'status': 'pending_verification',
      'is_active': true,
      'extracted_details': extractedDetails,
    });
  }

  Map<String, dynamic> _documentVersionDetails(
    Map<String, dynamic> values,
    String documentType,
  ) {
    final keys = documentType == 'passport'
        ? const [
            'full_name',
            'passport_number',
            'passport_issue_date',
            'passport_expiry_date',
            'country_of_issue',
            'nationality',
            'gender',
            'dob',
            'place_of_birth',
            'ocr_completed',
          ]
        : const [
            'visa_number',
            'visa_type',
            'occupation',
            'sponsor',
            'uid_number',
            'emirates_id',
            'visa_issue_date',
            'visa_expiry_date',
            'ocr_completed',
          ];
    return {
      for (final key in keys)
        if (values[key] != null) key: values[key],
    };
  }

  Future<void> _createDocumentNotifications(
    SupabaseClient client, {
    required String candidateId,
    required String documentType,
    required bool replaced,
    required String expiryDate,
  }) async {
    final label = documentType == 'passport' ? 'Passport' : 'Visa';
    final rows = <Map<String, dynamic>>[
      {
        'candidate_id': candidateId,
        'document_type': documentType,
        'notification_type':
            replaced ? 'document_replaced' : 'document_uploaded',
        'title': replaced ? '$label replaced' : '$label uploaded',
        'body': replaced
            ? 'Your new $label is saved. The previous version remains archived.'
            : 'Your $label is saved securely.',
      },
      {
        'candidate_id': candidateId,
        'document_type': documentType,
        'notification_type': 'verification_pending',
        'title': '$label verification pending',
        'body': 'KAAM will show this document as pending until it is reviewed.',
      },
    ];
    final expiry = DateTime.tryParse(expiryDate.trim());
    if (expiry != null) {
      for (final days in [90, 60, 30, 7]) {
        rows.add({
          'candidate_id': candidateId,
          'document_type': documentType,
          'notification_type': '${documentType}_expiring',
          'title': '$label expires in $days days',
          'body': 'Please upload a renewed $label before expiry.',
          'scheduled_for':
              expiry.subtract(Duration(days: days)).toUtc().toIso8601String(),
        });
      }
    }
    await client.from('candidate_document_notifications').insert(rows);
  }
}

class EmployerRepository {
  const EmployerRepository();

  SupabaseClient get _client => _requireClient();

  Future<EmployerCompanyData?> loadMyCompany() async {
    final client = _client;
    final user = _requireUser(client);

    final row = await client
        .from('employer_companies')
        .select()
        .eq('owner_id', user.id)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : EmployerCompanyData.fromRow(row);
  }

  Future<EmployerCompanyData> upsertCompanyProfile({
    required String companyName,
    required String industry,
    required String companySize,
    required String location,
    required String branch,
    required String contactName,
    required String contactRole,
    String description = '',
    List<String> hiringNeeds = const [],
  }) async {
    final client = _client;
    final user = _requireUser(client);

    await client.from('profiles').upsert({
      'id': user.id,
      'role': KaamRole.employer.name,
      'email': user.email,
      'phone': user.phone,
      'full_name': _nullable(contactName),
      'status': 'active',
    }, onConflict: 'id');

    final existing = await client
        .from('employer_companies')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1)
        .maybeSingle();

    final values = {
      'owner_id': user.id,
      'company_name': companyName.trim(),
      'industry': _nullable(industry),
      'company_size': _nullable(companySize),
      'city': _nullable(location),
      'office_area': _nullable(branch),
      'contact_person': _nullable(contactName),
      'contact_role': _nullable(contactRole),
      'hiring_needs': hiringNeeds,
      'description': _nullable(description),
      'status': 'active',
    };

    if (existing == null) {
      await client.from('employer_companies').insert(values);
    } else {
      await client
          .from('employer_companies')
          .update(values)
          .eq('id', existing['id']);
    }

    _debug('Employer company profile saved');
    return await loadMyCompany() ?? const EmployerCompanyData();
  }

  Future<EmployerCompanyData> updateCompanyLogo(String publicUrl) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await client
        .from('employer_companies')
        .update({'logo_url': publicUrl}).eq('owner_id', user.id);
    return await loadMyCompany() ?? const EmployerCompanyData();
  }

  Future<List<EmployerHiringRequirement>> hiringRequirements() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('employer_hiring_requirements')
        .select()
        .eq('employer_id', user.id)
        .order('updated_at', ascending: false);
    return rows.map(EmployerHiringRequirement.fromRow).toList();
  }

  Future<EmployerHiringRequirement> saveHiringRequirement(
    EmployerHiringRequirement requirement,
  ) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    final company = await loadMyCompany();
    if (company?.id == null) {
      throw StateError(
          'Create your company profile before adding hiring requirements.');
    }
    final values = {
      'employer_id': user.id,
      'company_id': company!.id,
      'role': requirement.role,
      'custom_role': _nullable(requirement.customRole),
      'openings': requirement.openings,
      'salary_range': requirement.salaryRange,
      'work_location': requirement.workLocation,
      'working_hours': requirement.workingHours,
      'accommodation_provided': requirement.accommodationProvided,
      'transport_provided': requirement.transportProvided,
      'visa_provided': requirement.visaProvided,
      'immediate_joining': requirement.immediateJoining,
      'description': _nullable(requirement.description),
      'status': requirement.status,
    };
    final Map<String, dynamic> row;
    if (requirement.id == null) {
      row = await client
          .from('employer_hiring_requirements')
          .insert(values)
          .select()
          .single();
    } else {
      row = await client
          .from('employer_hiring_requirements')
          .update(values)
          .eq('id', requirement.id!)
          .select()
          .single();
    }
    return EmployerHiringRequirement.fromRow(row);
  }

  Future<void> updateHiringRequirementStatus(String id, String status) async {
    if (id.isEmpty) throw ArgumentError('Hiring requirement ID is missing.');
    await _ensureCurrentProfileNotBlocked(_client);
    await _client
        .from('employer_hiring_requirements')
        .update({'status': status}).eq('id', id);
  }

  Future<void> deleteHiringRequirement(String id) async {
    if (id.isEmpty) throw ArgumentError('Hiring requirement ID is missing.');
    await _ensureCurrentProfileNotBlocked(_client);
    await _client.from('employer_hiring_requirements').delete().eq('id', id);
  }

  Future<List<EmployerCandidate>> searchCandidates({
    String? query,
    EmployerCandidateSearchFilters filters =
        const EmployerCandidateSearchFilters(),
  }) async {
    final client = _client;

    final List<Map<String, dynamic>> rows;
    if (filters.effectiveCategories.length == 1 &&
        filters.effectiveSkills.length <= 1) {
      final result = await client.rpc('search_candidates_by_skills', params: {
        'requested_category': filters.effectiveCategories.first,
        'requested_skill': filters.effectiveSkills.isEmpty
            ? null
            : filters.effectiveSkills.first,
      });
      rows = List<Map<String, dynamic>>.from(result as List);
    } else {
      final result = await client
          .from('public_candidate_search')
          .select()
          .order('updated_at', ascending: false)
          .limit(100);
      rows = List<Map<String, dynamic>>.from(result);
    }
    final effectiveFilters = query == null
        ? filters
        : EmployerCandidateSearchFilters(
            query: query,
            categories: filters.effectiveCategories,
            skills: filters.effectiveSkills,
            locations: filters.effectiveLocations,
            experiences: filters.effectiveExperiences,
            visaStatuses: filters.effectiveVisaStatuses,
            availabilities: filters.effectiveAvailabilities,
            nationalities: filters.effectiveNationalities,
            languages: filters.effectiveLanguages,
            verifiedOnly: filters.verifiedOnly,
          );
    if (effectiveFilters.isEmpty) {
      return rows.map(_candidateFromPublicRow).toList();
    }

    return rows
        .where((row) =>
            EmployerCandidateSearchMatcher.matches(row, effectiveFilters))
        .map(_candidateFromPublicRow)
        .toList();
  }

  Future<void> saveCandidate(String candidateId) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    if (candidateId.isEmpty) {
      throw ArgumentError('Candidate ID is missing.');
    }

    await client.from('saved_candidates').upsert({
      'employer_id': user.id,
      'candidate_id': candidateId,
    }, onConflict: 'employer_id,candidate_id');
  }

  EmployerCandidate _candidateFromPublicRow(Map<String, dynamic> row) {
    final skills = _stringList(row['skills']);
    final categories = _stringList(row['job_categories']);
    final languages = _stringList(row['languages']);
    return EmployerCandidate(
      id: 'Candidate #${(row['id'] as String?)?.substring(0, 8) ?? 'KM'}',
      role: row['headline'] as String? ??
          (categories.isNotEmpty ? categories.join(', ') : 'Candidate'),
      location: [
        row['current_city'] as String?,
        row['current_country'] as String?,
      ].whereType<String>().where((value) => value.isNotEmpty).join(', '),
      expectedSalary: _salaryRange(row),
      availability: row['availability'] as String? ?? 'Availability not set',
      experience: '${row['experience_years'] ?? 0} years experience',
      previousRole: categories.join(', '),
      skills: skills.isEmpty ? categories : skills,
      languages: languages,
      savedDate: 'Saved from Supabase',
      allowedName: row['full_name'] as String?,
      profilePhotoUrl: row['profile_photo_url'] as String?,
      candidateProfileId: row['id'] as String?,
      mainCategory: categories.isEmpty ? '' : categories.first,
      currentLocation: [
        row['current_city'] as String?,
        row['current_country'] as String?,
      ].whereType<String>().where((value) => value.isNotEmpty).join(', '),
      preferredLocation: [
        row['preferred_city'] as String?,
        row['preferred_country'] as String?,
      ].whereType<String>().where((value) => value.isNotEmpty).join(', '),
      visaStatus: row['visa_status'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
    );
  }

  String _salaryRange(Map<String, dynamic> row) {
    final currency = row['currency'] as String? ?? 'AED';
    final min = row['expected_salary_min'];
    final max = row['expected_salary_max'];
    if (min == null && max == null) return 'Hidden';
    if (min == null) return '$currency $max';
    if (max == null) return '$currency $min';
    return '$currency $min - $max';
  }
}

class EmployerCandidateSearchMatcher {
  const EmployerCandidateSearchMatcher._();

  static bool matches(
    Map<String, dynamic> row,
    EmployerCandidateSearchFilters filters,
  ) {
    final searchable = [
      row['full_name'] as String? ?? '',
      row['headline'] as String? ?? '',
      row['current_city'] as String? ?? '',
      row['preferred_city'] as String? ?? '',
      row['current_country'] as String? ?? '',
      row['preferred_country'] as String? ?? '',
      row['availability'] as String? ?? '',
      row['bio'] as String? ?? '',
      ..._stringList(row['job_categories']),
      ..._stringList(row['skills']),
      ..._stringList(row['languages']),
    ].join(' ').toLowerCase();
    final query = filters.query.trim().toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return false;

    if (!_overlaps(
        _stringList(row['job_categories']), filters.effectiveCategories)) {
      return false;
    }
    if (!_overlaps(_stringList(row['skills']), filters.effectiveSkills)) {
      return false;
    }
    if (filters.effectiveLocations.isNotEmpty &&
        !filters.effectiveLocations
            .any((location) => _matchesLocation(row, location))) {
      return false;
    }
    if (!_valueIn(
        row['visa_status'] as String? ?? '', filters.effectiveVisaStatuses)) {
      return false;
    }
    if (!_valueIn(row['availability'] as String? ?? '',
        filters.effectiveAvailabilities)) {
      return false;
    }
    if (!_valueIn(
        row['nationality'] as String? ?? '', filters.effectiveNationalities)) {
      return false;
    }
    if (!_overlaps(_stringList(row['languages']), filters.effectiveLanguages)) {
      return false;
    }
    if (filters.verifiedOnly &&
        (row['is_verified'] as bool? ?? false) == false) {
      return false;
    }
    if (filters.effectiveExperiences.isNotEmpty) {
      final years = (row['experience_years'] as num?) ?? 0;
      final matchesExperience = filters.effectiveExperiences.any((experience) {
        if (experience == '3+ years') return years >= 3;
        if (experience == '5+ years') return years >= 5;
        if (experience == 'Fresher') return years <= 0;
        return false;
      });
      if (!matchesExperience) return false;
    }
    return true;
  }

  static bool _matchesLocation(Map<String, dynamic> row, String location) {
    final selected = location.trim().toLowerCase();
    if (selected.isEmpty) return true;
    final preferred = [
      row['preferred_country'] as String? ?? '',
      row['preferred_city'] as String? ?? '',
    ].join(' ').toLowerCase();
    final current = [
      row['current_country'] as String? ?? '',
      row['current_city'] as String? ?? '',
    ].join(' ').toLowerCase();
    if (selected == 'uae') {
      return preferred.contains('uae') ||
          preferred.contains('both') ||
          current.contains('uae');
    }
    if (selected == 'india') {
      return preferred.contains('india') ||
          preferred.contains('both') ||
          current.contains('india');
    }
    if (selected == 'both') {
      return preferred.contains('uae') ||
          preferred.contains('india') ||
          preferred.contains('both') ||
          current.contains('uae') ||
          current.contains('india');
    }
    return preferred.contains(selected) || current.contains(selected);
  }

  static bool _overlaps(List<String> rowValues, List<String> selectedValues) {
    if (selectedValues.isEmpty) return true;
    final normalizedRows = rowValues.map(_normalize).toSet();
    return selectedValues.map(_normalize).any(normalizedRows.contains);
  }

  static bool _valueIn(String rowValue, List<String> selectedValues) {
    if (selectedValues.isEmpty) return true;
    final normalized = _normalize(rowValue);
    return selectedValues.map(_normalize).contains(normalized);
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}

class InterestRepository {
  const InterestRepository();

  SupabaseClient get _client => _requireClient();

  Future<List<InterestRequest>> candidateRequests() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('interest_requests')
        .select(
            'id,status,message,created_at,employer_companies(company_name,industry,city)')
        .eq('candidate_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(_candidateRequestFromRow).toList();
  }

  Future<List<EmployerInterestRequest>> employerRequests() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('interest_requests')
        .select('id,status,message,created_at,candidate_id')
        .eq('employer_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(_employerRequestFromRow).toList();
  }

  Future<void> sendInterest({
    required String candidateId,
    required String jobTitle,
    required String salaryRange,
    required String location,
    required String workingHours,
    required String message,
    required bool accommodationProvided,
    required bool transportProvided,
    required bool visaSupport,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    if (candidateId.isEmpty) {
      throw ArgumentError('Candidate ID is missing.');
    }

    final company = await client
        .from('employer_companies')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1)
        .maybeSingle();
    if (company == null) {
      throw StateError(
          'Create and save your company profile before sending interest.');
    }

    await client.from('interest_requests').insert({
      'employer_id': user.id,
      'company_id': company['id'],
      'candidate_id': candidateId,
      'message':
          '${message.trim()}\n\nRole: ${jobTitle.trim()}\nSalary: ${salaryRange.trim()}\nLocation: ${location.trim()}\nHours: ${workingHours.trim()}\nAccommodation: ${accommodationProvided ? 'Yes' : 'No'}\nTransport: ${transportProvided ? 'Yes' : 'No'}\nVisa support: ${visaSupport ? 'Yes' : 'No'}',
    });
  }

  Future<void> respondToInterest({
    required String requestId,
    required bool accepted,
  }) async {
    if (requestId.isEmpty) {
      throw ArgumentError('Request ID is missing.');
    }
    await _ensureCurrentProfileNotBlocked(_client);
    await _client.from('interest_requests').update(
        {'status': accepted ? 'accepted' : 'rejected'}).eq('id', requestId);
  }

  InterestRequest _candidateRequestFromRow(Map<String, dynamic> row) {
    final company = row['employer_companies'] as Map<String, dynamic>? ?? {};
    final message = row['message'] as String? ?? '';
    return InterestRequest(
      id: row['id'] as String?,
      status: row['status'] as String? ?? 'pending',
      company: company['company_name'] as String? ?? 'Employer',
      role: _extractLine(message, 'Role') ?? 'Role shared in message',
      salary: _extractLine(message, 'Salary') ?? 'Salary not shared',
      location: _extractLine(message, 'Location') ??
          company['city'] as String? ??
          'Location not shared',
      message: message,
      date: row['created_at'] as String? ?? '',
      industry: company['industry'] as String? ?? 'Company',
      hours: _extractLine(message, 'Hours') ?? 'Hours not shared',
      support:
          'Accommodation: ${_extractLine(message, 'Accommodation') ?? '-'}, Transport: ${_extractLine(message, 'Transport') ?? '-'}',
    );
  }

  EmployerInterestRequest _employerRequestFromRow(Map<String, dynamic> row) {
    final message = row['message'] as String? ?? '';
    final candidateId = row['candidate_id'] as String? ?? '';
    return EmployerInterestRequest(
      id: row['id'] as String?,
      candidateId: candidateId.isEmpty
          ? 'Candidate'
          : 'Candidate #${candidateId.substring(0, 8)}',
      role: _extractLine(message, 'Role') ?? 'Candidate',
      jobTitle: _extractLine(message, 'Role') ?? 'Role not set',
      salary: _extractLine(message, 'Salary') ?? 'Salary not set',
      location: _extractLine(message, 'Location') ?? 'Location not set',
      workingHours: _extractLine(message, 'Hours') ?? 'Hours not set',
      message: message,
      status: row['status'] as String? ?? 'pending',
      sentDate: row['created_at'] as String? ?? '',
    );
  }
}

class MatchRepository {
  const MatchRepository();

  SupabaseClient get _client => _requireClient();

  Future<List<MatchItem>> candidateMatches() async {
    final client = _client;
    _requireUser(client);
    final result = await client.rpc('candidate_matches_with_access');
    final rows = List<Map<String, dynamic>>.from(result as List);
    return rows.map((row) {
      final chatEnabled = row['chat_enabled'] as bool? ?? false;
      final contactRevealed = row['contact_revealed'] as bool? ?? false;
      return MatchItem(
        id: row['match_id'] as String?,
        company: row['company_name'] as String? ?? 'Matched company',
        role: row['role'] as String? ?? 'Matched role',
        location: row['location'] as String? ?? '',
        status: 'Matched',
        preview: chatEnabled
            ? contactRevealed
                ? 'Contact details shared with this employer.'
                : 'Chat is available. Contact reveal is optional.'
            : 'Upgrade Candidate Membership to chat with matched employers and reveal your contact details.',
        chatEnabled: chatEnabled,
        canRevealContact: row['can_reveal_contact'] as bool? ?? false,
        contactRevealed: contactRevealed,
      );
    }).toList();
  }

  Future<List<EmployerMatch>> employerMatches() async {
    final client = _client;
    _requireUser(client);
    final result = await client.rpc('employer_matches_with_contact');
    final rows = List<Map<String, dynamic>>.from(result as List);
    return rows.map((row) {
      final candidateId = row['candidate_id'] as String? ?? '';
      final chatEnabled = row['chat_enabled'] as bool? ?? false;
      final contactRevealed = row['contact_revealed'] as bool? ?? false;
      return EmployerMatch(
        matchId: row['match_id'] as String?,
        candidateId: candidateId.isEmpty
            ? 'Candidate'
            : 'Candidate #${candidateId.substring(0, 8)}',
        name: row['display_name'] as String? ??
            (candidateId.isEmpty
                ? 'Candidate'
                : 'Candidate #${candidateId.substring(0, 8)}'),
        role: row['role'] as String? ?? 'Candidate',
        location: row['location'] as String? ?? '',
        status: 'Matched',
        lastMessage: chatEnabled
            ? contactRevealed
                ? 'Contact details revealed.'
                : 'Chat available. Contact details still hidden.'
            : 'Contact details unavailable.',
        matchDate: row['matched_at'] as String? ?? '',
        unreadCount: 0,
        chatEnabled: chatEnabled,
        contactRevealed: contactRevealed,
        phone: row['phone'] as String? ?? '',
        email: row['email'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> revealCandidateContact(String matchId) async {
    if (matchId.isEmpty) throw ArgumentError('Match ID is missing.');
    await _ensureCurrentProfileNotBlocked(_client);
    await _client
        .rpc('reveal_candidate_contact', params: {'target_match_id': matchId});
  }
}

class ChatRepository {
  const ChatRepository();

  SupabaseClient get _client => _requireClient();

  Stream<List<Map<String, dynamic>>> messages(String matchId) {
    if (matchId.isEmpty) return const Stream.empty();
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<void> sendMessage({
    required String matchId,
    required String body,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    if (matchId.isEmpty) {
      throw ArgumentError('Match ID is missing.');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    await _ensureCurrentProfileNotBlocked(client);
    final access = await client.rpc(
          'match_chat_enabled',
          params: {'target_match_id': matchId},
        ) as bool? ??
        false;
    if (!access) {
      throw StateError(
          'Chat is available only when the matched candidate has an active membership.');
    }

    await client.from('chat_messages').insert({
      'match_id': matchId,
      'sender_id': user.id,
      'body': body.trim(),
    });
  }
}

class KaamStorageRepository {
  const KaamStorageRepository();

  SupabaseClient get _client => _requireClient();

  Future<KaamUploadResult> uploadPublicFile({
    required List<int> bytes,
    required String fileName,
    required String folder,
  }) async {
    return _upload(
      bucket: 'kaam-public',
      folder: folder,
      bytes: bytes,
      fileName: fileName,
      publicFile: true,
    );
  }

  Future<KaamUploadResult> uploadPrivateFile({
    required List<int> bytes,
    required String fileName,
    required String folder,
  }) async {
    return _upload(
      bucket: 'kaam-private',
      folder: folder,
      bytes: bytes,
      fileName: fileName,
      publicFile: false,
    );
  }

  Future<KaamUploadResult> uploadCandidateIdentityDocument({
    required List<int> bytes,
    required String fileName,
    required String documentType,
  }) async {
    await _ensureCurrentProfileNotBlocked(_client);
    final extension = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final safeType = documentType.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final safeName =
        '${safeType}_${DateTime.now().millisecondsSinceEpoch}.${extension.toLowerCase()}';
    return _upload(
      bucket: 'kaam-private',
      folder: 'candidate-documents/$safeType',
      bytes: bytes,
      fileName: safeName,
      publicFile: false,
    );
  }

  Future<String> signedPrivateUrl(String path) async {
    if (path.trim().isEmpty) {
      throw ArgumentError('Document path is missing.');
    }
    return _client.storage.from('kaam-private').createSignedUrl(path, 60 * 10);
  }

  Future<void> recordVerificationDocument({
    required String documentType,
    required KaamUploadResult upload,
    String? companyId,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await client.from('verification_documents').insert({
      'owner_id': user.id,
      'company_id': companyId,
      'document_type': documentType,
      'bucket_id': upload.bucket,
      'file_path': upload.path,
      'status': 'pending',
    });
  }

  Future<List<VerificationDocumentData>> listMyDocuments() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('verification_documents')
        .select('id,document_type,bucket_id,file_path,status')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(VerificationDocumentData.fromRow).toList();
  }

  Future<KaamUploadResult> _upload({
    required String bucket,
    required String folder,
    required List<int> bytes,
    required String fileName,
    required bool publicFile,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    if (bytes.isEmpty) {
      throw ArgumentError('Selected file is empty.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '${user.id}/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    final publicUrl =
        publicFile ? client.storage.from(bucket).getPublicUrl(path) : null;
    _debug('Uploaded $folder file to $bucket');
    return KaamUploadResult(
      bucket: bucket,
      path: path,
      displayName: fileName,
      publicUrl: publicUrl,
    );
  }
}

SupabaseClient _requireClient() {
  final client = SupabaseService.maybeClient;
  if (client == null) {
    throw StateError(
        'Supabase is not configured. Check SUPABASE_URL and SUPABASE_ANON_KEY.');
  }
  return client;
}

User _requireUser(SupabaseClient client) {
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('Please sign in again before continuing.');
  }
  return user;
}

Future<void> _ensureCurrentProfileNotBlocked(SupabaseClient client) async {
  final user = _requireUser(client);
  final row = await client
      .from('profiles')
      .select('status')
      .eq('id', user.id)
      .maybeSingle();
  if (KaamAccountStatusPolicy.isBlocked(row?['status'] as String?)) {
    await client.auth.signOut(scope: SignOutScope.global);
    throw StateError(KaamAccountStatusPolicy.blockedMessage);
  }
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}

List<String> splitCsv(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

int? parseFirstInt(String value) {
  final match = RegExp(r'\d+').firstMatch(value.replaceAll(',', ''));
  return match == null ? null : int.tryParse(match.group(0)!);
}

int? parseLastInt(String value) {
  final matches = RegExp(r'\d+').allMatches(value.replaceAll(',', '')).toList();
  return matches.isEmpty ? null : int.tryParse(matches.last.group(0)!);
}

String? _extractLine(String message, String label) {
  final match =
      RegExp('^$label:\\s*(.+)\$', multiLine: true).firstMatch(message);
  return match?.group(1)?.trim();
}

KaamRole _roleFromName(String value) {
  for (final role in KaamRole.values) {
    if (role.name == value) return role;
  }
  return KaamRole.candidate;
}

bool _candidateOnboardingComplete(Map<String, dynamic>? row) {
  if (row == null) return false;
  final categories = _stringList(row['job_categories']);
  return (row['nationality'] as String? ?? '').trim().isNotEmpty &&
      (row['current_city'] as String? ?? '').trim().isNotEmpty &&
      (row['preferred_city'] as String? ?? '').trim().isNotEmpty &&
      categories.isNotEmpty &&
      (row['headline'] as String? ?? '').trim().isNotEmpty &&
      (row['availability'] as String? ?? '').trim().isNotEmpty;
}

void _debug(String message) {
  if (kDebugMode) {
    debugPrint('Kaam Supabase: $message');
  }
}
