import 'package:flutter/material.dart';
import 'package:milow/features/explore/presentation/pages/explore_page.dart';
import 'package:milow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:milow/features/inbox/presentation/pages/inbox_page.dart';
import 'package:milow/features/settings/presentation/pages/settings_page.dart';

class TabsShell extends StatefulWidget {
  final int initialIndex;
  const TabsShell({required this.initialIndex, super.key});

  @override
  State<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<TabsShell> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TabsShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _index) {
      _index = widget.initialIndex;
      _controller.jumpToPage(_index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: background,
      body: PageView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: const [
          DashboardPage(),
          ExplorePage(),
          InboxPage(),
          SettingsPage(),
        ],
      ),
    );
  }
}
