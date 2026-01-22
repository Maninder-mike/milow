import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/expense_repository.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:milow_core/milow_core.dart';

/// Page displaying list of all expenses with filtering options.
class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({super.key});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String? _selectedCategory;
  double _monthTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    try {
      final expenses = await ExpenseRepository.getExpenses();
      final monthTotal = await ExpenseRepository.getCurrentMonthTotal();
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _monthTotal = monthTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await ExpenseRepository.refresh();
    await _loadExpenses();
  }

  List<Expense> get _filteredExpenses {
    if (_selectedCategory == null) return _expenses;
    return _expenses.where((e) => e.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/add-expense');
          if (result == true) {
            unawaited(_loadExpenses());
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: Column(
        children: [
          // Month Summary Card
          Container(
            margin: EdgeInsets.all(tokens.spacingL),
            padding: EdgeInsets.all(tokens.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(tokens.shapeL),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
                SizedBox(width: tokens.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Month',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        '\$${_monthTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_expenses.length} expenses',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Chips
          if (_selectedCategory != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacingL),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      Expense.categoryLabels[_selectedCategory] ?? '',
                    ),
                    onDeleted: () => setState(() => _selectedCategory = null),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),

          // Expense List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        left: tokens.spacingL,
                        right: tokens.spacingL,
                        bottom: 100,
                      ),
                      itemCount: _filteredExpenses.length,
                      itemBuilder: (context, index) {
                        return _buildExpenseCard(_filteredExpenses[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final tokens = context.tokens;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: tokens.textTertiary,
          ),
          SizedBox(height: tokens.spacingL),
          Text(
            'No expenses yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: tokens.textSecondary),
          ),
          SizedBox(height: tokens.spacingS),
          Text(
            'Tap + to add your first expense',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return M3SpringButton(
      onTap: () async {
        final result = await context.push(
          '/add-expense',
          extra: {'expense': expense},
        );
        if (result == true) {
          unawaited(_loadExpenses());
        }
      },
      child: AnimatedContainer(
        duration: M3ExpressiveMotion.durationShort,
        curve: M3ExpressiveMotion.standard,
        margin: EdgeInsets.only(bottom: tokens.spacingM),
        padding: EdgeInsets.all(tokens.spacingL),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(tokens.shapeM),
        ),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(tokens.shapeS),
              ),
              child: Icon(
                _getCategoryIcon(expense.category),
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(width: tokens.spacingM),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.vendor ?? expense.categoryLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${expense.categoryLabel} • ${DateFormat.MMMd().format(expense.expenseDate)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.textTertiary),
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  expense.formattedAmount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                if (expense.isReimbursable)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(tokens.shapeXS),
                    ),
                    child: Text(
                      expense.isReimbursed ? 'Reimbursed' : 'Pending',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: tokens.info),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacingL),
              Wrap(
                spacing: tokens.spacingS,
                runSpacing: tokens.spacingS,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (_) {
                      setState(() => _selectedCategory = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...Expense.categories.map((category) {
                    return FilterChip(
                      label: Text(Expense.categoryLabels[category] ?? category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
              SizedBox(height: tokens.spacingL),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'toll':
        return Icons.toll;
      case 'meal':
        return Icons.restaurant;
      case 'scale':
        return Icons.scale;
      case 'lumper':
        return Icons.inventory;
      case 'parking':
        return Icons.local_parking;
      case 'lodging':
        return Icons.hotel;
      case 'maintenance':
        return Icons.build;
      case 'permits':
        return Icons.description;
      case 'fines':
        return Icons.warning;
      default:
        return Icons.receipt_long;
    }
  }
}
