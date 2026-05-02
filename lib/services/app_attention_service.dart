import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAttentionService {
  AppAttentionService._();

  static final AppAttentionService instance = AppAttentionService._();

  static const _homeKey = 'app_attention_home_v1';
  static const _exploreKey = 'app_attention_explore_v1';

  final ValueNotifier<bool> home = ValueNotifier<bool>(false);
  final ValueNotifier<bool> explore = ValueNotifier<bool>(false);

  SharedPreferences? _prefs;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    home.value = _prefs?.getBool(_homeKey) ?? false;
    explore.value = _prefs?.getBool(_exploreKey) ?? false;
    _loaded = true;
  }

  Future<void> markHome() async {
    home.value = true;
    await _persist();
  }

  Future<void> markExplore() async {
    explore.value = true;
    await _persist();
  }

  Future<void> clearHome() async {
    home.value = false;
    await _persist();
  }

  Future<void> clearExplore() async {
    explore.value = false;
    await _persist();
  }

  Future<void> markTargetTab(String? targetTab) async {
    switch ((targetTab ?? '').trim()) {
      case 'home':
        await markHome();
        return;
      case 'explore':
        await markExplore();
        return;
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await Future.wait([
      prefs.setBool(_homeKey, home.value),
      prefs.setBool(_exploreKey, explore.value),
    ]);
  }
}
