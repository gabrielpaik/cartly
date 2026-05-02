import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import '../services/admob_service.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';

class CartlyAppBootstrap {
  final List<CameraDescription> cameras;

  const CartlyAppBootstrap({required this.cameras});
}

Future<CartlyAppBootstrap> initializeCartlyApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final cameras = await availableCameras();
  await AuthStore.instance.load();
  await CartStore.instance.load();
  await AdMobService.instance.initialize();

  return CartlyAppBootstrap(cameras: cameras);
}
