import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate basic profile location mapping', () {
    test('keeps current and preferred locations separate when they differ', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'UAE',
        currentLocation: 'Dubai',
        preferredCountry: 'India',
        preferredLocation: 'Kerala',
      );

      expect(values['current_country'], 'UAE');
      expect(values['current_city'], 'Dubai');
      expect(values['preferred_country'], 'India');
      expect(values['preferred_city'], 'Kerala');
    });

    test('saves the actual current location to current_city', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'UAE',
        currentLocation: 'Sharjah',
        preferredCountry: 'UAE',
        preferredLocation: 'Dubai',
      );

      expect(values['current_city'], 'Sharjah');
    });

    test('saves the preferred location only to preferred_city', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'UAE',
        currentLocation: 'Sharjah',
        preferredCountry: 'UAE',
        preferredLocation: 'Dubai',
      );

      expect(values['preferred_city'], 'Dubai');
      expect(values['current_city'], isNot(values['preferred_city']));
    });

    test('maps UAE emirates without using India state values', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'UAE',
        currentLocation: 'Abu Dhabi',
        preferredCountry: 'UAE',
        preferredLocation: 'Ras Al Khaimah',
      );

      expect(values['current_country'], 'UAE');
      expect(values['current_city'], 'Abu Dhabi');
      expect(values['preferred_city'], 'Ras Al Khaimah');
    });

    test('maps India states without using UAE emirate values', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'India',
        currentLocation: 'Tamil Nadu',
        preferredCountry: 'India',
        preferredLocation: 'Kerala',
      );

      expect(values['current_country'], 'India');
      expect(values['current_city'], 'Tamil Nadu');
      expect(values['preferred_city'], 'Kerala');
    });

    test('clears stale region values after a country change', () {
      final values = CandidateBasicProfileLocationMapper.candidateProfileValues(
        nationality: 'Indian',
        currentCountry: 'India',
        currentLocation: 'Dubai',
        preferredCountry: 'UAE',
        preferredLocation: 'Kerala',
      );

      expect(values['current_country'], 'India');
      expect(values['current_city'], isNull);
      expect(values['preferred_country'], 'UAE');
      expect(values['preferred_city'], isNull);
    });
  });
}
