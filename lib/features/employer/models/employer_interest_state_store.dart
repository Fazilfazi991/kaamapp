import 'package:flutter/foundation.dart';

class EmployerInterestStateStore extends ChangeNotifier {
  EmployerInterestStateStore._();
  static final instance = EmployerInterestStateStore._();
  final Map<String, String> _states = {};
  String? statusFor(String? candidateId) =>
      candidateId == null ? null : _states[candidateId];
  void hydrate(Map<String, String> states) {
    if (mapEquals(_states, states)) return;
    _states
      ..clear()
      ..addAll(states);
    notifyListeners();
  }

  void setStatus(String candidateId, String status) {
    if (candidateId.isEmpty || _states[candidateId] == status) return;
    _states[candidateId] = status;
    notifyListeners();
  }

  void clear() {
    if (_states.isNotEmpty) {
      _states.clear();
      notifyListeners();
    }
  }
}
