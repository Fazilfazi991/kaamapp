import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

enum PassportFileValidationCode {
  valid,
  video,
  unsupported,
  empty,
  tooLarge,
  unreadable,
}

enum PassportFileKind { jpeg, png, pdf }

class PassportFileValidationResult {
  const PassportFileValidationResult(this.code, {this.kind});

  final PassportFileValidationCode code;
  final PassportFileKind? kind;

  bool get isValid => code == PassportFileValidationCode.valid;

  String get message => switch (code) {
        PassportFileValidationCode.video =>
          'Videos cannot be used as passport documents. Please choose an image.',
        PassportFileValidationCode.unsupported =>
          'Unsupported passport file. Please upload a JPG, JPEG, PNG, or supported PDF.',
        PassportFileValidationCode.empty =>
          'We could not read this file. Please choose another one.',
        PassportFileValidationCode.tooLarge =>
          'This file is too large. Please choose a smaller passport image.',
        PassportFileValidationCode.unreadable =>
          'We could not read this file. Please choose another one.',
        PassportFileValidationCode.valid => '',
      };
}

typedef PassportImageDecoder = Future<bool> Function(Uint8List bytes);

class PassportFileValidator {
  PassportFileValidator({PassportImageDecoder? decodeImage})
      : _decodeImage = decodeImage ?? _canDecodeImage;

  static const maxBytes = 10 * 1024 * 1024;
  static const supportsWebp = false;
  static const supportsPdf = true;
  static const supportedExtensions = {'jpg', 'jpeg', 'png', 'pdf'};

  final PassportImageDecoder _decodeImage;

  Future<PassportFileValidationResult> validate({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      return const PassportFileValidationResult(
        PassportFileValidationCode.empty,
      );
    }
    if (bytes.length > maxBytes) {
      return const PassportFileValidationResult(
        PassportFileValidationCode.tooLarge,
      );
    }
    if (_isVideo(bytes)) {
      return const PassportFileValidationResult(
        PassportFileValidationCode.video,
      );
    }

    final extension = _extension(fileName);
    if (!supportedExtensions.contains(extension)) {
      return const PassportFileValidationResult(
        PassportFileValidationCode.unsupported,
      );
    }

    final kind = _kindFromSignature(bytes);
    if (kind == null || !_extensionMatchesKind(extension, kind)) {
      return const PassportFileValidationResult(
        PassportFileValidationCode.unsupported,
      );
    }
    if (kind == PassportFileKind.pdf) {
      return _hasPdfEndMarker(bytes)
          ? const PassportFileValidationResult(
              PassportFileValidationCode.valid,
              kind: PassportFileKind.pdf,
            )
          : const PassportFileValidationResult(
              PassportFileValidationCode.unreadable,
            );
    }
    var decodable = false;
    try {
      decodable = await _decodeImage(bytes);
    } catch (_) {
      decodable = false;
    }
    if (!decodable) {
      return const PassportFileValidationResult(
        PassportFileValidationCode.unreadable,
      );
    }
    return PassportFileValidationResult(
      PassportFileValidationCode.valid,
      kind: kind,
    );
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).trim().toLowerCase();
  }

  static PassportFileKind? _kindFromSignature(Uint8List bytes) {
    if (_startsWith(bytes, const [0xff, 0xd8, 0xff])) {
      return PassportFileKind.jpeg;
    }
    if (_startsWith(
      bytes,
      const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    )) {
      return PassportFileKind.png;
    }
    if (supportsPdf &&
        _startsWith(bytes, const [0x25, 0x50, 0x44, 0x46, 0x2d])) {
      return PassportFileKind.pdf;
    }
    return null;
  }

  static bool _extensionMatchesKind(
    String extension,
    PassportFileKind kind,
  ) =>
      switch (kind) {
        PassportFileKind.jpeg => extension == 'jpg' || extension == 'jpeg',
        PassportFileKind.png => extension == 'png',
        PassportFileKind.pdf => extension == 'pdf',
      };

  static bool _isVideo(Uint8List bytes) {
    if (bytes.length >= 12) {
      final riff = _asciiAt(bytes, 0, 'RIFF');
      if (riff && _asciiAt(bytes, 8, 'AVI ')) return true;
      if (_asciiAt(bytes, 4, 'ftyp')) return true; // MP4 and MOV families.
    }
    return _startsWith(bytes, const [0x1a, 0x45, 0xdf, 0xa3]); // MKV/WebM.
  }

  static bool _hasPdfEndMarker(Uint8List bytes) {
    final start = bytes.length > 2048 ? bytes.length - 2048 : 0;
    for (var index = start; index <= bytes.length - 5; index += 1) {
      if (_asciiAt(bytes, index, '%%EOF')) return true;
    }
    return false;
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  static bool _asciiAt(Uint8List bytes, int offset, String value) {
    if (offset < 0 || bytes.length < offset + value.length) return false;
    for (var index = 0; index < value.length; index += 1) {
      if (bytes[offset + index] != value.codeUnitAt(index)) return false;
    }
    return true;
  }

  static Future<bool> _canDecodeImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      return true;
    } catch (_) {
      return false;
    } finally {
      codec?.dispose();
    }
  }
}

class PassportFileReadException implements Exception {
  const PassportFileReadException();

  String get message =>
      'We could not read this file. Please choose another image.';
}

class PassportPlatformFileReader {
  const PassportPlatformFileReader();

  Future<Uint8List> read(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;

    final stream = file.readStream;
    if (stream != null) {
      try {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in stream) {
          builder.add(chunk);
          if (builder.length > PassportFileValidator.maxBytes) {
            break;
          }
        }
        return builder.takeBytes();
      } catch (_) {
        throw const PassportFileReadException();
      }
    }

    final path = file.path?.trim() ?? '';
    if (path.isNotEmpty && !path.toLowerCase().startsWith('content://')) {
      try {
        return await File(path).readAsBytes();
      } catch (_) {
        throw const PassportFileReadException();
      }
    }
    throw const PassportFileReadException();
  }
}
