import 'package:flutter/material.dart';
import 'task_list_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'reminders_list_screen.dart';
import 'challenges_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final PageController _pageController = PageController(initialPage: 2);
  int _selectedIndex = 2;

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: const [
          TaskListScreen(),
          CalendarScreen(),
          HomeScreen(),
          RemindersScreen(),
          ChallengesScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        color: Colors.white,
        child: Row(
          children: List.generate(5, (index) {
            final bool isSelected = _selectedIndex == index;
            // Ajuste de tamaños: no activo 30, activo 36
            final double iconSize = isSelected ? 36 : 30;

            return Expanded(
              flex: isSelected ? 2 : 1,
              child: GestureDetector(
                onTap: () => _onItemTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _getIcon(index),
                    size: iconSize,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.checklist;
      case 1:
        return Icons.calendar_today;
      case 2:
        return Icons.home;
      case 3:
        return Icons.notifications;
      case 4:
        return Icons.flag;
      default:
        return Icons.help;
    }
  }
}
