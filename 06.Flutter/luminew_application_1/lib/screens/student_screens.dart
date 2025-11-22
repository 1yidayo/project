import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'interview_screens.dart';
import 'chat_screens.dart';

class StudentMainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const StudentMainScaffold({
    super.key,
    required this.onLogout,
    required this.user,
  });

  @override
  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();
}

class _StudentMainScaffoldState extends State<StudentMainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      InterviewHomePage(user: widget.user),
      ClassChatRoom(
        chatKey: 'public',
        userEmail: widget.user.email,
        title: '公共交流',
        showAppBar: false,
      ), // ✅ 聊天室設為分頁，會有導覽列
      InterviewRecordListScreen(user: widget.user),
      StudentClassScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      appBar: _index == 1 ? AppBar(title: const Text('公共交流區')) : null,
      body: screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '主頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            label: '交流',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            label: '紀錄',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: '班級',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

// ✅ 漂亮的卡片式主頁
class InterviewHomePage extends StatelessWidget {
  final AppUser user;
  const InterviewHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主頁'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '歡迎回來, ${user.name}！',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 20),
            _buildCard(
              context,
              title: '開始模擬面試',
              icon: Icons.mic_external_on_outlined,
              subtitle: '設定場景，即時獲得 AI 分析回饋',
              color: Colors.red.shade600,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockInterviewSetupScreen(user: user),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '常用功能入口',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildCard(
              context,
              title: '查看面試紀錄',
              icon: Icons.video_library_outlined,
              subtitle: '回放、查看過往練習與評分詳情',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InterviewRecordListScreen(user: user),
                ),
              ),
            ),
            _buildCard(
              context,
              title: '更新學習歷程',
              icon: Icons.description_outlined,
              subtitle: '上傳資料，優化 AI 提問',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DataEntryScreen(user: user)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),
        leading: Icon(
          icon,
          color: color != null ? Colors.white : Theme.of(context).primaryColor,
          size: 30,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color != null ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: color != null ? Colors.white70 : Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: color != null ? Colors.white70 : Colors.grey[600],
        ),
        onTap: onTap,
      ),
    );
  }
}

// 學生班級管理
class StudentClassScreen extends StatefulWidget {
  final AppUser user;
  const StudentClassScreen({super.key, required this.user});
  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  final _codeCtrl = TextEditingController();
  List<Class> _classes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      _classes = await SqlService.getStudentClasses(widget.user.email);
    } catch (e) {
      print(e);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _join() async {
    if (_codeCtrl.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      Class? cls = await SqlService.joinClass(
        _codeCtrl.text,
        widget.user.email,
      );
      _codeCtrl.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加入成功：${cls?.name}')));
      await _loadClasses();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的班級')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '加入新班級',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                            labelText: '輸入邀請碼',
                            border: OutlineInputBorder(),
                            hintText: "例如: C123456",
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _join,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('加入'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _classes.isEmpty
                ? const Center(child: Text("尚未加入任何班級"))
                : ListView.builder(
                    itemCount: _classes.length,
                    itemBuilder: (ctx, i) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.school, color: Colors.green),
                        title: Text(_classes[i].name),
                        subtitle: Text('代碼: ${_classes[i].invitationCode}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassChatRoom(
                              chatKey: _classes[i].id,
                              userEmail: widget.user.email,
                              title: _classes[i].name,
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

// 資料填寫
class DataEntryScreen extends StatefulWidget {
  final AppUser user;
  const DataEntryScreen({super.key, required this.user});
  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('資料填寫')),
      body: FutureBuilder<List<LearningPortfolio>>(
        future: SqlService.getPortfolios(widget.user.email),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '學習歷程檔案',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('上傳新檔案'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final c = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('上傳檔案'),
                      content: TextField(
                        controller: c,
                        decoration: const InputDecoration(labelText: '檔案標題'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            if (c.text.isNotEmpty) {
                              await SqlService.addPortfolio(
                                widget.user.email,
                                c.text,
                              );
                              Navigator.pop(ctx);
                              setState(() {});
                            }
                          },
                          child: const Text('上傳'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 30),
              ...snapshot.data!.map(
                (p) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.file_present,
                      color: Colors.orange,
                    ),
                    title: Text(p.title),
                    subtitle: Text(p.uploadDate),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
