import 'package:flutter/material.dart';
// 修正：導入 screens 的絕對路徑
import 'package:luminew_application_1/screens/student/class_screen.dart';
import 'package:luminew_application_1/screens/student/data_entry_screen.dart';
import 'package:luminew_application_1/screens/student/interview/interview_screens.dart';
import 'package:luminew_application_1/screens/student/interview/record_list_screen.dart';
import 'package:luminew_application_1/screens/common/settings_screen.dart';

class StudentMainScaffold extends StatefulWidget {
  final String userId;

  const StudentMainScaffold({super.key, required this.userId});

  @override
  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();
}

class _StudentMainScaffoldState extends State<StudentMainScaffold> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    InterviewHomePage(userId: widget.userId), // 主頁
    InterviewRecordListScreen(userId: widget.userId), // 面試紀錄
    DataEntryScreen(userId: widget.userId), // 填寫資料
    ClassScreen(userId: widget.userId), // 班級
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '主頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_external_on_outlined),
            activeIcon: Icon(Icons.mic_external_on),
            label: '面試紀錄',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: '填寫資料',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: '班級',
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
