import 'dart:async';

import 'package:flutter/material.dart';

import 'services/app_config_store.dart';

class SplashScreen extends StatefulWidget {
  final Widget next;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _assetPath = 'assets/images/intro.png';
  static const String _bundledSplashName = 'cartly_splash_default.png';
  static const AssetImage _bundledImage = AssetImage(_assetPath);
  static const Duration _appConfigTimeout = Duration(seconds: 2);
  static const Duration _imagePrecacheTimeout = Duration(seconds: 2);
  static const Duration _minimumRemoteVisible = Duration.zero;

  Timer? _timer;
  ImageProvider _imageProvider = _bundledImage;

  bool _useBundledSplash(String? splashUrl) {
    final trimmed = splashUrl?.trim() ?? '';
    if (trimmed.isEmpty) {
      return true;
    }
    final path = Uri.tryParse(trimmed)?.path.toLowerCase() ?? trimmed.toLowerCase();
    return path.endsWith(_bundledSplashName);
  }

  Future<ImageProvider> _resolvePreferredImage() async {
    try {
      await AppConfigStore.instance.refresh().timeout(_appConfigTimeout);
    } catch (_) {}

    final splashUrl = AppConfigStore.instance.branding.value.splashImageUrl;
    if (_useBundledSplash(splashUrl)) {
      return _bundledImage;
    }
    return NetworkImage(splashUrl!.trim());
  }

  Future<void> _precache(ImageProvider image) async {
    if (!mounted) return;
    final configuration = createLocalImageConfiguration(context);
    final stream = image.resolve(configuration);
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    await completer.future.timeout(_imagePrecacheTimeout);
  }

  Future<void> _runSplashSequence() async {
    final startedAt = DateTime.now();
    DateTime? switchedAt;

    try {
      final nextImage = await _resolvePreferredImage();
      try {
        await _precache(nextImage);
      } catch (_) {
        if (nextImage is NetworkImage) {
          try {
            await _precache(_bundledImage);
          } catch (_) {}
        }
        rethrow;
      }
      if (!mounted) return;
      if (nextImage is NetworkImage) {
        setState(() => _imageProvider = nextImage);
        switchedAt = DateTime.now();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _imageProvider = _bundledImage);
    }

    final afterResolve = DateTime.now();
    final remainingBase = widget.duration - afterResolve.difference(startedAt);
    if (remainingBase > Duration.zero) {
      await Future<void>.delayed(remainingBase);
    }

    if (switchedAt != null) {
      final remoteVisibleFor = DateTime.now().difference(switchedAt);
      final remainingRemote = _minimumRemoteVisible - remoteVisibleFor;
      if (remainingRemote > Duration.zero) {
        await Future<void>.delayed(remainingRemote);
      }
    }

    if (!mounted) return;
    _timer = Timer(Duration.zero, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.next,
          transitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSplashSequence());
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
          image: _imageProvider,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Image(
            image: _bundledImage,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
