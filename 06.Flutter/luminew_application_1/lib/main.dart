import 'package:flutter/material.dart';

import 'dart:async'; // For Future/Async operations

import 'dart:math'; // For random scores

// --- 模擬數據和服務 (Mocked Services) ---

// 模擬用戶角色

enum UserRole { unauthenticated, student, teacher }

// 模擬班級資料模型 (修正：使 studentIds 可變)

class Class {
  final String id;

  final String name;

  final String teacherId;

  final String invitationCode;

  final List<String> studentIds; // 模擬班級內學生列表 (允許修改)

  Class({
    required this.id,

    required this.name,

    required this.teacherId,

    required this.invitationCode,

    this.studentIds = const [],
  });
}

// 模擬學生資料模型 (新增，用於老師查看)

class Student {
  final String id;

  final String name;

  final int latestScore;

  final String latestInterviewDate;

  Student({
    required this.id,

    required this.name,

    this.latestScore = 0,

    this.latestInterviewDate = 'N/A',
  });
}

// 模擬面試紀錄數據

class InterviewRecord {
  final String id;

  final String studentId;

  final DateTime date;

  final int durationSec;

  final Map<String, int> scores;

  final String type;

  InterviewRecord({
    required this.id,

    required this.studentId,

    required this.date,

    required this.durationSec,

    required this.scores,

    required this.type,
  });

  int get overallScore => scores['overall'] ?? 0;
}

// 模擬學習歷程檔案

class LearningPortfolio {
  final String id;

  final String title;

  final String uploadDate;

  LearningPortfolio({
    required this.id,

    required this.title,

    required this.uploadDate,
  });
}

// 模擬 Firestore 服務

class MockFirestoreService {
  // 模擬已存在的班級 (修正：確保 studentIds 可變)

  final List<Class> _classes = [
    Class(
      id: 'C1001',

      name: '高三輔導班',

      teacherId: 'T999@email.com',

      invitationCode: 'ABC1234',

      studentIds: [
        'student1@email.com',

        'student2@email.com',

        'S1001@email.com',
      ],
    ),

    Class(
      id: 'C1002',

      name: '資管APCS專班',

      teacherId: 'T888@email.com',

      invitationCode: 'XYZ9876',
    ),
  ];

  // 模擬面試紀錄 (新增)

  final List<InterviewRecord> _interviewRecords = [
    // 範例紀錄
    InterviewRecord(
      id: 'IR001',

      studentId: 'student1@email.com',

      date: DateTime(2025, 11, 10),

      durationSec: 350,

      scores: {
        'overall': 85,

        'emotion': 70,

        'completeness': 80,

        'fluency': 95,

        'confidence': 80,
      },

      type: '科系專業',
    ),
  ];

  // 模擬所有學生資料

  final List<Student> _allStudents = [
    Student(
      id: 'student1@email.com',

      name: '婉晴',

      latestScore: 88,

      latestInterviewDate: '2025/11/08',
    ),

    Student(
      id: 'student2@email.com',

      name: '雨萱',

      latestScore: 92,

      latestInterviewDate: '2025/11/10',
    ),

    Student(
      id: 'S1001@email.com', // 修正 ID 格式

      name: '逸翔',

      latestScore: 75,

      latestInterviewDate: '2025/11/09',
    ),

    Student(
      id: 'student3@email.com',

      name: '柏廷',

      latestScore: 95,

      latestInterviewDate: '2025/11/10',
    ),
  ];

  // 模擬學習歷程檔案儲存 (Key: userId)

  final Map<String, List<LearningPortfolio>> _portfolios = {
    'student1@email.com': [
      LearningPortfolio(
        id: 'LP001',

        title: 'Python 資料分析與應用成果報告',

        uploadDate: '2025/08/15',
      ),

      LearningPortfolio(
        id: 'LP002',

        title: '高中英文作文競賽得獎作品',

        uploadDate: '2025/09/01',
      ),
    ],
  };

  // 模擬聊天室訊息 (使用 Map 區分公共和班級聊天)

  final Map<String, List<String>> _chatMessages = {
    'public': [
      "系統公告：歡迎使用平台公共交流區！",

      "婉晴：請問大家，面試時語速怎麼控制比較好？",

      "柏廷：我建議準備好重點，語氣保持穩定，不要太快。",
    ],

    'C1001': [
      "T999@email.com：同學們，這週的模擬面試重點在專業題型。",

      "S1001@email.com：了解！會加強 APCS 邏輯的口語表達。",
    ],
  };

  // 模擬取得所有班級

  Future<List<Class>> getClasses() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return _classes;
  }

  // 模擬根據 ID 取得班級學生

  Future<List<Student>> getClassStudents(String classId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final targetClass = _classes.firstWhere((c) => c.id == classId);

    return _allStudents
        .where((s) => targetClass.studentIds.contains(s.id))
        .toList();
  }

  // 模擬創建新班級

  Future<Class> createClass(String name, String teacherId) async {
    final newClass = Class(
      id: 'C${_classes.length + 1001}',

      name: name,

      teacherId: teacherId,

      invitationCode: (DateTime.now().millisecondsSinceEpoch % 1000000)
          .toString()
          .padLeft(6, '0'),

      // 修正：創建時給予一個可變的 List
      studentIds: [],
    );

    _classes.add(newClass);

    await Future.delayed(const Duration(milliseconds: 500));

    return newClass;
  }

  // 模擬加入班級 (根據邀請碼)

  Future<Class?> joinClass(String code, String studentId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final targetClass = _classes.firstWhere(
      (c) => c.invitationCode == code,

      orElse: () => throw Exception('無效的邀請碼'),
    );

    // 修正：在模擬環境中，由於 Class 實例是 final 的，

    // 這裡我們直接找到列表中的對應物件，並假設 List 是可變的 (這是模擬環境的限制)

    final classToUpdate = _classes.firstWhere((c) => c.id == targetClass.id);

    if (!classToUpdate.studentIds.contains(studentId)) {
      (classToUpdate.studentIds as List<String>).add(studentId);
    }

    return targetClass;
  }

  // 模擬聊天室即時串流

  Stream<List<String>> getChatStream(String chatKey) async* {
    if (!_chatMessages.containsKey(chatKey)) {
      _chatMessages[chatKey] = ["歡迎來到 $chatKey 聊天室！"];
    }

    // 簡單模擬，實際應使用 onSnapshot 監聽

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 2));

      yield List.from(_chatMessages[chatKey]!); // 發出當前的訊息列表
    }
  }

  // 模擬發送聊天訊息

  void sendChatMessage(String message, String userId, String chatKey) {
    if (message.trim().isNotEmpty) {
      _chatMessages[chatKey]!.add("$userId：$message");
    }
  }

  // 模擬取得學習歷程檔案

  Future<List<LearningPortfolio>> getPortfolios(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return _portfolios[userId] ?? [];
  }

  // 模擬上傳新的學習歷程檔案

  Future<void> addPortfolio(String userId, String title) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final newPortfolio = LearningPortfolio(
      id: 'LP${Random().nextInt(10000)}',

      title: title,

      uploadDate:
          '${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}',
    );

    _portfolios.putIfAbsent(userId, () => []);

    _portfolios[userId]!.add(newPortfolio);
  }

  // 模擬刪除學習歷程檔案

  Future<void> deletePortfolio(String userId, String id) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _portfolios[userId]?.removeWhere((p) => p.id == id);
  }

  // 新增: 模擬儲存面試紀錄

  Future<void> addInterviewRecord(InterviewRecord record) async {
    await Future.delayed(const Duration(milliseconds: 500));

    _interviewRecords.add(record);
  }

  // 新增: 模擬取得學生的面試紀錄

  Future<List<InterviewRecord>> getStudentRecords(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return _interviewRecords.where((r) => r.studentId == studentId).toList();
  }
}

