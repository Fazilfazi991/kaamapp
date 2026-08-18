import 'package:flutter/foundation.dart';

/// Shared, in-memory save state for currently mounted employer candidate views.
/// The authoritative state is hydrated from Supabase whenever a candidate list
/// is loaded; local changes are only published after the backend succeeds.
class EmployerSavedStateStore extends ChangeNotifier {
  EmployerSavedStateStore._();

  static final instance = EmployerSavedStateStore._();

  final Map<String, bool> _states = {};

  bool? isSavedFor(String? candidateId) =>
      candidateId == null ? null : _states[candidateId];

  void hydrate(Iterable<String> savedCandidateIds) {
    final next = <String, bool>{
      for (final id in savedCandidateIds)
        if (id.isNotEmpty) id: true,
    };
    if (mapEquals(_states, next)) return;
    _states
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void setSaved(String candidateId, bool isSaved) {
    if (candidateId.isEmpty || _states[candidateId] == isSaved) return;
    _states[candidateId] = isSaved;
    notifyListeners();
  }

  void clear() {
    if (_states.isEmpty) return;
    _states.clear();
    notifyListeners();
  }
}
