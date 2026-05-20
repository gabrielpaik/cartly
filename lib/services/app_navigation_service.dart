import 'package:flutter/material.dart';

typedef AppTabSelectionHandler = void Function(int index);
typedef AppSavedOpenHandler = Future<void> Function();
typedef AppLoginOpenHandler = Future<void> Function({bool preferSignup});
typedef AppAccountSettingsOpenHandler = Future<void> Function();

class AppNavigationService {
  AppNavigationService._();

  static final AppNavigationService instance = AppNavigationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  AppTabSelectionHandler? _selectTab;
  AppSavedOpenHandler? _openSaved;
  AppLoginOpenHandler? _openLogin;
  AppAccountSettingsOpenHandler? _openAccountSettings;

  void bind({
    required AppTabSelectionHandler selectTab,
    required AppSavedOpenHandler openSaved,
    required AppLoginOpenHandler openLogin,
    required AppAccountSettingsOpenHandler openAccountSettings,
  }) {
    _selectTab = selectTab;
    _openSaved = openSaved;
    _openLogin = openLogin;
    _openAccountSettings = openAccountSettings;
  }

  void unbind() {
    _selectTab = null;
    _openSaved = null;
    _openLogin = null;
    _openAccountSettings = null;
  }

  void selectTab(int index) {
    _selectTab?.call(index);
  }

  Future<void> openSaved() async {
    final handler = _openSaved;
    if (handler == null) return;
    await handler();
  }

  Future<void> openLogin({bool preferSignup = false}) async {
    final handler = _openLogin;
    if (handler == null) return;
    await handler(preferSignup: preferSignup);
  }

  Future<void> openAccountSettings() async {
    final handler = _openAccountSettings;
    if (handler == null) return;
    await handler();
  }
}
