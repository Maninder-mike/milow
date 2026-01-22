import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Local Hive store for expenses.
///
/// Provides immediate local access to expense data while syncing
/// happens in the background.
class LocalExpenseStore {
  static const String _boxName = 'driver_expenses';

  static Box<String>? _box;

  /// Initialize the store
  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('[LocalExpenseStore] Initialized, items: ${_box?.length}');
  }

  static Box<String> get _ensureBox {
    final box = _box;
    if (box == null) {
      throw StateError('LocalExpenseStore.init() must be called before use');
    }
    return box;
  }

  /// Get an expense by ID
  static Expense? get(String id) {
    final jsonStr = _ensureBox.get(id);
    if (jsonStr == null) return null;
    try {
      return Expense.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Get all expenses for a user
  static List<Expense> getAllForUser(String userId) {
    final expenses = <Expense>[];
    for (final jsonStr in _ensureBox.values) {
      try {
        final expense = Expense.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
        if (expense.userId == userId) {
          expenses.add(expense);
        }
      } catch (_) {
        // Skip invalid entries
      }
    }
    // Sort by date descending
    expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return expenses;
  }

  /// Save an expense
  static Future<void> put(Expense expense) async {
    if (expense.id == null) return;
    final jsonStr = json.encode(expense.toJson());
    await _ensureBox.put(expense.id, jsonStr);
  }

  /// Delete an expense
  static Future<void> delete(String id) async {
    await _ensureBox.delete(id);
  }

  /// Clear all entries (for logout)
  static Future<void> clear() async {
    await _ensureBox.clear();
  }

  /// Watch for changes
  static ValueListenable<Box<String>> watchBox() => _ensureBox.listenable();
}
