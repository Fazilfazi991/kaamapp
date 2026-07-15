import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../supabase_backend/kaam_backend.dart';

enum IdentityDocumentType { passport, visa }

class IdentityDocumentReviewArgs {
  const IdentityDocumentReviewArgs({
    required this.type,
    required this.upload,
    required this.extraction,
    this.ocrError,
  });

  final IdentityDocumentType type;
  final KaamUploadResult upload;
  final PassportExtractionResult extraction;
  final String? ocrError;

  Map<String, String> get extractedFields => extraction.toIdentityFields();
}

class PassportExtractionResult {
  const PassportExtractionResult({
    this.fullName,
    this.firstName,
    this.lastName,
    this.passportNumber,
    this.nationality,
    this.dateOfBirth,
    this.gender,
    this.issueDate,
    this.expiryDate,
    this.placeOfBirth,
    this.countryOfIssue,
    this.confidenceScores = const {},
    this.rawText,
    this.responseKeys = const [],
  });

  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? passportNumber;
  final String? nationality;
  final DateTime? dateOfBirth;
  final String? gender;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? placeOfBirth;
  final String? countryOfIssue;
  final Map<String, double> confidenceScores;
  final String? rawText;
  final List<String> responseKeys;

  bool get hasAnyData {
    return [
      fullName,
      passportNumber,
      nationality,
      gender,
      placeOfBirth,
      countryOfIssue,
      rawText,
    ].whereType<String>().any((value) => value.trim().isNotEmpty) ||
        dateOfBirth != null ||
        issueDate != null ||
        expiryDate != null;
  }

  Map<String, String> toIdentityFields() {
    return {
      'full_name': _clean(fullName ?? _joinedName),
      'passport_number': _clean(passportNumber),
      'nationality': _clean(nationality),
      'dob': _formatDate(dateOfBirth),
      'gender': _clean(gender),
      'passport_issue_date': _formatDate(issueDate),
      'passport_expiry_date': _formatDate(expiryDate),
      'place_of_birth': _clean(placeOfBirth),
      'country_of_issue': _clean(countryOfIssue),
    };
  }

  String get _joinedName {
    return [firstName, lastName]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
  }

  static PassportExtractionResult empty() => const PassportExtractionResult();

  static PassportExtractionResult fromResponse(dynamic response) {
    final root = _asMap(response);
    if (root.isEmpty) return empty();
    final data = _asMap(root['data']).isNotEmpty ? _asMap(root['data']) : root;
    final confidence = _confidence(root['confidence'] ?? data['confidence']);
    final rawText = _firstRawString(data, const [
      'raw_text',
      'rawText',
      'text',
      'ocr_text',
      'mrz',
      'mrz_text',
      'mrzText',
    ]);
    final mrz = _parseMrz(rawText ?? _firstString(data, const ['mrz_text', 'mrzText']));

    return PassportExtractionResult(
      fullName: _firstString(data, const ['full_name', 'fullName', 'name', 'holder_name', 'holderName']) ??
          mrz.fullName,
      firstName: _firstString(data, const ['first_name', 'firstName', 'given_names', 'givenNames']) ??
          mrz.firstName,
      lastName: _firstString(data, const ['last_name', 'lastName', 'surname']) ?? mrz.lastName,
      passportNumber: _firstString(data, const [
            'passport_number',
            'passportNumber',
            'document_number',
            'documentNumber',
            'number',
          ]) ??
          mrz.passportNumber,
      nationality: _firstString(data, const ['nationality', 'nationality_code', 'nationalityCode']) ??
          mrz.nationality,
      dateOfBirth: _firstDate(data, const ['date_of_birth', 'dateOfBirth', 'dob', 'birth_date', 'birthDate']) ??
          mrz.dateOfBirth,
      gender: _firstString(data, const ['sex', 'gender']) ?? mrz.gender,
      issueDate: _firstDate(data, const ['issue_date', 'issueDate', 'date_of_issue']),
      expiryDate: _firstDate(data, const ['expiry_date', 'expiryDate', 'expiration_date', 'date_of_expiry']) ??
          mrz.expiryDate,
      placeOfBirth: _firstString(data, const ['place_of_birth', 'placeOfBirth', 'birth_place']),
      countryOfIssue: _firstString(data, const ['country_of_issue', 'countryOfIssue', 'issuing_country', 'issuingCountry']) ??
          mrz.countryOfIssue,
      confidenceScores: confidence,
      rawText: rawText,
      responseKeys: data.keys.map((key) => key.toString()).toList()..sort(),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  static String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return _clean(text);
    }
    return null;
  }

