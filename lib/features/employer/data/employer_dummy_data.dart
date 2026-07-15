import '../models/employer_models.dart';

class EmployerDummyData {
  const EmployerDummyData._();

  static const companyName = 'Bright Star Cleaning Services';
  static const industry = 'Facilities Management';
  static const location = 'Dubai, UAE';
  static const companySize = '51-200 employees';
  static const contactPerson = 'Nadia Rahman';
  static const contactRole = 'HR Manager';
  static const verificationStatus = 'Pending Review';

  static const candidates = [
    EmployerCandidate(
      id: 'Candidate #KM2048',
      role: 'Cleaner Supervisor',
      location: 'Dubai, UAE',
      expectedSalary: 'AED 2,500',
      availability: 'Available immediately',
      experience: '5 years experience',
      previousRole: 'Housekeeping Team Lead',
      skills: ['Cleaning', 'Team Lead', 'Hotel Experience', 'Room Service'],
      languages: ['English', 'Hindi', 'Malayalam'],
      savedDate: 'Saved today',
      isSaved: true,
      isMatched: true,
      allowedName: 'Ahmed K.',
    ),
    EmployerCandidate(
      id: 'Candidate #KM1921',
      role: 'Light Vehicle Driver',
      location: 'Sharjah, UAE',
      expectedSalary: 'AED 3,000',
      availability: 'Available in 7 days',
      experience: '4 years experience',
      previousRole: 'Delivery Driver',
      skills: ['UAE Roads', 'Customer Service', 'Fleet Logs'],
      languages: ['English', 'Urdu', 'Arabic Basic'],
      savedDate: 'Saved yesterday',
      isSaved: true,
    ),
    EmployerCandidate(
      id: 'Candidate #KM2105',
      role: 'Housekeeping Attendant',
      location: 'Abu Dhabi, UAE',
      expectedSalary: 'AED 2,200',
      availability: 'Available now',
      experience: '3 years experience',
      previousRole: 'Room Attendant',
      skills: ['Housekeeping', 'Laundry', 'Guest Rooms'],
      languages: ['English', 'Tagalog'],
      savedDate: 'Saved Jun 28',
    ),
  ];

  static const interests = [
    EmployerInterestRequest(
      candidateId: 'Candidate #KM2048',
      role: 'Cleaner Supervisor',
      jobTitle: 'Cleaning Team Lead',
      salary: 'AED 2,200 - AED 2,800',
      location: 'Dubai',
      workingHours: '9 hours with weekly off',
      message: 'We like your hotel housekeeping experience and team lead background.',
      status: 'Accepted',
      sentDate: 'Today',
    ),
    EmployerInterestRequest(
      candidateId: 'Candidate #KM1921',
      role: 'Light Vehicle Driver',
      jobTitle: 'Delivery Driver',
      salary: 'AED 2,800 - AED 3,200',
      location: 'Sharjah',
      workingHours: '10 hours with overtime',
      message: 'We are hiring drivers for a new facilities route.',
      status: 'Pending',
      sentDate: 'Yesterday',
    ),
    EmployerInterestRequest(
      candidateId: 'Candidate #KM2105',
      role: 'Housekeeping Attendant',
      jobTitle: 'Housekeeping Attendant',
      salary: 'AED 2,000 - AED 2,300',
      location: 'Abu Dhabi',
      workingHours: 'Shift duty',
      message: 'Your room service experience looks relevant for our hotel client.',
      status: 'Declined',
      sentDate: 'Jun 25',
    ),
  ];

  static const matches = [
    EmployerMatch(
      candidateId: 'Candidate #KM2048',
      name: 'Ahmed K.',
      role: 'Cleaner Supervisor',
      location: 'Dubai',
      status: 'Interviewing',
      lastMessage: 'Can you share interview timing?',
      matchDate: 'Today',
      unreadCount: 2,
    ),
    EmployerMatch(
      candidateId: 'Candidate #KM1874',
      name: 'Candidate #KM1874',
      role: 'Security Guard',
      location: 'Ajman',
      status: 'New Match',
      lastMessage: 'Thanks for accepting the request.',
      matchDate: 'Yesterday',
      unreadCount: 0,
    ),
  ];

  static const notifications = [
    EmployerNotificationItem(
      title: 'Candidate accepted your interest',
      body: 'Candidate #KM2048 unlocked chat for Cleaning Team Lead.',
      time: '10:45 AM',
      iconName: 'match',
    ),
    EmployerNotificationItem(
      title: 'New message received',
      body: 'Ahmed K. asked for interview timing.',
      time: '10:46 AM',
      iconName: 'chat',
    ),
    EmployerNotificationItem(
      title: 'Hiring activity update',
      body: 'You have sent 12 interest requests in the demo workspace.',
      time: 'Yesterday',
      iconName: 'activity',
    ),
    EmployerNotificationItem(
      title: 'Verification under review',
      body: 'Your trade license has been received securely.',
      time: 'Jun 26',
      iconName: 'verify',
    ),
  ];

  static const teamMembers = [
    TeamMember(name: 'Nadia Rahman', email: 'nadia@brightstar.example', role: 'Admin'),
    TeamMember(name: 'Omar Khalid', email: 'omar@brightstar.example', role: 'Recruiter'),
    TeamMember(name: 'Sara Mathew', email: 'sara@brightstar.example', role: 'Viewer'),
  ];
}
