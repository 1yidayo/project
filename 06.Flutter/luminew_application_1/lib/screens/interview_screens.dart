// fileName: lib/screens/interview_screens.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // 確保 pubspec.yaml 有 camera
import 'package:http/http.dart' as http; // 確保 pubspec.yaml 有 http
import '../models.dart';
import '../mock_data.dart';
import '../sql_service.dart'; // 必須引用，用於存檔與讀取留言
import 'package:fl_chart/fl_chart.dart';

// 全域變數：用來儲存可用的相機列表
List<CameraDescription> cameras = [];

// ==========================================
// 1. 面試紀錄列表 (讀取 SQL 資料)
// ==========================================
class InterviewRecordListScreen extends StatefulWidget {
  final AppUser user;
  const InterviewRecordListScreen({super.key, required this.user});

  @override
  State<InterviewRecordListScreen> createState() =>
      _InterviewRecordListScreenState();
}

class _InterviewRecordListScreenState extends State<InterviewRecordListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試紀錄')),
      body: FutureBuilder<List<InterviewRecord>>(
        // 從 SQL 資料庫讀取資料
        future: SqlService.getRecords(widget.user.id, 'All'),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 容錯：如果 SQL 沒資料或出錯，回退顯示 Mock 資料 (避免畫面全白)
          final records = (snapshot.data == null || snapshot.data!.isEmpty)
              ? mockService.getRecords(widget.user.email)
              : snapshot.data!;

          if (records.isEmpty) {
            return const Center(child: Text('尚無紀錄'));
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (ctx, i) {
              final r = records[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text(
                      "${r.overallScore}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  title: Text('${r.type} (${r.language})'),
                  subtitle: Text(
                    '${r.date.toString().split(' ')[0]} | ${r.interviewer}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      // 點擊後進入詳細結果頁 (包含留言功能)
                      builder: (_) =>
                          InterviewResultScreen(record: r, user: widget.user,aiComment: r.aiComment,
                        aiSuggestion: r.aiSuggestion),
                    ),
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
// 2. 面試設定頁 (完整下拉選單)
// ==========================================
class MockInterviewSetupScreen extends StatefulWidget {
  final AppUser user;
  const MockInterviewSetupScreen({super.key, required this.user});

  @override
  State<MockInterviewSetupScreen> createState() =>
      _MockInterviewSetupScreenState();
}

class _MockInterviewSetupScreenState extends State<MockInterviewSetupScreen> {
  // 儲存使用者的選擇
  String _type = '通用型';
  String _interviewer = '保羅';
  String _lang = '中文';
  bool _saveVideo = true;

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
              "請選擇面試偏好",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 1. 面試類型
            _buildDropdown('面試類型', [
              '通用型',
              '科系專業',
              '學經歷',
            ], (v) => setState(() => _type = v!)),

            // 2. 面試官
            _buildDropdown('面試官', [
              '保羅',
              '林湘霖',
              '藍易振',
              'AI 面試官',
            ], (v) => setState(() => _interviewer = v!)),

            // 3. 語言
            _buildDropdown('語言', [
              '中文',
              '英文',
            ], (v) => setState(() => _lang = v!)),

            // 4. 儲存設定
            SwitchListTile(
              title: const Text('儲存錄影'),
              value: _saveVideo,
              onChanged: (v) => setState(() => _saveVideo = v),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                // 將選好的參數傳遞給錄影頁面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MockInterviewScreen(
                      user: widget.user,
                      type: _type,
                      interviewer: _interviewer,
                      language: _lang,
                      saveVideo: _saveVideo,
                    ),
                  ),
                );
              },
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

  // 下拉選單 UI 封裝
  Widget _buildDropdown(
    String label,
    List<String> items,
    Function(String?) onChange,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField(
        initialValue: items[0],
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChange,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// ==========================================
// 3. 面試錄影頁 (相機 + AI連線 + SQL儲存)
// ==========================================
class MockInterviewScreen extends StatefulWidget {
  final AppUser user;
  final String type;
  final String interviewer;
  final String language;
  final bool saveVideo;

  const MockInterviewScreen({
    super.key,
    required this.user,
    required this.type,
    required this.interviewer,
    required this.language,
    required this.saveVideo,
  });

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isUploading = false;
  int _sec = 0;
  Timer? _timer;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }

      if (cameras.isNotEmpty) {
        // 優先使用前鏡頭
        final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _controller = CameraController(frontCam, ResolutionPreset.low);
        await _controller!.initialize();
        if (mounted) setState(() {});
      } else {
        setState(() => _statusMessage = "找不到相機鏡頭，請檢查設備。");
      }
    } catch (e) {
      print("相機初始化失敗: $e");
      setState(() => _statusMessage = "相機開啟失敗: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _sec = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _sec++);
      });
    } catch (e) {
      print("開始錄影失敗: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("錄影啟動失敗: $e")));
    }
  }

  Future<void> _stopAndAnalyze() async {
    if (!_isRecording) return;

    // 停止計時與錄影
    _timer?.cancel();
    XFile file;
    try {
      file = await _controller!.stopVideoRecording();
    } catch (e) {
      print("停止錄影失敗: $e");
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });
    }

    try {
      // ★★★ IP 設定：請確認這裡改成您電腦的 IP ★★★
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/analyze'),
      );

      request.files.add(await http.MultipartFile.fromPath('video', file.path));

      print("正在上傳影片...");
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 300),
        onTimeout: () {
          throw Exception("連線逾時，請檢查 Python Server 是否開啟");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final emotions = data['emotions'];
        final ai = data['ai_analysis'];
        final timelineList = data['timeline'] ?? [];

        // 建立紀錄物件
        final r = InterviewRecord(
          id: 'IR${DateTime.now().millisecondsSinceEpoch}',
          studentId: widget.user.email,
          date: DateTime.now(),
          durationSec: _sec,
          scores: {
            'overall': ai['overall_score'] ?? 0,
            'confidence': emotions['confidence'] ?? 0,
            'passion': emotions['passion'] ?? 0,
            'nervous': emotions['nervous'] ?? 0,
            'relaxed': emotions['relaxed'] ?? 0,
          },
          type: widget.type,
          interviewer: widget.interviewer,
          language: widget.language,
          privacy: 'Private',
          aiComment: ai['comment'] ?? '',
          aiSuggestion: ai['suggestion'] ?? '',
          timelineData: jsonEncode(timelineList)
        );

        // 1. 存入 Mock (即時顯示用)
        mockService.addRecord(r);

        // 2. ★存入 SQL 資料庫★
        try {
          await SqlService.saveRecord(r);
          print("✅ 資料庫儲存成功！");
        } catch (dbError) {
          print("❌ 資料庫儲存失敗: $dbError");
        }

        if (mounted) {
          // 跳轉到結果頁，並使用 popUntil 讓它可以回到首頁
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => InterviewResultScreen(
                record: r,
                user: widget.user,
                aiComment: ai['comment'],
                aiSuggestion: ai['suggestion'],
              ),
            ),
          );
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print("錯誤: $e");
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("分析失敗"),
            content: Text(
              "錯誤訊息：$e\n\n請確認：\n1. Python Server 有開嗎？\n2. IP 位址改對了嗎？",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("確定"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 相機預覽
          SizedBox.expand(child: CameraPreview(_controller!)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "面試官: ${widget.interviewer}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${(_sec ~/ 60).toString().padLeft(2, '0')}:${(_sec % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 10),
                        Text(
                          "AI 正在分析您的表情...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isRecording
                              ? _stopAndAnalyze
                              : _startRecording,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.transparent,
                            ),
                            child: _isRecording
                                ? const Icon(
                                    Icons.stop,
                                    color: Colors.white,
                                    size: 40,
                                  )
                                : const Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 超級整合結果頁 (AI分析 + 留言板 + 詳細設定)
// ==========================================
class InterviewResultScreen extends StatefulWidget {
  final InterviewRecord record;
  final AppUser user;
  final String? aiComment;
  final String? aiSuggestion;

  const InterviewResultScreen({
    super.key,
    required this.record,
    required this.user,
    this.aiComment,
    this.aiSuggestion,
  });

  @override
  State<InterviewResultScreen> createState() => _InterviewResultScreenState();
}

class _InterviewResultScreenState extends State<InterviewResultScreen> {
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];

  bool _isIndexMode = false;

  // ★★★ 新增這個函式：用來判斷分數顏色 ★★★
  List<Color> _getScoreGradient(int score) {
    if (score < 61) {
      // 60分(含)以下：紅色 (警示)
      return [Colors.red.shade700, Colors.redAccent];
    } else if (score <= 80) {
      // 61-80分：綠色 (及格/良好)
      return [Colors.green.shade700, Colors.greenAccent];
    } else {
      // 81分(含)以上：藍色 (優秀)
      return [Colors.indigo, Colors.blueAccent];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  // 讀取留言 (從 SQL)
  void _loadComments() async {
    try {
      var c = await SqlService.getComments(widget.record.id);
      if (mounted) setState(() => _comments = c);
    } catch (e) {
      print("留言讀取失敗 (可能是 ID 不對或 DB 沒資料): $e");
    }
  }

  // 發送留言
  void _send() async {
    if (_commentCtrl.text.isEmpty) return;
    try {
      await SqlService.sendComment(
        widget.record.id,
        widget.user.id,
        _commentCtrl.text,
      );
      _commentCtrl.clear();
      _loadComments(); // 重新讀取
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("留言失敗: $e")));
    }
  }

  // 更新隱私權
  void _updatePrivacy(String? v) async {
    if (v == null) return;
    try {
      await SqlService.updatePrivacy(widget.record.id, v);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("已改為 $v")));
    } catch (e) {
      print("更新失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ★★★ 新增這段：定義資料並由高到低排序 ★★★
    final statList = [
      {'label': "自信 (Confidence)", 'score': widget.record.scores['confidence'] ?? 0, 'color': Colors.blue},
      {'label': "熱忱 (Passion)", 'score': widget.record.scores['passion'] ?? 0, 'color': Colors.red},
      {'label': "緊張 (Nervous)", 'score': widget.record.scores['nervous'] ?? 0, 'color': Colors.orange},
      {'label': "沈穩 (Relaxed)", 'score': widget.record.scores['relaxed'] ?? 0, 'color': Colors.green},
    ];
    // 從大排到小
    statList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('面試結果'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'AI 分析'), // Tab 1: AI 分析報告
              Tab(text: '評語討論'), // Tab 2: 留言板功能
              Tab(text: '詳細設定'), // Tab 3: 隱私設定與回放
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ------------------------------------
            // Tab 1: AI 分析報告 (顯示圖表與評語)
            // ------------------------------------
            // ------------------------------------
            // Tab 1: AI 分析報告 (顯示圖表與評語)
            // ------------------------------------
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      // ★ 改成動態顏色
                      gradient: LinearGradient(
                        colors: _getScoreGradient(widget.record.overallScore),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getScoreGradient(widget.record.overallScore).last.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'AI 綜合評分',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          '${widget.record.overallScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // ★★★ 順便把評語文字也改成對應的 ★★★
                        Text(
                          widget.record.overallScore >= 90 ? '表現完美！' :
                          widget.record.overallScore >= 61 ? '表現不錯！' : '加油，再接再厲',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.aiComment != null) ...[
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.smart_toy, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text(
                                  "AI 教練短評",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.aiComment!,
                              style: const TextStyle(height: 1.5),
                            ),
                            const Divider(height: 24),
                            const Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  "改進建議",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.aiSuggestion!,
                              style: const TextStyle(
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "微表情數據分析",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const SizedBox(height: 20),

                  // 1. 切換按鈕 (情緒版 vs 索引版)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton("情緒 % 數版", !_isIndexMode, () {
                          setState(() => _isIndexMode = false);
                        }),
                        _buildTabButton("索引型 (次數)", _isIndexMode, () {
                          setState(() => _isIndexMode = true);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. 根據模式顯示對應的圖表
                  if (!_isIndexMode) ...[
                    // === 模式 A: %數型 ===
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("情緒平均佔比", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    _buildPercentageBars(), // 呼叫長條圖
                    
                    const SizedBox(height: 30),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("情緒波動曲線", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    _buildTimelineChart(), // 呼叫曲線圖
                  ] else ...[
                    // === 模式 B: 索引型 ===
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("主導情緒統計 (Winner Takes All)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    _buildIndexCountView(), // 呼叫次數統計
                  ],
                  
                  const SizedBox(height: 20),

                  const SizedBox(height: 30),

                  // 回首頁按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('回到首頁'),
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------
            // Tab 2: 評語討論 (留言板功能)
            // ------------------------------------
            Column(
              children: [
                Expanded(
                  child: _comments.isEmpty
                      ? const Center(child: Text("尚無留言，快來搶頭香！"))
                      : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (ctx, i) {
                            bool isMe =
                                _comments[i].senderName == widget.user.name;
                            return ListTile(
                              title: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Text(
                                  _comments[i].senderName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              subtitle: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.green[100]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(_comments[i].content),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(
                            hintText: '輸入評語...',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ------------------------------------
            // Tab 3: 詳細設定 (隱私設定與詳細資訊)
            // ------------------------------------
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('面試官'),
                    trailing: Text(widget.record.interviewer),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('語言'),
                    trailing: Text(widget.record.language),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('時長'),
                    trailing: Text('${widget.record.durationSec} 秒'),
                  ),
                  const Divider(),
                  if (widget.user.id == widget.record.studentId) ...[
                    const Text(
                      "公開權限設定：",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: widget.record.privacy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Private',
                          child: Text('私人 (僅自己可見)'),
                        ),
                        DropdownMenuItem(
                          value: 'Class',
                          child: Text('班級 (老師與同學可見)'),
                        ),
                        DropdownMenuItem(
                          value: 'Platform',
                          child: Text('平台 (公開)'),
                        ),
                      ],
                      onChanged: _updatePrivacy,
                    ),
                  ],
                  const Spacer(),
                  // 回放功能按鈕 (這裡只做 UI 示意)
                  const Icon(Icons.play_circle, size: 80, color: Colors.grey),
                  const Text("播放影片 (需實作雲端儲存)"),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                "$score%",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: score / 100,
            color: color,
            backgroundColor: Colors.grey[200],
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }
  // 1. 切換按鈕樣式
  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 2. 長條圖
  Widget _buildPercentageBars() {
    final statList = [
      {'label': "自信", 'score': widget.record.scores['confidence'] ?? 0, 'color': Colors.blue},
      {'label': "熱忱", 'score': widget.record.scores['passion'] ?? 0, 'color': Colors.red},
      {'label': "緊張", 'score': widget.record.scores['nervous'] ?? 0, 'color': Colors.orange},
      {'label': "沈穩", 'score': widget.record.scores['relaxed'] ?? 0, 'color': Colors.green},
    ];
    statList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return Column(
      children: statList.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text("${item['score']}%", style: TextStyle(color: item['color'] as Color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: (item['score'] as int) / 100,
              color: item['color'] as Color,
              backgroundColor: Colors.grey[200],
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // 3. 索引型統計
  Widget _buildIndexCountView() {
    List<dynamic> timeline = [];
    try {
      timeline = jsonDecode(widget.record.timelineData);
    } catch (e) {
      return const Text("無詳細數據");
    }

    if (timeline.isEmpty) return const Text("數據不足");

    Map<String, int> counts = {'c': 0, 'p': 0, 'n': 0, 'r': 0};
    int total = timeline.length;

    for (var point in timeline) {
      int c = point['c'];
      int p = point['p'];
      int n = point['n'];
      int r = point['r'];
      
      int maxVal = [c, p, n, r].reduce((curr, next) => curr > next ? curr : next);
      
      if (c == maxVal) counts['c'] = counts['c']! + 1;
      else if (p == maxVal) counts['p'] = counts['p']! + 1;
      else if (n == maxVal) counts['n'] = counts['n']! + 1;
      else if (r == maxVal) counts['r'] = counts['r']! + 1;
    }

    return Column(
      children: [
        _buildCountRow("自信 (Confidence)", counts['c']!, total, Colors.blue),
        _buildCountRow("熱忱 (Passion)", counts['p']!, total, Colors.red),
        _buildCountRow("緊張 (Nervous)", counts['n']!, total, Colors.orange),
        _buildCountRow("沈穩 (Relaxed)", counts['r']!, total, Colors.green),
      ],
    );
  }

  Widget _buildCountRow(String label, int count, int total, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 4, height: 40, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("主導了 $count 秒", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(
            "${count}s", 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // 4. 曲線圖 (已修正：移除所有會報錯的 const)
  // 4. 曲線圖 (移除觸摸提示版)
  Widget _buildTimelineChart() {
    List<dynamic> timeline = [];
    try {
      timeline = jsonDecode(widget.record.timelineData);
    } catch (_) {
      return const SizedBox();
    }
    
    if (timeline.isEmpty) return const Center(child: Text("無時間軸數據"));

    // 計算最大秒數，用來設定 X 軸範圍
    double maxSeconds = 0;
    if (timeline.isNotEmpty) {
      maxSeconds = (timeline.last['t'] as num).toDouble();
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 24, left: 12, top: 24, bottom: 12),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: maxSeconds > 0 ? maxSeconds : 10, // 動態設定 X 軸長度
          
          // 1. 網格設定
          gridData: FlGridData(
            show: true, 
            verticalInterval: 1, // 每 1 秒一條垂直線
            horizontalInterval: 20, // 每 20 分一條水平線
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),

          // 2. 標題與刻度
          titlesData: FlTitlesData(
            // 下方 X 軸 (時間)
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1, // 每 1 秒顯示一次刻度
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  if (val % 1 != 0) return const SizedBox.shrink(); 
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "${val.toInt()}s", 
                      style: const TextStyle(fontSize: 10, color: Colors.grey)
                    ),
                  );
                },
              ),
            ),
            // 左側 Y 軸 (分數 0-100)
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,     // 0, 20, 40, 60, 80, 100
                reservedSize: 40,
                getTitlesWidget: (val, meta) {
                  return Text(
                    "${val.toInt()}", 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)
                  );
                },
              ),
            ),
            // 上方與右方不顯示
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),

          // 3. 邊框
          borderData: FlBorderData(
            show: true, 
            border: Border.all(color: Colors.grey[300]!)
          ),

          // 4. 線條數據
          lineBarsData: [
            _buildLine(timeline, 'c', Colors.blue),   // 自信
            _buildLine(timeline, 'p', Colors.red),    // 熱忱
            _buildLine(timeline, 'n', Colors.orange), // 緊張
            _buildLine(timeline, 'r', Colors.green),  // 沈穩
          ],
          
          // 這裡原本的第 5 點已移除
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<dynamic> data, String key, Color color) {
    return LineChartBarData(
      spots: data.map((e) => FlSpot((e['t'] as num).toDouble(), (e[key] as num).toDouble())).toList(),
      isCurved: true, 
      color: color,
      barWidth: 3, 
      isStrokeCapRound: true,
      // 顯示資料點
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
        return FlDotCirclePainter(
          radius: 2,
          color: Colors.white,
          strokeWidth: 2,
          strokeColor: color,
        );
      }),
      belowBarData: BarAreaData(show: false),
    );
  }
}