  static String? _firstRawString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static DateTime? _firstDate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _parseDate(value?.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final text = value.trim();
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final normalized = text.replaceAll(RegExp(r'[./]'), '-');
    final parts = normalized.split('-');
    if (parts.length == 3) {
      if (parts.first.length == 4) {
        return DateTime.tryParse(normalized);
      }
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) return DateTime(year, month, day);
    }
    return null;
  }

  static Map<String, double> _confidence(dynamic value) {
    final map = _asMap(value);
    return map.map((key, value) {
      final parsed = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
      return MapEntry(key, parsed);
    });
  }

  static PassportExtractionResult _parseMrz(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty();
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim().replaceAll(' ', ''))
        .where((line) => line.length >= 30)
        .toList();
    final start = lines.indexWhere((line) => line.startsWith('P<'));
    if (start < 0 || lines.length <= start + 1) return empty();
    final line1 = lines[start].padRight(44, '<').substring(0, 44);
    final line2 = lines[start + 1].padRight(44, '<').substring(0, 44);
    final country = line1.substring(2, 5).replaceAll('<', '');
    final names = line1.substring(5).split('<<');
    final lastName = _mrzName(names.isNotEmpty ? names[0] : '');
    final firstName = _mrzName(names.length > 1 ? names[1] : '');
    final passportNumber = line2.substring(0, 9).replaceAll('<', '');
    final nationality = line2.substring(10, 13).replaceAll('<', '');
    return PassportExtractionResult(
      fullName: [firstName, lastName].where((value) => value.isNotEmpty).join(' '),
      firstName: firstName,
      lastName: lastName,
      passportNumber: passportNumber,
      nationality: nationality,
      dateOfBirth: _parseMrzDate(line2.substring(13, 19), isBirthDate: true),
      gender: line2.substring(20, 21).replaceAll('<', ''),
      expiryDate: _parseMrzDate(line2.substring(21, 27), isBirthDate: false),
      countryOfIssue: country,
      rawText: raw,
    );
  }

  static DateTime? _parseMrzDate(String value, {required bool isBirthDate}) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return null;
    final yy = int.parse(value.substring(0, 2));
    final mm = int.parse(value.substring(2, 4));
    final dd = int.parse(value.substring(4, 6));
    final now = DateTime.now();
    var year = isBirthDate ? 1900 + yy : 2000 + yy;
    if (isBirthDate && year > now.year) year -= 100;
    if (!isBirthDate && year < now.year - 10) year += 100;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    return DateTime(year, mm, dd);
  }

  static String _mrzName(String value) {
    return value
        .split('<')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0] + part.substring(1).toLowerCase())
        .join(' ');
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _clean(String? value) => value?.replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
}

abstract class IdentityDocumentOcrService {
  Future<PassportExtractionResult> extract({
    required IdentityDocumentType type,
    required KaamUploadResult upload,
    required String fileName,
  });
}

class SupabaseIdentityOcrService implements IdentityDocumentOcrService {
  const SupabaseIdentityOcrService();

  @override
  Future<PassportExtractionResult> extract({
    required IdentityDocumentType type,
    required KaamUploadResult upload,
    required String fileName,
  }) async {
    final functionName = AppConfig.ocrEdgeFunction.trim();
    if (functionName.isEmpty) {
      throw StateError('OCR Edge Function is not configured.');
    }
    final client = SupabaseService.maybeClient;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    if (kDebugMode) {
      debugPrint('Kaam OCR: request started for ${type.name}');
      debugPrint('Kaam OCR: storage path ${_safePath(upload.path)}');
    }
    final response = await client.functions.invoke(
      functionName,
      body: {
        'document_type': type.name,
        'bucket': upload.bucket,
        'path': upload.path,
        'file_name': fileName,
      },
    );
    if (kDebugMode) {
      debugPrint('Kaam OCR: response status ${response.status}');
    }
    if (response.status >= 400) {
      throw StateError('OCR request failed with status ${response.status}.');
    }
    final result = PassportExtractionResult.fromResponse(response.data);
    if (kDebugMode) {
      debugPrint('Kaam OCR: response keys ${result.responseKeys.join(', ')}');
      debugPrint('Kaam OCR: parsed passport ${_masked(result.passportNumber)}');
    }
    if (!result.hasAnyData) {
      throw StateError('OCR returned no readable passport data.');
    }
    return result;
  }

  String _safePath(String value) {
    final parts = value.split('/');
    if (parts.length <= 2) return value;
    return '${parts.first}/.../${parts.last}';
  }

  String _masked(String? value) {
    final text = value ?? '';
    if (text.length < 3) return 'not found';
    return '${text[0]}******${text[text.length - 1]}';
  }
}

class SafeFallbackIdentityOcrService implements IdentityDocumentOcrService {
  const SafeFallbackIdentityOcrService();

  @override
  Future<PassportExtractionResult> extract({
    required IdentityDocumentType type,
    required KaamUploadResult upload,
    required String fileName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return PassportExtractionResult.empty();
  }
}

class IdentityFieldSpec {
  const IdentityFieldSpec(this.key, this.label);

  final String key;
  final String label;
}

List<IdentityFieldSpec> fieldsFor(IdentityDocumentType type) {
  return switch (type) {
    IdentityDocumentType.passport => const [
        IdentityFieldSpec('full_name', 'Full Name'),
        IdentityFieldSpec('passport_number', 'Passport Number'),
        IdentityFieldSpec('nationality', 'Nationality'),
        IdentityFieldSpec('dob', 'Date of Birth'),
        IdentityFieldSpec('gender', 'Gender'),
        IdentityFieldSpec('passport_issue_date', 'Issue Date'),
        IdentityFieldSpec('passport_expiry_date', 'Expiry Date'),
        IdentityFieldSpec('place_of_birth', 'Place of Birth'),
        IdentityFieldSpec('country_of_issue', 'Country of Issue'),
      ],
    IdentityDocumentType.visa => const [
        IdentityFieldSpec('visa_number', 'Visa Number'),
        IdentityFieldSpec('visa_type', 'Visa Type'),
        IdentityFieldSpec('occupation', 'Occupation'),
        IdentityFieldSpec('sponsor', 'Sponsor'),
        IdentityFieldSpec('uid_number', 'UID'),
        IdentityFieldSpec('emirates_id', 'Emirates ID Number'),
        IdentityFieldSpec('visa_issue_date', 'Issue Date'),
        IdentityFieldSpec('visa_expiry_date', 'Expiry Date'),
      ],
  };
}
