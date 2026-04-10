import 'package:flutter/widgets.dart';

import 'app/app_bootstrap.dart';
import 'app/wimc_app.dart';

Future<void> main() async {
  final bootstrap = await initializeWimcApp();
  runApp(WimcApp(cameras: bootstrap.cameras));
}
