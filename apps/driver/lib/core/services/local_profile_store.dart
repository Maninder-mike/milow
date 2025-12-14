import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalProfileStore {
  static const String _boxName = 'profiles';

  static Box<String>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _ensureBox {
    final box = _box;
    if (box == null) {
      throw StateError('LocalProfileStore.init() must be called before use');
    }
    return box;
  }

  static Map<String, dynamic>? get(String userId) {
    final jsonStr = _ensureBox.get(userId);
    if (jsonStr == null) return null;
    try {
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String userId, Map<String, dynamic> profile) async {
    final jsonStr = json.encode(profile);
    await _ensureBox.put(userId, jsonStr);
  }

  static Future<void> delete(String userId) async {
    await _ensureBox.delete(userId);
  }

  static ValueListenable<Box<String>> watchBox() => _ensureBox.listenable();
}
