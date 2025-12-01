// fileName: lib/screens/student_screens.dart
import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'interview_screens.dart';
import 'chat_screens.dart';

const Color kPrimaryColor = Color(0xFF3F51B5);
const Color kBackgroundColor = Color(0xFFF8F9FB);
const double kRadius = 16.0;

// ==========================================
// 1. 學生端主架構
// ==========================================
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
      ),
      InterviewRecordListScreen(user: widget.user),
      StudentClassScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _index == 1
          ? AppBar(
              title: const Text('公共交流區'),
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: Colors.black,
            )
          : null,
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主頁',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '交流',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: '紀錄',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: '班級',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. 學生主頁
// ==========================================
class InterviewHomePage extends StatelessWidget {
  final AppUser user;
  const InterviewHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('主頁', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentNotificationsScreen(user: user),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Hello, ${user.name}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '準備好開始練習了嗎？',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),

            _buildCard(
              context,
              title: '開始模擬面試 (AI)',
              icon: Icons.smart_toy,
              subtitle: '與 AI 機器人練習',
              color: kPrimaryColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockInterviewSetupScreen(user: user),
                ),
              ),
            ),

            _buildCard(
              context,
              title: '預約 Live 面試',
              icon: Icons.calendar_today_rounded,
              subtitle: '搶約老師時段',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentBookingScreen(user: user),
                ),
              ),
            ),

            _buildCard(
              context,
              title: '查看面試紀錄',
              icon: Icons.history_rounded,
              subtitle: '歷史練習',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InterviewRecordListScreen(user: user),
                ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (color ?? Colors.black).withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 預約面試
// ==========================================
class StudentBookingScreen extends StatefulWidget {
  final AppUser user;
  const StudentBookingScreen({super.key, required this.user});
  @override
  State<StudentBookingScreen> createState() => _StudentBookingScreenState();
}

class _StudentBookingScreenState extends State<StudentBookingScreen> {
  final _teacherEmailCtrl = TextEditingController();
  List<InterviewSlot> _slots = [];
  bool _isLoading = false;

  Future<void> _search() async {
    if (_teacherEmailCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      var list = await SqlService.getAvailableSlots(_teacherEmailCtrl.text);
      setState(() => _slots = list);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("錯誤: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _book(String slotId) async {
    try {
      await SqlService.bookSlot(slotId, widget.user.email);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ 預約成功！")));
      _search();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ 失敗: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("預約面試"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teacherEmailCtrl,
                    decoration: InputDecoration(
                      labelText: "輸入老師 Email",
                      hintText: "teacher@test.com",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text("查詢"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                ? const Center(
                    child: Text(
                      "目前無可用時段",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _slots.length,
                    itemBuilder: (ctx, i) {
                      final s = _slots[i];
                      final dateStr = "${s.startTime.month}/${s.startTime.day}";
                      final timeStr =
                          "${s.startTime.hour.toString().padLeft(2, '0')}:${s.startTime.minute.toString().padLeft(2, '0')}";
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: Colors.green,
                            ),
                          ),
                          title: Text(
                            "$dateStr $timeStr (30分)",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            "名額：1",
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _book(s.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("立即預約"),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 通知中心
// ==========================================
class StudentNotificationsScreen extends StatefulWidget {
  final AppUser user;
  const StudentNotificationsScreen({super.key, required this.user});
  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  Future<void> _respond(String id, String status) async {
    await SqlService.updateInvitation(id, status);
    setState(() {});
  }

  void _joinMeeting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("視訊會議")),
          body: const Center(
            child: Text("學生視訊畫面連線中...", style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("通知中心"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<Invitation>>(
        future: SqlService.getInvitations(widget.user.id, false),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) return const Center(child: Text("目前無新通知"));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.length,
            itemBuilder: (ctx, i) {
              final inv = snap.data![i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            color: kPrimaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${inv.teacherName} 邀請您面試",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        inv.message,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (inv.status == 'Pending') ...[
                            TextButton(
                              onPressed: () => _respond(inv.id, 'Rejected'),
                              child: const Text(
                                "殘忍拒絕",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _respond(inv.id, 'Accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text("接受邀請"),
                            ),
                          ] else if (inv.status == 'Accepted') ...[
                            Expanded(child: Container()),
                            ElevatedButton.icon(
                              onPressed: _joinMeeting,
                              icon: const Icon(Icons.video_call),
                              label: const Text("進入面試"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                          ] else ...[
                            Text(
                              "已拒絕",
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
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
// 5. 學生班級 (修復括號問題)
// ==========================================
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
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _classes = await SqlService.getStudentClasses(widget.user.email);
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _join() async {
    if (_codeCtrl.text.isEmpty) return;
    try {
      await SqlService.joinClass(_codeCtrl.text, widget.user.email);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("成功加入")));
      _codeCtrl.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('我的班級'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "輸入 6 位數邀請碼",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _join,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text("加入"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _classes.isEmpty
                ? const Center(child: Text("尚未加入班級"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classes.length,
                    itemBuilder: (ctx, i) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const Icon(
                          Icons.school,
                          color: kPrimaryColor,
                          size: 32,
                        ),
                        title: Text(
                          _classes[i].name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text("點擊進入聊天室"),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
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
