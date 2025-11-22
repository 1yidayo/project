import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'chat_screens.dart';

// 1. 教師端主架構 (底部導覽列)
class TeacherMainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const TeacherMainScaffold({
    super.key,
    required this.onLogout,
    required this.user,
  });

  @override
  State<TeacherMainScaffold> createState() => _TeacherMainScaffoldState();
}

class _TeacherMainScaffoldState extends State<TeacherMainScaffold> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TeacherClassScreen(user: widget.user),
      ClassChatRoom(
        chatKey: 'public',
        userEmail: widget.user.email,
        title: '公共交流區',
        showAppBar: false,
      ),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      // 只有在聊天室分頁顯示 AppBar，避免其他頁面雙重標題
      appBar: _idx == 1 ? AppBar(title: const Text('互動交流')) : null,
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: '班級管理'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '互動交流'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

// 2. 班級管理頁 (列表 + 創建)
class TeacherClassScreen extends StatefulWidget {
  final AppUser user;
  const TeacherClassScreen({super.key, required this.user});
  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  final _ctrl = TextEditingController();
  List<Class> _list = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 延遲執行讀取，確保畫面已準備好
    Future.delayed(Duration.zero, _load);
  }

  // 讀取列表 (含錯誤顯示)
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var data = await SqlService.getTeacherClasses(widget.user.email);
      if (mounted) {
        setState(() {
          _list = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("載入錯誤: $e");
      if (mounted) {
        // 如果讀取失敗，顯示紅字警告
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("列表載入失敗: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // 創建班級
  Future<void> _create() async {
    if (_ctrl.text.isEmpty) return;
    FocusScope.of(context).unfocus(); // 收起鍵盤

    setState(() => _isLoading = true);
    try {
      await SqlService.createClass(_ctrl.text, widget.user.email);

      // 給資料庫一點時間緩衝 (0.5秒)
      await Future.delayed(const Duration(milliseconds: 500));

      _ctrl.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('建立成功！')));

      // 重新讀取列表
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('班級管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      labelText: '輸入新班級名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('建班'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                ? const Center(child: Text("目前沒有班級，請建立一個！"))
                : ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.school, color: Colors.indigo),
                        title: Text(
                          _list[i].name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('代碼: ${_list[i].invitationCode}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        // 點擊進入詳情頁
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherClassDetailScreen(
                              cls: _list[i],
                              user: widget.user,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// 3. 班級詳情頁 (學生列表 + 聊天室 Tab)
class TeacherClassDetailScreen extends StatelessWidget {
  final Class cls;
  final AppUser user;
  const TeacherClassDetailScreen({
    super.key,
    required this.cls,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(cls.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: '學生列表'),
              Tab(text: '班級聊天'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: 學生列表
            FutureBuilder<List<Student>>(
              future: SqlService.getClassStudents(cls.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.isEmpty)
                  return const Center(child: Text("尚無學生加入\n請將邀請碼給學生"));

                return ListView.builder(
                  itemCount: snap.data!.length,
                  itemBuilder: (ctx, i) {
                    final s = snap.data![i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(s.name[0])),
                      title: Text(s.name),
                      subtitle: const Text("點擊發送邀請"),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.mail_outline,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          SqlService.sendInvitation(user.email, s.id, "邀請面試");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已發送邀請給 ${s.name}')),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            // Tab 2: 班級聊天室
            ClassChatRoom(
              chatKey: cls.id,
              userEmail: user.email,
              title: cls.name,
              showAppBar: false,
            ),
          ],
        ),
      ),
    );
  }
}
