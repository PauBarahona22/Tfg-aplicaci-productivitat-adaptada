
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/reminder_service.dart';
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
  final ReminderService _reminderService = ReminderService();

  @override
  void initState() {
    super.initState();
    _setupNotificationActions();
  }

  Future<void> _setupNotificationActions() async {
    await _reminderService.initialize();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _handleNotificationAction(details);
      },
    );
  }

  void _handleNotificationAction(NotificationResponse details) async {
    if (details.payload == null) return;

    final String reminderId = details.payload!;

    switch (details.actionId) {
      case 'complete':
        await _reminderService.completeReminderFromNotification(reminderId);
        break;
      case 'delay_15':
        await _reminderService.delayReminderFromNotification(reminderId, 15);
        break;
      case 'delay_60':
        await _reminderService.delayReminderFromNotification(reminderId, 60);
        break;
      default:
        _navigateToRemindersTab();
        break;
    }
  }

  void _navigateToRemindersTab() {
    _onItemTapped(3);
  }

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
        color: Color(0xFFBAD1C2),
        child: Row(
          children: List.generate(5, (index) {
            final bool isSelected = _selectedIndex == index;
            final double iconSize = isSelected ? 40 : 34;

            return Expanded(
              flex: isSelected ? 2 : 1,
              child: GestureDetector(
                onTap: () => _onItemTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF4FA095) : Color(0xFF9BB8A5),
                    border: Border.all(color: Color(0xFF25766B)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _getIcon(index),
                    size: iconSize,
                    color: isSelected ? Colors.white : Color(0xFF25766B),
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