// 實例化模擬服務

final mockFirestoreService = MockFirestoreService();

// --- 應用程式入口點與狀態管理 ---

void main() {
  runApp(const LuminewApp());
}

// 導覽列項目定義

class NavigationItem {
  final String title;

  final IconData icon;

  final Widget screen;

  const NavigationItem({
    required this.title,

    required this.icon,

    required this.screen,
  });
}

// 學生端的主應用程式 (處理 Auth 狀態)

class LuminewApp extends StatefulWidget {
  const LuminewApp({super.key});

  @override
  State<LuminewApp> createState() => _LuminewAppState();
}

class _LuminewAppState extends State<LuminewApp> {
  UserRole _currentRole = UserRole.unauthenticated;

  String? _currentUserId; // 模擬 Firebase User ID

  @override
  void initState() {
    super.initState();

    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _currentRole = UserRole.unauthenticated;
    });
  }

  // 模擬登入/註冊/切換角色

  void _setAuth(UserRole role, String userId) {
    setState(() {
      _currentRole = role;

      _currentUserId = userId;
    });
  }

  void _logout() {
    setState(() {
      _currentRole = UserRole.unauthenticated;

      _currentUserId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;

    switch (_currentRole) {
      case UserRole.student:
        homeScreen = StudentMainScaffold(
          onLogout: _logout,

          userId: _currentUserId!,
        );

        break;

      case UserRole.teacher:
        homeScreen = TeacherMainScaffold(
          onLogout: _logout,

          userId: _currentUserId!,
        );

        break;

      case UserRole.unauthenticated:
      default:
        homeScreen = AuthScreen(onAuthSuccess: _setAuth);

        break;
    }

    return MaterialApp(
      title: 'Luminew 虛擬面試系統',

      theme: ThemeData(
        primarySwatch: Colors.indigo,

        useMaterial3: true,

        scaffoldBackgroundColor: const Color(0xFFF7F7F7),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,

          foregroundColor: Color(0xFF1E1E1E),

          elevation: 1,
        ),
      ),

      home: homeScreen,
    );
  }
}

// --- 1. 身份驗證頁面 (AuthScreen) ---

class AuthScreen extends StatefulWidget {
  final Function(UserRole, String) onAuthSuccess;

  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.student;

  bool _isLoggingIn = true;

  bool _isLoading = false;

  String? _errorMessage;

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;

