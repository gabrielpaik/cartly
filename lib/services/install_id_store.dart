import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class InstallIdStore {
  InstallIdStore._();

  static const _key = 'wimc_install_id_v1';
  static final _random = Random.secure();

  static Future<String> getOrCreate() async {
    final sp = await SharedPreferences.getInstance();
    final current = sp.getString(_key)?.trim() ?? '';
    if (current.isNotEmpty) return current;

    final next = List.generate(
      24,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
    await sp.setString(_key, next);
    return next;
  }

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
}
