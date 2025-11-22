import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text(title)),
  );
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const SettingsScreen({super.key, required this.onLogout, required this.user});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.name;
  }

  Future<void> _saveName() async {
    try {
      await SqlService.updateUserName(widget.user.email, _nameCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('名稱已更新，請重新登入生效')));
        Navigator.pop(context);
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Row(
              children: [
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('修改名稱'),
                        content: TextField(controller: _nameCtrl),
                        actions: [
                          TextButton(
                            onPressed: _saveName,
                            child: const Text('儲存'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            accountEmail: Text(widget.user.email),
            currentAccountPicture: CircleAvatar(
              child: Text(widget.user.name[0]),
            ),
            decoration: const BoxDecoration(color: Colors.indigo),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出'),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }
}
