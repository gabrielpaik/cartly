import 'dart:async';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import '../services/admob_service.dart';
import '../services/app_config_store.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';

class CartlyAppBootstrap {
  final List<CameraDescription> cameras;

  const CartlyAppBootstrap({required this.cameras});
}

Future<CartlyAppBootstrap> initializeCartlyApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {}

  final camerasFuture = availableCameras().timeout(
    const Duration(seconds: 4),
    onTimeout: () => <CameraDescription>[],
  );

  try {
    await AuthStore.instance.load().timeout(const Duration(seconds: 6));
  } catch (_) {}

  try {
    await CartStore.instance.load().timeout(const Duration(seconds: 6));
  } catch (_) {}

  try {
    await AppConfigStore.instance.load().timeout(const Duration(seconds: 4));
  } catch (_) {}

  unawaited(AdMobService.instance.initialize());

  List<CameraDescription> cameras;
  try {
    cameras = await camerasFuture;
  } catch (_) {
    cameras = const <CameraDescription>[];
  }

  return CartlyAppBootstrap(cameras: cameras);
}
