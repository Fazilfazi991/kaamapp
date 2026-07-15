import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../supabase_backend/kaam_backend.dart';
import 'identity_document_ocr_service.dart';

class DocumentStatusService {
  const DocumentStatusService._();

  static const pendingVerification = 'pending_verification';
  static const verified = 'verified';
  static const rejected = 'rejected';
  static const reuploadRequired = 'reupload_required';
  static const notUploaded = 'not_uploaded';

  static String normalized(String status, {required bool uploaded, String expiry = ''}) {
    if (!uploaded) return notUploaded;
    if (isExpired(expiry)) return 'expired';
    final value = status.trim().toLowerCase();
    return value.isEmpty ? pendingVerification : value;
  }

  static String label(String status, {required bool uploaded, String expiry = ''}) {
    return switch (normalized(status, uploaded: uploaded, expiry: expiry)) {
      verified => 'Verified',
      rejected => 'Rejected',
      reuploadRequired => 'Re-upload Required',
      'expired' => 'Expired',
      notUploaded => 'Not Uploaded',
      _ => 'Pending Verification',
    };
  }

  static Color color(String status, {required bool uploaded, String expiry = ''}) {
    return switch (normalized(status, uploaded: uploaded, expiry: expiry)) {
      verified => AppColors.success,
      rejected || reuploadRequired || 'expired' => AppColors.error,
      notUploaded => AppColors.mutedText,
      _ => AppColors.warning,
    };
  }

  static IconData icon(String status, {required bool uploaded, String expiry = ''}) {
    return switch (normalized(status, uploaded: uploaded, expiry: expiry)) {
      verified => Icons.verified_rounded,
      rejected || reuploadRequired || 'expired' => Icons.warning_amber_rounded,
      notUploaded => Icons.upload_file_rounded,
      _ => Icons.pending_actions_rounded,
    };
  }

  static bool isExpired(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return false;
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }

  static String validityText(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return 'Expiry not set';
    final today = DateTime.now();
    final days = date.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    if (days < 90) return 'Expires in $days days';
    final months = (days / 30).floor();
    if (months < 24) return 'Expires in $months months';
    final years = (days / 365).floor();
    return 'Expires in $years years';
  }

  static List<String> reminderDates(String expiryDate) {
    final date = DateTime.tryParse(expiryDate.trim());
    if (date == null) return const [];
    return [90, 60, 30, 7]
        .map((days) => date.subtract(Duration(days: days)).toUtc().toIso8601String())
        .toList();
  }

  static List<DocumentTimelineEntry> timeline({
    required CandidateIdentityDocumentData identity,
    required IdentityDocumentType type,
    required List<CandidateDocumentVersionData> versions,
  }) {
    final isPassport = type == IdentityDocumentType.passport;
    final uploadedAt = isPassport ? identity.passportUploadedAt : identity.visaUploadedAt;
    final status = isPassport ? identity.passportStatus : identity.visaStatus;
    final version = isPassport ? identity.passportVersion : identity.visaVersion;
    final entries = <DocumentTimelineEntry>[];
    if (uploadedAt.isNotEmpty) {
      entries.add(DocumentTimelineEntry('Document uploaded', uploadedAt));
      if (identity.ocrCompleted) entries.add(DocumentTimelineEntry('OCR completed', uploadedAt));
      entries.add(DocumentTimelineEntry('Profile updated', identity.updatedAt.isEmpty ? uploadedAt : identity.updatedAt));
      entries.add(DocumentTimelineEntry(label(status, uploaded: true), uploadedAt));
      entries.add(DocumentTimelineEntry('Latest version v$version', uploadedAt));
    }
    for (final old in versions.where((item) => item.documentType == type.name && !item.isActive)) {
      entries.add(DocumentTimelineEntry('Previous version v${old.versionNumber}', old.createdAt));
    }
    return entries;
  }
}

class DocumentTimelineEntry {
  const DocumentTimelineEntry(this.title, this.date);

  final String title;
  final String date;
}
