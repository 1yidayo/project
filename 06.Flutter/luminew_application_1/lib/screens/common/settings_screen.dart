import 'package:flutter/material.dart';
// 修正：導入 services 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('使用者資訊'),
            subtitle: const Text('頭貼、名稱、ID、身份'),
            trailing: const Icon(Icons.edit),
            onTap: () {
              /* 跳轉至使用者資訊頁 */
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              '登出',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              // 登出
              await firebaseService.signOut();
              // AuthWrapper 會自動處理跳轉
            },
          ),
        ],
      ),
    );
  }
}
