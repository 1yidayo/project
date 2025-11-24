import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../mock_data.dart';

class InterviewRecordListScreen extends StatelessWidget {
  final AppUser user;
  const InterviewRecordListScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    final records = mockService.getRecords(user.email);
    return Scaffold(
      appBar: AppBar(title: const Text('面試紀錄')),
      body: records.isEmpty
          ? const Center(child: Text('尚無紀錄'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (ctx, i) {
                final r = records[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.video_camera_back, color: Colors.white),
                    ),
                    title: Text('${r.type} 面試'),
                    subtitle: Text(
                      '${r.date.toString().split(' ')[0]} | ${r.overallScore}分',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InterviewResultScreen(record: r),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class MockInterviewSetupScreen extends StatelessWidget {
  final AppUser user;
  const MockInterviewSetupScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "請選擇面試類型",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: '通用型',
              items: const [
                DropdownMenuItem(value: '通用型', child: Text('通用型')),
                DropdownMenuItem(value: '專業型', child: Text('專業型')),
              ],
              onChanged: (v) {},
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockInterviewScreen(user: user),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                '開始面試',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MockInterviewScreen extends StatefulWidget {
  final AppUser user;
  const MockInterviewScreen({super.key, required this.user});
  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  int _sec = 0;
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => setState(() => _sec++),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _end() {
    _timer.cancel();
    // ✅ 修正點：補上缺少的欄位 (interviewer, language, privacy)
    final r = InterviewRecord(
      id: 'IR${DateTime.now().millisecondsSinceEpoch}',
      studentId: widget.user.email,
      date: DateTime.now(),
      durationSec: _sec,
      scores: {'overall': 80 + Random().nextInt(20)},
      type: '通用型',
      interviewer: 'AI 面試官', // 補上預設值
      language: '中文', // 補上預設值
      privacy: 'Private', // 補上預設值
    );

    mockService.addRecord(r);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => InterviewResultScreen(record: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.face, size: 100, color: Colors.white),
            Text(
              "$_sec 秒",
              style: const TextStyle(color: Colors.white, fontSize: 30),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _end,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              child: const Text(
                '結束面試',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InterviewResultScreen extends StatelessWidget {
  final InterviewRecord record;
  const InterviewResultScreen({super.key, required this.record});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試結果')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.indigo, Colors.blueAccent],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '綜合評分',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    '${record.overallScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '表現優異，繼續保持！',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('面試時長'),
              trailing: Text('${record.durationSec} 秒'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('面試類型'),
              trailing: Text(record.type),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('面試官'),
              trailing: Text(record.interviewer),
            ), // 顯示面試官
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('返回'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
