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

  IdentityDocumentReviewArgs? get args {
    final value = ModalRoute.of(context)?.settings.arguments;
    return value is IdentityDocumentReviewArgs ? value : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controllers.isEmpty) _setup();
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity details saved.')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ));
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
            'If automatic reading misses anything, enter it manually. KAAM never guesses document values.',
            style: AppTextStyles.body,
          ),
        ),
        if (currentArgs.ocrError != null) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We could not automatically read your passport.',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 6),
                const Text('Please enter your details manually.',
                    style: AppTextStyles.body),
                const SizedBox(height: 6),
                Text(currentArgs.ocrError!, style: AppTextStyles.muted),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final field in fields) ...[
          AppTextField(
            controller: controllers[field.key],
            label: field.label,
            hint: field.key.contains('date') || field.key == 'dob'
                ? 'YYYY-MM-DD'
                : null,
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
                    onPressed: () => Navigator.of(context).pop())),
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
          const Text('This field already contains information.',
              style: AppTextStyles.label),
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
