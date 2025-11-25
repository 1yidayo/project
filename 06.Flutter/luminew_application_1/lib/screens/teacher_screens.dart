// fileName: lib/screens/teacher_screens.dart
import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'chat_screens.dart';
import 'interview_screens.dart'; // 引用修好的錄影與紀錄頁面

// ==========================================
// 1. 教師端主架構
//    (底部保留：班級、交流、評語、設定)
//    (頂部右上：鈴鐺 -> 邀請管理)
// ==========================================
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
    // 定義主畫面的四個分頁
    final pages = [
      TeacherClassScreen(user: widget.user), // 0. 班級管理
      ClassChatRoom(
        chatKey: 'public',
        userEmail: widget.user.email,
        title: '公共交流',
        showAppBar: false,
      ), // 1. 公共交流
      InterviewRecordListScreen(user: widget.user), // 2. 評語/紀錄中心 (這是您要保留的)
      SettingsScreen(onLogout: widget.onLogout, user: widget.user), // 3. 設定
    ];

    // 對應的標題
    final titles = ['班級管理', '互動交流', '紀錄審閱', '設定'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_idx]),
        actions: [
          // ★ 修改：右上角鈴鐺圖示 (查看邀請狀態)
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherNotificationsScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: '班級'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '交流'),
          // ★ 這裡保留了評語頁，移除了邀請頁
          BottomNavigationBarItem(icon: Icon(Icons.rate_review), label: '評語'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

// ==========================================
// 2. 老師通知中心 (獨立頁面：查看邀請狀態)
// ==========================================
class TeacherNotificationsScreen extends StatelessWidget {
  final AppUser user;
  const TeacherNotificationsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("邀請發送紀錄")),
      body: FutureBuilder<List<Invitation>>(
        future: SqlService.getInvitations(user.id, true), // true = 我是老師
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(
              child: Text(
                "目前沒有已發送的邀請\n請至班級學生列表發送",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (ctx, i) {
              final inv = snap.data![i];
              
              // 狀態顏色與文字
              Color statusColor = Colors.orange;
              String statusText = "等待回覆";
              IconData statusIcon = Icons.access_time;

              if (inv.status == 'Accepted') {
                statusColor = Colors.green;
                statusText = "學生已接受";
                statusIcon = Icons.check_circle;
              } else if (inv.status == 'Rejected') {
                statusColor = Colors.red;
                statusText = "學生已拒絕";
                statusIcon = Icons.cancel;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Text("發送給：${inv.studentName}"),
                  subtitle: Text("訊息: ${inv.message}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        inv.date.split(' ')[0], // 顯示日期
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 3. 班級管理頁 (列表 + 創建)
// ==========================================
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
    Future.delayed(Duration.zero, _load);
  }

  // 讀取列表
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
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await SqlService.createClass(_ctrl.text, widget.user.email);
      await Future.delayed(const Duration(milliseconds: 500));
      _ctrl.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('建立成功！')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 這裡不用 AppBar，因為外層已經有了
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
                ? const Center(
                    child: Text(
                      "目前沒有班級，請建立一個！",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
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

// ==========================================
// 4. 班級詳情頁 (學生列表 + 聊天室 + 發送邀請功能)
// ==========================================
class TeacherClassDetailScreen extends StatefulWidget {
  final Class cls;
  final AppUser user;
  const TeacherClassDetailScreen({
    super.key,
    required this.cls,
    required this.user,
  });

  @override
  State<TeacherClassDetailScreen> createState() => _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen> {
  final _inviteMsgCtrl = TextEditingController();

  // 顯示發送邀請的對話框
  void _showInviteDialog(Student student) {
    _inviteMsgCtrl.text = "同學你好，邀請你進行一次模擬面試。"; // 預設訊息
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("邀請 ${student.name} 面試"),
        content: TextField(
          controller: _inviteMsgCtrl,
          decoration: const InputDecoration(
            labelText: '邀請訊息',
            hintText: '輸入給學生的訊息...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_inviteMsgCtrl.text.isEmpty) return;
              Navigator.pop(ctx); // 先關閉對話框
              try {
                await SqlService.sendInvitation(
                  widget.user.email,
                  student.id,
                  _inviteMsgCtrl.text,
                );
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已發送邀請給 ${student.name}')),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('發送失敗: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text("發送邀請"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.cls.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: '學生列表'),
              Tab(text: '班級聊天'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: 學生列表 (含發送邀請按鈕)
            FutureBuilder<List<Student>>(
              future: SqlService.getClassStudents(widget.cls.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.isEmpty)
                  return const Center(
                    child: Text(
                      "尚無學生加入\n請將邀請碼給學生",
                      textAlign: TextAlign.center,
                    ),
                  );

                return ListView.builder(
                  itemCount: snap.data!.length,
                  itemBuilder: (ctx, i) {
                    final s = snap.data![i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(s.name[0])),
                      title: Text(s.name),
                      subtitle: const Text("點擊右側按鈕發送面試邀請"),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.mail_outline,
                          color: Colors.blue,
                        ),
                        // 點擊後跳出邀請對話框
                        onPressed: () => _showInviteDialog(s),
                      ),
                    );
                  },
                );
              },
            ),
            // Tab 2: 班級聊天室
            ClassChatRoom(
              chatKey: widget.cls.id,
              userEmail: widget.user.email,
              title: widget.cls.name,
              showAppBar: false,
            ),
          ],
        ),
      ),
    );
  }
}