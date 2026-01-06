import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/core/models/border_wait_time.dart';

class BorderWaitTimeCard extends StatefulWidget {
  final BorderWaitTime waitTime;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const BorderWaitTimeCard({
    required this.waitTime,
    super.key,
    this.onTap,
    this.onRemove,
  });

  @override
  State<BorderWaitTimeCard> createState() => _BorderWaitTimeCardState();
}

class _BorderWaitTimeCardState extends State<BorderWaitTimeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Determine delay color based on commercial truck delay
    final Color delayColor = _getDelayColor(
      widget.waitTime.commercialDelay,
      widget.waitTime.operationalStatus,
      tokens,
    );

    return Card(
      margin: EdgeInsets.only(bottom: tokens.radiusM),
      elevation: 0,
      color: tokens.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.spacingL),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(tokens.spacingL),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.spacingM),
              child: Row(
                children: [
                  // Delay section
                  Container(
                    width: 90,
                    padding: EdgeInsets.symmetric(vertical: tokens.spacingS),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.waitTime.delayDisplay.split(' ').first,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                        ),
                        if (_getDelayLabel().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _getDelayLabel(),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: delayColor,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 50,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  SizedBox(width: tokens.spacingM),
                  // Port info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.waitTime.crossingName.isNotEmpty
                              ? widget.waitTime.crossingName
                              : widget.waitTime.portName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: tokens.spacingXS),
                        Text(
                          '${widget.waitTime.portName} • ${widget.waitTime.lanesOpen}/${widget.waitTime.maxLanes} lanes',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Expand/remove icon
                  if (widget.onRemove != null)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: widget.onRemove,
                      tooltip: 'Remove',
                    )
                  else
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: M3ExpressiveMotion.durationMedium,
                      curve: M3ExpressiveMotion.standard,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(context, tokens),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: M3ExpressiveMotion.durationMedium,
              firstCurve: M3ExpressiveMotion.standard,
              secondCurve: M3ExpressiveMotion.standard,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, DesignTokens tokens) {
    final waitTime = widget.waitTime;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(
        tokens.spacingM,
        0,
        tokens.spacingM,
        tokens.spacingM,
      ),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          SizedBox(height: tokens.spacingM),

          // Standard Commercial Lanes
          _buildLaneSection(
            context,
            tokens,
            title: 'Standard Commercial Lanes',
            icon: Icons.local_shipping_outlined,
            delay: waitTime.delayDisplay,
            lanesOpen: waitTime.commercialLanesOpen,
            maxLanes: waitTime.maxLanes,
            status: waitTime.operationalStatus ?? 'N/A',
            updateTime: waitTime.updateTime,
            delayColor: _getDelayColor(
              waitTime.commercialDelay,
              waitTime.operationalStatus,
              tokens,
            ),
            accentColor: accentColor,
          ),

          SizedBox(height: tokens.radiusM),

          // FAST Lanes
          _buildLaneSection(
            context,
            tokens,
            title: 'FAST Lanes',
            icon: Icons.speed_outlined,
            delay: waitTime.fastDelayDisplay,
            lanesOpen: waitTime.fastLanesOpen,
            maxLanes: waitTime.fastMaxLanes,
            status: waitTime.fastOperationalStatus ?? 'N/A',
            updateTime: null,
            delayColor: _getDelayColor(
              waitTime.fastLanesDelay,
              waitTime.fastOperationalStatus,
              tokens,
            ),
            accentColor: accentColor,
          ),

          SizedBox(height: tokens.spacingM),
          SizedBox(height: tokens.spacingM),
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          SizedBox(height: tokens.radiusM),
          SizedBox(height: tokens.radiusM),

          // Port details
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  context,
                  icon: Icons.access_time_outlined,
                  label: 'Hours',
                  value: waitTime.hours ?? 'N/A',
                ),
              ),
              SizedBox(width: tokens.radiusM),
              Expanded(
                child: _buildInfoChip(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Border',
                  value: waitTime.border ?? 'N/A',
                ),
              ),
            ],
          ),

          SizedBox(height: tokens.radiusM),

          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  context,
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: waitTime.portStatus,
                  valueColor: waitTime.portStatus == 'Open'
                      ? tokens.success
                      : tokens.error,
                ),
              ),
              SizedBox(width: tokens.radiusM),
              Expanded(
                child: _buildInfoChip(
                  context,
                  icon: Icons.update_outlined,
                  label: 'Updated',
                  value: waitTime.time ?? 'N/A',
                ),
              ),
            ],
          ),

          // Construction notice if available
          if (waitTime.constructionNotice != null &&
              waitTime.constructionNotice!.isNotEmpty &&
              !waitTime.constructionNotice!.contains('null')) ...[
            SizedBox(height: tokens.radiusM),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(tokens.radiusM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(tokens.radiusS),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: tokens.warning,
                  ),
                  SizedBox(width: tokens.spacingS),
                  Expanded(
                    child: Text(
                      waitTime.constructionNotice!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLaneSection(
    BuildContext context,
    DesignTokens tokens, {
    required String title,
    required IconData icon,
    required String delay,
    required int lanesOpen,
    required int maxLanes,
    required String status,
    required String? updateTime,
    required Color delayColor,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.all(tokens.radiusM),
      decoration: BoxDecoration(
        color: delayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.radiusM),
        border: Border.all(color: delayColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              SizedBox(width: tokens.spacingS),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacingS,
                  vertical: tokens.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: delayColor,
                  borderRadius: BorderRadius.circular(tokens.shapeS),
                ),
                child: Text(
                  delay,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingS),
          Row(
            children: [
              Text(
                'Lanes: $lanesOpen/$maxLanes open',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: tokens.spacingM),
              Text(
                'Status: $status',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (updateTime != null && updateTime.isNotEmpty) ...[
            SizedBox(height: tokens.spacingXS),
            Text(
              'Last updated: $updateTime',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: context.tokens.spacingS),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getDelayColor(int? delay, String? status, DesignTokens tokens) {
    if (status == 'Lanes Closed' || status == 'N/A') {
      return tokens.textTertiary; // Gray for closed/N/A
    }
    if (delay == null || delay == 0) {
      return tokens.success; // Green - no delay
    } else if (delay <= 30) {
      return tokens.warning; // Amber - moderate
    } else {
      return tokens.error; // Red - heavy
    }
  }

  String _getDelayLabel() {
    final delay = widget.waitTime.commercialDelay;
    final status = widget.waitTime.operationalStatus;

    if (status == 'Lanes Closed') return '';
    if (status == 'Update Pending') return '';
    if (delay == null || delay == 0) return 'Delay';
    if (delay < 60) return 'min delay';
    final display = widget.waitTime.delayDisplay.split(' ');
    if (display.length > 1) {
      return display.sublist(1).join(' ');
    }
    return 'Delay';
  }
}

/// Compact card for horizontal scrolling list
class BorderWaitTimeCompactCard extends StatelessWidget {
  final BorderWaitTime waitTime;
  final VoidCallback? onTap;

  const BorderWaitTimeCompactCard({
    required this.waitTime,
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Determine delay color based on commercial truck delay
    Color delayColor;
    final delay = waitTime.commercialDelay ?? 0;
    if (delay == 0) {
      delayColor = tokens.success;
    } else if (delay <= 30) {
      delayColor = tokens.warning;
    } else {
      delayColor = tokens.error;
    }

    return Container(
      width: 200,
      margin: EdgeInsets.only(right: tokens.radiusM),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusL),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusL),
          child: Padding(
            padding: EdgeInsets.all(tokens.radiusM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: delayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: tokens.spacingS),
                    Expanded(
                      child: Text(
                        waitTime.portName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacingS),
                Text(
                  waitTime.delayDisplay,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: delayColor,
                  ),
                ),
                SizedBox(height: tokens.spacingXS),
                Text(
                  '${waitTime.lanesOpen} lanes open',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
