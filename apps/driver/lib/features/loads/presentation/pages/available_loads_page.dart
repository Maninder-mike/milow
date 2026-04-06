import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/load_repository.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AvailableLoadsPage extends StatefulWidget {
  const AvailableLoadsPage({super.key});

  @override
  State<AvailableLoadsPage> createState() => _AvailableLoadsPageState();
}

class _AvailableLoadsPageState extends State<AvailableLoadsPage> {
  List<Load> _loads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final loads = await LoadRepository.getLoads(refresh: true);
      if (mounted) {
        setState(() {
          _loads = loads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading loads: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    
    // Split loads into Assigned (need acceptance) and Active (in progress)
    final assignedStatus = [
      LoadStatus.assigned, 
      LoadStatus.pending, 
      LoadStatus.tendered, 
      LoadStatus.dispatched
    ];
    
    final activeStatus = [
      LoadStatus.enRoute,
      LoadStatus.atPickup,
      LoadStatus.loaded,
      LoadStatus.atStop,
      LoadStatus.atDelivery,
    ];
    
    final assignedLoads = _loads.where((l) => assignedStatus.contains(l.status)).toList();
    final activeLoads = _loads.where((l) => activeStatus.contains(l.status)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('My Loads'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assigned'),
              Tab(text: 'Active'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildLoadList(assignedLoads, tokens),
                  _buildLoadList(activeLoads, tokens),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadList(List<Load> loads, DesignTokens tokens) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: loads.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: EdgeInsets.all(tokens.spacingM),
              itemCount: loads.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: tokens.spacingM),
              itemBuilder: (context, index) =>
                  _buildLoadCard(loads[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 400,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No loads available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadCard(Load load) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeM),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.push('/load-details/${load.id}').then((_) => _loadData()),
        borderRadius: BorderRadius.circular(tokens.shapeM),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    load.loadReference,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusBadge(load.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(load.goods, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (load.stops.isNotEmpty) ...[
                _buildStopInfo(
                  'Pickup',
                  load.stops.first.location,
                  load.stops.first.appointmentWindow,
                ),
                const SizedBox(height: 8),
                _buildStopInfo(
                  'Delivery',
                  load.stops.last.location,
                  load.stops.last.appointmentWindow,
                ),
              ],
              const SizedBox(height: 16),
              if (load.status == LoadStatus.assigned || load.status == LoadStatus.pending)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    M3SpringButton(
                      onTap: () async {
                        await LoadRepository.updateLoadStatus(
                          load.id,
                          LoadStatus.rejected,
                        );
                        await _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.error),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'REJECT',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    M3SpringButton(
                      onTap: () async {
                        await LoadRepository.updateLoadStatus(
                          load.id,
                          LoadStatus.enRoute,
                        );
                        await _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ACCEPT',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopInfo(
    String label,
    LoadLocation loc,
    AppointmentWindow? appointmentWindow,
  ) {
    return Row(
      children: [
        Icon(
          label == 'Pickup' ? Icons.location_on_outlined : Icons.flag_outlined,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ${loc.city}, ${loc.state}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (appointmentWindow != null)
                Text(
                  '${DateFormat('HH:mm').format(appointmentWindow.start)} - ${DateFormat('HH:mm').format(appointmentWindow.end)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(LoadStatus status) {
    final tokens = context.tokens;
    Color color;
    switch (status) {
      case LoadStatus.assigned:
        color = Colors.blue;
        break;
      case LoadStatus.enRoute:
        color = Colors.orange;
        break;
      case LoadStatus.delivered:
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
