import 'package:flutter/material.dart';
// 修正：導入 services, models 和 screens 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';
import 'package:luminew_application_1/models/app_models.dart';
import 'package:luminew_application_1/screens/common/class_chat_room.dart';

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
          // 加入班級區塊
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
          // 班級列表
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
                shrinkWrap: true, // 讓 ListView 在 Column 中正常顯示
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
                        // 跳轉到班級聊天室
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
