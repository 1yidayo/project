import 'package:flutter/material.dart';
// 修正：導入 services, models 和 screens 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';
import 'package:luminew_application_1/models/app_models.dart';
import 'package:luminew_application_1/screens/common/class_chat_room.dart';

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
            // 公共交流區
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
