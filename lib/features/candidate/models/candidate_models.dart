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
