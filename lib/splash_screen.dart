import 'dart:async';

import 'package:flutter/material.dart';

import 'services/app_config_store.dart';

class SplashScreen extends StatefulWidget {
  final Widget next;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _assetPath = 'assets/images/intro.png';

  Timer? _timer;

  ImageProvider _currentImage() {
    final splashUrl = AppConfigStore.instance.branding.value.splashImageUrl;
    if (splashUrl != null && splashUrl.isNotEmpty) {
      return NetworkImage(splashUrl);
    }
    return const AssetImage(_assetPath);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await precacheImage(_currentImage(), context);
      } catch (_) {}

      _timer = Timer(widget.duration, () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.next,
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image(
          image: _currentImage(),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => const Image(
            image: AssetImage(_assetPath),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
