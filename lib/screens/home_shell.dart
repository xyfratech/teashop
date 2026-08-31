import 'package:flutter/material.dart';

import 'calculator_screen.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Index 0 is the calculator (the raised centre button). 1-4 are the tabs
  /// flanking it. Settings opens as its own route from the Home header.
  int _index = 0;

  static const List<Widget> _pages = [
    CalculatorScreen(),
    DashboardScreen(),
    TransactionsScreen(),
    ProductsScreen(),
    ReportsScreen(),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final calcSelected = _index == 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 66,
        height: 66,
        child: FloatingActionButton(
          onPressed: () => _go(0),
          elevation: 2,
          highlightElevation: 2,
          heroTag: null, // permanent nav control, never part of a route flight
          tooltip: 'Calculator',
          shape: const CircleBorder(),
          backgroundColor:
              calcSelected ? scheme.primary : scheme.primaryContainer,
          foregroundColor:
              calcSelected ? scheme.onPrimary : scheme.onPrimaryContainer,
          child: const Icon(Icons.calculate, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: scheme.surface,
        elevation: 3,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Home',
                          selected: _index == 1,
                          onTap: () => _go(1),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.receipt_long_outlined,
                          activeIcon: Icons.receipt_long,
                          label: 'Entries',
                          selected: _index == 2,
                          onTap: () => _go(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 72),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Icons.local_cafe_outlined,
                          activeIcon: Icons.local_cafe,
                          label: 'Menu',
                          selected: _index == 3,
                          onTap: () => _go(3),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.insights_outlined,
                          activeIcon: Icons.insights,
                          label: 'Reports',
                          selected: _index == 4,
                          onTap: () => _go(4),
                        ),
                      ),
                    ],
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
