import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/expense_repository.dart';
import 'package:milow/core/services/receipt_scanner_service.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/core/utils/error_handler.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:milow_core/milow_core.dart';

/// Page for adding or editing an expense.
class AddExpensePage extends StatefulWidget {
  final Expense? existingExpense;
  final String? tripId;

  const AddExpensePage({super.key, this.existingExpense, this.tripId});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'other';
  String _selectedCurrency = 'USD';
  String _selectedPaymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  bool _isReimbursable = false;
  bool _isSubmitting = false;
  bool _isScanning = false;
  File? _receiptImage;

  final List<String> _paymentMethods = [
    'cash',
    'credit_card',
    'debit_card',
    'fuel_card',
    'company_account',
  ];

  final Map<String, String> _paymentMethodLabels = {
    'cash': 'Cash',
    'credit_card': 'Credit Card',
    'debit_card': 'Debit Card',
    'fuel_card': 'Fuel Card',
    'company_account': 'Company Account',
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      _prefillData(widget.existingExpense!);
    }
  }

  void _prefillData(Expense expense) {
    _amountController.text = expense.amount.toStringAsFixed(2);
    _descriptionController.text = expense.description ?? '';
    _vendorController.text = expense.vendor ?? '';
    _locationController.text = expense.location ?? '';
    _selectedCategory = expense.category;
    _selectedCurrency = expense.currency;
    _selectedPaymentMethod = expense.paymentMethod ?? 'cash';
    _selectedDate = expense.expenseDate;
    _isReimbursable = expense.isReimbursable;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Scan receipt using Google ML Kit Document Scanner
  Future<void> _scanReceipt() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          pageLimit: 1,
          isGalleryImport: true,
        ),
      );

      final result = await documentScanner.scanDocument();

      if (result.images.isNotEmpty) {
        final scannedFile = File(result.images.first);
        setState(() => _receiptImage = scannedFile);

        // Parse receipt for data extraction
        if (mounted) {
          _showParsingDialog();
          try {
            final scannedData = await ReceiptScannerService.instance
                .scanReceipt(scannedFile);

            if (mounted) {
              Navigator.of(context).pop(); // Close parsing dialog

              // Auto-fill extracted data
              if (scannedData.totalCost != null &&
                  _amountController.text.isEmpty) {
                _amountController.text = scannedData.totalCost!.toStringAsFixed(
                  2,
                );
              }
              if (scannedData.vendor != null &&
                  _vendorController.text.isEmpty) {
                _vendorController.text = scannedData.vendor!;
              }
              if (scannedData.date != null) {
                setState(() => _selectedDate = scannedData.date!);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt scanned! Check extracted data.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(); // Close parsing dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt attached (OCR extraction failed)'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }

      await documentScanner.close();
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _showParsingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Extracting receipt data...'),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final expense = Expense(
        id: widget.existingExpense?.id,
        expenseDate: _selectedDate,
        category: _selectedCategory,
        amount: double.parse(_amountController.text),
        currency: _selectedCurrency,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        vendor: _vendorController.text.isNotEmpty
            ? _vendorController.text
            : null,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        paymentMethod: _selectedPaymentMethod,
        isReimbursable: _isReimbursable,
        tripId: widget.tripId ?? widget.existingExpense?.tripId,
      );

      if (widget.existingExpense != null) {
        await ExpenseRepository.updateExpense(expense);
      } else {
        await ExpenseRepository.createExpense(expense);
      }

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.existingExpense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(tokens.spacingL),
          children: [
            // Category Selection
            Text(
              'Category',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: tokens.textSecondary),
            ),
            SizedBox(height: tokens.spacingS),
            Wrap(
              spacing: tokens.spacingS,
              runSpacing: tokens.spacingS,
              children: Expense.categories.map((category) {
                final isSelected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(Expense.categoryLabels[category] ?? category),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  avatar: Icon(
                    _getCategoryIcon(category),
                    size: 18,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.spacingL),

            // Amount and Currency
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: _selectedCurrency == 'CAD' ? 'C\$ ' : '\$ ',
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid amount';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: tokens.spacingM),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                    ],
                    onChanged: (v) => setState(() => _selectedCurrency = v!),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacingL),

            // Date
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(tokens.shapeM),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  filled: true,
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat.yMMMd().format(_selectedDate)),
              ),
            ),
            SizedBox(height: tokens.spacingL),

            // Vendor
            TextFormField(
              controller: _vendorController,
              decoration: const InputDecoration(
                labelText: 'Vendor / Merchant',
                hintText: 'e.g., Flying J, McDonald\'s',
                filled: true,
                prefixIcon: Icon(Icons.store),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: tokens.spacingL),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Chicago, IL',
                filled: true,
                prefixIcon: Icon(Icons.location_on),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: tokens.spacingL),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'Optional details',
                filled: true,
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            SizedBox(height: tokens.spacingL),

            // Payment Method
            DropdownButtonFormField<String>(
              initialValue: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                filled: true,
                prefixIcon: Icon(Icons.payment),
              ),
              items: _paymentMethods.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(_paymentMethodLabels[method] ?? method),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedPaymentMethod = v!),
            ),
            SizedBox(height: tokens.spacingL),

            // Receipt Scan
            Card(
              child: InkWell(
                onTap: _isScanning ? null : _scanReceipt,
                borderRadius: BorderRadius.circular(tokens.shapeM),
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacingL),
                  child: Column(
                    children: [
                      _isScanning
                          ? SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(
                              _receiptImage != null
                                  ? Icons.check_circle
                                  : Icons.document_scanner,
                              size: 48,
                              color: _receiptImage != null
                                  ? tokens.success
                                  : tokens.textTertiary,
                            ),
                      SizedBox(height: tokens.spacingS),
                      Text(
                        _receiptImage != null
                            ? 'Receipt scanned ✓'
                            : 'Scan Receipt',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _receiptImage != null
                              ? tokens.success
                              : tokens.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_receiptImage == null)
                        Text(
                          'Auto-extract amount, vendor & date',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacingL),

            // Reimbursable Toggle
            SwitchListTile(
              title: const Text('Reimbursable'),
              subtitle: const Text('Mark this expense for reimbursement'),
              value: _isReimbursable,
              onChanged: (v) => setState(() => _isReimbursable = v),
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: tokens.spacingXL),

            // Submit Button
            M3SpringButton(
              onTap: _isSubmitting ? null : _submit,
              child: AnimatedContainer(
                duration: M3ExpressiveMotion.durationMedium,
                curve: M3ExpressiveMotion.standard,
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: tokens.spacingL),
                decoration: BoxDecoration(
                  color: _isSubmitting
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primary,
                  borderRadius: BorderRadius.circular(tokens.shapeL),
                ),
                child: Center(
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            strokeCap: StrokeCap.round,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Expense' : 'Save Expense',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacingXL),
          ],
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
