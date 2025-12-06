import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/models/border_wait_time.dart';

class BorderWaitTimeCard extends StatefulWidget {
  final BorderWaitTime waitTime;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const BorderWaitTimeCard({
    required this.waitTime, super.key,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF667085);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    // Determine delay color based on commercial truck delay
    final Color delayColor = _getDelayColor(
      widget.waitTime.commercialDelay,
      widget.waitTime.operationalStatus,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Delay section
                          Container(
                            width: 90,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.waitTime.delayDisplay.split(' ').first,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getDelayLabel(),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: delayColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Divider
                          Container(width: 1, height: 50, color: dividerColor),
                          const SizedBox(width: 16),
                          // Port info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.waitTime.crossingName.isNotEmpty
                                      ? widget.waitTime.crossingName
                                      : widget.waitTime.portName,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.waitTime.portName} • ${widget.waitTime.lanesOpen}/${widget.waitTime.maxLanes} lanes',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: subtextColor,
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
                                color: subtextColor,
                              ),
                              onPressed: widget.onRemove,
                              tooltip: 'Remove',
                            )
                          else
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: subtextColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Expanded content
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildExpandedContent(
                        isDark: isDark,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        dividerColor: dividerColor,
                      ),
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color dividerColor,
  }) {
    final waitTime = widget.waitTime;
    final accentColor = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),

          // Standard Commercial Lanes
          _buildLaneSection(
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
            ),
            textColor: textColor,
            subtextColor: subtextColor,
            accentColor: accentColor,
          ),

          const SizedBox(height: 12),

          // FAST Lanes
          _buildLaneSection(
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
            ),
            textColor: textColor,
            subtextColor: subtextColor,
            accentColor: accentColor,
          ),

          const SizedBox(height: 16),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 12),

          // Port details
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.access_time_outlined,
                  label: 'Hours',
                  value: waitTime.hours ?? 'N/A',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.location_on_outlined,
                  label: 'Border',
                  value: waitTime.border ?? 'N/A',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: waitTime.portStatus,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  valueColor: waitTime.portStatus == 'Open'
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.update_outlined,
                  label: 'Updated',
                  value: waitTime.time ?? 'N/A',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          // Construction notice if available
          if (waitTime.constructionNotice != null &&
              waitTime.constructionNotice!.isNotEmpty &&
              !waitTime.constructionNotice!.contains('null')) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      waitTime.constructionNotice!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
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

  Widget _buildLaneSection({
    required String title,
    required IconData icon,
    required String delay,
    required int lanesOpen,
    required int maxLanes,
    required String status,
    required String? updateTime,
    required Color delayColor,
    required Color textColor,
    required Color subtextColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: delayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: delayColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: delayColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  delay,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Lanes: $lanesOpen/$maxLanes open',
                style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
              ),
              const SizedBox(width: 16),
              Text(
                'Status: $status',
                style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
              ),
            ],
          ),
          if (updateTime != null && updateTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Last updated: $updateTime',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: subtextColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subtextColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getDelayColor(int? delay, String? status) {
    if (status == 'Lanes Closed' || status == 'N/A') {
      return const Color(0xFF6B7280); // Gray for closed/N/A
    }
    if (delay == null || delay == 0) {
      return const Color(0xFF22C55E); // Green - no delay
    } else if (delay <= 30) {
      return const Color(0xFFF59E0B); // Amber - moderate
    } else {
      return const Color(0xFFEF4444); // Red - heavy
    }
  }

  String _getDelayLabel() {
    final delay = widget.waitTime.commercialDelay;
    final status = widget.waitTime.operationalStatus;

    if (status == 'Lanes Closed') return 'Closed';
    if (status == 'Update Pending') return 'Pending';
    if (delay == null || delay == 0) return 'No Delay';
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
    required this.waitTime, super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);

    // Determine delay color based on commercial truck delay
    Color delayColor;
    final delay = waitTime.commercialDelay ?? 0;
    if (delay == 0) {
      delayColor = const Color(0xFF22C55E);
    } else if (delay <= 30) {
      delayColor = const Color(0xFFF59E0B);
    } else {
      delayColor = const Color(0xFFEF4444);
    }

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        waitTime.portName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  waitTime.delayDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: delayColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${waitTime.lanesOpen} lanes open',
                  style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
