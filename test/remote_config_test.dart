import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/remote_config/app_remote_config.dart';
import 'package:kaam_perfect_match/core/updates/play_update_service.dart';

void main() {
  test('remote config keeps safe defaults for malformed values', () {
    final config = AppRemoteConfig.fromJson(
        {'maintenance_mode': 'true', 'maximum_candidate_skills': 15});
    expect(config.maintenanceMode, isFalse);
    expect(config.intValue('maximum_candidate_skills'), 15);
    expect(config.stringValue('maintenance_title'), isNotEmpty);
  });

  test('semantic versions compare numeric components rather than strings', () {
    expect(
        SemanticVersion.tryParse('1.10.0')!
            .compareTo(SemanticVersion.tryParse('1.2.0')!),
        greaterThan(0));
    expect(SemanticVersion.tryParse('invalid'), isNull);
  });

  test('only a valid forced minimum requests an immediate update', () {
    final forced = UpdateDecision.from(
        installedVersion: '1.0.0',
        minimumVersion: '1.1.0',
        forceEnabled: true,
        flexibleEnabled: true);
    final optional = UpdateDecision.from(
        installedVersion: '1.1.0',
        minimumVersion: '1.1.0',
        forceEnabled: true,
        flexibleEnabled: true);
    expect(forced.type, PlayUpdateType.immediate);
    expect(optional.type, PlayUpdateType.flexible);
  });
}
