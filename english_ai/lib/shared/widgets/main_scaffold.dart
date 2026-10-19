import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Ultra-smooth MainScaffold with silky fade-slide transitions,
/// horizontal swipe gesture detection, and zero-jank branch caching.
class MainScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const MainScaffold({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _isMovingForward = true;

  void _onTap(int index) {
    if (index == widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index, initialLocation: true);
    } else {
      setState(() {
        _isMovingForward = index > widget.navigationShell.currentIndex;
      });
      widget.navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navBgColor = theme.bottomNavigationBarTheme.backgroundColor ??
        context.palette.surface;
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: context.palette.background,
      // Horizontal swipe gesture: flick left/right to change tab
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -260 && currentIndex < widget.children.length - 1) {
            // Swiped left -> Next tab
            _onTap(currentIndex + 1);
          } else if (velocity > 260 && currentIndex > 0) {
            // Swiped right -> Previous tab
            _onTap(currentIndex - 1);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (index) {
            final isCurrent = index == currentIndex;
            // Compute silky micro-slide offset (-2% or +2%)
            final double slideX =
                isCurrent ? 0.0 : (_isMovingForward ? 0.03 : -0.03);

            return IgnorePointer(
              ignoring: !isCurrent,
              child: AnimatedOpacity(
                opacity: isCurrent ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedSlide(
                  offset: Offset(slideX, 0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: RepaintBoundary(
                    child: widget.children[index],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => _onTap(0),
                ),
                _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Learn',
                  isSelected: currentIndex == 1,
                  onTap: () => _onTap(1),
                ),
                _NavItem(
                  icon: Icons.sports_esports_rounded,
                  label: 'Practice',
                  isSelected: currentIndex == 2,
                  onTap: () => _onTap(2),
                ),
                _NavItem(
                  icon: Icons.smart_toy_rounded,
                  label: 'AI Tutor',
                  isSelected: currentIndex == 3,
                  onTap: () => _onTap(3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: currentIndex == 4,
                  onTap: () => _onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom bottom nav item with fast, zero-jank micro-animations.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  size: 24,
                  color:
                      isSelected ? AppColors.primary : context.palette.textHint,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      isSelected ? AppColors.primary : context.palette.textHint,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
