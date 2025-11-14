import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:io';

// 假設 firebase_options.dart 存在於 lib/ 中

// --- 0. 資料模型 (Models) ---

enum UserRole { unauthenticated, student, teacher }

// 班級資料模型
class Class {
  final String id;
  final String name;
  final String teacherId;
  final String invitationCode;
  final List<String> studentIds;

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.invitationCode,
    this.studentIds = const [],
  });

  factory Class.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Class(
      id: doc.id,
      name: data['className'] ?? '未知班級',
      teacherId: data['teacherId'] ?? '',
      invitationCode: data['invitationCode'] ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'className': name,
      'teacherId': teacherId,
      'invitationCode': invitationCode,
      'studentIds': studentIds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// 學生資料模型
class Student {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory Student.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Student(
      id: doc.id,
      name: data['userName'] ?? '未知使用者',
      email: data['email'] ?? '',
      role: (data['role'] == 'teacher') ? UserRole.teacher : UserRole.student,
    );
  }
}

// 面試紀錄模型
class InterviewRecord {
  final String id;
  final String studentId;
  final DateTime date;
  final int durationSec;
  final int overallScore;
  final Map<String, int> scores;
  final String interviewType;
  final String? videoUrl;

  InterviewRecord({
    required this.id,
    required this.studentId,
    required this.date,
    this.durationSec = 0,
    this.overallScore = 0,
    this.scores = const {},
    this.interviewType = '通用型',
    this.videoUrl,
  });

  factory InterviewRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return InterviewRecord(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      durationSec: data['durationSec'] ?? 0,
      overallScore: data['overallScore'] ?? 0,
      scores: Map<String, int>.from(data['scores'] ?? {}),
      interviewType: data['type'] ?? '通用型',
      videoUrl: data['videoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'date': Timestamp.fromDate(date),
      'durationSec': durationSec,
      'overallScore': overallScore,
      'scores': scores,
      'type': interviewType,
      'videoUrl': videoUrl,
    };
  }
}

// 學習歷程檔案模型
class LearningPortfolio {
  final String id;
  final String fileName;
  final String fileUrl;
  final String storagePath;
  final DateTime uploadedAt;
  final String studentId;

  LearningPortfolio({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.storagePath,
    required this.uploadedAt,
    required this.studentId,
  });

  factory LearningPortfolio.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return LearningPortfolio(
      id: doc.id,
      fileName: data['fileName'] ?? '未知檔案',
      fileUrl: data['fileUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp? ?? Timestamp.now())
          .toDate(),
      studentId: data['studentId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'studentId': studentId,
    };
  }
}

// --- 1. Firebase 核心服務 (Services) ---

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final String _appId = 'Luminew';

  // --- Auth ---

  User? get currentUser => _auth.currentUser;

