import 'package:flutter/material.dart';

// 佔位符頁面
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, textAlign: TextAlign.center)),
    );
  }
}

// 通知中心 (佔位符)
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知中心')),
      body: const Center(
        child: Text(
          '【通知中心頁】\n面試邀約、互動交流訊息、班級邀請/公告等通知。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
