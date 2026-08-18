import 'package:flutter/foundation.dart';

import '../supabase/supabase_service.dart';

typedef PrivateProfilePhotoSigner = Future<String> Function(String path);

class PrivateProfilePhotoChange {
  const PrivateProfilePhotoChange({
    required this.previousPath,
    required this.nextPath,
    required this.revision,
  });

  final String previousPath;
  final String nextPath;
  final int revision;
}

class PrivateProfilePhotoResolver {
  const PrivateProfilePhotoResolver._();

  static const signedUrlLifetime = Duration(minutes: 10);
  static const cacheLifetime = Duration(minutes: 8);
  static final RegExp _candidateIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final Map<String, _PrivatePhotoCacheEntry> _cache = {};
  static final ValueNotifier<PrivateProfilePhotoChange?> changes =
      ValueNotifier(null);
  static int _revision = 0;

  static bool isCandidatePhotoPath(String path, {String? candidateId}) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || Uri.tryParse(trimmed)?.hasScheme == true) {
      return false;
    }
    final parts = trimmed.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length < 3 ||
        !_candidateIdPattern.hasMatch(parts.first) ||
        parts[1] != 'candidate-profile-photos') {
      return false;
    }
    return candidateId == null ||
        candidateId.trim().isEmpty ||
        parts.first == candidateId.trim();
  }

  static Future<String> resolve(
    String path, {
    String? candidateId,
    bool forceRefresh = false,
    DateTime? now,
    PrivateProfilePhotoSigner? signer,
  }) async {
    final trimmed = path.trim();
    if (!isCandidatePhotoPath(trimmed, candidateId: candidateId)) {
      throw ArgumentError('Candidate profile photo path is invalid.');
    }
    final currentTime = now ?? DateTime.now().toUtc();
    final cached = _cache[trimmed];
    if (!forceRefresh &&
        cached != null &&
        currentTime.isBefore(cached.expiresAt)) {
      return cached.future;
    }

    if (kDebugMode) {
      debugPrint('[ProfilePhoto] resolve=started private_path_present=true');
    }
    final resolveUrl = signer ?? _createSignedUrl;
    final future = resolveUrl(trimmed);
    final entry = _PrivatePhotoCacheEntry(
      future: future,
      expiresAt: currentTime.add(cacheLifetime),
    );
    _cache[trimmed] = entry;
    try {
      final url = await future;
      if (url.trim().isEmpty) throw StateError('Signed URL was empty.');
      if (kDebugMode) debugPrint('[ProfilePhoto] resolve=succeeded');
      return url;
    } catch (_) {
      if (identical(_cache[trimmed], entry)) _cache.remove(trimmed);
      if (kDebugMode) debugPrint('[ProfilePhoto] resolve=failed');
      rethrow;
    }
  }

  static bool needsRefresh(String path, {DateTime? now}) {
    final cached = _cache[path.trim()];
    return cached == null ||
        !(now ?? DateTime.now().toUtc()).isBefore(cached.expiresAt);
  }

  static void invalidate(String path) {
    final trimmed = path.trim();
    if (trimmed.isNotEmpty) _cache.remove(trimmed);
    _notify(previousPath: trimmed, nextPath: trimmed);
  }

  static void replace(String previousPath, String nextPath) {
    final previous = previousPath.trim();
    final next = nextPath.trim();
    if (previous.isNotEmpty) _cache.remove(previous);
    if (next.isNotEmpty) _cache.remove(next);
    _notify(previousPath: previous, nextPath: next);
  }

  static void clear() {
    _cache.clear();
    _notify(previousPath: '', nextPath: '');
  }

  @visibleForTesting
  static bool hasCachedPath(String path) => _cache.containsKey(path.trim());

  static Future<String> _createSignedUrl(String path) {
    return SupabaseService.client.storage
        .from('kaam-private')
        .createSignedUrl(path, signedUrlLifetime.inSeconds);
  }

  static void _notify({
    required String previousPath,
    required String nextPath,
  }) {
    changes.value = PrivateProfilePhotoChange(
      previousPath: previousPath,
      nextPath: nextPath,
      revision: ++_revision,
    );
    if (kDebugMode) debugPrint('[ProfilePhoto] cache=invalidated');
  }
}

class _PrivatePhotoCacheEntry {
  const _PrivatePhotoCacheEntry({
    required this.future,
    required this.expiresAt,
  });

  final Future<String> future;
  final DateTime expiresAt;
}
