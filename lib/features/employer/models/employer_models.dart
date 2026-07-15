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
    this.isVerified = false,
    this.isSaved = false,
    this.isMatched = false,
    this.allowedName,
    this.candidateProfileId,
    this.profilePhotoUrl,
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
  final bool isVerified;
  final bool isSaved;
  final bool isMatched;
  final String? allowedName;
  final String? candidateProfileId;
  final String? profilePhotoUrl;

  String get displayName =>
      allowedName == null || allowedName!.trim().isEmpty ? id : allowedName!;
}

class EmployerHiringRequirement {
  const EmployerHiringRequirement({
    this.id,
    required this.role,
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

  factory EmployerHiringRequirement.fromRow(Map<String, dynamic> row) {
    return EmployerHiringRequirement(
      id: row['id'] as String?,
      role: row['role'] as String? ?? '',
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
