// fileName: lib/screens/interview_screens.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // 確保 pubspec.yaml 有 camera
import 'package:http/http.dart' as http; // 確保 pubspec.yaml 有 http
import '../models.dart';
import '../mock_data.dart';
import '../sql_service.dart'; // 必須引用，用於存檔與讀取留言

// 全域變數：用來儲存可用的相機列表
List<CameraDescription> cameras = [];

// ==========================================
// 1. 面試紀錄列表 (讀取 SQL 資料)
// ==========================================
class InterviewRecordListScreen extends StatefulWidget {
  final AppUser user;
  const InterviewRecordListScreen({super.key, required this.user});

  @override
  State<InterviewRecordListScreen> createState() => _InterviewRecordListScreenState();
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
                      builder: (_) => InterviewResultScreen(
                        record: r, 
                        user: widget.user,
                      ),
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
  State<MockInterviewSetupScreen> createState() => _MockInterviewSetupScreenState();
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
            _buildDropdown(
              '面試類型', 
              ['通用型', '科系專業', '學經歷'], 
              (v) => setState(() => _type = v!)
            ),
            
            // 2. 面試官
            _buildDropdown(
              '面試官', 
              ['保羅', '林湘霖', '藍易振', 'AI 面試官'], 
              (v) => setState(() => _interviewer = v!)
            ),
            
            // 3. 語言
            _buildDropdown(
              '語言', 
              ['中文', '英文'], 
              (v) => setState(() => _lang = v!)
            ),
            
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
  Widget _buildDropdown(String label, List<String> items, Function(String?) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField(
        value: items[0],
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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

        _controller = CameraController(frontCam, ResolutionPreset.medium);
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
        if(mounted) setState(() => _sec++);
      });
    } catch (e) {
      print("開始錄影失敗: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("錄影啟動失敗: $e")));
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
    
    if(mounted) {
      setState(() {
        _isRecording = false;
        _isUploading = true; 
      });
    }

    try {
      // ★★★ IP 設定：請確認這裡改成您電腦的 IP ★★★
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.119:5000/analyze'), 
      );
      
      request.files.add(await http.MultipartFile.fromPath('video', file.path));
      
      print("正在上傳影片...");
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 45), 
        onTimeout: () {
          throw Exception("連線逾時，請檢查 Python Server 是否開啟");
        },
      );
      
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final emotions = data['emotions'];
        final ai = data['ai_analysis'];

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
          },
          type: widget.type,             
          interviewer: widget.interviewer, 
          language: widget.language,     
          privacy: 'Private',            
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
            MaterialPageRoute(builder: (_) => InterviewResultScreen(
              record: r, 
              user: widget.user,
              aiComment: ai['comment'],
              aiSuggestion: ai['suggestion'],
            )),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("錯誤: $e");
      if (mounted) {
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text("分析失敗"),
            content: Text("錯誤訊息：$e\n\n請確認：\n1. Python Server 有開嗎？\n2. IP 位址改對了嗎？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("確定"),
              )
            ],
          )
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text("面試官: ${widget.interviewer}", style: const TextStyle(color: Colors.white)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          "${(_sec ~/ 60).toString().padLeft(2, '0')}:${(_sec % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                        Text("AI 正在分析您的表情...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          onTap: _isRecording ? _stopAndAnalyze : _startRecording,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: _isRecording ? Colors.red : Colors.transparent,
                            ),
                            child: _isRecording 
                              ? const Icon(Icons.stop, color: Colors.white, size: 40)
                              : const Icon(Icons.circle, color: Colors.white, size: 60),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("留言失敗: $e")));
    }
  }

  // 更新隱私權
  void _updatePrivacy(String? v) async {
    if (v == null) return;
    try {
      await SqlService.updatePrivacy(widget.record.id, v);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已改為 $v")));
    } catch (e) {
      print("更新失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('面試結果'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'AI 分析'), // Tab 1: AI 分析報告
              Tab(text: '評語討論'),  // Tab 2: 留言板功能
              Tab(text: '詳細設定'),  // Tab 3: 隱私設定與回放
            ],
          ),
        ),
        body: TabBarView(
          children: [
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
                      gradient: const LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('AI 綜合評分', style: TextStyle(color: Colors.white70)),
                        Text('${widget.record.overallScore}', 
                          style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),
                        Text(widget.record.overallScore >= 80 ? '表現優異！' : '還有進步空間', style: const TextStyle(color: Colors.white)),
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
                            const Row(children: [Icon(Icons.smart_toy, color: Colors.indigo), SizedBox(width: 8), Text("AI 教練短評", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                            const SizedBox(height: 8),
                            Text(widget.aiComment!, style: const TextStyle(height: 1.5)),
                            const Divider(height: 24),
                            const Row(children: [Icon(Icons.lightbulb, color: Colors.orange), SizedBox(width: 8), Text("改進建議", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                            const SizedBox(height: 8),
                            Text(widget.aiSuggestion!, style: const TextStyle(color: Colors.black87, height: 1.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Align(alignment: Alignment.centerLeft, child: Text("微表情數據分析", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  _buildStatRow("自信 (Confidence)", widget.record.scores['confidence'] ?? 0, Colors.blue),
                  _buildStatRow("熱忱 (Passion)", widget.record.scores['passion'] ?? 0, Colors.red),
                  _buildStatRow("緊張 (Nervous)", widget.record.scores['nervous'] ?? 0, Colors.orange),
                  
                  const SizedBox(height: 30),
                  
                  // 回首頁按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
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
                          bool isMe = _comments[i].senderName == widget.user.name;
                          return ListTile(
                            title: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Text(_comments[i].senderName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                            subtitle: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.green[100] : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[300]!),
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
                      Expanded(child: TextField(controller: _commentCtrl, decoration: const InputDecoration(hintText: '輸入評語...'))),
                      IconButton(icon: const Icon(Icons.send), onPressed: _send),
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
                    const Text("公開權限設定：", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: widget.record.privacy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Private', child: Text('私人 (僅自己可見)')),
                        DropdownMenuItem(value: 'Class', child: Text('班級 (老師與同學可見)')),
                        DropdownMenuItem(value: 'Platform', child: Text('平台 (公開)')),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w500)), Text("$score%", style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: score / 100, color: color, backgroundColor: Colors.grey[200], minHeight: 10, borderRadius: BorderRadius.circular(5)),
        ],
      ),
    );
  }
}


