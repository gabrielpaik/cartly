import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../services/admob_service.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';

class WimcAppBootstrap {
  final List<CameraDescription> cameras;

  const WimcAppBootstrap({required this.cameras});
}

Future<WimcAppBootstrap> initializeWimcApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  await AuthStore.instance.load();
  await CartStore.instance.load();
  await AdMobService.instance.initialize();

  return WimcAppBootstrap(cameras: cameras);
}
