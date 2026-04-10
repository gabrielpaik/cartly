import 'app_config_store.dart';

class AppRuntimeCopy {
  AppRuntimeCopy._();

  static String text(List<String> path, String fallback) {
    dynamic current = AppConfigStore.instance.copy.value;
    for (final segment in path) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return fallback;
      }
    }
    if (current is String && current.trim().isNotEmpty) {
      return current;
    }
    return fallback;
  }
}