      _errorMessage = null;
    });

    final email = _emailController.text;

    final password = _passwordController.text;

    try {
      await Future.delayed(const Duration(seconds: 1));

      if (email.isEmpty || password.isEmpty) {
        throw Exception("電子郵件和密碼不能為空");
      }

      // 模擬成功登入/註冊後，使用 email 當作簡易的 User ID

      // 修正：統一學生 ID 格式為 email 方便模擬

      String userId =
          email.toLowerCase().contains('teacher') ||
              _selectedRole == UserRole.teacher
          ? email
          : email;

      widget.onAuthSuccess(_selectedRole, userId);
    } catch (e) {
      setState(() {
        _errorMessage = _isLoggingIn
            ? "登入失敗: ${e.toString()}"
            : "註冊失敗: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLoggingIn ? '登入系統' : '註冊帳號')),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: <Widget>[
              _buildRoleSelector(),

              const SizedBox(height: 20),

              TextField(
                controller: _emailController,

                decoration: const InputDecoration(
                  // 提示：學生請使用 student1@email.com, 老師請用 T999@email.com
                  labelText: '電子郵件 (模擬ID)',

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),

                  prefixIcon: Icon(Icons.email),
                ),

                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 15),

              TextField(
                controller: _passwordController,

                decoration: InputDecoration(
                  labelText: _isLoggingIn ? '密碼' : '設定密碼',

                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),

                  prefixIcon: const Icon(Icons.lock),
                ),

                obscureText: true,
              ),

              const SizedBox(height: 30),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),

                  child: Text(
                    _errorMessage!,

                    style: TextStyle(
                      color: Colors.red.shade700,

                      fontWeight: FontWeight.bold,
                    ),

                    textAlign: TextAlign.center,
                  ),
                ),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleAuth,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,

                        padding: const EdgeInsets.symmetric(vertical: 15),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      child: Text(
                        _isLoggingIn ? '登入' : '註冊',

                        style: const TextStyle(
                          fontSize: 18,

                          color: Colors.white,
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoggingIn = !_isLoggingIn;

                    _errorMessage = null;
                  });
                },

                child: Text(_isLoggingIn ? '沒有帳號？點此註冊' : '已有帳號？點此登入'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(8),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [
          _RoleOption(
            title: '學生',

            icon: Icons.person_outline,

            isSelected: _selectedRole == UserRole.student,

            onTap: () => setState(() => _selectedRole = UserRole.student),
          ),

          _RoleOption(
            title: '教師',

            icon: Icons.school_outlined,

            isSelected: _selectedRole == UserRole.teacher,

            onTap: () => setState(() => _selectedRole = UserRole.teacher),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String title;

  final IconData icon;

  final bool isSelected;

  final VoidCallback onTap;

  const _RoleOption({
    required this.title,

    required this.icon,

    required this.isSelected,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(8),

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),

        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,

            width: isSelected ? 2 : 1,
          ),
        ),

        child: Row(
          children: [
            Icon(
              icon,

              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),

            const SizedBox(width: 8),

            Text(
              title,

              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,

                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. 教師端主架構 (TeacherMainScaffold) ---

class TeacherMainScaffold extends StatefulWidget {
  final VoidCallback onLogout;

  final String userId;

  const TeacherMainScaffold({
    super.key,

    required this.onLogout,

    required this.userId,
  });

  @override
  State<TeacherMainScaffold> createState() => _TeacherMainScaffoldState();
}

class _TeacherMainScaffoldState extends State<TeacherMainScaffold> {
  int _selectedIndex = 0;

  late final List<NavigationItem> _navigationItems = [
    NavigationItem(
      title: '班級管理',

      icon: Icons.groups_outlined,

      screen: TeacherClassScreen(userId: widget.userId),
    ),

    NavigationItem(
      title: '互動交流', // 新增：用於公共和班級聊天

      icon: Icons.chat_bubble_outline,

      screen: TeacherCommunicationScreen(userId: widget.userId),
    ),

    NavigationItem(
      title: '面試邀請',

      icon: Icons.mail_outline,

      screen: const PlaceholderScreen(title: '教師：面試邀請'),
    ),

    NavigationItem(
      title: '評語請求',

      icon: Icons.rate_review_outlined,

      screen: const PlaceholderScreen(title: '教師：評語請求'),
    ),

    NavigationItem(
      title: '設定',

      icon: Icons.settings_outlined,

      screen: SettingsScreen(onLogout: widget.onLogout),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _navigationItems[_selectedIndex].screen,

      bottomNavigationBar: BottomNavigationBar(
        items: _navigationItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon),

            label: item.title,
          );
        }).toList(),

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

// --- 2.1 教師班級管理頁 (TeacherClassScreen) ---

class TeacherClassScreen extends StatefulWidget {
  final String userId;

  const TeacherClassScreen({super.key, required this.userId});

  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  final TextEditingController _classNameController = TextEditingController();

  List<Class> _teacherClasses = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);

    final allClasses = await mockFirestoreService.getClasses();

    _teacherClasses = allClasses
        .where((c) => c.teacherId == widget.userId)
        .toList();

    setState(() => _isLoading = false);
  }

  Future<void> _createClass() async {
    final className = _classNameController.text;

    if (className.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final newClass = await mockFirestoreService.createClass(
        className,

        widget.userId,
      );

      // 模擬環境：手動將新創建的班級加入列表以更新 UI

      _teacherClasses.add(newClass);

      setState(() {
        _classNameController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '成功創建班級: ${newClass.name}，代碼：${newClass.invitationCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('創建失敗: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('班級管理 (教師端)')),

      body: Column(
        children: [
          _buildCreateClassSection(context),

          const Divider(),

          Expanded(child: _buildClassList()),
        ],
      ),
    );
  }

  Widget _buildCreateClassSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            '創建新班級',

            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _classNameController,

                  decoration: const InputDecoration(
                    labelText: '班級名稱',

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createClass,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,

                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,

                          vertical: 15,
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      child: const Text(
                        '創建',

                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teacherClasses.isEmpty) {
      return Center(
        child: Text(
          "您目前沒有創建任何班級 (ID: ${widget.userId})",

          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _teacherClasses.length,

      itemBuilder: (context, index) {
        final cls = _teacherClasses[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

          child: ListTile(
            title: Text(
              cls.name,

              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            subtitle: Text('ID: ${cls.id} | 學生人數: ${cls.studentIds.length}'),

            trailing: Chip(
              label: Text('代碼: ${cls.invitationCode}'),

              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            ),

            onTap: () {
              // 跳轉到班級詳情/學生列表

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TeacherClassDetailScreen(
                    classItem: cls,

                    teacherId: widget.userId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// --- 2.2 教師班級詳情頁 (TeacherClassDetailScreen) ---

class TeacherClassDetailScreen extends StatefulWidget {
  final Class classItem;

  final String teacherId;

  const TeacherClassDetailScreen({
    super.key,

    required this.classItem,

    required this.teacherId,
  });

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Student> _students = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    // 模擬載入學生資訊

    _students = await mockFirestoreService.getClassStudents(
      widget.classItem.id,
    );

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classItem.name),

        bottom: TabBar(
          controller: _tabController,

          tabs: const [
            Tab(text: '學生列表'),

            Tab(text: '班級聊天室'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,

        children: [
          _buildStudentListTab(),

          ClassChatRoom(
            chatKey: widget.classItem.id,

            userId: widget.teacherId,

            title: widget.classItem.name,
          ), // 班級聊天室
        ],
      ),
    );
  }

  Widget _buildStudentListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return const Center(child: Text("此班級尚無學生。"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),

      itemCount: _students.length,

      itemBuilder: (context, index) {
        final student = _students[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),

          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.indigo),

            title: Text(
              student.name,

              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            subtitle: Text('學生ID: ${student.id}'),

            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  '最新分數: ${student.latestScore}',

                  style: TextStyle(
                    color: student.latestScore >= 90
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),

                Text(
                  '面試日期: ${student.latestInterviewDate}',

                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            onTap: () {
              // 實際應用中，跳轉到該學生的詳細紀錄/評語頁面

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('查看學生 ${student.name} 的面試紀錄')),
              );
            },
          ),
        );
      },
    );
  }
}

// --- 2.3 教師互動交流頁 (TeacherCommunicationScreen) ---

class TeacherCommunicationScreen extends StatelessWidget {
  final String userId;

  const TeacherCommunicationScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,

      child: Scaffold(
        appBar: AppBar(
          title: const Text('互動交流'),

          bottom: const TabBar(
            tabs: [
              Tab(text: '公共交流區'),

              Tab(text: '我的班級聊天'),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            // 修正：ClassChatRoom 後面加上逗號
            ClassChatRoom(chatKey: 'public', userId: userId),

            // 班級聊天列表
            _buildClassChatList(context),
          ],
        ),
      ),
    );
  }

  // 老師可以看到自己班級的聊天室入口

  Widget _buildClassChatList(BuildContext context) {
    // 這裡只是模擬，實際應用中應從 Firestore 載入該教師的班級

    return FutureBuilder<List<Class>>(
      future: mockFirestoreService.getClasses(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final classes =
            snapshot.data?.where((c) => c.teacherId == userId).toList() ?? [];

        if (classes.isEmpty) {
          return const Center(child: Text('您尚未創建任何班級。'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),

          itemCount: classes.length,

          itemBuilder: (context, index) {
            final cls = classes[index];

            return Card(
              child: ListTile(
                leading: const Icon(Icons.chat),

                title: Text('${cls.name} 聊天室'),

                subtitle: Text('ID: ${cls.id}'),

                trailing: const Icon(Icons.arrow_forward_ios),

                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ClassChatRoom(
                        chatKey: cls.id,

                        userId: userId,

                        title: cls.name,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// --- 3. 學生端主架構 (StudentMainScaffold) ---

class StudentMainScaffold extends StatefulWidget {
  final VoidCallback onLogout;

  final String userId;

  const StudentMainScaffold({
    super.key,

    required this.onLogout,

    required this.userId,
  });

  @override
  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();
}

class _StudentMainScaffoldState extends State<StudentMainScaffold> {
  int _selectedIndex = 0; // 當前選中的導覽項目

  // 修正導覽列結構以包含面試紀錄 (移除了獨立的主頁卡片結構)

  late final List<NavigationItem> _navigationItems = [
    NavigationItem(
      title: '主頁', // 改回主頁

      icon: Icons.home_outlined,

      screen: InterviewHomePage(userId: widget.userId), // 引入新的主頁內容
    ),

    NavigationItem(
      title: '面試紀錄', // 獨立為一個導覽項目

      icon: Icons.mic_external_on_outlined,

      screen: InterviewRecordListScreen(userId: widget.userId),
    ),

    NavigationItem(
      title: '填寫資料',

      icon: Icons.description_outlined,

      screen: DataEntryScreen(userId: widget.userId),
    ),

    NavigationItem(
      title: '班級',

      icon: Icons.groups_outlined,

      screen: ClassScreen(userId: widget.userId),
    ),

    NavigationItem(
      title: '設定',

      icon: Icons.settings_outlined,

      screen: SettingsScreen(onLogout: widget.onLogout),
    ),
  ];

  // 由於通知中心常駐在 App Bar，這裡暫時將它合併到設置中，或作為彈出式通知處理

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _navigationItems[_selectedIndex].screen,

      bottomNavigationBar: BottomNavigationBar(
        items: _navigationItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon),

            label: item.title,
          );
        }).toList(),

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

// --- 3.1 學生班級頁 (ClassScreen) ---

class ClassScreen extends StatefulWidget {
  final String userId;

  const ClassScreen({super.key, required this.userId});

  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _joinCodeController = TextEditingController();

  bool _isJoining = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  Future<void> _joinClass() async {
    final code = _joinCodeController.text.trim();

    if (code.isEmpty) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final joinedClass = await mockFirestoreService.joinClass(
        code,

        widget.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功加入班級: ${joinedClass!.name}')));
      }

      _joinCodeController.clear();

      // 由於是模擬，這裡需要手動刷新，實際使用 StreamBuilder 監聽班級資料則不需要

      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {});
    } catch (e) {
      if (mounted) {
        // 修正錯誤訊息處理

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '加入失敗: ${e.toString().contains(':') ? e.toString().split(':')[1].trim() : e.toString()}',
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的班級'),

        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),

            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],

        bottom: TabBar(
          controller: _tabController,

          tabs: const [
            Tab(text: '班級列表'),

            Tab(text: '公共交流區'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,

        children: [
          _buildClassListTab(),

          _buildPublicChatTab(widget.userId), // 修正調用
        ],
      ),
    );
  }

  Widget _buildClassListTab() {
    return FutureBuilder<List<Class>>(
      future: mockFirestoreService.getClasses(),

      builder: (context, snapshot) {
        // 模擬從 Firestore 取得所有班級，並篩選出學生已加入的班級

        final allClasses = snapshot.data ?? [];

        final studentClasses = allClasses
            .where((c) => c.studentIds.contains(widget.userId))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              Card(
                elevation: 2,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(16.0),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        '加入新班級',

                        style: TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Text(
                        '請輸入教師提供的邀請碼 (測試碼: ABC1234, XYZ9876)',

                        style: TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _joinCodeController,

                              decoration: const InputDecoration(
                                labelText: '班級邀請碼',

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                              ),

                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),

                          const SizedBox(width: 10),

                          _isJoining
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _joinClass,

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,

                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,

                                      vertical: 15,
                                    ),

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),

                                  child: const Text(
                                    '加入',

                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                '我的班級列表',

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              if (studentClasses.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),

                    child: Text('您目前尚未加入任何班級。'),
                  ),
                )
              else
                ...studentClasses.map(
                  (cls) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.school, color: Colors.green),

                      title: Text(cls.name),

                      subtitle: Text('教師 ID: ${cls.teacherId}'),

                      trailing: const Icon(Icons.arrow_forward_ios),

                      onTap: () {
                        // 跳轉到班級聊天室

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ClassChatRoom(
                              chatKey: cls.id,

                              userId: widget.userId,

                              title: cls.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 修正：調用 ClassChatRoom 時傳遞 'public' 作為 chatKey

  Widget _buildPublicChatTab(String userId) {
    return ClassChatRoom(chatKey: 'public', userId: userId);
  }
}

// --- 3.2 公共聊天室 (PublicChatRoom) & 班級聊天室 (ClassChatRoom) ---

// 共用聊天室介面，根據 chatKey 區分公共或班級

class ClassChatRoom extends StatefulWidget {
  final String chatKey; // 'public' for public, or Class ID for class chat

  final String userId;

  final String title;

  const ClassChatRoom({
    super.key,

    required this.chatKey,

    required this.userId,

    this.title = '公共交流區',
  });

  @override
  State<ClassChatRoom> createState() => _ClassChatRoomState();
}

class _ClassChatRoomState extends State<ClassChatRoom> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,

          duration: const Duration(milliseconds: 300),

          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    mockFirestoreService.sendChatMessage(
      _messageController.text,

      widget.userId,

      widget.chatKey,
    );

    _messageController.clear();

    // 延遲滾動確保新訊息已渲染

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  // 檢查是否為當前用戶發送

  bool _isCurrentUser(String sender) {
    return sender == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 如果不是公共交流區，則需要顯示標題
      appBar: widget.chatKey != 'public'
          ? AppBar(title: Text(widget.title))
          : null,

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: mockFirestoreService.getChatStream(widget.chatKey),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("尚無訊息"));
                }

                final messages = snapshot.data!;

                // 首次載入或數據更新時滾動到底部

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,

                  padding: const EdgeInsets.all(10),

                  itemCount: messages.length,

                  itemBuilder: (context, index) {
                    final message = messages[index];

                    return _buildChatMessageBubble(message);
                  },
                );
              },
            ),
          ),

          // 輸入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

            color: Colors.white,

            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,

                      decoration: InputDecoration(
                        hintText: "以 ${widget.userId} 身份輸入訊息...",

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),

                          borderSide: BorderSide.none,
                        ),

                        filled: true,

                        fillColor: Colors.grey.shade100,

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,

                          vertical: 8,
                        ),
                      ),

                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    icon: Icon(
                      Icons.send,

                      color: Theme.of(context).primaryColor,
                    ),

                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(String fullMessage) {
    final parts = fullMessage.split('：');

    final sender = parts[0];

    final messageContent = parts.length > 1
        ? parts.sublist(1).join('：')
        : sender;

    final isMyMessage = _isCurrentUser(sender);

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),

        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),

        decoration: BoxDecoration(
          color: isMyMessage
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,

          borderRadius: BorderRadius.circular(12).copyWith(
            topLeft: isMyMessage
                ? const Radius.circular(12)
                : const Radius.circular(0),

            topRight: isMyMessage
                ? const Radius.circular(0)
                : const Radius.circular(12),
          ),
        ),

        child: Column(
          crossAxisAlignment: isMyMessage
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,

          children: [
            if (!isMyMessage)
              Text(
                sender,

                style: TextStyle(
                  fontWeight: FontWeight.bold,

                  fontSize: 10,

                  color: isMyMessage ? Colors.white70 : Colors.black54,
                ),
              ),

            Text(
              messageContent,

              style: TextStyle(
                color: isMyMessage ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 學生端：面試主頁結構 (InterviewHomePage) (修正為 App 主頁) ---

class InterviewHomePage extends StatelessWidget {
  final String userId;

  const InterviewHomePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主頁'),

        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),

            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: <Widget>[
            Text(
              '歡迎回來, ${userId}！',

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

              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MockInterviewSetupScreen(),
                  ),
                );
              },
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

              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        InterviewRecordListScreen(userId: userId),
                  ),
                );
              },
            ),

            _buildCard(
              context,

              title: '面試邀請',

              icon: Icons.mail_outline,

              subtitle: '查看及回應教師發送的模擬面試邀請',

              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const InterviewInvitationScreen(),
                  ),
                );
              },
            ),

            _buildCard(
              context,

              title: '更新學習歷程',

              icon: Icons.description_outlined,

              subtitle: '上傳資料，優化 AI 提問的精準度',

              onTap: () {
                // 跳轉到填寫資料頁

                // 這裡需要使用一個通用的導航方法，但由於是在 Scaffold 內，我們使用 Navigator.pop/push

                // 模擬點擊底部的「填寫資料」按鈕

                // 實際應用中，會直接導航到對應的 Tab/Page

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已跳轉至填寫資料頁')));
              },
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

// --- 3.3 學生端：面試場景設定 (MockInterviewSetupScreen) ---

class MockInterviewSetupScreen extends StatefulWidget {
  const MockInterviewSetupScreen({super.key});

  @override
  State<MockInterviewSetupScreen> createState() =>
      _MockInterviewSetupScreenState();
}

class _MockInterviewSetupScreenState extends State<MockInterviewSetupScreen> {
  String? _selectedType = '通用型';

  String? _selectedOfficer = 'AI 面試官';

  String? _selectedLanguage = '中文';

  bool _shouldSaveVideo = true;

  bool _saveAsDefault = false;

  final List<String> _types = ['通用型', '科系專業', '學經歷'];

  final List<String> _officers = ['AI 面試官', '模擬教授', '模擬人資'];

  final List<String> _languages = ['中文', '英文'];

  void _startInterview(String studentId) {
    // 這裡可以將設定儲存到 Firestore

    // 導航到模擬面試頁面

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MockInterviewScreen(
          interviewType: _selectedType!,

          studentId: studentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 假設我們能從最近的 StudentMainScaffold 獲取 userId

    final studentMainScaffold = context
        .findAncestorStateOfType<_StudentMainScaffoldState>();

    final studentId =
        studentMainScaffold?.widget.userId ?? 'student1@email.com';

    return Scaffold(
      appBar: AppBar(title: const Text('模擬面試場景設定')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: <Widget>[
            _buildDropdown(
              '問題類型',

              _selectedType,

              _types,

              (newValue) => setState(() => _selectedType = newValue),

              Icons.category_outlined,
            ),

            _buildDropdown(
              '面試官',

              _selectedOfficer,

              _officers,

              (newValue) => setState(() => _selectedOfficer = newValue),

              Icons.face_retouching_natural_outlined,
            ),

            _buildDropdown(
              '面試語言',

              _selectedLanguage,

              _languages,

              (newValue) => setState(() => _selectedLanguage = newValue),

              Icons.language_outlined,
            ),

            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text('儲存面試錄影'),

              value: _shouldSaveVideo,

              onChanged: (value) => setState(() => _shouldSaveVideo = value),

              secondary: Icon(
                Icons.videocam_outlined,

                color: Theme.of(context).primaryColor,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),

              tileColor: Colors.white,
            ),

            const SizedBox(height: 10),

            SwitchListTile(
              title: const Text('設為預設場景'),

              value: _saveAsDefault,

              onChanged: (value) => setState(() => _saveAsDefault = value),

              secondary: Icon(
                Icons.bookmark_outline,

                color: Theme.of(context).primaryColor,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),

              tileColor: Colors.white,
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () => _startInterview(studentId),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,

                padding: const EdgeInsets.symmetric(vertical: 18),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                '開始模擬面試',

                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,

    String? currentValue,

    List<String> items,

    Function(String?) onChanged,

    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),

      child: DropdownButtonFormField<String>(
        value: currentValue,

        decoration: InputDecoration(
          labelText: label,

          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),

          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),

          filled: true,

          fillColor: Colors.white,
        ),

        items: items.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),

        onChanged: onChanged,
      ),
    );
  }
}

// --- 3.4 學生端：模擬面試頁 (MockInterviewScreen) ---

class MockInterviewScreen extends StatefulWidget {
  final String interviewType;

  final String studentId; // 傳入學生 ID

  const MockInterviewScreen({
    super.key,

    required this.interviewType,

    required this.studentId,
  });

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  late Timer _timer;

  int _secondsElapsed = 0;

  bool _isRecording = true;

  @override
  void initState() {
    super.initState();

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _endInterview() async {
    _timer.cancel();

    final totalTime = _secondsElapsed;

    final random = Random();

    final recordId = 'IR${DateTime.now().millisecondsSinceEpoch}';

    // 模擬 AI 評分 (1-100)

    final scores = {
      'overall': 70 + random.nextInt(30),

      'emotion': 60 + random.nextInt(40),

      'completeness': 50 + random.nextInt(50),

      'fluency': 75 + random.nextInt(25),

      'confidence': 65 + random.nextInt(35),
    };

    final result = InterviewRecord(
      id: recordId,

      studentId: widget.studentId, // 儲存學生 ID

      date: DateTime.now(),

      durationSec: totalTime,

      scores: scores,

      type: widget.interviewType,
    );

    // 修正：將面試結果儲存到模擬服務中

    await mockFirestoreService.addInterviewRecord(result);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => InterviewResultScreen(record: result),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();

    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('模擬面試 (${widget.interviewType})'),

        automaticallyImplyLeading: false, // 隱藏返回按鈕

        backgroundColor: Colors.black87,

        foregroundColor: Colors.white,
      ),

      body: Stack(
        children: [
          // 模擬視訊畫面 (佔位符)
          Container(color: Colors.black),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                const Icon(Icons.videocam_off, color: Colors.white54, size: 80),

                const SizedBox(height: 10),

                const Text(
                  'AI 面試官畫面 (視訊連線模擬)',

                  style: TextStyle(color: Colors.white54),
                ),

                const SizedBox(height: 50),

                // 學生畫面 (小視窗，右下角)
                Align(
                  alignment: Alignment.bottomRight,

                  child: Container(
                    width: 120,

                    height: 160,

                    margin: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),

                      borderRadius: BorderRadius.circular(10),

                      border: Border.all(color: Colors.white, width: 2),
                    ),

                    child: const Center(
                      child: Text(
                        '我的畫面',

                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 頂部狀態欄
          Positioned(
            top: 0,

            left: 0,

            right: 0,

            child: Container(
              color: Colors.black54,

              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Chip(
                    label: Text(
                      _formatTime(_secondsElapsed),

                      style: const TextStyle(
                        color: Colors.white,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    avatar: const Icon(Icons.timer, color: Colors.white),

                    backgroundColor: Colors.red.shade700,
                  ),

                  if (_isRecording)
                    const Chip(
                      label: Text(
                        '正在紀錄',

                        style: TextStyle(color: Colors.white),
                      ),

                      avatar: Icon(
                        Icons.fiber_manual_record,

                        color: Colors.red,

                        size: 16,
                      ),

                      backgroundColor: Colors.green,
                    ),
                ],
              ),
            ),
          ),

          // 底部控制按鈕
          Positioned(
            bottom: 30,

            left: 0,

            right: 0,

            child: Center(
              child: ElevatedButton.icon(
                onPressed: _endInterview,

                icon: const Icon(Icons.stop, color: Colors.white),

                label: const Text(
                  '結束面試',

                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,

                    vertical: 12,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),

                  elevation: 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3.5 學生端：面試結束頁 (InterviewResultScreen) ---

class InterviewResultScreen extends StatelessWidget {
  final InterviewRecord record;

  const InterviewResultScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('面試結果'),

        automaticallyImplyLeading: false,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: <Widget>[
            _buildOverallScoreCard(context),

            const SizedBox(height: 16),

            _buildInfoCard(
              title: '面試詳情',

              children: [
                _buildDetailRow(
                  Icons.calendar_today,

                  '日期',

                  '${record.date.year}/${record.date.month}/${record.date.day}',
                ),

                _buildDetailRow(
                  Icons.timer,

                  '時長',

                  '${(record.durationSec ~/ 60).toString().padLeft(2, '0')}:${(record.durationSec % 60).toString().padLeft(2, '0')}',
                ),

                _buildDetailRow(Icons.school, '類型', record.type),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'AI 評分雷達分析',

              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // 雷達圖模擬
            RadarChartMock(scores: record.scores),

            const SizedBox(height: 20),

            const Text(
              'AI 評語概要',

              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildFeedbackSection(),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('正在儲存筆記...')));
                  },

                  icon: const Icon(Icons.edit, color: Colors.white),

                  label: const Text(
                    '做筆記',

                    style: TextStyle(color: Colors.white),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,

                      vertical: 10,
                    ),
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    // 導航到面試紀錄詳情，並替換當前頁面

                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) =>
                            InterviewRecordDetailScreen(record: record),
                      ),
                    );
                  },

                  icon: const Icon(Icons.history, color: Colors.white),

                  label: const Text(
                    '查看詳情',

                    style: TextStyle(color: Colors.white),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,

                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScoreCard(BuildContext context) {
    return Card(
      color: Theme.of(context).primaryColor,

      elevation: 4,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          children: [
            const Text(
              '總分',

              style: TextStyle(color: Colors.white, fontSize: 18),
            ),

            const SizedBox(height: 8),

            Text(
              '${record.overallScore}',

              style: const TextStyle(
                color: Colors.white,

                fontSize: 60,

                fontWeight: FontWeight.bold,
              ),
            ),

            const Text(
              '（滿分 100）',

              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,

    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: Padding(
        padding: const EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              title,

              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const Divider(height: 16),

            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),

      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),

          const SizedBox(width: 8),

          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black87)),
          ),

          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Card(
      elevation: 0,

      color: Colors.grey.shade100,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: const Padding(
        padding: EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              '情緒 (70)：您的語氣積極，但在回答專業問題時略顯緊張。',

              style: TextStyle(fontSize: 14),
            ),

            SizedBox(height: 8),

            Text('流暢 (90)：回答非常流利，沒有明顯的口吃或停頓。', style: TextStyle(fontSize: 14)),

            SizedBox(height: 8),

            Text(
              '回答完整 (65)：關於「未來規劃」的部分缺乏具體細節，建議補充實施步驟。',

              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 學生端：面試紀錄列表 (InterviewRecordListScreen) (更新) ---

class InterviewRecordListScreen extends StatelessWidget {
  final String userId;

  const InterviewRecordListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試紀錄')),

      body: FutureBuilder<List<InterviewRecord>>(
        future: mockFirestoreService.getStudentRecords(userId),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return const Center(
              child: Text(
                '您尚未有面試紀錄，快去開始一場模擬面試吧！',

                textAlign: TextAlign.center,

                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),

            itemCount: records.length,

            itemBuilder: (context, index) {
              final record = records[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),

                elevation: 1,

                child: ListTile(
                  leading: Icon(
                    Icons.video_camera_back,

                    color: Theme.of(context).primaryColor,
                  ),

                  title: Text('${record.type} 面試紀錄'),

                  subtitle: Text(
                    '日期: ${record.date.year}/${record.date.month.toString().padLeft(2, '0')}/${record.date.day.toString().padLeft(2, '0')} | 時長: ${(record.durationSec ~/ 60).toString().padLeft(2, '0')}:${(record.durationSec % 60).toString().padLeft(2, '0')}',
                  ),

                  trailing: Chip(
                    label: Text(
                      '${record.overallScore} 分',

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,

                        color: Colors.white,
                      ),
                    ),

                    backgroundColor: record.overallScore > 80
                        ? Colors.green
                        : Colors.orange,
                  ),

                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            InterviewRecordDetailScreen(record: record),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- 學生端：面試紀錄詳情頁 (InterviewRecordDetailScreen) (新增) ---

class InterviewRecordDetailScreen extends StatelessWidget {
  final InterviewRecord record;

  const InterviewRecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試紀錄詳情')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            // 模擬影片回放區域
            Container(
              height: 200,

              color: Colors.black,

              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,

                  color: Colors.white,

                  size: 60,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 總分和日期資訊
            _buildOverallScoreCard(context),

            const SizedBox(height: 16),

            // AI 評分雷達分析
            const Text(
              'AI 評分雷達分析',

              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            RadarChartMock(scores: record.scores),

            const SizedBox(height: 20),

            // 各項評語欄位 (重複使用 ResultScreen 的 Feedback 結構)
            const Text(
              'AI 評語概要',

              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildFeedbackSection(),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('做筆記功能待實作...')),
                    );
                  },

                  icon: const Icon(Icons.edit, color: Colors.white),

                  label: const Text(
                    '做筆記',

                    style: TextStyle(color: Colors.white),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,

                      vertical: 10,
                    ),
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    // 模擬刪除功能，需要二次確認

                    _showDeleteConfirmation(context, record.id);
                  },

                  icon: const Icon(Icons.delete_outline, color: Colors.white),

                  label: const Text(
                    '刪除紀錄',

                    style: TextStyle(color: Colors.white),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,

                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScoreCard(BuildContext context) {
    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.9),

      elevation: 4,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  '總分',

                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),

                const SizedBox(height: 4),

                Text(
                  '${record.overallScore}',

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 48,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(
                  '類型: ${record.type}',

                  style: const TextStyle(color: Colors.white70),
                ),

                Text(
                  '時長: ${(record.durationSec ~/ 60).toString().padLeft(2, '0')}:${(record.durationSec % 60).toString().padLeft(2, '0')}',

                  style: const TextStyle(color: Colors.white70),
                ),

                Text(
                  'ID: ${record.id}',

                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Card(
      elevation: 0,

      color: Colors.grey.shade100,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: const Padding(
        padding: EdgeInsets.all(16.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              '情緒 (70)：您的語氣積極，但在回答專業問題時略顯緊張。',

              style: TextStyle(fontSize: 14),
            ),

            SizedBox(height: 8),

            Text('流暢 (90)：回答非常流利，沒有明顯的口吃或停頓。', style: TextStyle(fontSize: 14)),

            SizedBox(height: 8),

            Text(
              '回答完整 (65)：關於「未來規劃」的部分缺乏具體細節，建議補充實施步驟。',

              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String recordId) {
    showDialog(
      context: context,

      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除確認'),

          content: const Text('您確定要永久刪除此面試紀錄嗎？此操作無法撤銷。'),

          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),

              child: const Text('取消'),
            ),

            ElevatedButton(
              onPressed: () {
                // 模擬刪除操作

                // 由於沒有 mockDeleteRecord 方法，這裡只做提示

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('已刪除紀錄 ID: $recordId')));

                Navigator.of(context).pop(); // 關閉對話框

                Navigator.of(context).pop(); // 返回上一頁 (紀錄列表)
              },

              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

              child: const Text('確定刪除', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// 模擬雷達圖組件 (Custom Widget to represent the concept)

class RadarChartMock extends StatelessWidget {
  final Map<String, int> scores;

  const RadarChartMock({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final radarScores = [
      scores['emotion'] ?? 0,

      scores['completeness'] ?? 0,

      scores['fluency'] ?? 0,

      scores['confidence'] ?? 0,

      scores['overall'] ?? 0, // 為了填滿 5 個點
    ];

    final labels = ['情緒', '完整性', '流暢度', '自信心', '總分'];

    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),

        height: 250,

        width: 300,

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(12),

          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,

              blurRadius: 5,

              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: CustomPaint(
          painter: _RadarChartPainter(radarScores, labels),

          child: Container(),
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<int> scores;

  final List<String> labels;

  _RadarChartPainter(this.scores, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final radius = size.width / 2;

    final numberOfPoints = scores.length;

    const maxScore = 100.0;

    // 繪製背景網格

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 繪製同心圓

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, gridPaint);
    }

    // 繪製中心點到邊緣的軸線和標籤

    for (int i = 0; i < numberOfPoints; i++) {
      final angle = 2 * pi * i / numberOfPoints - pi / 2;

      final x = center.dx + radius * cos(angle);

      final y = center.dy + radius * sin(angle);

      canvas.drawLine(center, Offset(x, y), gridPaint);

      // 繪製標籤

      final textSpan = TextSpan(
        text: labels[i],

        style: TextStyle(
          color: Colors.black87,

          fontSize: 10,

          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,

        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // 調整標籤位置，使其在軸線外側

      final labelOffset = Offset(
        center.dx + (radius + 10) * cos(angle) - textPainter.width / 2,

        center.dy + (radius + 10) * sin(angle) - textPainter.height / 2,
      );

      canvas.translate(labelOffset.dx, labelOffset.dy);

      textPainter.paint(canvas, Offset.zero);

      canvas.translate(-labelOffset.dx, -labelOffset.dy);
    }

    // 繪製分數點和區域

    final dataPaint = Paint()
      ..color = Colors.indigo.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();

    List<Offset> points = [];

    for (int i = 0; i < numberOfPoints; i++) {
      final angle = 2 * pi * i / numberOfPoints - pi / 2;

      final scoreRatio = scores[i] / maxScore;

      final scoreRadius = radius * scoreRatio;

      final x = center.dx + scoreRadius * cos(angle);

      final y = center.dy + scoreRadius * sin(angle);

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();

    // 填充區域

    canvas.drawPath(path, dataPaint);

    // 繪製邊框

    canvas.drawPath(path, borderPaint);

    // 繪製分數點

    final dotPaint = Paint()..color = Colors.white;

    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);

      canvas.drawCircle(point, 3, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// --- 4. 共用及其他頁面 ---

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

// 設置頁面 (加入登出功能)

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;

  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),

      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.person_outline),

            title: const Text('使用者資訊'),

            subtitle: const Text('頭貼、名稱、ID、身份 (Free Student)'),

            trailing: const Icon(Icons.edit),

            onTap: () {
              /* 跳轉至使用者資訊頁 */
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.payment_outlined),

            title: const Text('訂閱方案'),

            subtitle: const Text('查看 Free/Pro 方案功能差異'),

            trailing: const Icon(Icons.arrow_forward_ios),

            onTap: () {
              /* 跳轉至訂閱方案頁 */
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),

            title: const Text(
              '登出',

              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),

            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

// --- 學生端：資料填寫頁 (DataEntryScreen) ---

class DataEntryScreen extends StatefulWidget {
  final String userId;

  const DataEntryScreen({super.key, required this.userId});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<LearningPortfolio> _portfolios = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _loadPortfolios();
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  Future<void> _loadPortfolios() async {
    setState(() => _isLoading = true);

    _portfolios = await mockFirestoreService.getPortfolios(widget.userId);

    setState(() => _isLoading = false);
  }

  // 模擬檔案選擇並上傳

  Future<void> _mockFileUpload() async {
    final mockFileName =
        '學習歷程檔案 ${DateTime.now().second} - ${DateTime.now().millisecond}';

    // 實際應用中會調用 file_picker 並上傳到 Firebase Storage

    // 這裡我們直接模擬新增到列表中

    await mockFirestoreService.addPortfolio(widget.userId, mockFileName);

    // 重新載入列表

    _loadPortfolios();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功上傳並分析檔案：「${mockFileName.substring(0, 10)}...」'),
        ),
      );
    }
  }

  // 刪除檔案

  Future<void> _deletePortfolio(String id) async {
    await mockFirestoreService.deletePortfolio(widget.userId, id);

    _loadPortfolios();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('檔案已移除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資料與履歷填寫'),

        bottom: TabBar(
          controller: _tabController,

          tabs: const [
            Tab(text: '學習歷程檔案'),

            Tab(text: '基本資料與自傳'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,

        children: [
          _buildPortfolioUploadTab(context),

          const PlaceholderScreen(title: '基本資料與自傳填寫區'),
        ],
      ),
    );
  }

  Widget _buildPortfolioUploadTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const Text(
                'AI 分析資料上傳',

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                '上傳您的學習歷程檔案（例如：專題報告、多元表現），AI 將分析內容以生成更精準的模擬面試問題。',

                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _mockFileUpload,

                icon: const Icon(Icons.cloud_upload),

                label: const Text('選擇並上傳檔案 (PDF/DOCX)'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 12),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        Expanded(child: _buildPortfolioList()),
      ],
    );
  }

  Widget _buildPortfolioList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_portfolios.isEmpty) {
      return Center(
        child: Text(
          '尚未上傳任何學習歷程檔案。\n請點擊上方按鈕開始上傳。',

          textAlign: TextAlign.center,

          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),

      itemCount: _portfolios.length,

      itemBuilder: (context, index) {
        final item = _portfolios[index];

        return Card(
          elevation: 1,

          margin: const EdgeInsets.only(bottom: 8),

          child: ListTile(
            leading: const Icon(Icons.insert_drive_file, color: Colors.green),

            title: Text(item.title),

            subtitle: Text('上傳日期: ${item.uploadDate}'),

            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),

              onPressed: () => _deletePortfolio(item.id),
            ),

            onTap: () {
              // 實際應用中，可以跳轉到檔案預覽或詳情頁

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('模擬分析檔案 ${item.title}')));
            },
          ),
        );
      },
    );
  }
}

// --- 學生端原有頁面 Placeholder ---

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知中心')),

      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),

          child: Text(
            '【通知中心頁】\n顯示老師邀約面試、互動交流訊息、班級公告等通知列表。',

            textAlign: TextAlign.center,

            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class InterviewInvitationScreen extends StatelessWidget {
  const InterviewInvitationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: '面試邀請列表');
  }
}
