import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../supabase_backend/kaam_backend.dart';

class StructuredOption {
  const StructuredOption({required this.code, required this.label});

  final String code;
  final String label;
}

class EmployerCompanyOptions {
  const EmployerCompanyOptions._();

  static const companySizes = [
    StructuredOption(code: '1_10', label: '1-10'),
    StructuredOption(code: '11_25', label: '11-25'),
    StructuredOption(code: '26_50', label: '26-50'),
    StructuredOption(code: '51_100', label: '51-100'),
    StructuredOption(code: '101_250', label: '101-250'),
    StructuredOption(code: '251_500', label: '251-500'),
    StructuredOption(code: '500_plus', label: '500+'),
  ];

  static const contactRoles = [
    StructuredOption(code: 'owner', label: 'Owner'),
    StructuredOption(code: 'founder', label: 'Founder'),
    StructuredOption(code: 'co_founder', label: 'Co-Founder'),
    StructuredOption(code: 'managing_director', label: 'Managing Director'),
    StructuredOption(code: 'director', label: 'Director'),
    StructuredOption(code: 'general_manager', label: 'General Manager'),
    StructuredOption(code: 'hr_manager', label: 'HR Manager'),
    StructuredOption(code: 'hr_executive', label: 'HR Executive'),
    StructuredOption(code: 'recruitment_manager', label: 'Recruitment Manager'),
    StructuredOption(code: 'recruiter', label: 'Recruiter'),
    StructuredOption(code: 'operations_manager', label: 'Operations Manager'),
    StructuredOption(
        code: 'operations_executive', label: 'Operations Executive'),
    StructuredOption(code: 'admin_manager', label: 'Admin Manager'),
    StructuredOption(code: 'administrator', label: 'Administrator'),
    StructuredOption(code: 'supervisor', label: 'Supervisor'),
    StructuredOption(code: 'pro', label: 'PRO'),
    StructuredOption(code: 'other', label: 'Other'),
  ];
}

String? retainedAreaForEmirateChange({
  required String nextEmirate,
  required String? currentArea,
}) {
  if (currentArea == null || currentArea.trim().isEmpty) return null;
  return CandidateLocationOptions.isValidAreaForEmirate(
          nextEmirate, currentArea)
      ? currentArea
      : null;
}

class SelectionField extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    this.onTap,
    this.errorText,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback? onTap;
  final String? errorText;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    final canTap = enabled && !loading && onTap != null;
    return Semantics(
      button: canTap,
      enabled: canTap,
      label: '$label: ${hasValue ? value : hint}',
      child: InkWell(
        onTap: canTap ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color:
                        canTap ? AppColors.secondaryText : AppColors.mutedText,
                  ),
          ),
          child: Text(
            loading ? 'Loading…' : (hasValue ? value : hint),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: hasValue ? AppTextStyles.body : AppTextStyles.muted,
          ),
        ),
      ),
    );
  }
}

Future<T?> showSearchSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T option) label,
  T? selected,
  bool loading = false,
  String? errorText,
  Future<void> Function()? onRetry,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _SearchSelectionSheet<T>(
      title: title,
      options: options,
      label: label,
      selected: selected,
      loading: loading,
      errorText: errorText,
      onRetry: onRetry,
    ),
  );
}

class _SearchSelectionSheet<T> extends StatefulWidget {
  const _SearchSelectionSheet({
    required this.title,
    required this.options,
    required this.label,
    required this.selected,
    required this.loading,
    required this.errorText,
    required this.onRetry,
  });

  final String title;
  final List<T> options;
  final String Function(T option) label;
  final T? selected;
  final bool loading;
  final String? errorText;
  final Future<void> Function()? onRetry;

  @override
  State<_SearchSelectionSheet<T>> createState() =>
      _SearchSelectionSheetState<T>();
}

class _SearchSelectionSheetState<T> extends State<_SearchSelectionSheet<T>> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = widget.options
        .where((option) =>
            widget.label(option).toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.36,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Expanded(
                      child: Text(widget.title, style: AppTextStyles.title)),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.loading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.errorText != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(widget.errorText!,
                                    textAlign: TextAlign.center),
                                if (widget.onRetry != null) ...[
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => widget.onRetry!(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(child: Text('No matching options.'))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final isSelected = option == widget.selected;
                                return ListTile(
                                  title: Text(widget.label(option),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          color: AppColors.primaryPink)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(context).pop(option),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
