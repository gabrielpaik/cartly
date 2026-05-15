import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../services/app_attention_service.dart';
import '../services/app_config_store.dart';
import '../services/app_location_service.dart';
import '../services/app_navigation_service.dart';
import '../services/push_navigation_service.dart';
import '../services/push_registration_service.dart';
import '../services/shopping_nudge_service.dart';
import '../splash_screen.dart';

class CartlyApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CartlyApp({super.key, required this.cameras});

  @override
  State<CartlyApp> createState() => _CartlyAppState();
}

class _CartlyAppState extends State<CartlyApp> with WidgetsBindingObserver {
  late final Listenable _runtimeListenable = Listenable.merge([
    AppConfigStore.instance.branding,
    AppConfigStore.instance.copy,
    AppConfigStore.instance.adSlots,
    AppConfigStore.instance.runtime,
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppConfigStore.instance.load());
    unawaited(AppAttentionService.instance.load());
    unawaited(PushNavigationService.instance.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ShoppingNudgeService.instance.initialize());
      unawaited(
        ShoppingNudgeService.instance.syncHomeAttentionFromReminderStatus(),
      );
      unawaited(PushRegistrationService.instance.initialize());
      unawaited(AppLocationService.instance.initializeOnLaunch());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppConfigStore.instance.refresh());
      unawaited(
        PushNavigationService.instance.syncAttentionFromSystemNotifications(),
      );
      unawaited(
        ShoppingNudgeService.instance.syncHomeAttentionFromReminderStatus(),
      );
      unawaited(PushRegistrationService.instance.refreshRegistration());
      unawaited(AppLocationService.instance.refreshIfAuthorized());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtimeListenable,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: AppNavigationService.instance.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Pretendard',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE31837),
            ),
          ),
          home: SplashScreen(next: HomePage(cameras: widget.cameras)),
        );
      },
    );
  }
}
