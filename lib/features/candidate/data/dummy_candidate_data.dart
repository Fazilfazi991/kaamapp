import '../models/candidate_models.dart';

class DummyCandidateData {
  const DummyCandidateData._();

  static const candidateName = 'Candidate';
  static const title = 'Preferred role';
  static const location = 'Location';
  static const salary = 'Expected salary';
  static const availability = 'Availability';
  static const profileStrength = 0;

  static const skills = [
    'Cleaning operations',
    'Team supervision',
    'Guest rooms',
    'Deep cleaning',
    'Inventory',
  ];

  static const languages = ['English', 'Hindi', 'Urdu', 'Basic Arabic'];

  static const stats = [
    CandidateStat('New Interest Requests', '3', 'Pending employer requests'),
    CandidateStat('Profile Views This Week', '17', '+12% from last week'),
    CandidateStat('Active Matches', '2', 'Chat is unlocked'),
  ];

  static const requests = [
    InterestRequest(
      company: 'Bright Star Cleaning Services',
      role: 'Cleaner Supervisor',
      salary: 'AED 2,200 - AED 2,800',
      location: 'Dubai, UAE',
      message: 'We liked your experience and want to discuss this role.',
      date: 'Today',
      industry: 'Facilities management',
      hours: '9 hours, 6 days per week',
      support: 'Accommodation provided, transport available',
    ),
    InterestRequest(
      company: 'City Way Facilities',
      role: 'Housekeeping Staff',
      salary: 'AED 1,800 - AED 2,300',
      location: 'Sharjah, UAE',
      message: 'Your housekeeping background matches our new opening.',
      date: 'Yesterday',
      industry: 'Facilities management',
      hours: '8 hours, rotating shift',
      support: 'Transport provided',
    ),
    InterestRequest(
      company: 'Elite Hospitality Group',
      role: 'Room Attendant',
      salary: 'AED 2,000 - AED 2,500',
      location: 'Dubai Marina',
      message: 'We are hiring room attendants for a premium hotel team.',
      date: '2 days ago',
      industry: 'Hospitality',
      hours: '8 hours, 6 days per week',
      support: 'Accommodation and meals provided',
    ),
  ];

  static const matches = [
    MatchItem(
      company: 'Bright Star Cleaning Services',
      role: 'Cleaner Supervisor',
      location: 'Dubai, UAE',
      status: 'New',
      preview: 'Are you available for an interview this week?',
    ),
    MatchItem(
      company: 'Elite Hospitality Group',
      role: 'Room Attendant',
      location: 'Dubai Marina',
      status: 'Interviewing',
      preview: 'Interview slot confirmed for Thursday.',
    ),
  ];

  static const chats = [
    ChatItem(
      company: 'Bright Star Cleaning Services',
      role: 'Cleaner Supervisor',
      message: 'Are you available for an interview this week?',
      time: '10:42',
      unread: 2,
    ),
    ChatItem(
      company: 'Elite Hospitality Group',
      role: 'Room Attendant',
      message: 'Interview slot confirmed for Thursday.',
      time: 'Yesterday',
    ),
  ];
}
