import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'interview_flow.dart'; // 新的面試流程
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
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      StudentHomePage(user: widget.user),
      InterviewRecordCenter(user: widget.user, isTeacher: false), // 整合的紀錄中心
      DataEntryScreen(user: widget.user),
      StudentClassScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '主頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_edu),
            label: '評語/紀錄',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.edit_document), label: '資料'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '班級'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

class StudentHomePage extends StatelessWidget {
  final AppUser user;
  const StudentHomePage({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luminew 主頁'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationCenter(user: user, isTeacher: false),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user.name}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 20),
            _ActionCard(
              title: '開始模擬面試',
              icon: Icons.mic,
              color: Colors.redAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InterviewSetupScreen(user: user),
                ),
              ),
            ),
            _ActionCard(
              title: '公共交流區',
              icon: Icons.forum,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ClassChatRoom(chatKey: 'public', userEmail: user.email),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '快捷功能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('我的面試回放'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InterviewRecordCenter(user: user, isTeacher: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DataEntryScreen extends StatelessWidget {
  final AppUser user;
  const DataEntryScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('資料填寫'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '基本資料'),
              Tab(text: '學習經歷'),
              Tab(text: '備審資料'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SimpleForm(user: user, cat: '基本資料'),
            _SimpleForm(user: user, cat: '學習經歷'),
            _SimpleForm(user: user, cat: '備審資料'),
          ],
        ),
      ),
    );
  }
}

class _SimpleForm extends StatelessWidget {
  final AppUser user;
  final String cat;
  const _SimpleForm({required this.user, required this.cat});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "$cat 填寫功能開發中\n(可連接 SQL LearningPortfolios 表)",
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

// StudentClassScreen 保持與之前相同，或貼上即可
class StudentClassScreen extends StatefulWidget {
  final AppUser user;
  const StudentClassScreen({super.key, required this.user});
  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  final _codeCtrl = TextEditingController();
  List<Class> _list = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    var d = await SqlService.getStudentClasses(widget.user.email);
    if (mounted) setState(() => _list = d);
  }

  void _join() async {
    if (_codeCtrl.text.isEmpty) return;
    try {
      await SqlService.joinClass(_codeCtrl.text, widget.user.email);
      _codeCtrl.clear();
      _load();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('成功加入')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的班級')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: '邀請碼',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton(onPressed: _join, child: const Text('加入')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _list.length,
              itemBuilder: (ctx, i) => Card(
                child: ListTile(
                  title: Text(_list[i].name),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassChatRoom(
                        chatKey: _list[i].id,
                        userEmail: widget.user.email,
                        title: _list[i].name,
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
