import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'home/home_screen.dart';
import 'habits/habits_screen.dart';
import 'progress_screen.dart';
import 'achievements/achievements_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HabitsScreen(),
    ProgressScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.checklist_rounded, Icons.checklist_outlined, 'Habits'),
    (Icons.insights_rounded, Icons.insights_outlined, 'Progress'),
    (Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Wins'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: cs.secondary.withValues(alpha: .14)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: .16),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final selected = _currentIndex == index;
                      final accent = index.isEven ? cs.primary : cs.secondary;
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _currentIndex = index),
                          borderRadius: BorderRadius.circular(22),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: selected ? accent.withValues(alpha: .16) : Colors.transparent,
                              borderRadius: BorderRadius.circular(19),
                              boxShadow: selected
                                  ? [BoxShadow(color: accent.withValues(alpha: .18), blurRadius: 18)]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selected ? item.$1 : item.$2,
                                  color: selected ? accent : cs.onSurface.withValues(alpha: .55),
                                  size: selected ? 24 : 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.$3,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                                    color: selected ? accent : cs.onSurface.withValues(alpha: .55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
