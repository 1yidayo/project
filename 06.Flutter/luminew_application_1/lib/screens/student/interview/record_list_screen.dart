import 'package:flutter/material.dart';
// 修正：導入 services 和 models 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';
import 'package:luminew_application_1/models/app_models.dart';

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
