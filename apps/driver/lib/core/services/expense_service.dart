import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Service for direct Supabase expense operations.
class ExpenseService {
  static const String _tableName = 'driver_expenses';
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => _client.auth.currentUser?.id;

  /// Get all expenses for current user
  static Future<List<Expense>> getExpenses() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('expense_date', ascending: false);

      return (response as List)
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseService] Error fetching expenses: $e');
      return [];
    }
  }

  /// Get expenses by trip ID
  static Future<List<Expense>> getExpensesByTripId(String tripId) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('trip_id', tripId)
          .isFilter('deleted_at', null)
          .order('expense_date', ascending: false);

      return (response as List)
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseService] Error fetching trip expenses: $e');
      return [];
    }
  }

  /// Get expense by ID
  static Future<Expense?> getExpenseById(String expenseId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('id', expenseId)
          .maybeSingle();

      if (response == null) return null;
      return Expense.fromJson(response);
    } catch (e) {
      debugPrint('[ExpenseService] Error fetching expense: $e');
      return null;
    }
  }

  /// Create expense
  static Future<Expense?> createExpense(Expense expense) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final payload = expense.toJson();
      payload['user_id'] = userId;
      payload.remove('id');

      final response = await _client
          .from(_tableName)
          .insert(payload)
          .select()
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      debugPrint('[ExpenseService] Error creating expense: $e');
      rethrow;
    }
  }

  /// Update expense
  static Future<Expense?> updateExpense(Expense expense) async {
    if (expense.id == null) throw Exception('Expense ID required for update');

    try {
      final payload = expense.toJson();
      payload['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from(_tableName)
          .update(payload)
          .eq('id', expense.id!)
          .select()
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      debugPrint('[ExpenseService] Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete expense (soft delete)
  static Future<void> deleteExpense(String expenseId) async {
    try {
      await _client
          .from(_tableName)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', expenseId);
    } catch (e) {
      debugPrint('[ExpenseService] Error deleting expense: $e');
      rethrow;
    }
  }

  /// Search expenses
  static Future<List<Expense>> searchExpenses(String query) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .or(
            'vendor.ilike.%$query%,description.ilike.%$query%,location.ilike.%$query%',
          )
          .order('expense_date', ascending: false);

      return (response as List)
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseService] Error searching expenses: $e');
      return [];
    }
  }

  /// Get expenses summary by category for a date range
  static Future<Map<String, double>> getExpenseSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _userId;
    if (userId == null) return {};

    try {
      var query = _client
          .from(_tableName)
          .select('category, amount')
          .eq('user_id', userId)
          .isFilter('deleted_at', null);

      if (startDate != null) {
        query = query.gte('expense_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('expense_date', endDate.toIso8601String());
      }

      final response = await query;

      final summary = <String, double>{};
      for (final row in response as List) {
        final data = row as Map<String, dynamic>;
        final category = data['category'] as String;
        final amount = (data['amount'] as num).toDouble();
        summary[category] = (summary[category] ?? 0) + amount;
      }

      return summary;
    } catch (e) {
      debugPrint('[ExpenseService] Error getting summary: $e');
      return {};
    }
  }
}
