import 'package:flutter/foundation.dart';

import '../models/household_state.dart';
import 'auth_store.dart';
import 'remote_household_repository.dart';

class HouseholdStore {
  HouseholdStore._();
  static final HouseholdStore instance = HouseholdStore._();

  RemoteHouseholdRepository? _repository;
  RemoteHouseholdRepository get _remote => _repository ??= RemoteHouseholdRepository();

  final ValueNotifier<HouseholdState> state = ValueNotifier(HouseholdState.empty);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> refresh() async {
    final session = AuthStore.instance.session.value;
    if (session == null || session.authToken.trim().isEmpty || session.isGuest) {
      state.value = HouseholdState.empty;
      return;
    }
    isLoading.value = true;
    try {
      state.value = await _remote.getHousehold(session.authToken);
    } finally {
      isLoading.value = false;
    }
  }

  Future<HouseholdState> generateInviteCode() async {
    final session = AuthStore.instance.session.value;
    if (session == null || session.authToken.trim().isEmpty) {
      throw const RemoteHouseholdException('로그인이 필요해');
    }
    final next = await _remote.generateInviteCode(session.authToken);
    state.value = next;
    return next;
  }

  Future<HouseholdState> joinByCode(String inviteCode) async {
    final session = AuthStore.instance.session.value;
    if (session == null || session.authToken.trim().isEmpty) {
      throw const RemoteHouseholdException('로그인이 필요해');
    }
    final next = await _remote.joinByCode(
      authToken: session.authToken,
      inviteCode: inviteCode,
    );
    state.value = next;
    return next;
  }

  void clear() {
    state.value = HouseholdState.empty;
  }
}
