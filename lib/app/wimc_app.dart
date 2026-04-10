import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../services/app_config_store.dart';
import '../splash_screen.dart';

class WimcApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const WimcApp({super.key, required this.cameras});

  @override
  State<WimcApp> createState() => _WimcAppState();
}

class _WimcAppState extends State<WimcApp> with WidgetsBindingObserver {
  late final Listenable _runtimeListenable = Listenable.merge([
    AppConfigStore.instance.branding,
    AppConfigStore.instance.copy,
    AppConfigStore.instance.adSlots,
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppConfigStore.instance.load());
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtimeListenable,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Pretendard',
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE31837)),
          ),
          home: SplashScreen(next: HomePage(cameras: widget.cameras)),
        );
      },
    );
  }
}
