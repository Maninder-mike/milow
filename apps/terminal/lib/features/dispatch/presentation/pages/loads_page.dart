import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/features/dispatch/presentation/providers/load_providers.dart';
import 'package:terminal/features/dispatch/presentation/providers/quote_providers.dart';
import 'package:terminal/features/users/data/user_repository_provider.dart';
import 'package:terminal/features/dashboard/services/vehicle_service.dart';
import 'package:terminal/features/dispatch/domain/models/load.dart';
import 'package:terminal/features/dispatch/domain/models/quote.dart';
import 'package:terminal/features/dispatch/presentation/widgets/load_entry_form.dart';
import 'package:terminal/features/dispatch/presentation/widgets/broker_entry_dialog.dart';
import 'package:terminal/features/dispatch/domain/models/broker.dart';
import 'package:terminal/core/constants/app_colors.dart';
import 'package:terminal/features/dispatch/presentation/widgets/dispatch_stat_card.dart';
import 'package:terminal/features/dispatch/presentation/widgets/load_assignment_dialog.dart';
import 'package:terminal/features/dispatch/presentation/widgets/load_quote_dialog.dart'
    hide QuoteLineItem;
import 'package:terminal/features/billing/presentation/widgets/invoice_builder_dialog.dart';

class LoadsPage extends ConsumerStatefulWidget {
  const LoadsPage({super.key});

  @override
  ConsumerState<LoadsPage> createState() => _LoadsPageState();
}

class _LoadsPageState extends ConsumerState<LoadsPage> {
  String _searchText = '';

  @override
  void initState() {
    super.initState();
  }

  // Keyboard Navigation
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int? _focusedIndex;

