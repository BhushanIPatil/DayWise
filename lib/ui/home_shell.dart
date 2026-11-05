import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'calendar_page.dart';
import 'accounts_page.dart';
import 'entry_sheet.dart';
import 'insights_page.dart';
import 'settings_page.dart';
import 'week_page.dart';
import 'widgets.dart';

/// Four tabs plus a centre "+" button, in a floating pill-shaped bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new day may have started while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      AppScope.read(context).generateDue();
    }
  }

  static const List<Widget> _pages = [
    CalendarPage(),
    WeekPage(),
    InsightsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          Column(
            children: [
              if (_tab != 3)
                const SafeArea(bottom: false, child: AccountSwitcher()),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: _tab != 3,
                  child: IndexedStack(index: _tab, children: _pages),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BannerAdWidget(),
              const SizedBox(height: 10),
              _NavPill(
                index: _tab,
                onSelect: (i) {
                  tapHaptic();
                  setState(() => _tab = i);
                },
                onAdd: () {
                  tapHaptic();
                  showEntrySheet(context, date: DateTime.now());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(33),
        border: Border.all(
          color: context.isDark
              ? const Color(0x1AFFFFFF)
              : const Color(0x0F000000),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _item(context, 0, Icons.calendar_month_rounded, 'Calendar'),
          _item(context, 1, Icons.view_week_rounded, 'Week'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: accentGradient(context.cs.primary),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tint(context.cs.primary, 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          _item(context, 2, Icons.insights_rounded, 'Insights'),
          _item(context, 3, Icons.settings_rounded, 'Settings'),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon, String label) {
    final sel = index == i;
    final color = sel ? context.cs.primary : context.cs.onSurfaceVariant;
    return Expanded(
      child: InkResponse(
        onTap: () => onSelect(i),
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: sel
                    ? tint(context.cs.primary, 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
