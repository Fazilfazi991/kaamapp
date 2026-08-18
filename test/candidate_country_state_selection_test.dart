import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/profile/candidate_profile_completion.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate country and state selection', () {
    test('1. country options contain only UAE and India', () {
      expect(CandidateLocationOptions.countries, ['UAE', 'India']);
    });

    test('2. Other is not selectable', () {
      expect(CandidateLocationOptions.countries, isNot(contains('Other')));
      expect(CandidateLocationOptions.countries, isNot(contains('Both')));
      expect(
        CandidateLocationOptions.countries,
        isNot(contains('All Locations')),
      );
    });

    test('3. UAE selects the emirate options', () {
      expect(
        CandidateLocationOptions.regionsForCountry('UAE'),
        CandidateLocationOptions.uaeEmirates,
      );
      expect(CandidateLocationOptions.uaeEmirates, contains('Dubai'));
    });

    test('4. India selects the state options', () {
      expect(
        CandidateLocationOptions.regionsForCountry('India'),
        CandidateLocationOptions.indianStates,
      );
      expect(CandidateLocationOptions.indianStates, contains('Kerala'));
    });

    test('5. India state and union territory list is populated', () {
      expect(CandidateLocationOptions.indianStates, hasLength(36));
      expect(
        CandidateLocationOptions.indianStates,
        containsAll([
          'Andhra Pradesh',
          'Delhi',
          'Jammu and Kashmir',
          'Ladakh',
          'Puducherry',
          'Andaman and Nicobar Islands',
        ]),
      );
    });

    test('6. UAE does not expose India states', () {
      expect(
        CandidateLocationOptions.regionsForCountry('UAE'),
        isNot(contains('Kerala')),
      );
    });

    test('7. India does not expose UAE emirates', () {
      expect(
        CandidateLocationOptions.regionsForCountry('India'),
        isNot(contains('Dubai')),
      );
    });

    test('8. missing UAE emirate blocks save', () {
      expect(
        CandidateLocationOptions.validationError('UAE', ''),
        'Select your emirate.',
      );
      expect(CandidateLocationOptions.isComplete('UAE', ''), isFalse);
    });

    test('9. missing India state blocks save', () {
      expect(
        CandidateLocationOptions.validationError('India', ''),
        'Select your state.',
      );
      expect(CandidateLocationOptions.isComplete('India', ''), isFalse);
    });

    test('10. saving UAE clears an incompatible India state', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'UAE',
        currentLocation: 'Kerala',
        preferredCountry: 'UAE',
        preferredLocation: 'Dubai',
      );

      expect(values['current_country'], 'UAE');
      expect(values['current_city'], isNull);
    });

    test('11. saving India clears an incompatible UAE emirate', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'India',
        currentLocation: 'Dubai',
        preferredCountry: 'India',
        preferredLocation: 'Kerala',
      );

      expect(values['current_country'], 'India');
      expect(values['current_city'], isNull);
    });

    test('12. switching country changes the dependent options', () {
      final uae = CandidateLocationOptions.regionsForCountry('UAE');
      final india = CandidateLocationOptions.regionsForCountry('India');

      expect(uae, contains('Dubai'));
      expect(uae, isNot(contains('Kerala')));
      expect(india, contains('Kerala'));
      expect(india, isNot(contains('Dubai')));
    });

    test('13. saved emirate restores after restart simulation', () {
      final stored = _candidateRow(country: 'UAE', region: 'Dubai');
      final beforeRestart = _profile(stored);
      final afterRestart = _profile({...stored});

      expect(beforeRestart.currentCountry, 'UAE');
      expect(afterRestart.currentCountry, 'UAE');
      expect(afterRestart.currentCity, 'Dubai');
    });

    test('14. saved India state restores after restart simulation', () {
      final stored = _candidateRow(country: 'India', region: 'Kerala');
      final beforeRestart = _profile(stored);
      final afterRestart = _profile({...stored});

      expect(beforeRestart.currentCity, 'Kerala');
      expect(afterRestart.currentCountry, 'India');
      expect(afterRestart.currentCity, 'Kerala');
    });

    test('15. logout and login restore country and dependent location', () {
      final databaseRow = _candidateRow(
        country: 'india',
        region: 'tamil nadu',
      );
      final firstSession = _profile(databaseRow);
      final nextSession = _profile({...databaseRow});

      expect(firstSession.currentCountry, nextSession.currentCountry);
      expect(nextSession.currentCountry, 'India');
      expect(nextSession.currentCity, 'Tamil Nadu');
    });

    test('16. Edit Profile routes use the same location rules', () {
      final basicDetails = File(
        'lib/features/candidate/onboarding/basic_details_screen.dart',
      ).readAsStringSync();
      final experience = File(
        'lib/features/candidate/onboarding/skills_experience_screen.dart',
      ).readAsStringSync();
      final editProfile = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();

      expect(basicDetails, contains('CandidateLocationOptions.countries'));
      expect(experience, contains('CandidateLocationOptions.countries'));
      expect(editProfile, contains('AppRoutes.editBasicDetails'));
      expect(editProfile, contains('AppRoutes.skillsExperience'));
    });

    test('17. legacy UAE and India labels normalize safely', () {
      expect(CandidateLocationOptions.normalizeCountry('uae'), 'UAE');
      expect(
        CandidateLocationOptions.normalizeCountry('United Arab Emirates'),
        'UAE',
      );
      expect(CandidateLocationOptions.normalizeCountry('INDIA'), 'India');
      expect(
        CandidateLocationOptions.normalizeRegionForCountry(
          'India',
          'Pondicherry',
        ),
        'Puducherry',
      );
      expect(
        CandidateLocationOptions.normalizeRegionForCountry('India', 'Orissa'),
        'Odisha',
      );
    });

    test('18. legacy Other loads safely but must be corrected', () {
      final profile = _profile(
        _candidateRow(country: 'Other', region: 'Somewhere'),
      );

      expect(profile.currentCountry, isEmpty);
      expect(profile.currentCity, isEmpty);
      expect(CandidateLocationOptions.validationError('Other', ''),
          'Select your country.');
    });

    test('19. profile completion uses the shared location rule', () {
      final completeLocation = CandidateProfileCompletion.calculate(
        _completeBasicProfile(country: 'India', region: 'Kerala'),
      );
      final invalidLocation = CandidateProfileCompletion.calculate(
        _completeBasicProfile(country: 'India', region: 'Dubai'),
      );

      expect(
        completeLocation
            .sections[CandidateProfileSection.basicDetails]!.missingFields,
        isNot(contains('current location')),
      );
      expect(
        invalidLocation
            .sections[CandidateProfileSection.basicDetails]!.missingFields,
        contains('current location'),
      );
    });

    test('20. display formatting uses clean region and country labels', () {
      expect(CandidateLocationOptions.format('uae', 'dubai'), 'Dubai, UAE');
      expect(
        CandidateLocationOptions.format('india', 'kerala'),
        'Kerala, India',
      );
    });

    test('21. location update does not include unrelated profile fields', () {
      final backend = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      final start = backend.indexOf(
        'Future<CandidateProfileData> updateCurrentLocation',
      );
      final end = backend.indexOf(
        'Future<CandidateProfileData> updateVisaDetails',
        start,
      );
      final locationUpdate = backend.substring(start, end);

      expect(locationUpdate, contains("'current_country'"));
      expect(locationUpdate, contains("'current_city'"));
      expect(locationUpdate, isNot(contains("'skills'")));
      expect(locationUpdate, isNot(contains("'visa_status'")));
      expect(locationUpdate, isNot(contains("'profile_photo_url'")));
    });

    test('22. raw database location values are not exposed', () {
      final profile = _profile(
        _candidateRow(country: 'united arab emirates', region: 'DUBAI'),
      );

      expect(profile.currentCountry, 'UAE');
      expect(profile.currentCity, 'Dubai');
      expect(
        CandidateLocationOptions.format(
          profile.currentCountry,
          profile.currentCity,
        ),
        'Dubai, UAE',
      );
      expect(CandidateLocationOptions.format('Other', 'raw_value'), isEmpty);
    });
  });
}

Map<String, dynamic> _candidateRow({
  required String country,
  required String region,
}) =>
    {
      'current_country': country,
      'current_city': region,
      'preferred_country': country,
      'preferred_city': region,
    };

CandidateProfileData _profile(Map<String, dynamic> candidate) =>
    CandidateProfileData.fromRows(profile: const {}, candidate: candidate);

CandidateProfileData _completeBasicProfile({
  required String country,
  required String region,
}) =>
    CandidateProfileData(
      fullName: 'Maya Candidate',
      nationality: 'Indian',
      currentCountry: country,
      currentCity: region,
      preferredCountry: country,
      preferredCity: region,
      phone: '+971500000000',
      email: 'maya@example.com',
    );
