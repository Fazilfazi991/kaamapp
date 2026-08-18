import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../taxonomy/taxonomy_repository.dart';

Future<TaxonomyRole?> showJobRoleSearchSheet({
  required BuildContext context,
  required Future<List<TaxonomyRole>> Function(String query) search,
  TaxonomyRole? selected,
}) {
  return showModalBottomSheet<TaxonomyRole>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _JobRoleSearchSheet(search: search, selected: selected),
  );
}

class _JobRoleSearchSheet extends StatefulWidget {
  const _JobRoleSearchSheet({required this.search, this.selected});
  final Future<List<TaxonomyRole>> Function(String query) search;
  final TaxonomyRole? selected;

  @override
  State<_JobRoleSearchSheet> createState() => _JobRoleSearchSheetState();
}

class _JobRoleSearchSheetState extends State<_JobRoleSearchSheet> {
  final controller = TextEditingController();
  Timer? debounce;
  List<TaxonomyRole> results = const [];
  String? error;
  bool loading = false;
  int requestId = 0;

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final currentRequest = ++requestId;
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          results = const [];
          error = null;
          loading = false;
        });
      }
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.search(query);
      if (!mounted || currentRequest != requestId) return;
      setState(() {
        results = loaded;
        loading = false;
      });
    } on Object catch (exception, stackTrace) {
      if (kDebugMode) {
        debugPrint('[EmployerTaxonomy] job-role search failed: $exception');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted || currentRequest != requestId) return;
      setState(() {
        error = 'Unable to load job roles.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SearchSheetFrame(
        title: 'Select Job Role',
        controller: controller,
        hint: 'Search job roles...',
        onChanged: _onChanged,
        loading: loading,
        error: error,
        onRetry: () => _search(controller.text),
        emptyMessage: controller.text.trim().isEmpty
            ? 'Type to search live job roles.'
            : 'No matching job roles.',
        child: ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final role = results[index];
            final isSelected = role.id == widget.selected?.id;
            return ListTile(
              title:
                  Text(role.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${role.category} • ${role.industry}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.primaryPink)
                  : null,
              onTap: () => Navigator.of(context).pop(role),
            );
          },
        ),
      );
}

Future<List<CompetencySkill>?> showCompetencySkillSearchSheet({
  required BuildContext context,
  required Future<List<CompetencySkill>> Function(String query) search,
  required Iterable<CompetencySkill> selected,
}) {
  return showModalBottomSheet<List<CompetencySkill>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _CompetencySkillSearchSheet(search: search, selected: selected),
  );
}

class _CompetencySkillSearchSheet extends StatefulWidget {
  const _CompetencySkillSearchSheet(
      {required this.search, required this.selected});
  final Future<List<CompetencySkill>> Function(String query) search;
  final Iterable<CompetencySkill> selected;
  @override
  State<_CompetencySkillSearchSheet> createState() =>
      _CompetencySkillSearchSheetState();
}

class _CompetencySkillSearchSheetState
    extends State<_CompetencySkillSearchSheet> {
  final controller = TextEditingController();
  late final Map<String, CompetencySkill> selected = {
    for (final skill in widget.selected) skill.id: skill
  };
  Timer? debounce;
  List<CompetencySkill> results = const [];
  String? error;
  bool loading = false;
  int requestId = 0;
  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final currentRequest = ++requestId;
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          results = const [];
          error = null;
          loading = false;
        });
      }
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.search(query);
      if (!mounted || currentRequest != requestId) return;
      setState(() {
        results = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted || currentRequest != requestId) return;
      setState(() {
        error = 'Unable to load skills.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SearchSheetFrame(
        title: 'Add Skills',
        controller: controller,
        hint: 'Search skills...',
        onChanged: _onChanged,
        loading: loading,
        error: error,
        onRetry: () => _search(controller.text),
        emptyMessage: controller.text.trim().isEmpty
            ? 'Search competency skills.'
            : 'No matching skills.',
        footer: FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(selected.values.toList()),
            child: const Text('Done')),
        child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final skill = results[index];
              final checked = selected.containsKey(skill.id);
              return CheckboxListTile(
                  value: checked,
                  title: Text(skill.name),
                  onChanged: (_) => setState(() {
                        checked
                            ? selected.remove(skill.id)
                            : selected[skill.id] = skill;
                      }));
            }),
      );
}

class _SearchSheetFrame extends StatelessWidget {
  const _SearchSheetFrame(
      {required this.title,
      required this.controller,
      required this.hint,
      required this.onChanged,
      required this.loading,
      required this.error,
      required this.onRetry,
      required this.emptyMessage,
      required this.child,
      this.footer});
  final String title, hint, emptyMessage;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.42,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) => Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(title, style: AppTextStyles.title)),
                        IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded))
                      ])),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: onChanged,
                          decoration: InputDecoration(
                              hintText: hint,
                              prefixIcon: const Icon(Icons.search_rounded)))),
                  const SizedBox(height: 8),
                  Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                              ? Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      Text(error!),
                                      TextButton(
                                          onPressed: onRetry,
                                          child: const Text('Retry'))
                                    ]))
                              : child),
                  if (!loading &&
                      error == null &&
                      child is ListView &&
                      (child as ListView)
                              .childrenDelegate
                              .estimatedChildCount ==
                          0)
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(emptyMessage)),
                  if (footer != null)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: SizedBox(width: double.infinity, child: footer)),
                ])),
      );
}
