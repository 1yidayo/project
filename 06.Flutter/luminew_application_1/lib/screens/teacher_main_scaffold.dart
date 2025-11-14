import 'package:flutter/material.dart';
// 修正：導入 screens 的絕對路徑
import 'package:luminew_application_1/screens/teacher/teacher_class_screen.dart';
import 'package:luminew_application_1/screens/common/communication_screen.dart';
import 'package:luminew_application_1/screens/student/placeholder_screens.dart';
import 'package:luminew_application_1/screens/common/settings_screen.dart';

class TeacherMainScaffold extends StatefulWidget {
  final String userId;

  const TeacherMainScaffold({super.key, required this.userId});

  @override
  State<TeacherMainScaffold> createState() => _TeacherMainScaffoldState();
}

class _TeacherMainScaffoldState extends State<TeacherMainScaffold> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    TeacherClassScreen(userId: widget.userId), // 班級管理
    TeacherCommunicationScreen(userId: widget.userId), // 互動交流
    const PlaceholderScreen(title: '教師：面試邀請'), // 面試邀請
    const PlaceholderScreen(title: '教師：評語請求'), // 評語請求
    const SettingsScreen(), // 設定
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: '班級管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: '互動交流',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            activeIcon: Icon(Icons.mail),
            label: '面試邀請',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rate_review_outlined),
            activeIcon: Icon(Icons.rate_review),
            label: '評語請求',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
      ),
    );
  }
}
