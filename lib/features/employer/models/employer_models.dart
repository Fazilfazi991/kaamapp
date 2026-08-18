class EmployerCandidate {
  const EmployerCandidate({
    required this.id,
    required this.role,
    required this.location,
    required this.expectedSalary,
    required this.availability,
    required this.experience,
    required this.previousRole,
    required this.skills,
    required this.languages,
    required this.savedDate,
    this.mainCategory = '',
    this.currentLocation = '',
    this.preferredLocation = '',
    this.visaStatus = '',
    this.verificationStatus = '',
    this.isSaved = false,
    this.isMatched = false,
    this.interestStatus,
    this.allowedName,
    this.candidateProfileId,
    this.profilePhotoUrl,
    this.about = '',
  });

  final String id;
  final String role;
  final String location;
  final String expectedSalary;
  final String availability;
  final String experience;
  final String previousRole;
  final List<String> skills;
  final List<String> languages;
  final String savedDate;
  final String mainCategory;
  final String currentLocation;
  final String preferredLocation;
  final String visaStatus;
  final String verificationStatus;
  bool get isManuallyVerified =>
      verificationStatus.trim().toLowerCase() == 'verified';
  bool get isVerified => isManuallyVerified;
  final bool isSaved;
  final bool isMatched;
  final String? interestStatus;
  bool get hasActiveInterest =>
      interestStatus == 'pending' || interestStatus == 'accepted';
  final String? allowedName;
  final String? candidateProfileId;
  final String? profilePhotoUrl;
  final String about;

  String get displayName =>
      allowedName == null || allowedName!.trim().isEmpty ? id : allowedName!;

  EmployerCandidate copyWith(
      {bool? isSaved, String? savedDate, String? interestStatus}) {
    return EmployerCandidate(
      id: id,
      role: role,
      location: location,
      expectedSalary: expectedSalary,
      availability: availability,
      experience: experience,
      previousRole: previousRole,
      skills: skills,
      languages: languages,
      savedDate: savedDate ?? this.savedDate,
      mainCategory: mainCategory,
      currentLocation: currentLocation,
      preferredLocation: preferredLocation,
      visaStatus: visaStatus,
      verificationStatus: verificationStatus,
      isSaved: isSaved ?? this.isSaved,
      isMatched: isMatched,
      interestStatus: interestStatus ?? this.interestStatus,
      allowedName: allowedName,
      candidateProfileId: candidateProfileId,
      profilePhotoUrl: profilePhotoUrl,
      about: about,
    );
  }
}

class EmployerHiringRequirement {
  const EmployerHiringRequirement({
    this.id,
    required this.role,
    this.jobRoleId,
    this.competencySkillIds = const [],
    this.customRole = '',
    required this.openings,
    required this.salaryRange,
    required this.workLocation,
    required this.workingHours,
    required this.accommodationProvided,
    required this.transportProvided,
    required this.visaProvided,
    required this.immediateJoining,
    this.description = '',
    this.status = 'active',
  });

  final String? id;
  final String role;
  final String? jobRoleId;
  final List<String> competencySkillIds;
  final String customRole;
  final int openings;
  final String salaryRange;
  final String workLocation;
  final String workingHours;
  final bool accommodationProvided;
  final bool transportProvided;
  final bool visaProvided;
  final bool immediateJoining;
  final String description;
  final String status;

  String get displayRole => customRole.trim().isNotEmpty ? customRole : role;

  EmployerHiringRequirement copyWith({
    String? id,
    String? role,
    String? jobRoleId,
    List<String>? competencySkillIds,
    String? customRole,
    int? openings,
    String? salaryRange,
    String? workLocation,
    String? workingHours,
    bool? accommodationProvided,
    bool? transportProvided,
    bool? visaProvided,
    bool? immediateJoining,
    String? description,
    String? status,
  }) {
    return EmployerHiringRequirement(
      id: id ?? this.id,
      role: role ?? this.role,
      jobRoleId: jobRoleId ?? this.jobRoleId,
      competencySkillIds: competencySkillIds ?? this.competencySkillIds,
      customRole: customRole ?? this.customRole,
      openings: openings ?? this.openings,
      salaryRange: salaryRange ?? this.salaryRange,
      workLocation: workLocation ?? this.workLocation,
      workingHours: workingHours ?? this.workingHours,
      accommodationProvided:
          accommodationProvided ?? this.accommodationProvided,
      transportProvided: transportProvided ?? this.transportProvided,
      visaProvided: visaProvided ?? this.visaProvided,
      immediateJoining: immediateJoining ?? this.immediateJoining,
      description: description ?? this.description,
      status: status ?? this.status,
    );
  }

  factory EmployerHiringRequirement.fromRow(Map<String, dynamic> row) {
    return EmployerHiringRequirement(
      id: row['id'] as String?,
      role: row['role'] as String? ?? '',
      jobRoleId: row['job_role_id'] as String?,
      customRole: row['custom_role'] as String? ?? '',
      openings: row['openings'] as int? ?? 1,
      salaryRange: row['salary_range'] as String? ?? '',
      workLocation: row['work_location'] as String? ?? '',
      workingHours: row['working_hours'] as String? ?? '',
      accommodationProvided: row['accommodation_provided'] as bool? ?? false,
      transportProvided: row['transport_provided'] as bool? ?? false,
      visaProvided: row['visa_provided'] as bool? ?? false,
      immediateJoining: row['immediate_joining'] as bool? ?? false,
      description: row['description'] as String? ?? '',
      status: row['status'] as String? ?? 'active',
    );
  }
}

class EmployerInterestRequest {
  const EmployerInterestRequest({
    this.id,
    required this.candidateId,
    required this.role,
    required this.jobTitle,
    required this.salary,
    required this.location,
    required this.workingHours,
    required this.message,
    required this.status,
    required this.sentDate,
    this.candidateName = 'Candidate',
    this.candidatePhotoUrl = '',
    this.experience = '',
    this.availability = '',
    this.accommodation = '',
    this.transport = '',
    this.visaSupport = '',
  });

  final String? id;
  final String candidateId;
  final String role;
  final String jobTitle;
  final String salary;
  final String location;
  final String workingHours;
  final String message;
  final String status;
  final String sentDate;
  final String candidateName;
  final String candidatePhotoUrl;
  final String experience;
  final String availability;
  final String accommodation;
  final String transport;
  final String visaSupport;
}

class EmployerMatch {
  const EmployerMatch({
    this.matchId,
    required this.candidateId,
    required this.name,
    required this.role,
    required this.location,
    required this.status,
    required this.lastMessage,
    required this.matchDate,
    required this.unreadCount,
    this.chatEnabled = false,
    this.contactRevealed = false,
    this.phone = '',
    this.email = '',
    this.candidateProfileId = '',
    this.profilePhotoUrl = '',
  });

  final String? matchId;
  final String candidateId;
  final String name;
  final String role;
  final String location;
  final String status;
  final String lastMessage;
  final String matchDate;
  final int unreadCount;
  final bool chatEnabled;
  final bool contactRevealed;
  final String phone;
  final String email;
  final String candidateProfileId;
  final String profilePhotoUrl;
}

class EmployerNotificationItem {
  const EmployerNotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.iconName,
  });

  final String title;
  final String body;
  final String time;
  final String iconName;
}

class TeamMember {
  const TeamMember({
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final String role;
}
