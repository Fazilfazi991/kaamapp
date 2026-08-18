import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../supabase_backend/kaam_backend.dart';
import 'document_status_service.dart';
import 'identity_document_ocr_service.dart';

class IdentityDocumentReviewScreen extends StatefulWidget {
  const IdentityDocumentReviewScreen({super.key});

  @override
  State<IdentityDocumentReviewScreen> createState() =>
      _IdentityDocumentReviewScreenState();
}

class _IdentityDocumentReviewScreenState
    extends State<IdentityDocumentReviewScreen> {
  final repository = const CandidateProfileRepository();
  final controllers = <String, TextEditingController>{};
  final replaceProfileFields = <String, bool>{};
  CandidateProfileData profile = const CandidateProfileData();
  bool loading = true;
  bool saving = false;
  bool correctionMode = false;
  late final TextEditingController correctionReasonController;

  IdentityDocumentReviewArgs? get args {
    final value = ModalRoute.of(context)?.settings.arguments;
    return value is IdentityDocumentReviewArgs ? value : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controllers.isEmpty) {
      correctionReasonController = TextEditingController();
      _setup();
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    correctionReasonController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final currentArgs = args;
    if (currentArgs == null) {
      setState(() => loading = false);
      return;
    }
    for (final field in fieldsFor(currentArgs.type)) {
      controllers[field.key] = TextEditingController(
        text: currentArgs.extractedFields[field.key] ?? '',
      );
    }
    try {
      profile = await repository.loadCurrentProfile();
      replaceProfileFields['full_name'] = profile.fullName.trim().isEmpty;
      replaceProfileFields['nationality'] = profile.nationality.trim().isEmpty;
      replaceProfileFields['gender'] = true;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load profile for review: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final currentArgs = args;
    if (currentArgs == null) return;
    final values = {
      for (final entry in controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    if (correctionMode) {
      final reason = correctionReasonController.text.trim();
      if (reason.length < 8) {
        _message('Tell us why the extracted value needs correction.');
        return;
      }
      values['identity_correction_reason'] = reason;
    }

    if (currentArgs.type == IdentityDocumentType.passport) {
      if ((values['full_name'] ?? '').isEmpty) {
        _message('Full name is required.');
        return;
      }
      if ((values['passport_number'] ?? '').isEmpty) {
        _message('Passport number is required.');
        return;
      }
      if ((values['nationality'] ?? '').isEmpty) {
        _message('Nationality is required.');
        return;
      }
      if (!_dateIsValid(values['dob'] ?? '')) {
        _message('Date of birth is required. Use YYYY-MM-DD.');
        return;
      }
      if (!_expiryIsValid(values['passport_expiry_date'] ?? '')) {
        _message('Passport expiry must be a future date. Use YYYY-MM-DD.');
        return;
      }
    }
    if (currentArgs.type == IdentityDocumentType.visa &&
        (values['visa_expiry_date'] ?? '').isNotEmpty &&
        !_expiryIsValid(values['visa_expiry_date']!)) {
      _message('Visa expiry must be a future date. Use YYYY-MM-DD.');
      return;
    }

    setState(() => saving = true);
    try {
      final documentValues = {
        ...values,
        if (currentArgs.type == IdentityDocumentType.passport) ...{
          'passport_file_url': currentArgs.upload.path,
          if (currentArgs.backUpload != null)
            'passport_back_file_url': currentArgs.backUpload!.path,
          'passport_status': DocumentStatusService.pendingVerification,
          'passport_verified': false,
        } else ...{
          'visa_file_url': currentArgs.upload.path,
          'visa_status': DocumentStatusService.pendingVerification,
          'visa_verified': false,
        },
        'ocr_completed': currentArgs.ocrError == null,
      };
      final profileValues = <String, dynamic>{};
      final candidateValues = <String, dynamic>{};
      if (_shouldApply('full_name')) {
        profileValues['full_name'] = values['full_name'];
      }
      if (_shouldApply('nationality')) {
        candidateValues['nationality'] = values['nationality'];
      }
      if (_shouldApply('gender')) {
        candidateValues['gender'] = values['gender'];
      }

      await repository.saveIdentityDocuments(
        documentValues,
        profileValues: profileValues,
        candidateValues: candidateValues,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Passport submitted'),
          content: const Text(
            'Passport submitted successfully. Your document is now under review.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Identity review save failed: type=${error.runtimeType}');
      _message('We couldn\'t save your passport details. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  bool _shouldApply(String key) {
    final value = controllers[key]?.text.trim() ?? '';
    if (value.isEmpty) return false;
    return replaceProfileFields[key] ?? true;
  }

  bool _expiryIsValid(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return false;
    final today = DateTime.now();
    return date.isAfter(DateTime(today.year, today.month, today.day));
  }

  bool _dateIsValid(String value) {
    return DateTime.tryParse(value.trim()) != null;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentArgs = args;
    if (currentArgs == null) {
      return const ScreenScaffold(
        title: 'Review Extracted Details',
        showBack: true,
        children: [Text('Open this screen after uploading a document.')],
      );
    }
    final fields = fieldsFor(currentArgs.type);
    return ScreenScaffold(
      title: 'Review Extracted Details',
      showBack: true,
      children: [
        const Text(
          'Please verify the extracted information before continuing.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        const AppCard(
          child: Text(
            'These values come from the validated document. They are locked by default to protect against accidental or arbitrary changes.',
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: correctionMode
              ? 'Cancel correction'
              : 'Correct an extracted value',
          onPressed: saving
              ? null
              : () => setState(() => correctionMode = !correctionMode),
        ),
        if (correctionMode) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: correctionReasonController,
            label: 'Reason for correction',
            hint: 'For example: my middle name was omitted',
          ),
        ],
        const SizedBox(height: 16),
        _UploadedFilesCard(args: currentArgs),
        const SizedBox(height: 16),
        for (final field in fields) ...[
          AppTextField(
            controller: controllers[field.key],
            label: field.label,
            hint: field.key.contains('date') || field.key == 'dob'
                ? 'YYYY-MM-DD'
                : null,
            readOnly: !correctionMode,
          ),
          if (_hasProfileConflict(field.key))
            _ConflictChoice(
              existingValue: _existingValue(field.key),
              replace: replaceProfileFields[field.key] ?? false,
              onChanged: (value) =>
                  setState(() => replaceProfileFields[field.key] = value),
            ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: saving ? 'Saving...' : 'Save & Continue',
                onPressed: saving ? null : _save,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _hasProfileConflict(String key) {
    final existing = _existingValue(key);
    final incoming = controllers[key]?.text.trim() ?? '';
    return existing.isNotEmpty &&
        incoming.isNotEmpty &&
        existing.toLowerCase() != incoming.toLowerCase();
  }

  String _existingValue(String key) {
    return switch (key) {
      'full_name' => profile.fullName,
      'nationality' => profile.nationality,
      _ => '',
    };
  }
}

class _UploadedFilesCard extends StatelessWidget {
  const _UploadedFilesCard({required this.args});

  final IdentityDocumentReviewArgs args;

  @override
  Widget build(BuildContext context) {
    final isPassport = args.type == IdentityDocumentType.passport;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Uploaded files', style: AppTextStyles.label),
          const SizedBox(height: 8),
          _FileLine(
            label: isPassport ? 'Front' : 'Document',
            path: args.upload.path,
          ),
          if (args.backUpload != null) ...[
            const SizedBox(height: 6),
            _FileLine(label: 'Back', path: args.backUpload!.path),
          ],
        ],
      ),
    );
  }
}

class _FileLine extends StatelessWidget {
  const _FileLine({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: AppTextStyles.muted),
        Expanded(
          child: Text(
            path.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body,
          ),
        ),
      ],
    );
  }
}

class _ConflictChoice extends StatelessWidget {
  const _ConflictChoice({
    required this.existingValue,
    required this.replace,
    required this.onChanged,
  });

  final String existingValue;
  final bool replace;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This field already contains information.',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 6),
          Text('Existing: $existingValue', style: AppTextStyles.muted),
          _ChoiceRow(
            label: 'Keep Existing',
            selected: !replace,
            onTap: () => onChanged(false),
          ),
          _ChoiceRow(
            label: 'Replace With Extracted',
            selected: replace,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}
