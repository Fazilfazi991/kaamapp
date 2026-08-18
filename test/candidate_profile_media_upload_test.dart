import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('candidate profile media uploads', () {
    late final String mediaSource;
    late final String backendSource;
    late final String resolverSource;
    late final String avatarSource;
    late final String storageSql;

    setUpAll(() {
      mediaSource = File(
        'lib/features/candidate/onboarding/profile_media_screen.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      resolverSource = File(
        'lib/core/storage/private_profile_photo_resolver.dart',
      ).readAsStringSync();
      avatarSource = File(
        'lib/core/widgets/private_profile_photo_avatar.dart',
      ).readAsStringSync();
      storageSql = [
        File('supabase/001_kaam_initial_schema.sql').readAsStringSync(),
        File('supabase/002_mvp_functionality_patch.sql').readAsStringSync(),
      ].join('\n');
    });

    test('CV upload supports PDF DOC and DOCX with Android content bytes', () {
      expect(mediaSource, contains("withData: true"));
      expect(mediaSource, contains("withReadStream: true"));
      expect(mediaSource, contains("_readPlatformFileBytes(file)"));
      expect(mediaSource, contains("file.bytes"));
      expect(mediaSource, contains("file.readStream"));
      expect(mediaSource, contains("!path.startsWith('content://')"));
      expect(mediaSource, contains("'pdf', 'doc', 'docx'"));
      expect(mediaSource, contains("folder: 'candidate-cv'"));
    });

    test('CV failures map to safe useful messages', () {
      expect(mediaSource, contains('Unsupported CV format'));
      expect(mediaSource, contains('smaller than 10 MB'));
      expect(mediaSource, contains('We could not read this file'));
      expect(mediaSource, contains('We could not upload your CV right now'));
      expect(mediaSource, contains('_debugMediaUpload'));
      expect(mediaSource, isNot(contains('PostgrestException(')));
    });

    test('CV metadata persists through candidate profile fields', () {
      expect(backendSource, contains("'resume_url': path"));
      expect(
        backendSource,
        contains("'resume_file_name': _nullable(fileName)"),
      );
      expect(backendSource, contains("'resume_file_size': fileSize"));
      expect(mediaSource, contains('profile.resumeFileName'));
      expect(mediaSource, contains('profile.resumeFileSize'));
      expect(mediaSource, contains('CV uploaded successfully.'));
      expect(mediaSource, contains('Remove CV'));
    });

    test('profile photo preview uses local image then signed private URL', () {
      expect(mediaSource, contains('localPhotoBytes = bytes'));
      expect(mediaSource, contains('PrivateProfilePhotoAvatar'));
      expect(mediaSource, contains('localBytes: localBytes'));
      expect(resolverSource, contains(".from('kaam-private')"));
      expect(resolverSource, contains('.createSignedUrl('));
      expect(avatarSource, contains('BoxFit.cover'));
      expect(avatarSource, contains('gaplessPlayback: true'));
    });

    test('profile photo replace and remove update visible state', () {
      expect(mediaSource, contains('Replace Photo'));
      expect(mediaSource, contains('Choose from Gallery'));
      expect(mediaSource, contains('Remove Photo'));
      expect(mediaSource, contains('localPhotoBytes = null'));
      expect(mediaSource, contains('PrivateProfilePhotoResolver.replace'));
      expect(backendSource, contains("'profile_photo_url': path"));
      expect(
        backendSource,
        contains("'profile_photo_file_name': _nullable(fileName)"),
      );
    });

    test('private storage policies remain owner scoped', () {
      expect(storageSql, contains('kaam-private'));
      expect(storageSql, contains('kaam_private_owner_upload'));
      expect(storageSql, contains('kaam_private_owner_read'));
      expect(storageSql, contains('auth.uid()::text'));
      expect(
        storageSql,
        isNot(contains('bucket_id = \'kaam-private\' and true')),
      );
      expect(storageSql, isNot(contains('using (true)')));
      expect(storageSql, isNot(contains('with check (true)')));
    });
  });
}
