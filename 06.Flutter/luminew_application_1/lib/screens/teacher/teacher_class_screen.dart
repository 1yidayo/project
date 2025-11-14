import 'package:flutter/material.dart';
// 修正：導入 services, models 和 screens 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';
import 'package:luminew_application_1/models/app_models.dart';
import 'package:luminew_application_1/screens/common/class_chat_room.dart';

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

// --- 教師班級詳情頁 ---
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
          ), // 班級聊天室
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
                  // 實際應用中，跳轉到該學生的詳細紀錄/評語頁面
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
