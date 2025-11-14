import 'dart:async';
import 'package:flutter/material.dart';
// 修正：導入 services, models 和 screens 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';
import 'package:luminew_application_1/models/app_models.dart';
import 'package:luminew_application_1/screens/student/interview/record_list_screen.dart';

// --- 1. 面試主頁 (InterviewHomePage) ---
// (現在是學生端的主頁)
class InterviewHomePage extends StatelessWidget {
  final String userId;
  const InterviewHomePage({super.key, required this.userId});

  // 異步獲取使用者名稱
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
            // 歡迎橫幅
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

            // 開始模擬面試
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

            // 查看面試紀錄
            _buildCard(
              context,
              title: '查看面試紀錄',
              icon: Icons.video_library_outlined,
              subtitle: '回放、查看過往練習與評分詳情',
              color: Theme.of(context).primaryColor,
              onTap: () {
                // 修正：這裡應該是切換 Tab，而不是 Push
                // 暫時先用 Push 測試，未來應改為由 MainScaffold 控制
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

// --- 2. 模擬面試場景設定 (MockInterviewSetupScreen) ---
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

// --- 3. 模擬面試進行中 (MockInterviewScreen) ---
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

  // 格式化計時器
  String _formatDuration(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  // 結束面試
  void _onDone() {
    _timer?.cancel();
    // 模擬 AI 評分
    final record = InterviewRecord(
      id: '', // Firestore 會自動生成
      studentId: widget.userId,
      date: DateTime.now(),
      durationSec: _seconds,
      overallScore: 79, // 模擬總分
      scores: {
        'emotion': 80,
        'completeness': 75,
        'fluency': 85,
        'confidence': 70,
        'logic': 82,
      },
      interviewType: widget.interviewType,
    );

    // 將結果存入 Firebase
    firebaseService
        .addInterviewRecord(record)
        .then((_) {
          // 導航到結果頁
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => InterviewResultScreen(record: record),
            ),
          );
        })
        .catchError((e) {
          // 處理錯誤
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

// --- 4. 面試結束頁面 (InterviewResultScreen) ---
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
            // 總分
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
            // 雷達圖
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
            // AI 評語 (佔位符)
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
            // 底部按鈕
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
                      // *** 修正：回主頁 ***
                      // 清除所有路由並返回主頁 (索引 0)
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
