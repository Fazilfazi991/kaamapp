import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';

class SkillSelectionDraft {
  SkillSelectionDraft({
    required this.categories,
    required this.skills,
    this.primarySkillId,
  });
  final List<SkillCategoryData> categories;
  final List<SkillData> skills;
  String? primarySkillId;
}

class WorkPreferencesScreen extends StatefulWidget {
  const WorkPreferencesScreen({super.key});
  @override
  State<WorkPreferencesScreen> createState() => _WorkPreferencesScreenState();
}

class _WorkPreferencesScreenState extends State<WorkPreferencesScreen> {
  final repository = const CandidateProfileRepository();
  final categoryController = TextEditingController();
  final skillController = TextEditingController();
  SkillCategoryData? category;
  final selectedSkills = <SkillData>[];
  List<SkillCategoryData> categories = const [];
  List<SkillData> skills = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    categoryController.dispose();
    skillController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loadedCategories = await repository.loadSkillCategories();
      final loadedSkills = await repository.loadSkills(
          categoryIds: loadedCategories.map((item) => item.id));
      final saved = await repository.loadMySkills();
      if (!mounted) return;
      final savedCategoryId = saved.isEmpty ? null : saved.first.category.id;
      category = loadedCategories
          .where((item) => item.id == savedCategoryId)
          .firstOrNull;
      selectedSkills.addAll(loadedSkills.where((item) =>
          saved.any((selection) => selection.skill.id == item.id) &&
          item.categoryId == category?.id));
      categoryController.text = category?.name ?? '';
      skillController.text =
          selectedSkills.isEmpty ? '' : '${selectedSkills.length} selected';
      setState(() {
        categories = loadedCategories;
        skills = loadedSkills;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'We couldn\'t load the skills. Please try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<SkillData> get _categorySkills =>
      skills.where((item) => item.categoryId == category?.id).toList();

  Future<void> _pickCategory() async {
    final next = await _pickOne<SkillCategoryData>(
      title: 'Select a work category',
      items: categories,
      label: (item) => item.name,
      selected: category,
    );
    if (next == null || next.id == category?.id) return;
    if (selectedSkills.isNotEmpty) {
      final proceed = await _confirmCategoryChange();
      if (!proceed) return;
    }
    setState(() {
      category = next;
      selectedSkills.clear();
      categoryController.text = next.name;
      skillController.clear();
    });
  }

  Future<bool> _confirmCategoryChange() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change category?'),
          content: const Text(
              'Changing the category will clear your selected skills.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'))
          ],
        ),
      ) ??
      false;

  Future<T?> _pickOne<T>(
      {required String title,
      required List<T> items,
      required String Function(T) label,
      T? selected}) async {
    final search = TextEditingController();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(builder: (context, setSheetState) {
          final query = search.text.toLowerCase();
          final filtered = items
              .where((item) => label(item).toLowerCase().contains(query))
              .toList();
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .7,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.title),
                      const SizedBox(height: 12),
                      AppTextField(
                          controller: search,
                          label: 'Search',
                          hint: 'Search',
                          onChanged: (_) => setSheetState(() {})),
                      const SizedBox(height: 8),
                      Expanded(
                          child: ListView(children: [
                        for (final item in filtered)
                          ListTile(
                              title: Text(label(item)),
                              trailing: identical(item, selected)
                                  ? const Icon(Icons.check,
                                      color: AppColors.primaryPink)
                                  : null,
                              onTap: () => Navigator.pop(context, item))
                      ])),
                    ])),
          );
        }),
      ),
    );
  }

  Future<void> _pickSkills() async {
    final search = TextEditingController();
    final temporary = List<SkillData>.of(selectedSkills);
    final picked = await showModalBottomSheet<List<SkillData>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(builder: (context, setSheetState) {
          final query = search.text.toLowerCase();
          final filtered = _categorySkills
              .where((item) => item.name.toLowerCase().contains(query))
              .toList();
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .75,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Select your skills (${temporary.length}/${CandidateSkillLimits.maxSkills})',
                          style: AppTextStyles.title),
                      const SizedBox(height: 12),
                      AppTextField(
                          controller: search,
                          label: 'Search skills',
                          hint: 'Search skills',
                          onChanged: (_) => setSheetState(() {})),
                      Expanded(
                          child: ListView(children: [
                        for (final skill in filtered)
                          _SkillChoiceTile(
                              skill: skill,
                              selected:
                                  temporary.any((item) => item.id == skill.id),
                              onChanged: (checked) {
                                if (checked == true &&
                                    temporary.length >=
                                        CandidateSkillLimits.maxSkills) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(CandidateSkillLimits
                                              .maxMessage)));
                                  return;
                                }
                                setSheetState(() {
                                  checked == true
                                      ? temporary.add(skill)
                                      : temporary.removeWhere(
                                          (item) => item.id == skill.id);
                                });
                              })
                      ])),
                      PrimaryButton(
                          label: 'Done',
                          onPressed: () => Navigator.pop(context, temporary)),
                    ])),
          );
        }),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        selectedSkills
          ..clear()
          ..addAll(picked);
        skillController.text =
            picked.isEmpty ? '' : '${picked.length} selected';
      });
    }
  }

  void _continue() {
    if (category == null) return _message('Please select a main category.');
    if (selectedSkills.isEmpty) {
      return _message('Please select at least one skill.');
    }
    if (selectedSkills.length > CandidateSkillLimits.maxSkills) {
      return _message(CandidateSkillLimits.maxMessage);
    }
    Navigator.of(context).pushNamed(AppRoutes.primaryProfession,
        arguments: SkillSelectionDraft(
            categories: [category!], skills: List.of(selectedSkills)));
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) =>
      ScreenScaffold(title: 'Work Category', showBack: true, children: [
        const ProgressStepper(current: 3, total: 5),
        const SizedBox(height: 22),
        const Text('What type of work do you do?',
            style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text('Choose your main category, then add the jobs you can do.',
            style: AppTextStyles.body),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          AppCard(child: Text(error!, style: AppTextStyles.body)),
        AppTextField(
            controller: categoryController,
            label: 'Main Category',
            hint: 'Select a work category',
            readOnly: true,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            onTap: loading ? null : _pickCategory),
        if (category != null) ...[
          const SizedBox(height: 14),
          AppTextField(
              controller: skillController,
              label: 'Job Role / Skill',
              hint: 'Select your skill',
              readOnly: true,
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              onTap: _pickSkills),
          const SizedBox(height: 10),
          Text(
              'Selected skills: ${selectedSkills.length}/${CandidateSkillLimits.maxSkills}',
              style: selectedSkills.length > CandidateSkillLimits.maxSkills
                  ? const TextStyle(color: AppColors.error)
                  : AppTextStyles.muted),
          if (selectedSkills.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final skill in selectedSkills)
                    InputChip(
                        label: Text(skill.name),
                        onDeleted: () => setState(() {
                              selectedSkills
                                  .removeWhere((item) => item.id == skill.id);
                              skillController.text = selectedSkills.isEmpty
                                  ? ''
                                  : '${selectedSkills.length} selected';
                            }))
                ]))
        ],
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Continue',
            onPressed:
                category == null || selectedSkills.isEmpty ? null : _continue),
      ]);
}

class _SkillChoiceTile extends StatelessWidget {
  const _SkillChoiceTile({
    required this.skill,
    required this.selected,
    required this.onChanged,
  });

  final SkillData skill;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppColors.elevatedCard : Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primaryPink : AppColors.border,
        ),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        value: selected,
        activeColor: AppColors.primaryPink,
        title: Text(skill.name, style: AppTextStyles.body),
        onChanged: (value) => onChanged(value ?? false),
      ),
    );
  }
}
