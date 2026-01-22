import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow_core/milow_core.dart';

import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/local_expense_store.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/expense_service.dart';

/// Repository for expenses with offline-first support.
///
/// - Reads from local cache first (instant)
/// - Writes to local cache immediately + queues sync
/// - Background syncs when online
class ExpenseRepository {
  static const _uuid = Uuid();
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => _client.auth.currentUser?.id;

  /// Get all expenses for current user (local-first)
  static Future<List<Expense>> getExpenses({bool refresh = true}) async {
    final userId = _userId;
    if (userId == null) return [];

    // Return cached data immediately
    final cached = LocalExpenseStore.getAllForUser(userId);

    if (refresh && connectivityService.isOnline) {
      // Fire-and-forget refresh
      unawaited(_refreshFromServer(userId));
    }

    return cached;
  }

  /// Force refresh from server and update cache
  static Future<List<Expense>> refresh() async {
    final userId = _userId;
    if (userId == null) return [];

    return await _refreshFromServer(userId);
  }

  static Future<List<Expense>> _refreshFromServer(String userId) async {
    try {
      final serverExpenses = await ExpenseService.getExpenses();

      // Clear existing local cache for this user
      final existingLocal = LocalExpenseStore.getAllForUser(userId);
      for (final expense in existingLocal) {
        if (expense.id != null) {
          await LocalExpenseStore.delete(expense.id!);
        }
      }

      // Update local cache with server data
      for (final expense in serverExpenses) {
        await LocalExpenseStore.put(expense);
      }

      debugPrint(
        '[ExpenseRepository] Refreshed ${serverExpenses.length} expenses from server',
      );
      return serverExpenses;
    } catch (e) {
      debugPrint('[ExpenseRepository] Failed to refresh: $e');
      return LocalExpenseStore.getAllForUser(userId);
    }
  }

  /// Get expenses by trip ID
  static Future<List<Expense>> getExpensesByTripId(String tripId) async {
    final userId = _userId;
    if (userId == null) return [];

    // Filter local cache by trip ID
    final all = LocalExpenseStore.getAllForUser(userId);
    return all.where((e) => e.tripId == tripId).toList();
  }

  /// Get a single expense by ID (local-first)
  static Future<Expense?> getExpenseById(String expenseId) async {
    // Check local cache first
    final cached = LocalExpenseStore.get(expenseId);
    if (cached != null) return cached;

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await ExpenseService.getExpenseById(expenseId);
    }

    return null;
  }

  /// Create a new expense (offline-capable)
  static Future<Expense> createExpense(Expense expense) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Generate local ID if not present
    final localId = expense.id ?? _uuid.v4();
    final localExpense = expense.copyWith(
      id: localId,
      userId: userId,
      createdAt: DateTime.now(),
    );

    // Save to local cache immediately
    await LocalExpenseStore.put(localExpense);
    debugPrint('[ExpenseRepository] Created locally: $localId');

    // Queue sync operation
    final payload = localExpense.toJson();
    payload['user_id'] = userId;
    payload.remove('id');

    await syncQueueService.enqueue(
      tableName: 'driver_expenses',
      operationType: 'create',
      payload: payload,
      localId: localId,
    );

    return localExpense;
  }

  /// Update an existing expense (offline-capable)
  static Future<Expense> updateExpense(Expense expense) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (expense.id == null) {
      throw Exception('Expense ID is required for update');
    }

    // Update local cache immediately
    final updatedExpense = expense.copyWith(updatedAt: DateTime.now());

    await LocalExpenseStore.put(updatedExpense);
    debugPrint('[ExpenseRepository] Updated locally: ${expense.id}');

    // Queue sync operation
    final payload = updatedExpense.toJson();
    payload['updated_at'] = DateTime.now().toIso8601String();

    await syncQueueService.enqueue(
      tableName: 'driver_expenses',
      operationType: 'update',
      payload: payload,
      localId: expense.id!,
    );

    return updatedExpense;
  }

  /// Delete an expense (offline-capable)
  static Future<void> deleteExpense(String expenseId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Delete from local cache immediately
    await LocalExpenseStore.delete(expenseId);
    debugPrint('[ExpenseRepository] Deleted locally: $expenseId');

    // Queue sync operation (Soft Delete)
    await syncQueueService.enqueue(
      tableName: 'driver_expenses',
      operationType: 'update',
      payload: {
        'id': expenseId,
        'user_id': userId,
        'deleted_at': DateTime.now().toIso8601String(),
      },
      localId: expenseId,
    );
  }

  /// Search expenses (local search if offline)
  static Future<List<Expense>> searchExpenses(String query) async {
    final userId = _userId;
    if (userId == null) return [];

    if (connectivityService.isOnline) {
      try {
        return await ExpenseService.searchExpenses(query);
      } catch (_) {
        // Fallback to local search
      }
    }

    // Local search
    final all = LocalExpenseStore.getAllForUser(userId);
    final queryLower = query.toLowerCase();
    return all.where((expense) {
      return (expense.vendor?.toLowerCase().contains(queryLower) ?? false) ||
          (expense.description?.toLowerCase().contains(queryLower) ?? false) ||
          (expense.location?.toLowerCase().contains(queryLower) ?? false) ||
          expense.category.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Get total expenses for current month
  static Future<double> getCurrentMonthTotal() async {
    final userId = _userId;
    if (userId == null) return 0;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final expenses = LocalExpenseStore.getAllForUser(userId);
    final filtered = expenses.where(
      (e) =>
          e.expenseDate.isAfter(startOfMonth) &&
          e.expenseDate.isBefore(endOfMonth),
    );
    double total = 0.0;
    for (final e in filtered) {
      total += e.amount;
    }
    return total;
  }

  /// Clear local cache (for logout)
  static Future<void> clearCache() async {
    await LocalExpenseStore.clear();
  }
}
