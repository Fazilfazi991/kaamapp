class CandidateStat {
  const CandidateStat(this.label, this.value, this.note);
  final String label;
  final String value;
  final String note;
}

class InterestRequest {
  const InterestRequest({
    this.id,
    this.status = 'pending',
    required this.company,
    required this.role,
    required this.salary,
    required this.location,
    required this.message,
    required this.date,
    required this.industry,
    required this.hours,
    required this.support,
    this.accommodation = '',
    this.transport = '',
    this.visaSupport = '',
    this.companyLogoUrl = '',
    this.companyVerified = false,
  });

  final String? id;
  final String status;
  final String company;
  final String role;
  final String salary;
  final String location;
  final String message;
  final String date;
  final String industry;
  final String hours;
  final String support;
  final String accommodation;
  final String transport;
  final String visaSupport;
  final String companyLogoUrl;
  final bool companyVerified;
}

class MatchItem {
  const MatchItem({
    this.id,
    required this.company,
    required this.role,
    required this.location,
    required this.status,
    required this.preview,
    this.chatEnabled = false,
    this.canRevealContact = false,
    this.contactRevealed = false,
  });

  final String? id;
  final String company;
  final String role;
  final String location;
  final String status;
  final String preview;
  final bool chatEnabled;
  final bool canRevealContact;
  final bool contactRevealed;
}

class ChatItem {
  const ChatItem({
    required this.company,
    required this.role,
    required this.message,
    required this.time,
    this.unread = 0,
  });

  final String company;
  final String role;
  final String message;
  final String time;
  final int unread;
}

class CandidateConversation {
  const CandidateConversation({
    required this.match,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final MatchItem match;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get hasMessages => lastMessageAt != null;
}
