import 'package:flutter/foundation.dart';

import '../models/saved_cart.dart';
import '../models/user_session.dart';

class PreviewState {
  PreviewState._();

  static final ValueNotifier<UserSession?> session = ValueNotifier<UserSession?>(null);
  static final ValueNotifier<List<SavedCart>> carts = ValueNotifier<List<SavedCart>>([]);
}
