import 'package:flutter/widgets.dart';

import 'app/app_bootstrap.dart';
import 'app/cartly_app.dart';

Future<void> main() async {
  final bootstrap = await initializeCartlyApp();
  runApp(CartlyApp(cameras: bootstrap.cameras));
}
