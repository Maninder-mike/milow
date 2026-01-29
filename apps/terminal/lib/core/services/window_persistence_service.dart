import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Service to persist and restore window state (size, position, maximized).
class WindowPersistenceService extends WindowListener {
  final SharedPreferences _prefs;

  static const _keyWidth = 'window_width';
  static const _keyHeight = 'window_height';
  static const _keyX = 'window_x';
  static const _keyY = 'window_y';
  static const _keyMaximized = 'window_maximized';

  WindowPersistenceService(this._prefs) {
    windowManager.addListener(this);
  }

  void dispose() {
    windowManager.removeListener(this);
  }

  Future<void> restoreState() async {
    final isMaximized = _prefs.getBool(_keyMaximized) ?? false;

    if (isMaximized) {
      await windowManager.maximize();
    } else {
      final width = _prefs.getDouble(_keyWidth);
      final height = _prefs.getDouble(_keyHeight);
      final x = _prefs.getDouble(_keyX);
      final y = _prefs.getDouble(_keyY);

      if (width != null && height != null) {
        await windowManager.setSize(Size(width, height));
      }

      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
    }
  }

  @override
  void onWindowResize() {
    _saveBounds();
  }

  @override
  void onWindowMove() {
    _saveBounds();
  }

  @override
  void onWindowMaximize() {
    _prefs.setBool(_keyMaximized, true);
  }

  @override
  void onWindowUnmaximize() {
    _prefs.setBool(_keyMaximized, false);
    _saveBounds();
  }

  Future<void> _saveBounds() async {
    // Don't save bounds if maximized, as we want the unmaximized bounds
    if (await windowManager.isMaximized()) return;

    final bounds = await windowManager.getBounds();
    await _prefs.setDouble(_keyWidth, bounds.width);
    await _prefs.setDouble(_keyHeight, bounds.height);
    await _prefs.setDouble(_keyX, bounds.topLeft.dx);
    await _prefs.setDouble(_keyY, bounds.topLeft.dy);
  }
}
