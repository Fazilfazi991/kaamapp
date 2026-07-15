import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/employer_models.dart';
import '../widgets/employer_widgets.dart';

class CandidateSearchScreen extends StatefulWidget {
  const CandidateSearchScreen({super.key});

  @override
  State<CandidateSearchScreen> createState() => _CandidateSearchScreenState();
}

class _CandidateSearchScreenState extends State<CandidateSearchScreen> {
  final searchController = TextEditingController();
  final repository = const EmployerRepository();
  final skillCatalog = const CandidateProfileRepository();
  String category = '';
  final skills = <String>{};
  final locations = <String>{};
  final experiences = <String>{};
  final visaStatuses = <String>{};
  final availabilities = <String>{};
  final nationalities = <String>{};
  final languages = <String>{};
  bool verifiedOnly = false;
  bool moreFiltersOpen = false;
  List<SkillCategoryData> catalogCategories = const [];
  List<SkillData> catalogSkills = const [];
  late Future<List<EmployerCandidate>> candidatesFuture = _searchFuture();

  static const categorySkills = {
    'Construction': [
      'Mason',
      'Carpenter',
      'Electrician',
      'Plumber',
      'Painter',
      'Tile Fixer',
      'Steel Fixer',
      'AC Technician'
    ],
    'Hospitality': [
      'Waiter',
      'Chef',
      'Kitchen Helper',
      'Barista',
      'Housekeeping'
    ],
    'Cleaning': [
      'House Cleaner',
      'Office Cleaner',
      'Deep Cleaner',
      'Kitchen Cleaner'
    ],
    'Driving': ['Light Vehicle Driver', 'Heavy Driver', 'Delivery Driver'],
    'Warehouse': ['Warehouse Helper', 'Picker', 'Forklift Operator'],
    'Security': ['Security Guard', 'CCTV Operator', 'Watchman'],
    'Retail': ['Sales Assistant', 'Cashier', 'Store Helper'],
    'IT & Technical': ['IT Support', 'Data Entry', 'Computer Operator'],
    'Healthcare': ['Caregiver', 'Nursing Assistant', 'Clinic Helper'],
    'Domestic Worker': ['Housemaid', 'Cook', 'Nanny'],
    'Manufacturing': ['Machine Operator', 'Factory Worker', 'Packing Staff'],
  };

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final categories = await skillCatalog.loadSkillCategories();
      final skills = await skillCatalog.loadSkills(
        categoryIds: categories.map((item) => item.id),
      );
      if (mounted) {
        setState(() {
          catalogCategories = categories;
          catalogSkills = skills;
        });
      }
    } catch (_) {
      // Search remains usable with its small compatibility catalog while a
      // connection is unavailable; it never writes fallback data to Supabase.
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<EmployerCandidate>> _searchFuture() {
    return repository.searchCandidates(
      filters: EmployerCandidateSearchFilters(
        query: searchController.text,
        category: category,
        skills: skills.toList(),
        locations: locations.toList(),
        experiences: experiences.toList(),
        visaStatuses: visaStatuses.toList(),
        availabilities: availabilities.toList(),
        nationalities: nationalities.toList(),
        languages: languages.toList(),
        verifiedOnly: verifiedOnly,
      ),
    );
  }

  void _search() {
    setState(() => candidatesFuture = _searchFuture());
  }

  void _clearFilters() {
    searchController.clear();
    setState(() {
      category = '';
      skills.clear();
      locations.clear();
      experiences.clear();
      visaStatuses.clear();
      availabilities.clear();
      nationalities.clear();
      languages.clear();
      verifiedOnly = false;
      candidatesFuture = _searchFuture();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Search Candidates',
      showBack: true,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        40 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      actions: [
        IconButton(
          tooltip: 'Saved candidates',
          onPressed: () => Navigator.of(context)
              .pushNamed(AppRoutes.employerSavedCandidates),
          icon: const Icon(Icons.bookmark_border_rounded),
        ),
      ],
      children: [
        AppTextField(
          controller: searchController,
          label: 'Search by skill, role or location',
          hint: 'Mason, Dubai, English',
          onChanged: (_) => _search(),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Search filters'),
        const SizedBox(height: 10),
        _DropdownField(
          label: 'Main Category',
          value: category,
          hint: 'Select a main category',
          options: catalogCategories.isEmpty
              ? categorySkills.keys.toList()
              : catalogCategories.map((item) => item.name).toList(),
          onChanged: (value) {
            setState(() {
              category = value ?? '';
              skills.clear();
            });
            _search();
          },
        ),
        if (category.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FilterLine(
            title: 'Skills',
            options: _skillOptionsForCategory(),
            selected: skills,
            onChanged: _search,
          ),
        ],
        const SizedBox(height: 16),
        _FilterLine(
          title: 'Location',
          options: const [
            'UAE',
            'India',
            'Both',
            'Dubai',
            'Abu Dhabi',
            'Sharjah'
          ],
          selected: locations,
          onChanged: _search,
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: () => setState(() => moreFiltersOpen = !moreFiltersOpen),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primaryPink),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('More Filters', style: AppTextStyles.label)),
              Icon(moreFiltersOpen
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded),
            ],
          ),
        ),
        if (moreFiltersOpen) ...[
          const SizedBox(height: 12),
          _MoreFilters(
            experiences: experiences,
            visaStatuses: visaStatuses,
            availabilities: availabilities,
            nationalities: nationalities,
            languages: languages,
            verifiedOnly: verifiedOnly,
            onVerified: (value) => setState(() => verifiedOnly = value),
            onChanged: _search,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: SecondaryButton(
                    label: 'Clear Filters', onPressed: _clearFilters)),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: 'Search', onPressed: _search)),
          ],
        ),
        const SizedBox(height: 18),
        const CandidatePrivacyNoticeCard(),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Recently Viewed'),
        const SizedBox(height: 10),
        const AppCard(
          child: Text(
            'Recently viewed profiles will appear here after profile-view tracking is connected.',
            style: AppTextStyles.muted,
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Recommended Candidates'),
        const SizedBox(height: 10),
        FutureBuilder<List<EmployerCandidate>>(
          future: candidatesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not search candidates',
                message: snapshot.error.toString(),
                action: SecondaryButton(label: 'Retry', onPressed: _search),
              );
            }
            final candidates = snapshot.data ?? const <EmployerCandidate>[];
            if (candidates.isEmpty) {
              return EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching candidates found',
                message: 'Try removing a skill or expanding the location.',
                action: SecondaryButton(
                    label: 'Clear Filters', onPressed: _clearFilters),
              );
            }
            return Column(
              children: candidates
                  .take(50)
                  .map((candidate) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CandidateMiniProfileCard(candidate: candidate),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<String> _skillOptionsForCategory() {
    if (catalogCategories.isEmpty) return categorySkills[category] ?? const [];
    final selectedCategory = catalogCategories
        .where((categoryItem) => categoryItem.name == category)
        .firstOrNull;
    if (selectedCategory == null) return const [];
    return catalogSkills
        .where((item) => item.categoryId == selectedCategory.id)
        .map((item) => item.name)
        .toList();
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value.trim().isEmpty ? null : value;
    return DropdownButtonFormField<String>(
      initialValue: options.contains(selected) ? selected : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(hint),
      items: [
        DropdownMenuItem<String>(value: '', child: Text(hint)),
        for (final option in options)
          DropdownMenuItem<String>(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }
}

class _MoreFilters extends StatelessWidget {
  const _MoreFilters({
    required this.experiences,
    required this.visaStatuses,
    required this.availabilities,
    required this.nationalities,
    required this.languages,
    required this.verifiedOnly,
    required this.onVerified,
    required this.onChanged,
  });

  final Set<String> experiences;
  final Set<String> visaStatuses;
  final Set<String> availabilities;
  final Set<String> nationalities;
  final Set<String> languages;
  final bool verifiedOnly;
  final ValueChanged<bool> onVerified;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterLine(
              title: 'Experience',
              options: const ['Fresher', '3+ years', '5+ years'],
              selected: experiences,
              onChanged: onChanged),
          _FilterLine(
              title: 'Visa status',
              options: const [
                'Employment Visa',
                'Visit Visa',
                'Cancelled Visa',
                'Own Visa',
                'No Visa',
                'Outside UAE'
              ],
              selected: visaStatuses,
              onChanged: onChanged),
          _FilterLine(
              title: 'Availability',
              options: const [
                'Available Immediately',
                'Within 15 days',
                'Within 1 month',
                'Currently Working'
              ],
              selected: availabilities,
              onChanged: onChanged),
          _FilterLine(
              title: 'Nationality',
              options: const [
                'Indian',
                'Pakistani',
                'Bangladeshi',
                'Nepali',
                'Filipino',
                'Sri Lankan'
              ],
              selected: nationalities,
              onChanged: onChanged),
          _FilterLine(
              title: 'Languages',
              options: const [
                'English',
                'Arabic',
                'Hindi',
                'Urdu',
                'Malayalam',
                'Tamil'
              ],
              selected: languages,
              onChanged: onChanged),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: verifiedOnly,
            onChanged: (value) {
              onVerified(value);
              onChanged();
            },
            title:
                const Text('Verified profile only', style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}

class _FilterLine extends StatelessWidget {
  const _FilterLine({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          const SizedBox(height: 8),
          _ChoiceWrap(
            options: options,
            selected: selected,
            onSelected: (value) {
              if (selected.contains(value)) {
                selected.remove(value);
              } else {
                selected.add(value);
              }
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option),
            selected: selected.contains(option),
            onSelected: (_) => onSelected(option),
            checkmarkColor: AppColors.white,
            selectedColor: AppColors.primaryPink,
            backgroundColor: AppColors.elevatedCard,
            side: BorderSide(
                color: selected.contains(option)
                    ? AppColors.primaryPink
                    : AppColors.border),
            labelStyle: TextStyle(
              color: selected.contains(option)
                  ? AppColors.white
                  : AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ),
      ],
    );
  }
}

class AdvancedFiltersScreen extends StatelessWidget {
  const AdvancedFiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Advanced Filters',
      showBack: true,
      children: [
        AppCard(
          child: Text(
            'Advanced filters now live inside Search Candidates under More Filters.',
            style: AppTextStyles.body,
          ),
        ),
      ],
    );
  }
}

class CandidateProfilePreviewScreen extends StatelessWidget {
  const CandidateProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final candidate = args is EmployerCandidate ? args : null;
    if (candidate == null) {
      return const ScreenScaffold(
        title: 'Candidate Profile',
        showBack: true,
        children: [
          Text('Open this screen from candidate search.',
              style: AppTextStyles.body)
        ],
      );
    }
    return ScreenScaffold(
      title: 'Candidate Profile',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(candidate.displayName, style: AppTextStyles.headline),
              const SizedBox(height: 6),
              Text(
                  candidate.mainCategory.isEmpty
                      ? candidate.role
                      : candidate.mainCategory,
                  style: AppTextStyles.title),
              const SizedBox(height: 10),
              Text('Skills: ${candidate.skills.take(3).join(', ')}',
                  style: AppTextStyles.body),
              Text(
                  'Current: ${candidate.currentLocation.isEmpty ? candidate.location : candidate.currentLocation}',
                  style: AppTextStyles.muted),
              Text(
                  'Preferred: ${candidate.preferredLocation.isEmpty ? 'Not set' : candidate.preferredLocation}',
                  style: AppTextStyles.muted),
              Text('${candidate.availability} | ${candidate.experience}',
                  style: AppTextStyles.muted),
              if (candidate.visaStatus.isNotEmpty)
                Text('Visa: ${candidate.visaStatus}',
                    style: AppTextStyles.muted),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const CandidatePrivacyNoticeCard(),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Languages'),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidate.languages
                .map((language) => SkillChip(label: language))
                .toList()),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Documents'),
        const SizedBox(height: 10),
        AppCard(
          child: Text(
            candidate.isVerified
                ? 'Verified profile. Private document images remain hidden.'
                : 'Verification pending. Private documents are hidden before accepted match.',
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Send Interest',
          onPressed: () => Navigator.of(context).pushNamed(
            AppRoutes.employerSendInterest,
            arguments: candidate,
          ),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Save Candidate',
          onPressed: () async {
            try {
              await const EmployerRepository()
                  .saveCandidate(candidate.candidateProfileId ?? '');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Candidate saved.')),
              );
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not save candidate: $error')),
              );
            }
          },
        ),
      ],
    );
  }
}

class SavedCandidatesScreen extends StatelessWidget {
  const SavedCandidatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Saved Candidates',
      showBack: true,
      children: [
        EmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'Saved candidates are being connected',
          message:
              'Saving now writes to Supabase. The saved-candidate list is disabled until the read policy is added.',
          action: PrimaryButton(
            label: 'Search Candidates',
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.employerCandidateSearch),
          ),
        ),
      ],
    );
  }
}
