import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/private_profile_photo_avatar.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../../taxonomy/taxonomy_repository.dart';
import '../models/employer_models.dart';
import '../models/employer_interest_state_store.dart';
import '../models/employer_saved_state_store.dart';
import '../widgets/employer_selector_fields.dart';
import '../widgets/employer_taxonomy_search_sheets.dart';
import '../widgets/employer_widgets.dart';

const _eyebrowStyle = TextStyle(
  color: AppColors.primaryPink,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.1,
);

class CandidateSearchScreen extends StatefulWidget {
  const CandidateSearchScreen({super.key});

  @override
  State<CandidateSearchScreen> createState() => _CandidateSearchScreenState();
}

class _CandidateSearchScreenState extends State<CandidateSearchScreen> {
  final searchController = TextEditingController();
  final minimumSalaryController = TextEditingController();
  final maximumSalaryController = TextEditingController();
  final resultsKey = GlobalKey();
  final repository = const EmployerRepository();
  TaxonomyRepository? taxonomyRepository;
  TaxonomyRole? selectedJobRole;
  String legacyRoleFilter = '';
  String locationCountry = '';
  final locations = <String>{};
  final experiences = <String>{};
  final visaStatuses = <String>{};
  final availabilities = <String>{};
  final nationalities = <String>{};
  final languages = <String>{};
  bool verifiedOnly = false;
  bool moreFiltersOpen = false;
  bool searchSubmitted = false;
  bool searchInProgress = false;
  bool candidateActionInProgress = false;
  int candidateIndex = 0;
  int passedCount = 0;
  final Map<String, bool> savedOverrides = {};
  late Future<List<EmployerCandidate>> candidatesFuture = _searchFuture();
  int searchRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    final client = SupabaseService.maybeClient;
    if (client != null) taxonomyRepository = TaxonomyRepository(client);
    EmployerInterestStateStore.instance.addListener(_interestStateChanged);
  }

  @override
  void dispose() {
    EmployerInterestStateStore.instance.removeListener(_interestStateChanged);
    searchController.dispose();
    minimumSalaryController.dispose();
    maximumSalaryController.dispose();
    super.dispose();
  }

  void _interestStateChanged() {
    if (mounted) setState(() {});
  }

  Future<List<EmployerCandidate>> _searchFuture() {
    return repository.searchCandidates(
      filters: EmployerCandidateSearchFilters(
        query: legacyRoleFilter.isNotEmpty
            ? legacyRoleFilter
            : searchController.text,
        category: '',
        locations: _effectiveLocationFilters(),
        experiences: experiences.toList(),
        visaStatuses: visaStatuses.toList(),
        availabilities: availabilities.toList(),
        nationalities: nationalities.toList(),
        languages: languages.toList(),
        verifiedOnly: verifiedOnly,
        minimumSalary: _parseSalary(minimumSalaryController.text),
        maximumSalary: _parseSalary(maximumSalaryController.text),
      ),
    );
  }

  int? _parseSalary(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  void _search({bool collapseFilters = false}) {
    final requestVersion = ++searchRequestVersion;
    final future = _searchFuture();
    setState(() {
      searchSubmitted = true;
      searchInProgress = true;
      candidateIndex = 0;
      passedCount = 0;
      if (collapseFilters) moreFiltersOpen = false;
      candidatesFuture = future;
    });
    future.whenComplete(() {
      if (!mounted || requestVersion != searchRequestVersion) return;
      setState(() => searchInProgress = false);
      if (collapseFilters) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final resultsContext = resultsKey.currentContext;
          if (resultsContext == null) return;
          Scrollable.ensureVisible(
            resultsContext,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0.05,
          );
        });
      }
    });
  }

  void _clearFilters() {
    searchController.clear();
    minimumSalaryController.clear();
    maximumSalaryController.clear();
    setState(() {
      selectedJobRole = null;
      legacyRoleFilter = '';
      locationCountry = '';
      locations.clear();
      experiences.clear();
      visaStatuses.clear();
      availabilities.clear();
      nationalities.clear();
      languages.clear();
      verifiedOnly = false;
      searchSubmitted = false;
      searchInProgress = false;
      candidatesFuture = _searchFuture();
      candidateIndex = 0;
      passedCount = 0;
    });
  }

  Future<void> _pickJobRole() async {
    final taxonomy = taxonomyRepository;
    if (taxonomy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to load job roles. Please retry.')),
      );
      return;
    }
    final picked = await showJobRoleSearchSheet(
      context: context,
      selected: selectedJobRole,
      search: (query) => taxonomy.searchRoles(query, limit: 20),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedJobRole = picked;
      // Candidate profiles still use legacy text fields. The existing broad
      // keyword filter safely checks headline, categories, and legacy skills.
      legacyRoleFilter = picked.name;
      searchController.text = picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showingMatches = searchSubmitted;
    return ScreenScaffold(
      title: searchSubmitted ? 'Match Candidates' : 'Find Candidates',
      showBack: true,
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 1),
      body: showingMatches ? _matchingBody() : null,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        40 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      actions: [
        IconButton(
          tooltip: searchSubmitted ? 'Refine search' : 'Saved candidates',
          onPressed: searchSubmitted
              ? () => _showFilterSheet('Refine search')
              : () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.employerSavedCandidates),
          icon: Icon(
            searchSubmitted
                ? Icons.tune_rounded
                : Icons.bookmark_border_rounded,
          ),
        ),
      ],
      children: showingMatches ? const [] : _findChildren(),
    );
  }

  List<Widget> _findChildren() {
    return [
      const Text('EMPLOYER SEARCH', style: _eyebrowStyle),
      const SizedBox(height: 8),
      Text(
        'Find the right people, faster.',
        style: AppTextStyles.display.copyWith(fontSize: 32),
      ),
      const SizedBox(height: 8),
      const Text(
        'Search, filter and start matching with suitable candidates.',
        style: AppTextStyles.body,
      ),
      const SizedBox(height: 24),
      Semantics(
        textField: true,
        label: 'Search by skill, role or keyword',
        child: TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            if (selectedJobRole != null &&
                value.trim().toLowerCase() !=
                    selectedJobRole!.name.toLowerCase()) {
              setState(() {
                selectedJobRole = null;
                legacyRoleFilter = '';
              });
            }
          },
          onSubmitted: (_) => _search(collapseFilters: true),
          decoration: InputDecoration(
            hintText: 'Search by skill, role or keyword',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Open all filters',
              onPressed: () => _showFilterSheet('All filters'),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Quick filters'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickFilterCard(
                width: width,
                icon: Icons.work_outline_rounded,
                label: 'Job Role',
                value: selectedJobRole?.name ?? 'All roles',
                onTap: _pickJobRole,
              ),
              _QuickFilterCard(
                width: width,
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: locationCountry.isEmpty
                    ? 'Anywhere'
                    : locations.isEmpty
                        ? locationCountry
                        : locations.first,
                onTap: () => _showFilterSheet('Location'),
              ),
              _QuickFilterCard(
                width: width,
                icon: Icons.work_history_outlined,
                label: 'Experience',
                value: experiences.isEmpty ? 'Any level' : experiences.first,
                onTap: () => _showFilterSheet('Experience'),
              ),
              _QuickFilterCard(
                width: width,
                icon: Icons.payments_outlined,
                label: 'Salary',
                value: _salaryFilterLabel(),
                onTap: () => _showFilterSheet('Salary'),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        label: searchInProgress ? 'Finding candidates...' : 'Start Matching',
        icon: Icons.person_search_rounded,
        onPressed:
            searchInProgress ? null : () => _search(collapseFilters: true),
      ),
      const SizedBox(height: 10),
      const Center(
        child: Text(
          'You can refine these filters at any time.',
          style: AppTextStyles.muted,
        ),
      ),
      const SizedBox(height: 26),
      const SectionHeader(title: 'Recently viewed'),
      const SizedBox(height: 10),
      _RecentlyViewedCandidates(repository: repository),
      const SizedBox(height: 18),
      const CandidatePrivacyNoticeCard(),
    ];
  }

  Widget _matchingBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
            ),
            child: KeyedSubtree(
              key: resultsKey,
              child: FutureBuilder<List<EmployerCandidate>>(
                future: candidatesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _matchingScrollableState(
                      const _CandidateSkeletonCard(),
                    );
                  }
                  if (snapshot.hasError) {
                    return _matchingScrollableState(
                      EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load candidates',
                        message:
                            'Check your connection and try loading this search again.',
                        action: PrimaryButton(
                          label: 'Try Again',
                          icon: Icons.refresh_rounded,
                          onPressed: () => _search(collapseFilters: true),
                        ),
                      ),
                    );
                  }
                  final candidates =
                      (snapshot.data ?? const <EmployerCandidate>[])
                          .where((candidate) {
                    final status = EmployerInterestStateStore.instance
                            .statusFor(candidate.candidateProfileId) ??
                        candidate.interestStatus;
                    return status != 'pending' && status != 'accepted';
                  }).toList();
                  if (candidates.isEmpty) {
                    return _matchingScrollableState(_noResults());
                  }
                  if (candidateIndex >= candidates.length) {
                    return _matchingScrollableState(
                        _reviewComplete(candidates));
                  }
                  return _activeCandidateMatch(
                    candidates[candidateIndex],
                    candidates.length,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchingHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active search', style: AppTextStyles.muted),
              const SizedBox(height: 3),
              Text(_filterSummary(), style: AppTextStyles.label),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _showFilterSheet('Refine search'),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Refine'),
        ),
      ],
    );
  }

  Widget _matchingScrollableState(Widget child) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _matchingHeader(),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _activeCandidateMatch(
      EmployerCandidate candidate, int totalCandidates) {
    final saved =
        savedOverrides[candidate.candidateProfileId ?? candidate.id] ??
            candidate.isSaved;
    return Column(
      children: [
        _matchingHeader(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${candidateIndex + 1} of $totalCandidates',
                style: AppTextStyles.label),
            const SizedBox(width: 10),
            Expanded(
              child: LinearProgressIndicator(
                value: (candidateIndex + 1) / totalCandidates,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: AppColors.border,
                color: AppColors.primaryPink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRect(
            child: Dismissible(
              key: ValueKey(candidate.candidateProfileId ?? candidate.id),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  _passCandidate();
                } else {
                  _showInterest(candidate);
                }
                return false;
              },
              background: const _SwipeBackground(
                alignment: Alignment.centerLeft,
                icon: Icons.handshake_rounded,
                label: 'Show Interest',
                color: AppColors.success,
              ),
              secondaryBackground: const _SwipeBackground(
                alignment: Alignment.centerRight,
                icon: Icons.close_rounded,
                label: 'Pass',
                color: AppColors.error,
              ),
              child: SingleChildScrollView(
                key: const PageStorageKey('matching-candidate-content'),
                padding: const EdgeInsets.only(bottom: 8),
                child:
                    _MatchingCandidateCard(candidate: candidate, saved: saved),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Swipe left to pass or right to show interest.',
          style: AppTextStyles.muted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _CandidateActionDock(
          saved: saved,
          processing: candidateActionInProgress,
          onPass: _passCandidate,
          onSave: () => _toggleCandidateSaved(candidate),
          onViewProfile: () => Navigator.of(context).pushNamed(
            AppRoutes.employerCandidateProfile,
            arguments: candidate,
          ),
          onShowInterest: () => _showInterest(candidate),
        ),
      ],
    );
  }

  Widget _noResults() {
    return EmptyState(
      icon: Icons.person_search_rounded,
      title: 'No strong matches yet',
      message: 'Try expanding the location, experience or salary filters.',
      action: PrimaryButton(
        label: 'Adjust Filters',
        icon: Icons.tune_rounded,
        onPressed: () => _showFilterSheet('Refine search'),
      ),
    );
  }

  Widget _reviewComplete(List<EmployerCandidate> candidates) {
    final savedCount = candidates.where((candidate) {
      final id = candidate.candidateProfileId ?? candidate.id;
      return savedOverrides[id] ?? candidate.isSaved;
    }).length;
    return EmptyState(
      icon: Icons.task_alt_rounded,
      title: 'You reviewed all current matches',
      message:
          '$savedCount saved · $passedCount passed. Your review stays available during this search.',
      action: Column(
        children: [
          PrimaryButton(
            label: 'Review Saved',
            icon: Icons.bookmark_rounded,
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.employerSavedCandidates),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Review Passed',
            icon: Icons.replay_rounded,
            onPressed: passedCount == 0
                ? null
                : () => setState(() {
                      candidateIndex = 0;
                      passedCount = 0;
                    }),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Adjust Filters',
            icon: Icons.tune_rounded,
            onPressed: () => _showFilterSheet('Refine search'),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Return to Dashboard',
            icon: Icons.home_outlined,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.employerDashboard,
              (route) => route.isFirst,
            ),
          ),
        ],
      ),
    );
  }

  void _passCandidate() {
    if (candidateActionInProgress) return;
    setState(() {
      candidateActionInProgress = true;
      candidateIndex += 1;
      passedCount += 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Candidate passed.')),
    );
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => candidateActionInProgress = false);
    });
  }

  Future<void> _toggleCandidateSaved(EmployerCandidate candidate) async {
    if (candidateActionInProgress) return;
    final id = candidate.candidateProfileId ?? '';
    if (id.isEmpty) return;
    final current = savedOverrides[id] ??
        EmployerSavedStateStore.instance.isSavedFor(id) ??
        candidate.isSaved;
    setState(() {
      candidateActionInProgress = true;
      savedOverrides[id] = !current;
    });
    try {
      if (current) {
        await repository.removeSavedCandidate(id);
      } else {
        await repository.saveCandidate(id);
      }
      if (!mounted) return;
      EmployerSavedStateStore.instance.setSaved(id, !current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            current ? 'Candidate removed from saved.' : 'Candidate saved.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => savedOverrides[id] = current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update saved candidate.')),
      );
    } finally {
      if (mounted) setState(() => candidateActionInProgress = false);
    }
  }

  void _showInterest(EmployerCandidate candidate) {
    if (candidateActionInProgress) return;
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.employerSendInterest, arguments: candidate);
  }

  String _salaryFilterLabel() {
    final minimum = _parseSalary(minimumSalaryController.text);
    final maximum = _parseSalary(maximumSalaryController.text);
    if (minimum == null && maximum == null) return 'Any range';
    return formatCandidateSalary(minimum: minimum, maximum: maximum);
  }

  Future<void> _showFilterSheet(String title) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.secondaryBackground,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refresh(VoidCallback update) {
              setSheetState(update);
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              minChildSize: 0.55,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title, style: AppTextStyles.title),
                          ),
                          IconButton(
                            tooltip: 'Close filters',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          20 + MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        children: [
                          SelectionField(
                            label: 'Job Role',
                            value: selectedJobRole?.name ?? '',
                            hint: 'Search or select role',
                            onTap: () async {
                              await _pickJobRole();
                              setSheetState(() {});
                            },
                          ),
                          if (selectedJobRole != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${selectedJobRole!.category} • ${selectedJobRole!.industry}',
                              style: AppTextStyles.muted,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Uses current candidate profile text until candidate taxonomy migration.',
                              style: AppTextStyles.muted,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _DropdownField(
                            label: 'Country',
                            value: locationCountry,
                            hint: 'All Locations',
                            options: CandidateLocationOptions.countries,
                            onChanged: (value) => refresh(() {
                              locationCountry = value ?? '';
                              locations.clear();
                            }),
                          ),
                          if (locationCountry == 'UAE') ...[
                            const SizedBox(height: 12),
                            _FilterLine(
                              title: 'Emirate',
                              allLabel: 'All Emirates',
                              options: CandidateLocationOptions.uaeEmirates,
                              selected: locations,
                              onChanged: () => setSheetState(() {}),
                            ),
                          ] else if (locationCountry == 'India') ...[
                            const SizedBox(height: 12),
                            _FilterLine(
                              title: 'State',
                              allLabel: 'All States',
                              options: CandidateLocationOptions.indianStates,
                              selected: locations,
                              onChanged: () => setSheetState(() {}),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _FilterLine(
                            title: 'Minimum experience',
                            allLabel: 'Any experience',
                            options: const ['Fresher', '3+ years', '5+ years'],
                            selected: experiences,
                            onChanged: () => setSheetState(() {}),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Expected salary range',
                            style: AppTextStyles.label,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minimumSalaryController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Minimum AED',
                                    hintText: '2,000',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: maximumSalaryController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Maximum AED',
                                    hintText: '4,000',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ExpansionTile(
                            initiallyExpanded: moreFiltersOpen,
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Advanced filters',
                              style: AppTextStyles.label,
                            ),
                            leading: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.primaryPink,
                            ),
                            onExpansionChanged: (value) =>
                                moreFiltersOpen = value,
                            children: [
                              _MoreFilters(
                                experiences: experiences,
                                visaStatuses: visaStatuses,
                                availabilities: availabilities,
                                nationalities: nationalities,
                                languages: languages,
                                verifiedOnly: verifiedOnly,
                                onVerified: (value) => refresh(
                                  () => verifiedOnly = value,
                                ),
                                onChanged: () => setSheetState(() {}),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Clear',
                              onPressed: () {
                                _clearFilters();
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Start Matching',
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _search(collapseFilters: true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _filterSummary() {
    final parts = [
      selectedJobRole?.name ?? 'All Roles',
      locationCountry.isEmpty
          ? 'All Locations'
          : locations.isEmpty
              ? 'All $locationCountry'
              : '$locationCountry: ${locations.join(', ')}',
      if (experiences.isNotEmpty) experiences.join(', '),
      if (availabilities.isNotEmpty) availabilities.join(', '),
      if (visaStatuses.isNotEmpty) visaStatuses.join(', '),
      if (_parseSalary(minimumSalaryController.text) != null ||
          _parseSalary(maximumSalaryController.text) != null)
        _salaryFilterLabel(),
    ];
    return parts.join(' • ');
  }

  List<String> _effectiveLocationFilters() {
    if (locationCountry.isEmpty) return const [];
    if (locations.isNotEmpty) return locations.toList();
    return [locationCountry];
  }
}

class _QuickFilterCard extends StatelessWidget {
  const _QuickFilterCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '$label filter, $value',
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(15),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primaryPink,
                        size: 21,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedText,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(label, style: AppTextStyles.label),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchingCandidateCard extends StatelessWidget {
  const _MatchingCandidateCard({
    required this.candidate,
    required this.saved,
  });

  final EmployerCandidate candidate;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final role = candidate.mainCategory.isEmpty
        ? candidate.role
        : candidate.mainCategory;
    final location = candidate.currentLocation.isEmpty
        ? candidate.location
        : candidate.currentLocation;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          candidate.availability.trim().isEmpty
                              ? 'Availability not specified'
                              : candidate.availability,
                          style: AppTextStyles.muted.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (saved) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.bookmark_rounded,
                  color: AppColors.primaryPink,
                  semanticLabel: 'Candidate saved',
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          PrivateProfilePhotoAvatar(
            path: candidate.profilePhotoUrl ?? '',
            candidateId: candidate.candidateProfileId,
            initials: profileInitials(candidate.displayName, fallback: 'C'),
            size: 132,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  candidate.displayName,
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (candidate.isManuallyVerified) ...[
                const SizedBox(width: 6),
                const Tooltip(
                  message: 'KAAM Verified',
                  child: Icon(
                    Icons.verified_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(role, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          _CandidateFact(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: location.isEmpty ? 'Not specified' : location,
          ),
          const SizedBox(height: 11),
          _CandidateFact(
            icon: Icons.work_history_outlined,
            label: 'Experience',
            value: candidate.experience.trim().isEmpty
                ? 'Not specified'
                : candidate.experience,
          ),
          const SizedBox(height: 11),
          _CandidateFact(
            icon: Icons.payments_outlined,
            label: 'Expected salary',
            value: candidate.expectedSalary,
          ),
          if (candidate.visaStatus.isNotEmpty) ...[
            const SizedBox(height: 11),
            _CandidateFact(
              icon: Icons.badge_outlined,
              label: 'Visa status',
              value: CandidateVisaStatus.labelFor(candidate.visaStatus),
            ),
          ],
          if (candidate.skills.isNotEmpty) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidate.skills
                    .take(3)
                    .map((skill) => SkillChip(label: skill))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidateActionDock extends StatelessWidget {
  const _CandidateActionDock({
    required this.saved,
    required this.processing,
    required this.onPass,
    required this.onSave,
    required this.onViewProfile,
    required this.onShowInterest,
  });

  final bool saved;
  final bool processing;
  final VoidCallback onPass;
  final VoidCallback onSave;
  final VoidCallback onViewProfile;
  final VoidCallback onShowInterest;

  @override
  Widget build(BuildContext context) {
    final pass = _CompactMatchActionButton(
      label: 'Pass',
      icon: Icons.close_rounded,
      onPressed: processing ? null : onPass,
    );
    final save = _CompactMatchActionButton(
      label: saved ? 'Saved' : 'Save',
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      onPressed: processing ? null : onSave,
    );
    final viewProfile = _CompactMatchActionButton(
      label: 'View Profile',
      icon: Icons.person_outline_rounded,
      onPressed: onViewProfile,
    );
    final showInterest = PrimaryButton(
      label: 'Show Interest',
      icon: Icons.handshake_rounded,
      onPressed: processing ? null : onShowInterest,
    );

    return Semantics(
      container: true,
      label: 'Candidate actions',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: pass),
                        const SizedBox(width: 8),
                        Expanded(child: save),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: viewProfile),
                        const SizedBox(width: 8),
                        Expanded(child: showInterest),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: pass),
                      const SizedBox(width: 8),
                      Expanded(child: save),
                      const SizedBox(width: 8),
                      Expanded(child: viewProfile),
                    ],
                  ),
                  const SizedBox(height: 8),
                  showInterest,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompactMatchActionButton extends StatelessWidget {
  const _CompactMatchActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.accentPurple, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateFact extends StatelessWidget {
  const _CandidateFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.secondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.muted),
              const SizedBox(height: 1),
              Text(value, style: AppTextStyles.label),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateSkeletonCard extends StatelessWidget {
  const _CandidateSkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget block({double? width, required double height, double radius = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.elevatedCard,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Semantics(
      label: 'Loading candidate matches',
      child: AppCard(
        child: Column(
          children: [
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primaryPink,
              backgroundColor: AppColors.border,
            ),
            const SizedBox(height: 24),
            block(width: 132, height: 132, radius: 66),
            const SizedBox(height: 18),
            block(width: 190, height: 24),
            const SizedBox(height: 10),
            block(width: 130, height: 15),
            const SizedBox(height: 24),
            block(height: 52),
            const SizedBox(height: 10),
            block(height: 52),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignment == Alignment.centerLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 5),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: color),
          ),
        ],
      ),
    );
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
            allLabel: 'All Experience Levels',
            options: const ['Fresher', '3+ years', '5+ years'],
            selected: experiences,
            onChanged: onChanged,
          ),
          _FilterLine(
            title: 'Visa status',
            allLabel: 'All Visa Statuses',
            options: const [
              'Employment Visa',
              'Visit Visa',
              'Cancelled Visa',
              'Own Visa',
              'No Visa',
              'Outside UAE',
            ],
            selected: visaStatuses,
            onChanged: onChanged,
          ),
          _FilterLine(
            title: 'Availability',
            allLabel: 'All Availability',
            options: const [
              'Available Immediately',
              'Within 15 days',
              'Within 1 month',
              'Currently Working',
            ],
            selected: availabilities,
            onChanged: onChanged,
          ),
          _FilterLine(
            title: 'Nationality',
            allLabel: 'All Nationalities',
            options: const [
              'Indian',
              'Pakistani',
              'Bangladeshi',
              'Nepali',
              'Filipino',
              'Sri Lankan',
            ],
            selected: nationalities,
            onChanged: onChanged,
          ),
          _FilterLine(
            title: 'Languages',
            allLabel: 'All Languages',
            options: const [
              'English',
              'Arabic',
              'Hindi',
              'Urdu',
              'Malayalam',
              'Tamil',
            ],
            selected: languages,
            onChanged: onChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: verifiedOnly,
            onChanged: (value) {
              onVerified(value);
              onChanged();
            },
            title: const Text(
              'Verified profile only',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLine extends StatelessWidget {
  const _FilterLine({
    required this.title,
    required this.allLabel,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String allLabel;
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
            options: [allLabel, ...options],
            selected: selected,
            onSelected: (value) {
              if (_isAllFilter(value)) {
                selected.clear();
                onChanged();
                return;
              }
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

bool _isAllFilter(String value) =>
    value.trim().toLowerCase().startsWith('all ');

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
                  : AppColors.border,
            ),
            labelStyle: TextStyle(
              color: selected.contains(option)
                  ? AppColors.white
                  : AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
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

class CandidateProfilePreviewScreen extends StatefulWidget {
  const CandidateProfilePreviewScreen({super.key});

  @override
  State<CandidateProfilePreviewScreen> createState() =>
      _CandidateProfilePreviewScreenState();
}

class _CandidateProfilePreviewScreenState
    extends State<CandidateProfilePreviewScreen> {
  final repository = const EmployerRepository();
  bool viewRecorded = false;
  bool saving = false;
  late bool saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final candidate = ModalRoute.of(context)?.settings.arguments;
    if (candidate is! EmployerCandidate || viewRecorded) return;
    saved = candidate.isSaved;
    saved = EmployerSavedStateStore.instance
            .isSavedFor(candidate.candidateProfileId) ??
        saved;
    viewRecorded = true;
    repository
        .recordCandidateView(candidate.candidateProfileId ?? '')
        .catchError((_) {});
  }

  Future<void> _toggleSaved(EmployerCandidate candidate) async {
    if (saving) return;
    final candidateId = candidate.candidateProfileId ?? '';
    final previous =
        EmployerSavedStateStore.instance.isSavedFor(candidateId) ?? saved;
    setState(() {
      saving = true;
      saved = !previous;
    });
    try {
      if (saved) {
        await repository.saveCandidate(candidateId);
      } else {
        await repository.removeSavedCandidate(
          candidateId,
        );
      }
      if (!mounted) return;
      EmployerSavedStateStore.instance.setSaved(
        candidateId,
        saved,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Candidate saved.' : 'Removed from saved candidates.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saved = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not update this candidate. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final candidate = args is EmployerCandidate ? args : null;
    if (candidate == null) {
      return const ScreenScaffold(
        title: 'Candidate Profile',
        showBack: true,
        children: [
          Text(
            'Open this screen from candidate search.',
            style: AppTextStyles.body,
          ),
        ],
      );
    }
    return ScreenScaffold(
      title: 'Candidate Profile',
      showBack: true,
      actions: [
        IconButton(
          tooltip: saved ? 'Remove saved candidate' : 'Save candidate',
          onPressed: saving ? null : () => _toggleSaved(candidate),
          icon: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          ),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PrivateProfilePhotoAvatar(
                path: candidate.profilePhotoUrl ?? '',
                candidateId: candidate.candidateProfileId,
                initials: profileInitials(
                  candidate.displayName,
                  fallback: 'C',
                ),
                size: 128,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      candidate.displayName,
                      style: AppTextStyles.headline,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (candidate.isManuallyVerified) ...[
                    const SizedBox(width: 6),
                    const Tooltip(
                      message: 'KAAM Verified',
                      child: Icon(
                        Icons.verified_rounded,
                        color: AppColors.success,
                        size: 21,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                candidate.mainCategory.isEmpty
                    ? candidate.role
                    : candidate.mainCategory,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _CandidateFact(
                icon: Icons.location_on_outlined,
                label: 'Current location',
                value: candidate.currentLocation.isEmpty
                    ? candidate.location
                    : candidate.currentLocation,
              ),
            ],
          ),
        ),
        if (candidate.about.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionHeader(title: 'About'),
          const SizedBox(height: 10),
          AppCard(child: Text(candidate.about, style: AppTextStyles.body)),
        ],
        const SizedBox(height: 18),
        const SectionHeader(title: 'Experience & preferences'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              _CandidateFact(
                icon: Icons.work_history_outlined,
                label: 'Experience',
                value: candidate.experience.trim().isEmpty
                    ? 'Not specified'
                    : candidate.experience,
              ),
              const SizedBox(height: 14),
              _CandidateFact(
                icon: Icons.event_available_outlined,
                label: 'Availability',
                value: candidate.availability.trim().isEmpty
                    ? 'Not specified'
                    : candidate.availability,
              ),
              const SizedBox(height: 14),
              _CandidateFact(
                icon: Icons.payments_outlined,
                label: 'Expected salary',
                value: candidate.expectedSalary,
              ),
              if (candidate.preferredLocation.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CandidateFact(
                  icon: Icons.travel_explore_rounded,
                  label: 'Preferred location',
                  value: candidate.preferredLocation,
                ),
              ],
              if (candidate.visaStatus.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CandidateFact(
                  icon: Icons.badge_outlined,
                  label: 'Visa status',
                  value: CandidateVisaStatus.labelFor(candidate.visaStatus),
                ),
              ],
            ],
          ),
        ),
        if (candidate.skills.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionHeader(title: 'Skills'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidate.skills
                .map((skill) => SkillChip(label: skill))
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        const CandidatePrivacyNoticeCard(),
        if (candidate.languages.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionHeader(title: 'Languages'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidate.languages
                .map((language) => SkillChip(label: language))
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        const SectionHeader(title: 'Documents'),
        const SizedBox(height: 10),
        AppCard(
          child: Text(
            switch (candidate.verificationStatus) {
              'verified' =>
                'KAAM Verified profile. Private document images remain hidden.',
              'pending_verification' =>
                'Verification is pending. Private document images remain hidden.',
              'reverification_required' =>
                'Profile verification requires an update. Private document images remain hidden.',
              'rejected' =>
                'Profile is not currently verified. Private document images remain hidden.',
              _ =>
                'Profile verification is unavailable. Private document images remain hidden.',
            },
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 22),
        if (candidate.interestStatus == 'pending')
          const PrimaryButton(
            label: 'Interest Sent',
            icon: Icons.schedule_rounded,
            onPressed: null,
          )
        else if (candidate.interestStatus == 'accepted')
          PrimaryButton(
            label: 'View Match',
            icon: Icons.handshake_rounded,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.employerMatches),
          )
        else
          PrimaryButton(
            label: 'Show Interest',
            icon: Icons.handshake_rounded,
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.employerSendInterest, arguments: candidate),
          ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: saved ? 'Remove Saved Candidate' : 'Save Candidate',
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          onPressed: saving ? null : () => _toggleSaved(candidate),
        ),
      ],
    );
  }
}

class SavedCandidatesScreen extends StatefulWidget {
  const SavedCandidatesScreen({super.key});

  @override
  State<SavedCandidatesScreen> createState() => _SavedCandidatesScreenState();
}

class _SavedCandidatesScreenState extends State<SavedCandidatesScreen> {
  final repository = const EmployerRepository();
  late Future<List<EmployerCandidate>> candidatesFuture =
      repository.savedCandidates();

  void _refresh() {
    final future = repository.savedCandidates();
    setState(() {
      candidatesFuture = future;
    });
  }

  @override
  void initState() {
    super.initState();
    EmployerSavedStateStore.instance.addListener(_savedStateChanged);
  }

  @override
  void dispose() {
    EmployerSavedStateStore.instance.removeListener(_savedStateChanged);
    super.dispose();
  }

  void _savedStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Saved Candidates',
      showBack: true,
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 2),
      actions: [
        IconButton(
          tooltip: 'Refresh saved candidates',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        FutureBuilder<List<EmployerCandidate>>(
          future: candidatesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load saved candidates',
                message: 'Please try again.',
                action: PrimaryButton(label: 'Retry', onPressed: _refresh),
              );
            }
            final candidates = (snapshot.data ?? const <EmployerCandidate>[])
                .where(
                  (candidate) =>
                      EmployerSavedStateStore.instance.isSavedFor(
                        candidate.candidateProfileId,
                      ) ??
                      candidate.isSaved,
                )
                .toList();
            if (candidates.isEmpty) {
              return EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved candidates yet',
                message: 'Candidates you save from search will appear here.',
                action: PrimaryButton(
                  label: 'Search Candidates',
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.employerCandidateSearch),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${candidates.length} saved candidates',
                  style: AppTextStyles.muted,
                ),
                const SizedBox(height: 12),
                for (final candidate in candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CandidateMiniProfileCard(
                      candidate: candidate.copyWith(isSaved: true),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentlyViewedCandidates extends StatefulWidget {
  const _RecentlyViewedCandidates({required this.repository});

  final EmployerRepository repository;

  @override
  State<_RecentlyViewedCandidates> createState() =>
      _RecentlyViewedCandidatesState();
}

class _RecentlyViewedCandidatesState extends State<_RecentlyViewedCandidates> {
  late Future<List<EmployerCandidate>> candidatesFuture =
      widget.repository.recentlyViewedCandidates(limit: 10);

  void _refresh() {
    setState(() {
      candidatesFuture = widget.repository.recentlyViewedCandidates(limit: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmployerCandidate>>(
      future: candidatesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading recently viewed...', style: AppTextStyles.body),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return const AppCard(
            child: Text(
              'Recently viewed could not be loaded.',
              style: AppTextStyles.muted,
            ),
          );
        }
        final candidates = snapshot.data ?? const <EmployerCandidate>[];
        if (candidates.isEmpty) {
          return const AppCard(
            child: Text(
              'No recently viewed candidates yet.',
              style: AppTextStyles.muted,
            ),
          );
        }
        return Column(
          children: [
            for (final candidate in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CandidateMiniProfileCard(
                  key: ValueKey(candidate.candidateProfileId ?? candidate.id),
                  candidate: candidate,
                  onSavedChanged: (isSaved) {
                    if (!isSaved) _refresh();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
