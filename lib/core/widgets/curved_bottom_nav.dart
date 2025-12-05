import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CurvedBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  const CurvedBottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class CurvedBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<CurvedBottomNavItem> items;
  final VoidCallback onCenterTap;
  final ValueChanged<int> onTap;

  const CurvedBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onCenterTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = const Color(0xFF6C5CE7); // Purple accent
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Glassy frosted pill bar
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.75),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 32,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left two items
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _NavButton(
                            icon: items[0].icon,
                            activeIcon: items[0].activeIcon,
                            label: items[0].label,
                            selected: currentIndex == 0,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => onTap(0),
                          ),
                          _NavButton(
                            icon: items[1].icon,
                            activeIcon: items[1].activeIcon,
                            label: items[1].label,
                            selected: currentIndex == 1,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => onTap(1),
                          ),
                        ],
                      ),
                    ),
                    // Center gap for floating button
                    const SizedBox(width: 76),
                    // Right two items
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _NavButton(
                            icon: items[2].icon,
                            activeIcon: items[2].activeIcon,
                            label: items[2].label,
                            selected: currentIndex == 2,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => onTap(2),
                          ),
                          _NavButton(
                            icon: items[3].icon,
                            activeIcon: items[3].activeIcon,
                            label: items[3].label,
                            selected: currentIndex == 3,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => onTap(3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Center floating circular button with glassy effect
          Positioned(
            bottom: 20,
            child: GestureDetector(
              onTap: onCenterTap,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [activeColor, activeColor.withValues(alpha: 0.85)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? (activeIcon ?? icon) : icon,
              color: selected ? activeColor : inactiveColor,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