  @override
  void dispose() {
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Load> _filterLoads(List<Load> rawLoads) {
    if (_searchText.isEmpty) return rawLoads;
    final search = _searchText.toLowerCase();
    return rawLoads.where((load) {
      return load.loadReference.toLowerCase().contains(search) ||
          load.pickup.companyName.toLowerCase().contains(search) ||
          load.delivery.companyName.toLowerCase().contains(search);
    }).toList();
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
    List<Load> currentLoads,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (currentLoads.isEmpty) return KeyEventResult.ignored;

      setState(() {
        if (_focusedIndex == null ||
            _focusedIndex! >= currentLoads.length - 1) {
          _focusedIndex = 0;
        } else {
          _focusedIndex = _focusedIndex! + 1;
        }
      });
      _scrollToFocused();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (currentLoads.isEmpty) return KeyEventResult.ignored;

      setState(() {
        if (_focusedIndex == null || _focusedIndex! <= 0) {
          _focusedIndex = currentLoads.length - 1;
        } else {
          _focusedIndex = _focusedIndex! - 1;
        }
        // _focusedIndex = (_focusedIndex == null || _focusedIndex! <= 0)
        //     ? currentLoads.length - 1
        //     : _focusedIndex! - 1;
      });
      _scrollToFocused();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex != null && _focusedIndex! < currentLoads.length) {
        _onEditLoad(currentLoads[_focusedIndex!]);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToFocused() {
    if (_focusedIndex == null) return;
    const itemHeight = 73.0; // 72 height + 1 separator approx
    final offset = _focusedIndex! * itemHeight;

    final minScroll = _scrollController.position.pixels;
    final maxScroll = minScroll + _scrollController.position.viewportDimension;

    if (offset < minScroll) {
      _scrollController.jumpTo(offset);
    } else if (offset + itemHeight > maxScroll) {
      _scrollController.jumpTo(
        offset + itemHeight - _scrollController.position.viewportDimension,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingLoad = ref.watch(isCreatingLoadProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: null,
      content: isCreatingLoad
          ? LoadEntryForm(
              onAddBroker: _openNewBrokerDialog,
              onSave: (newLoad) async {
                if (newLoad.id.isEmpty) {
                  await ref
                      .read(loadControllerProvider.notifier)
                      .createLoad(newLoad);
                } else {
                  await ref
                      .read(loadControllerProvider.notifier)
                      .updateLoad(newLoad);
                }

                if (ref.read(loadControllerProvider).hasError) {
                  if (context.mounted) {
                    displayInfoBar(
                      context,
                      builder: (context, close) => InfoBar(
                        title: const Text('Error Saving'),
                        content: Text(
                          ref.read(loadControllerProvider).error.toString(),
                        ),
                        severity: InfoBarSeverity.error,
                        onClose: close,
                      ),
                    );
                  }
                  return; // Don't close the form
                }

                ref.read(isCreatingLoadProvider.notifier).toggle(false);
                ref.read(loadDraftProvider.notifier).reset();
              },
              onCancel: () {
                ref.read(isCreatingLoadProvider.notifier).toggle(false);
                ref.read(loadDraftProvider.notifier).reset();
              },
            )
          : Consumer(
              builder: (context, ref, child) {
                final loadsAsync = ref.watch(loadsListProvider);
                final usersAsync = ref.watch(usersProvider);
                final vehiclesAsync = ref.watch(vehiclesListProvider);

                return loadsAsync.when(
                  data: (rawLoads) {
                    final users = usersAsync.value ?? [];
                    final vehicles = vehiclesAsync.value ?? [];

                    final loads = _filterLoads(rawLoads);
                    final now = DateTime.now();
                    final todayCount = rawLoads.where((l) {
                      return l.pickup.date.year == now.year &&
                          l.pickup.date.month == now.month &&
                          l.pickup.date.day == now.day;
                    }).length;

                    final completedCount = rawLoads
                        .where((l) => l.status.toLowerCase() == 'delivered')
                        .length;

                    final activeCount = rawLoads.where((l) {
                      final s = l.status.toLowerCase();
                      return s == 'assigned' || s == 'in transit';
                    }).length;

                    final delayedCount = rawLoads
                        .where((l) => l.isDelayed)
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16.0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DispatchStatCard(
                                  title: 'Total Loads',
                                  value: rawLoads.length.toString(),
                                  icon: FluentIcons.box_24_regular,
                                  iconColor: const Color(0xFF00ACC1),
                                  iconBackgroundColor: const Color(0xFFE0F7FA),
                                  breakdown: [
                                    StatBreakdownItem(
                                      label: 'Completed',
                                      value: completedCount.toString(),
                                    ),
                                    StatBreakdownItem(
                                      label: 'Active',
                                      value: activeCount.toString(),
                                    ),
                                    StatBreakdownItem(
                                      label: 'Delayed',
                                      value: delayedCount.toString(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: DispatchStatCard(
                                  title: 'Today',
                                  value: todayCount.toString(),
                                  icon: FluentIcons.calendar_ltr_24_regular,
                                  iconColor: const Color(0xFFFB8C00),
                                  iconBackgroundColor: const Color(0xFFFFF3E0),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: DispatchStatCard(
                                  title: 'Completed',
                                  value: completedCount.toString(),
                                  icon: FluentIcons.checkmark_circle_24_regular,
                                  iconColor: const Color(0xFF43A047),
                                  iconBackgroundColor: const Color(0xFFE8F5E9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextBox(
                                  placeholder:
                                      'Search by shipper, city or reference...',
                                  onChanged: (value) {
                                    setState(() => _searchText = value);
                                  },
                                  prefix: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                    ),
                                    child: Icon(FluentIcons.search_16_regular),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              FilledButton(
                                onPressed: () {
                                  ref
                                      .read(isCreatingLoadProvider.notifier)
                                      .toggle(true);
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                    const Color(0xFF009688),
                                  ),
                                  padding: WidgetStateProperty.all(
                                    const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      FluentIcons.add_24_regular,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add Load',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: _buildDispatchTable(
                              loads,
                              theme,
                              users: users,
                              vehicles: vehicles,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: ProgressRing()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
            ),
    );
  }

  void _onEditLoad(Load load) {
    ref.read(loadDraftProvider.notifier).update((_) => load);
    ref.read(isCreatingLoadProvider.notifier).toggle(true);
  }

  Future<void> _onDeleteLoad(Load load) async {
    await ref.read(loadControllerProvider.notifier).deleteLoad(load.id);
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Load Deleted'),
        content: Text('Successfully deleted load ${load.loadReference}'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  Future<void> _updateStatus(Load load, String newStatus) async {
    final updatedLoad = load.copyWith(status: newStatus);
    await ref.read(loadControllerProvider.notifier).updateLoad(updatedLoad);

    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Status Updated'),
        content: Text('Load #${load.loadReference} is now $newStatus'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  Future<void> _openAssignmentDialog(Load load) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return LoadAssignmentDialog(
          load: load,
          onAssign: (driverIds, truckId, trailerId) async {
            // 1. Update Load Object (Primary Driver)
            debugPrint('onAssign called with drivers: $driverIds');
            final String? primaryDriverId = driverIds.isNotEmpty
                ? driverIds.first
                : null;
            debugPrint('Setting primaryDriverId: $primaryDriverId');

            final updatedLoad = load.copyWith(
              assignedDriverId: primaryDriverId,
              assignedTruckId: truckId,
              assignedTrailerId: trailerId,
              status: 'Assigned',
            );

            await ref
                .read(loadControllerProvider.notifier)
                .updateLoad(updatedLoad);

            final controllerState = ref.read(loadControllerProvider);
            if (controllerState.hasError) {
              debugPrint('UpdateLoad failed: ${controllerState.error}');
              if (!mounted) return;
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('Assignment Failed'),
                  content: Text('${controllerState.error}'),
                  severity: InfoBarSeverity.error,
                  onClose: close,
                ),
              );
              return; // Stop execution
            }

            // 2. Persist assignments to fleet_assignments (Team Drivers)
            if (load.tripNumber.isNotEmpty && driverIds.isNotEmpty) {
              try {
                final supabase = Supabase.instance.client;
                final List<Map<String, dynamic>> assignments = [];

                for (final driverId in driverIds) {
                  assignments.add({
                    'assignee_id': driverId,
                    'resource_id': truckId,
                    'trip_number': load.tripNumber,
                    'type': 'trip_assignment',
                    'assigned_by': supabase.auth.currentUser?.id,
                  });
                }

                if (assignments.isNotEmpty) {
                  debugPrint('Upserting fleet assignments: $assignments');
                  await supabase
                      .from('fleet_assignments')
                      .upsert(
                        assignments,
                        onConflict: 'assignee_id, trip_number, type',
                      );
                  debugPrint('Fleet assignments upserted successfully');
                }
              } catch (e) {
                debugPrint('Error saving fleet assignments: $e');
                if (!mounted) return;
                displayInfoBar(
                  context,
                  builder: (context, close) => InfoBar(
                    title: const Text('Fleet Assignment Warning'),
                    content: Text('Could not save detailed assignments: $e'),
                    severity: InfoBarSeverity.warning,
                    onClose: close,
                  ),
                );
              }
            } else {
              debugPrint(
                'Skipping fleet assignments: TripNumber=${load.tripNumber}, DriverIds=${driverIds.length}',
              );
            }

            if (!mounted) return;
            displayInfoBar(
              context,
              builder: (context, close) => InfoBar(
                title: const Text('Load Assigned'),
                content: Text(
                  'Load #${load.loadReference} successfully assigned to ${driverIds.length} driver(s).',
                ),
                severity: InfoBarSeverity.success,
                onClose: close,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openQuoteDialog(Load load) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return LoadQuoteDialog(
          load: load,
          onPublish:
              ({
                required lineItems,
                required deliveryStartDate,
                required deliveryEndDate,
                required notes,
                required status,
                required poNumber,
                required loadReference,
                required expiresOn,
              }) async {
                // Check if meaningful load details changed
                if ((poNumber != null && poNumber != load.poNumber) ||
                    (loadReference != null &&
                        loadReference != load.loadReference)) {
                  // Update the load first
                  final updatedLoad = load.copyWith(
                    poNumber: poNumber,
                    loadReference: loadReference?.isNotEmpty == true
                        ? loadReference
                        : load.loadReference,
                  );
                  await ref
                      .read(loadControllerProvider.notifier)
                      .updateLoad(updatedLoad);
                }

                // Convert dialog line items to Quote model format
                final quoteLineItems = lineItems
                    .map(
                      (item) => QuoteLineItem(
                        type: item.type,
                        description: item.description,
                        rate: item.rate,
                        quantity: item.quantity,
                        unit: item.unit,
                      ),
                    )
                    .toList();

                final total = quoteLineItems.fold<double>(
                  0.0,
                  (sum, item) => sum + item.total,
                );

                final quote = Quote(
                  id: '',
                  loadId: load.id,
                  loadReference: load.loadReference,
                  status: status,
                  lineItems: quoteLineItems,
                  total: total,
                  notes: notes,
                  expiresOn: expiresOn,
                );

                try {
                  await ref
                      .read(quoteControllerProvider.notifier)
                      .createQuote(quote);

                  if (!mounted) return;
                  displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: Text(
                        status == 'draft' ? 'Draft Saved' : 'Quote Sent',
                      ),
                      content: Text(
                        'Quote for Load #${load.loadReference} ${status == 'draft' ? 'saved as draft' : 'sent successfully'}.',
                      ),
                      severity: InfoBarSeverity.success,
                      onClose: close,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: const Text('Error Saving Quote'),
                      content: Text('$e'),
                      severity: InfoBarSeverity.error,
                      onClose: close,
                    ),
                  );
                }
              },
        );
      },
    );
  }

  Widget _buildDispatchTable(
    List<Load> loads,
    FluentThemeData theme, {
    required List<UserProfile> users,
    required List<Map<String, dynamic>> vehicles,
  }) {
    if (loads.isEmpty) return _buildEmptyState();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.surfaceStrokeColorDefault.withValues(
            alpha: 0.05,
          ),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.resources.surfaceStrokeColorDefault.withValues(
                alpha: 0.03,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildHeaderCell('Trip #', flex: 2),
                _buildHeaderCell('Date', flex: 2, hasSort: true),
                _buildHeaderCell('Shipper', flex: 4),
                _buildHeaderCell('Cargo', flex: 3),
                _buildHeaderCell('Delivery', flex: 2),
                _buildHeaderCell('Receiver', flex: 4),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Assigned To', flex: 3),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: Focus(
              focusNode: _listFocusNode,
              onKeyEvent: (node, event) => _handleKeyEvent(node, event, loads),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: loads.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final load = loads[index];
                  final isFocused = index == _focusedIndex;
                  return _buildRow(
                    load,
                    index + 1,
                    theme,
                    isFocused: isFocused,
                    users: users,
                    vehicles: vehicles,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, bool hasSort = false}) {
    return Expanded(
      flex: flex,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: FluentTheme.of(context).resources.textFillColorSecondary,
            ),
          ),
          if (hasSort) ...[
            const SizedBox(width: 4),
            Icon(
              FluentIcons.chevron_down_16_regular,
              size: 12,
              color: FluentTheme.of(context).resources.textFillColorTertiary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    Load load,
    int seq,
    FluentThemeData theme, {
    required bool isFocused,
    required List<UserProfile> users,
    required List<Map<String, dynamic>> vehicles,
  }) {
    return _LoadRowItem(
      load: load,
      seq: seq,
      theme: theme,
      isFocused: isFocused,
      users: users,
      vehicles: vehicles,
      onEdit: () => _onEditLoad(load),
      onBuildQuote: () => _openQuoteDialog(load),
      onStatusUpdate: (status) {
        if (status == 'Assigned') {
          _openAssignmentDialog(load);
        } else {
          _updateStatus(load, status);
        }
      },
      onDelete: () => _onDeleteLoad(load),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.vehicle_truck_profile_24_regular, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No active loads',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Click "Add Load" to add a shipment from the board.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                ref.read(isCreatingLoadProvider.notifier).toggle(true),
            child: const Text('Add First Load'),
          ),
        ],
      ),
    );
  }

  Future<Broker?> _openNewBrokerDialog() async {
    Broker? createdBroker;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return BrokerEntryDialog(
          onSave: (newBroker) async {
            createdBroker = newBroker;
            if (!mounted) return;
            displayInfoBar(
              alignment: Alignment.bottomRight,
              context,
              builder: (infoBarContext, close) {
                return InfoBar(
                  title: const Text('Broker Saved'),
                  content: Text('Saved ${newBroker.name}'),
                  severity: InfoBarSeverity.success,
                  onClose: close,
                  action: IconButton(
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    onPressed: close,
                  ),
                );
              },
            );
          },
        );
      },
    );
    return createdBroker;
  }
}

class _LoadRowItem extends StatefulWidget {
  final Load load;
  final int seq;
  final FluentThemeData theme;
  final bool isFocused;
  final List<UserProfile> users;
  final List<Map<String, dynamic>> vehicles;
  final VoidCallback onEdit;
  final VoidCallback onBuildQuote;
  final Function(String) onStatusUpdate;
  final VoidCallback onDelete;

  const _LoadRowItem({
    required this.load,
    required this.seq,
    required this.theme,
    required this.isFocused,
    required this.users,
    required this.vehicles,
    required this.onEdit,
    required this.onBuildQuote,
    required this.onStatusUpdate,
    required this.onDelete,
  });

  @override
  State<_LoadRowItem> createState() => _LoadRowItemState();
}

class _LoadRowItemState extends State<_LoadRowItem> {
  final FlyoutController _flyoutController = FlyoutController();
  Offset _targetPosition = Offset.zero;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        setState(() {
          _targetPosition = details.localPosition;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showContextMenu();
        });
      },
      child: Stack(
        children: [
          HoverButton(
            onPressed: widget.onEdit,
            builder: (context, states) {
              return Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: states.isHovered
                    ? widget.theme.resources.subtleFillColorSecondary
                    : Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    border: widget.isFocused
                        ? Border.all(color: widget.theme.accentColor, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Trip # & Ref
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.load.tripNumber,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    widget.theme.resources.textFillColorPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Ref: ${widget.load.loadReference}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: widget
                                    .theme
                                    .resources
                                    .textFillColorTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.load.stops.length > 2)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.theme.accentColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    '+${widget.load.stops.length - 2} Stops',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: widget.theme.accentColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Date (Pickup)
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'MM/dd/yy',
                              ).format(widget.load.pickup.date),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    widget.theme.resources.textFillColorPrimary,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(widget.load.pickup.date),
                              style: GoogleFonts.outfit(
                                color: widget
                                    .theme
                                    .resources
                                    .textFillColorTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Shipper (Name + Address)
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.load.pickup.companyName,
                              style: GoogleFonts.outfit(
                                fontSize: 13, // Slightly smaller
                                fontWeight: FontWeight.w700,
                                color:
                                    widget.theme.resources.textFillColorPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.load.pickup.city}, ${widget.load.pickup.state} ${widget.load.pickup.zipCode}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: widget
                                    .theme
                                    .resources
                                    .textFillColorSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Cargo
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.load.weight} ${widget.load.weightUnit}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    widget.theme.resources.textFillColorPrimary,
                              ),
                            ),
                            Text(
                              '${widget.load.quantity} Units',
                              style: GoogleFonts.outfit(
                                color: widget
                                    .theme
                                    .resources
                                    .textFillColorTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Delivery Date
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'MM/dd/yy',
                              ).format(widget.load.delivery.date),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    widget.theme.resources.textFillColorPrimary,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(widget.load.delivery.date),
                              style: GoogleFonts.outfit(
                                color: widget
                                    .theme
                                    .resources
                                    .textFillColorTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Receiver (Name + Address)
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.load.delivery.companyName,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    widget.theme.resources.textFillColorPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.load.delivery.city}, ${widget.load.delivery.state} ${widget.load.delivery.zipCode}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: widget
                                    .theme
                                    .resources
                                    .textFillColorSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Status
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusChip(widget.load),
                        ),
                      ),
                      // Assigned To
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Driver Name
                              Text(
                                () {
                                  if (widget.load.assignedDriverId == null) {
                                    return 'Unassigned';
                                  }
                                  final driver = widget.users.firstWhere(
                                    (u) => u.id == widget.load.assignedDriverId,
                                    orElse: () => const UserProfile(
                                      id: '',
                                      role: UserRole.driver,
                                      fullName: 'Unknown',
                                    ),
                                  );
                                  return driver.fullName ?? 'Unknown Driver';
                                }(),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: widget
                                      .theme
                                      .resources
                                      .textFillColorPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Truck / Trailer
                              Text(
                                () {
                                  final parts = <String>[];
                                  if (widget.load.assignedTruckId != null) {
                                    final truck = widget.vehicles.firstWhere(
                                      (v) =>
                                          v['id'] ==
                                          widget.load.assignedTruckId,
                                      orElse: () => {},
                                    );
                                    if (truck.isNotEmpty) {
                                      parts.add(
                                        'Trk: ${truck['truck_number'] ?? 'N/A'}',
                                      );
                                    }
                                  }
                                  if (widget.load.assignedTrailerId != null) {
                                    final trailer = widget.vehicles.firstWhere(
                                      (v) =>
                                          v['id'] ==
                                          widget.load.assignedTrailerId,
                                      orElse: () => {},
                                    );
                                    if (trailer.isNotEmpty) {
                                      parts.add(
                                        'Trl: ${trailer['truck_number'] ?? 'N/A'}',
                                      );
                                    }
                                  }
                                  return parts.isEmpty
                                      ? 'No Resources'
                                      : parts.join(' / ');
                                }(),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: widget
                                      .theme
                                      .resources
                                      .textFillColorTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: _targetPosition.dx,
            top: _targetPosition.dy,
            child: FlyoutTarget(
              controller: _flyoutController,
              child: const SizedBox(height: 1, width: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Load load) {
    Color color;
    String status = load.status;
    String label = status.toUpperCase();

    if (load.isDelayed) {
      color = AppColors.error;
      label = 'DELAYED';
    } else {
      switch (status.toLowerCase()) {
        case 'pending':
        case 'scheduled':
          color = AppColors.info;
          label = 'SCHEDULED';
          break;
        case 'assigned':
          color = const Color(0xFF0288D1);
          break;
        case 'picked up':
          color = AppColors.success;
          label = 'PICKED UP';
          break;
        case 'in transit':
          color = AppColors.purple;
          break;
        case 'delivered':
          color = AppColors.success;
          break;
        default:
          color = AppColors.neutral;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showContextMenu() {
    _flyoutController.showFlyout(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomRight,
      ),
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.edit_24_regular),
              text: const Text('Edit'),
              onPressed: () {
                Navigator.pop(context);
                widget.onEdit();
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.document_text_24_regular),
              text: const Text('Build Quote'),
              onPressed: () {
                Navigator.pop(context);
                widget.onBuildQuote();
              },
            ),
            if (widget.load.status.toLowerCase() == 'delivered')
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.money_24_regular),
                text: const Text('Generate Invoice'),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) =>
                        InvoiceBuilderDialog(load: widget.load),
                  );
                },
              ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.contact_card_24_regular),
              text: const Text('Assign Load'),
              onPressed: () {
                Navigator.pop(context);
                widget.onStatusUpdate(
                  'Assigned',
                ); // This now triggers dialog via callback logic
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.vehicle_truck_24_regular),
              text: const Text('Mark as In Transit'),
              onPressed: () {
                Navigator.pop(context);
                widget.onStatusUpdate('In Transit');
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.checkmark_circle_24_regular),
              text: const Text('Mark as Delivered'),
              onPressed: () {
                Navigator.pop(context);
                widget.onStatusUpdate('Delivered');
              },
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: Icon(
                FluentIcons.dismiss_circle_24_regular,
                color: AppColors.error,
              ),
              text: const Text(
                'Cancel Load',
                style: TextStyle(color: AppColors.error),
              ),
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Cancel Load'),
                    content: const Text(
                      'Are you sure you want to cancel this load? This will mark the load as cancelled.',
                    ),
                    actions: [
                      Button(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('No, Keep'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onStatusUpdate('Cancelled');
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            AppColors.error,
                          ),
                        ),
                        child: const Text('Yes, Cancel'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: Icon(
                FluentIcons.delete_24_regular,
                color: AppColors.error,
              ),
              text: const Text(
                'Delete Load',
                style: TextStyle(color: AppColors.error),
              ),
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Delete Load'),
                    content: const Text(
                      'Are you sure you want to delete this load? This action cannot be undone.',
                    ),
                    actions: [
                      Button(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete();
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            AppColors.error,
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
