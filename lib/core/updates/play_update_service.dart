import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../remote_config/app_remote_config.dart';

enum PlayUpdateAvailability { unavailable, available, inProgress, downloaded }

enum PlayUpdateType { flexible, immediate }

abstract class PlayUpdateProvider {
  Future<PlayUpdateAvailability> check();
  Future<bool> start(PlayUpdateType type);
  Future<bool> completeFlexibleUpdate();
  Stream<PlayUpdateAvailability> get status;
}

class PlatformPlayUpdateProvider implements PlayUpdateProvider {
  static const _methods =
      MethodChannel('com.kaamperfectmatch.kaam/play_updates');
  static const _events =
      EventChannel('com.kaamperfectmatch.kaam/play_update_status');
  @override
  Stream<PlayUpdateAvailability> get status => Platform.isAndroid
      ? _events
          .receiveBroadcastStream()
          .map((event) => _parse(event as String?))
      : const Stream.empty();
  @override
  Future<PlayUpdateAvailability> check() async => !Platform.isAndroid
      ? PlayUpdateAvailability.unavailable
      : _parse(await _methods.invokeMethod<String>('check'));
  @override
  Future<bool> start(PlayUpdateType type) async =>
      Platform.isAndroid &&
      (await _methods.invokeMethod<bool>('start', {'type': type.name}) ??
          false);
  @override
  Future<bool> completeFlexibleUpdate() async =>
      Platform.isAndroid &&
      ((await _methods.invokeMethod<bool>('completeFlexible')) ?? false);
  PlayUpdateAvailability _parse(String? value) => switch (value) {
        'available' => PlayUpdateAvailability.available,
        'in_progress' => PlayUpdateAvailability.inProgress,
        'downloaded' => PlayUpdateAvailability.downloaded,
        _ => PlayUpdateAvailability.unavailable
      };
}

class UpdateDecision {
  const UpdateDecision({required this.type, required this.shouldRequest});
  final PlayUpdateType? type;
  final bool shouldRequest;
  static UpdateDecision from(
      {required String installedVersion,
      required String minimumVersion,
      required bool forceEnabled,
      required bool flexibleEnabled}) {
    final installed = SemanticVersion.tryParse(installedVersion);
    final minimum = SemanticVersion.tryParse(minimumVersion);
    if (forceEnabled &&
        installed != null &&
        minimum != null &&
        installed.compareTo(minimum) < 0) {
      return const UpdateDecision(
          type: PlayUpdateType.immediate, shouldRequest: true);
    }
    return UpdateDecision(
        type: flexibleEnabled ? PlayUpdateType.flexible : null,
        shouldRequest: flexibleEnabled);
  }
}
