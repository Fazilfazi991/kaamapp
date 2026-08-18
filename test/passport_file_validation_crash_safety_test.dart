import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/documents/passport_file_validator.dart';

void main() {
  group('passport file validation crash safety', () {
    final acceptedImageValidator = PassportFileValidator(
      decodeImage: (_) async => true,
    );

    test('1. JPG is accepted', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.jpg',
        bytes: _jpegBytes(),
      );

      expect(result.isValid, isTrue);
      expect(result.kind, PassportFileKind.jpeg);
    });

    test('2. JPEG is accepted', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.jpeg',
        bytes: _jpegBytes(),
      );

      expect(result.isValid, isTrue);
      expect(result.kind, PassportFileKind.jpeg);
    });

    test('3. PNG is accepted', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.png',
        bytes: _pngBytes(),
      );

      expect(result.isValid, isTrue);
      expect(result.kind, PassportFileKind.png);
    });

    test('4. WEBP follows configured support', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.webp',
        bytes: _webpBytes(),
      );

      expect(PassportFileValidator.supportsWebp, isFalse);
      expect(result.code, PassportFileValidationCode.unsupported);
    });

    test('5. PDF follows configured support', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.pdf',
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj\n%%EOF')),
      );

      expect(PassportFileValidator.supportsPdf, isTrue);
      expect(result.isValid, isTrue);
      expect(result.kind, PassportFileKind.pdf);
    });

    test('6. MP4 is rejected before upload', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.mp4',
        bytes: _isoVideoBytes('isom'),
      );

      expect(result.code, PassportFileValidationCode.video);
      expect(result.message, startsWith('Videos cannot be used'));
    });

    test('7. MOV is rejected', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.mov',
        bytes: _isoVideoBytes('qt  '),
      );

      expect(result.code, PassportFileValidationCode.video);
    });

    test('8. renamed video with an image extension is rejected', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'renamed.jpg',
        bytes: _isoVideoBytes('isom'),
      );

      expect(result.code, PassportFileValidationCode.video);
    });

    test('9. unsupported binary is rejected', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.jpg',
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      expect(result.code, PassportFileValidationCode.unsupported);
    });

    test('10. empty file is rejected', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.jpg',
        bytes: Uint8List(0),
      );

      expect(result.code, PassportFileValidationCode.empty);
    });

    test('11. oversized file is rejected', () async {
      final result = await acceptedImageValidator.validate(
        fileName: 'passport.jpg',
        bytes: Uint8List(PassportFileValidator.maxBytes + 1),
      );

      expect(result.code, PassportFileValidationCode.tooLarge);
    });

    test('12. corrupted image is rejected safely', () async {
      final validator = PassportFileValidator(decodeImage: (_) async => false);
      final result = await validator.validate(
        fileName: 'corrupt.jpg',
        bytes: _jpegBytes(),
      );

      expect(result.code, PassportFileValidationCode.unreadable);
    });

    test('13. content URI without normal path is handled', () async {
      const reader = PassportPlatformFileReader();
      final expected = _pngBytes();
      final file = PlatformFile(
        name: 'passport.png',
        size: expected.length,
        path: 'content://documents/passport',
        bytes: expected,
      );

      expect(await reader.read(file), expected);
    });

    test('14. bytes fallback works', () async {
      const reader = PassportPlatformFileReader();
      final expected = _jpegBytes();
      final file = PlatformFile(
        name: 'passport.jpg',
        size: expected.length,
        bytes: expected,
      );

      expect(await reader.read(file), expected);
    });

    test('15. stream fallback works', () async {
      const reader = PassportPlatformFileReader();
      final expected = _pngBytes();
      final file = PlatformFile(
        name: 'passport.png',
        size: expected.length,
        readStream: Stream.fromIterable([
          expected.sublist(0, 4),
          expected.sublist(4),
        ]),
      );

      expect(await reader.read(file), expected);
    });

    test('16. invalid file never reaches OCR', () {
      final source = _uploadSource();
      final pickerStart = source.indexOf('Future<_PickedDocument?> _pickFile');
      final pickerEnd = source.indexOf('Future<_PickedDocument?> _takePhoto');
      final picker = source.substring(pickerStart, pickerEnd);

      expect(picker, contains('await _validatePickedFile('));
      expect(picker, isNot(contains('ocr.extract(')));
    });

    test('17. invalid file never reaches storage upload', () {
      final source = _uploadSource();
      final pickerStart = source.indexOf('Future<_PickedDocument?> _pickFile');
      final pickerEnd = source.indexOf('Future<_PickedDocument?> _takePhoto');
      final picker = source.substring(pickerStart, pickerEnd);

      expect(picker, contains('await _validatePickedFile('));
      expect(picker, isNot(contains('uploadCandidateIdentityDocument(')));
    });

    test('18. invalid front preserves old front and back', () {
      final source = _uploadSource();

      expect(source, contains('final previousUpload ='));
      expect(source, contains('_restorePassportSide('));
      expect(source, contains('pendingReview = previousPendingReview'));
      expect(source, contains('side == _PassportSide.front'));
    });

    test('19. invalid back preserves old back and front', () {
      final source = _uploadSource();

      expect(source, contains('previousFileName'));
      expect(source, contains('previousPreview'));
      expect(source, contains('passportBackUpload = upload'));
      expect(source, contains('passportFrontUpload = upload'));
    });

    test('20. loading state clears after failure', () {
      final source = _uploadSource();

      expect(source, contains('} finally {'));
      expect(source, contains('passportFrontUploading = false'));
      expect(source, contains('passportBackUploading = false'));
      expect(source, contains('uploading = false'));
    });

    test('21. repeated invalid selections do not crash', () async {
      final validator = PassportFileValidator(decodeImage: (_) async => false);

      for (var attempt = 0; attempt < 25; attempt += 1) {
        final result = await validator.validate(
          fileName: 'corrupt.jpg',
          bytes: _jpegBytes(),
        );
        expect(result.code, PassportFileValidationCode.unreadable);
      }
    });

    test('22. raw backend errors are not shown', () {
      final source = _uploadSource();

      expect(source, isNot(contains('uploadError = error.toString()')));
      expect(source, isNot(contains('uploadError = exception.toString()')));
      expect(source, contains('We could not replace the passport front'));
      expect(source, contains('We could not replace the passport back'));
    });

    test('23. candidate stays on the active screen after invalid selection',
        () {
      final source = _uploadSource();
      final firstCatch = source.indexOf('on _UploadException catch (error)');
      final firstFinally = source.indexOf('} finally {', firstCatch);
      final errorBoundary = source.substring(firstCatch, firstFinally);

      expect(
        errorBoundary,
        contains(
          '_setErrorFor(IdentityDocumentType.passport, error.message, side)',
        ),
      );
      expect(errorBoundary, isNot(contains('Navigator.of')));
    });

    test('24. decoder exception cannot terminate the flow', () async {
      final validator = PassportFileValidator(
        decodeImage: (_) => throw StateError('native decoder failure'),
      );

      final result = await validator.validate(
        fileName: 'passport.jpg',
        bytes: _jpegBytes(),
      );

      expect(result.code, PassportFileValidationCode.unreadable);
    });
  });
}

Uint8List _jpegBytes() =>
    Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0xff, 0xd9]);

Uint8List _pngBytes() => Uint8List.fromList(
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, 4],
    );

Uint8List _webpBytes() => Uint8List.fromList([
      ...ascii.encode('RIFF'),
      0,
      0,
      0,
      0,
      ...ascii.encode('WEBP'),
    ]);

Uint8List _isoVideoBytes(String brand) => Uint8List.fromList([
      0,
      0,
      0,
      24,
      ...ascii.encode('ftyp'),
      ...ascii.encode(brand),
      0,
      0,
      0,
      0,
    ]);

String _uploadSource() => File(
      'lib/features/candidate/onboarding/documents_upload_screen.dart',
    ).readAsStringSync();