  Future<void> signUp(
    String email,
    String password,
    UserRole role,
    String userName,
  ) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential.user != null) {
      final userId = userCredential.user!.uid;
      final userProfileRef = _db
          .collection('artifacts/$_appId/users/$userId/profiles')
          .doc(userId);
      await userProfileRef.set({
        'email': email,
        'role': role == UserRole.student ? 'student' : 'teacher',
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserRole> getUserRole(String userId) async {
    final userProfileRef = _db
        .collection('artifacts/$_appId/users/$userId/profiles')
        .doc(userId);
    final doc = await userProfileRef.get();

    if (doc.exists && doc.data()!['role'] == 'teacher') {
      return UserRole.teacher;
    }
    return UserRole.student;
  }

  Future<String> getUserName(String userId) async {
    try {
      final userProfileRef = _db
          .collection('artifacts/$_appId/users/$userId/profiles')
          .doc(userId);
      final doc = await userProfileRef.get();
      if (doc.exists) {
        return doc.data()!['userName'] ?? '使用者';
      }
      return '使用者';
    } catch (e) {
      return '使用者';
    }
  }

  // --- 班級 (Classes) ---

  Future<Class> createClass(String className, String teacherId) async {
    final classRef = _db
        .collection('artifacts/$_appId/public/data/classes')
        .doc();
    final newClass = Class(
      id: classRef.id,
      name: className,
      teacherId: teacherId,
      invitationCode: (DateTime.now().millisecondsSinceEpoch % 1000000)
          .toString()
          .padLeft(6, '0'),
      studentIds: [],
    );

    await classRef.set(newClass.toFirestore());
    return newClass;
  }

  Future<Class> joinClass(String code, String studentId) async {
    final classQuery = await _db
        .collection('artifacts/$_appId/public/data/classes')
        .where('invitationCode', isEqualTo: code)
        .limit(1)
        .get();

    if (classQuery.docs.isEmpty) {
      throw Exception('無效的邀請碼');
    }

    final classDoc = classQuery.docs.first;
    final classRef = classDoc.reference;

    await _db.runTransaction((transaction) async {
      transaction.update(classRef, {
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
    });

    return Class.fromFirestore(
      classDoc as DocumentSnapshot<Map<String, dynamic>>,
    );
  }

  Stream<List<Class>> getTeacherClasses(String teacherId) {
    return _db
        .collection('artifacts/$_appId/public/data/classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Class.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Class>> getStudentClasses(String studentId) {
    return _db
        .collection('artifacts/$_appId/public/data/classes')
        .where('studentIds', arrayContains: studentId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Class.fromFirestore(doc)).toList(),
        );
  }

  Future<List<Student>> getClassStudents(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];

    final List<Student> students = [];
    for (String id in studentIds) {
      try {
        final userProfileRef = _db
            .collection('artifacts/$_appId/users/$id/profiles')
            .doc(id);
        final doc = await userProfileRef.get();
        if (doc.exists) {
          students.add(Student.fromFirestore(doc));
        }
      } catch (e) {
        // Handle error
      }
    }
    return students;
  }

  // --- 面試紀錄 (Interviews) ---

  Future<void> addInterviewRecord(InterviewRecord record) async {
    await _db
        .collection('artifacts/$_appId/public/data/interviews')
        .add(record.toFirestore());
  }

  Stream<List<InterviewRecord>> getStudentInterviewRecords(String studentId) {
    return _db
        .collection('artifacts/$_appId/public/data/interviews')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InterviewRecord.fromFirestore(doc))
              .toList(),
        );
  }

  // --- 學習歷程檔案 (Portfolios) ---

  Future<LearningPortfolio> addPortfolio(
    PlatformFile file,
    String studentId,
  ) async {
    final filePath =
        'artifacts/$_appId/users/$studentId/portfolios/${file.name}';
    final storageRef = _storage.ref(filePath);

    UploadTask uploadTask;
    if (file.bytes != null) {
      uploadTask = storageRef.putData(file.bytes!);
    } else {
      uploadTask = storageRef.putFile(File(file.path!));
    }

    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();

    final docRef = _db
        .collection('artifacts/$_appId/users/$studentId/portfolios')
        .doc();
    final newPortfolio = LearningPortfolio(
      id: docRef.id,
      fileName: file.name,
      fileUrl: fileUrl,
      storagePath: filePath,
      uploadedAt: DateTime.now(),
      studentId: studentId,
    );

    await docRef.set(newPortfolio.toFirestore());
    return newPortfolio;
  }

  Stream<List<LearningPortfolio>> getPortfolios(String studentId) {
    return _db
        .collection('artifacts/$_appId/users/$studentId/portfolios')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LearningPortfolio.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> deletePortfolio(LearningPortfolio portfolio) async {
    await _storage.ref(portfolio.storagePath).delete();

    await _db
        .collection('artifacts/$_appId/users/${portfolio.studentId}/portfolios')
        .doc(portfolio.id)
        .delete();
  }

  // --- 聊天室 (Chats) ---

  Stream<List<Map<String, dynamic>>> getChatStream(String chatKey) {
    return _db
        .collection('artifacts/$_appId/public/data/chats/$chatKey/messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  Future<void> sendChatMessage(
    String message,
    String userId,
    String chatKey,
    String userName,
  ) async {
    if (message.trim().isEmpty) return;

    await _db
        .collection('artifacts/$_appId/public/data/chats/$chatKey/messages')
        .add({
          'senderId': userId,
          'senderName': userName,
          'content': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
}

final firebaseService = FirebaseService();

// --- 2. 身份驗證頁面 (AuthScreen) ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  UserRole _selectedRole = UserRole.student;
  bool _isLoggingIn = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final userName = _userNameController.text.trim();

    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception("電子郵件和密碼不能為空");
      }

      if (_isLoggingIn) {
        await firebaseService.signIn(email, password);
      } else {
        if (userName.isEmpty) {
          throw Exception("使用者名稱不能為空");
        }
        await firebaseService.signUp(email, password, _selectedRole, userName);
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        msg = '無效的電子郵件或密碼';
      } else if (e.code == 'email-already-in-use') {
        msg = '此電子郵件已被註冊';
      } else if (e.code == 'weak-password') {
        msg = '密碼強度不足 (至少6位)';
      } else {
        msg = '驗證失敗: ${e.message}';
      }

      setState(() {
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '發生未知錯誤: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

              if (!_isLoggingIn)
                Column(
                  children: [
                    TextField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: '使用者名稱 (必填)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
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
                  labelText: _isLoggingIn ? '密碼' : '設定密碼 (至少6位)',
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

// --- 3. 學生端主架構 (StudentMainScaffold) ---

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

// --- 4. 教師端主架構 (TeacherMainScaffold) ---

class TeacherMainScaffold extends StatefulWidget {
  final String userId;

  const TeacherMainScaffold({super.key, required this.userId});

  @override
  State<TeacherMainScaffold> createState() => _TeacherMainScaffoldState();
}

class _TeacherMainScaffoldState extends State<TeacherMainScaffold> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    TeacherClassScreen(userId: widget.userId), // 班級管理
    TeacherCommunicationScreen(userId: widget.userId), // 互動交流
    const PlaceholderScreen(title: '教師：面試邀請'), // 面試邀請
    const PlaceholderScreen(title: '教師：評語請求'), // 評語請求
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
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: '班級管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: '互動交流',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            activeIcon: Icon(Icons.mail),
            label: '面試邀請',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rate_review_outlined),
            activeIcon: Icon(Icons.rate_review),
            label: '評語請求',
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

// --- 5. 共用頁面 (Common Screens) ---

// 設定頁面
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
              await firebaseService.signOut();
            },
          ),
        ],
      ),
    );
  }
}

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

// 教師互動交流頁 (TeacherCommunicationScreen)
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
            ClassChatRoom(chatKey: 'public', userId: userId),
            _buildClassChatList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildClassChatList(BuildContext context) {
    return StreamBuilder<List<Class>>(
      stream: firebaseService.getTeacherClasses(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('您尚未創建任何班級。'));
        }

        final classes = snapshot.data!;

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

// 聊天室 (ClassChatRoom)
class ClassChatRoom extends StatefulWidget {
  final String chatKey;
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
  String _userName = '使用者';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await firebaseService.getUserName(widget.userId);
    if (mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

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

    firebaseService.sendChatMessage(
      _messageController.text,
      widget.userId,
      widget.chatKey,
      _userName,
    );

    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  bool _isCurrentUser(String senderId) {
    return senderId == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.chatKey != 'public'
          ? AppBar(title: Text(widget.title))
          : null,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: firebaseService.getChatStream(widget.chatKey),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("尚無訊息"));
                }

                final messages = snapshot.data!;
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
                        hintText: "以 $_userName 身份輸入訊息...",
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

  Widget _buildChatMessageBubble(Map<String, dynamic> message) {
    final senderId = message['senderId'] ?? '';
    final senderName = message['senderName'] ?? '未知';
    final messageContent = message['content'] ?? '';
    final isMyMessage = _isCurrentUser(senderId);

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
                senderName,
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

// --- 6. 學生端頁面 (Student Screens) ---

// 學生班級頁 (ClassScreen)
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
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final joinedClass = await firebaseService.joinClass(code, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功加入班級: ${joinedClass.name}')));
      }
      _joinCodeController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加入失敗: ${e.toString().split(':').last.trim()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的班級'),
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
          ClassChatRoom(chatKey: 'public', userId: widget.userId),
        ],
      ),
    );
  }

  Widget _buildClassListTab() {
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '請輸入教師提供的邀請碼',
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
                                backgroundColor: Theme.of(context).primaryColor,
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
          StreamBuilder<List<Class>>(
            stream: firebaseService.getStudentClasses(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('您尚未加入任何班級。'));
              }

              final classes = snapshot.data!;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final cls = classes[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.school, color: Colors.green),
                      title: Text(cls.name),
                      subtitle: Text('教師ID: ${cls.teacherId}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ClassChatRoom(
                              chatKey: cls.id,
                              userId: widget.userId,
                              title: '${cls.name} 聊天室',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// 學生資料填寫頁 (DataEntryScreen)
class DataEntryScreen extends StatefulWidget {
  final String userId;
  const DataEntryScreen({super.key, required this.userId});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  String? _uploadError;

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

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        final file = result.files.single;

        await firebaseService.addPortfolio(file, widget.userId);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('成功上傳檔案: ${file.name}')));
        }
      }
    } catch (e) {
      setState(() {
        _uploadError = '上傳失敗: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteFile(LearningPortfolio portfolio) async {
    try {
      await firebaseService.deletePortfolio(portfolio);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已刪除檔案: ${portfolio.fileName}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗: ${e.toString()}')));
      }
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
            Tab(text: '基本資料 (模擬)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPortfolioTab(), _buildBasicDataTab()],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _isUploading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('上傳學習歷程檔案 (PDF/DOCX)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
          if (_uploadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _uploadError!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            '已上傳檔案列表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(child: _buildPortfolioList()),
        ],
      ),
    );
  }

  Widget _buildPortfolioList() {
    return StreamBuilder<List<LearningPortfolio>>(
      stream: firebaseService.getPortfolios(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('尚未上傳任何檔案。'));
        }

        final portfolios = snapshot.data!;

        return ListView.builder(
          itemCount: portfolios.length,
          itemBuilder: (context, index) {
            final portfolio = portfolios[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(
                  portfolio.fileName,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '上傳於: ${portfolio.uploadedAt.toLocal().toString().substring(0, 16)}',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('確認刪除'),
                        content: Text(
                          '您確定要刪除 ${portfolio.fileName} 嗎？此操作無法復原。',
                        ),
                        actions: [
                          TextButton(
                            child: const Text('取消'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          TextButton(
                            child: const Text(
                              '刪除',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _deleteFile(portfolio);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBasicDataTab() {
    return const Center(
      child: Text('【基本資料頁】\n學經歷、競賽經歷、自傳、申請方向等。', textAlign: TextAlign.center),
    );
  }
}

// 面試流程頁 (Interview Screens)
class InterviewHomePage extends StatelessWidget {
  final String userId;
  const InterviewHomePage({super.key, required this.userId});

  Future<String> _getUserName() async {
    return await firebaseService.getUserName(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主頁'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: 跳轉到通知中心
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FutureBuilder<String>(
              future: _getUserName(),
              builder: (context, snapshot) {
                String userName = '使用者';
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  userName = snapshot.data!;
                }
                return Text(
                  '歡迎回來,\n$userName !',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildCard(
              context,
              title: '開始模擬面試',
              icon: Icons.mic_external_on,
              subtitle: '設定場景，即時獲得 AI 分析回饋',
              color: Colors.red.shade600,
              isPrimary: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        MockInterviewSetupScreen(userId: userId),
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
              color: Theme.of(context).primaryColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        InterviewRecordListScreen(userId: userId),
                  ),
                );
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
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isPrimary ? color : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 16.0,
        ),
        leading: Icon(icon, color: isPrimary ? Colors.white : color, size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isPrimary ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isPrimary ? Colors.white70 : Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isPrimary ? Colors.white : Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

// 模擬面試場景設定 (MockInterviewSetupScreen)
class MockInterviewSetupScreen extends StatefulWidget {
  final String userId;
  const MockInterviewSetupScreen({super.key, required this.userId});

  @override
  State<MockInterviewSetupScreen> createState() =>
      _MockInterviewSetupScreenState();
}

class _MockInterviewSetupScreenState extends State<MockInterviewSetupScreen> {
  String _selectedType = '通用型';
  String _selectedLanguage = '中文';
  bool _saveVideo = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模擬面試場景設定')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: '問題類型'),
              items: ['通用型', '科系專業', '學經歷']
                  .map(
                    (label) =>
                        DropdownMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(labelText: '面試語言'),
              items: ['中文', '英文']
                  .map(
                    (label) =>
                        DropdownMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedLanguage = value);
              },
            ),
            SwitchListTile(
              title: const Text('儲存錄影'),
              value: _saveVideo,
              onChanged: (value) {
                setState(() => _saveVideo = value);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MockInterviewScreen(
                      userId: widget.userId,
                      interviewType: _selectedType,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('開始面試'),
            ),
          ],
        ),
      ),
    );
  }
}

// 模擬面試進行中 (MockInterviewScreen)
class MockInterviewScreen extends StatefulWidget {
  final String userId;
  final String interviewType;
  const MockInterviewScreen({
    super.key,
    required this.userId,
    required this.interviewType,
  });

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  void _onDone() {
    _timer?.cancel();
    final record = InterviewRecord(
      id: '',
      studentId: widget.userId,
      date: DateTime.now(),
      durationSec: _seconds,
      overallScore: 79,
      scores: {
        'emotion': 80,
        'completeness': 75,
        'fluency': 85,
        'confidence': 70,
        'logic': 82,
      },
      interviewType: widget.interviewType,
    );

    firebaseService
        .addInterviewRecord(record)
        .then((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => InterviewResultScreen(record: record),
            ),
          );
        })
        .catchError((e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('儲存紀錄失敗: $e')));
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('面試進行中... (${_formatDuration(_seconds)})'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red),
                SizedBox(width: 8),
                Text('正在紀錄', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: Text(
                  'AI 面試官畫面 (模擬)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade400,
              child: const Center(child: Text('學生畫面 (模擬)')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('提前結束'),
            ),
          ),
        ],
      ),
    );
  }
}

// 面試結束頁面 (InterviewResultScreen)
class InterviewResultScreen extends StatelessWidget {
  final InterviewRecord record;
  const InterviewResultScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試結果')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.indigo.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    '總分',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  Text(
                    record.overallScore.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '(滿分 100)',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI 評分雷達分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 5,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'AI 評分雷達圖 (視覺化待實作)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI 評語',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Card(
              child: ListTile(
                title: Text('情緒表現'),
                subtitle: Text('情緒穩定，但可適時增加微笑與自信。'),
              ),
            ),
            const Card(
              child: ListTile(
                title: Text('回答完整性'),
                subtitle: Text('回答結構完整，但第二題的細節可以再補充。'),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: 做筆記
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('做筆記'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('回主頁'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
}

// 面試紀錄列表 (InterviewRecordListScreen)
class InterviewRecordListScreen extends StatelessWidget {
  final String userId;
  const InterviewRecordListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試紀錄列表')),
      body: StreamBuilder<List<InterviewRecord>>(
        stream: firebaseService.getStudentInterviewRecords(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('您尚未有任何面試紀錄。'));
          }

          final records = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.video_camera_back_outlined),
                  title: Text(
                    '${record.interviewType} - ${record.date.toLocal().toString().substring(0, 10)}',
                  ),
                  subtitle: Text('時長: ${record.durationSec} 秒'),
                  trailing: Text(
                    '${record.overallScore} 分',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    // TODO: 跳轉到紀錄詳情頁 (含影片播放)
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

// 教師班級管理 (TeacherClassScreen)
class TeacherClassScreen extends StatefulWidget {
  final String userId;
  const TeacherClassScreen({super.key, required this.userId});

  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  final TextEditingController _classNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  Future<void> _createClass() async {
    final className = _classNameController.text;
    if (className.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final newClass = await firebaseService.createClass(
        className,
        widget.userId,
      );
      setState(() {
        _classNameController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功創建班級: ${newClass.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('創建失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    return StreamBuilder<List<Class>>(
      stream: firebaseService.getTeacherClasses(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "您目前沒有創建任何班級 (ID: ${widget.userId})",
              textAlign: TextAlign.center,
            ),
          );
        }

        final teacherClasses = snapshot.data!;

        return ListView.builder(
          itemCount: teacherClasses.length,
          itemBuilder: (context, index) {
            final cls = teacherClasses[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text(
                  cls.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'ID: ${cls.id} | 學生人數: ${cls.studentIds.length}',
                ),
                trailing: Chip(
                  label: Text('代碼: ${cls.invitationCode}'),
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                ),
                onTap: () {
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
      },
    );
  }
}

// 教師班級詳情頁
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
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListTab() {
    return FutureBuilder<List<Student>>(
      future: firebaseService.getClassStudents(widget.classItem.studentIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("此班級尚無學生。"));
        }

        final students = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.indigo),
                title: Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('學生ID: ${student.id}'),
                trailing: Text(student.email),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('查看學生 ${student.name} 的面試紀錄')),
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
