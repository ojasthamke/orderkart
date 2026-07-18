import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../expense/presentation/expense_screen.dart';
import '../../note/presentation/notes_list_screen.dart';
import '../../area/presentation/area_screen.dart';
import 'dashboard_screen.dart';
import '../../../core/services/permission_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InventoryScreen(showBack: false),
    AreaScreen(showBack: false),
    NotesListScreen(showBack: false),
    ExpenseScreen(showBack: false),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _requestPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await PermissionService.requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Crucial: lets body content extend under the floating bottom bar
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;

          if (_currentIndex != 0) {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
            );
            return;
          }

          final now = DateTime.now();
          if (_lastBackPressTime == null || 
              now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            SystemNavigator.pop();
          }
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          physics: const BouncingScrollPhysics(),
          children: _screens,
        ),
      ),
      bottomNavigationBar: FloatingGlassBottomBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        },
        destinations: const [
          FloatingBottomDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),
          FloatingBottomDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: 'Inventory',
          ),
          FloatingBottomDestination(
            icon: Icons.map_outlined,
            selectedIcon: Icons.map_rounded,
            label: 'Areas',
          ),
          FloatingBottomDestination(
            icon: Icons.note_alt_outlined,
            selectedIcon: Icons.note_alt_rounded,
            label: 'Notes',
          ),
          FloatingBottomDestination(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Expenses',
          ),
        ],
      ),
    );
  }
}

class FloatingGlassBottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final List<FloatingBottomDestination> destinations;

  const FloatingGlassBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(isDark ? 0.72 : 0.85),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  final isSelected = selectedIndex == index;
                  final item = destinations[index];
                  final activeColor = theme.colorScheme.primary;
                  final inactiveColor = isDark ? Colors.white54 : Colors.black45;

                  return InkWell(
                    onTap: () => onDestinationSelected(index),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isSelected
                            ? activeColor.withOpacity(isDark ? 0.18 : 0.1)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected ? activeColor : inactiveColor,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? activeColor : inactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingBottomDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingBottomDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
