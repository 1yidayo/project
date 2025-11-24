import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';
import 'chat_screens.dart'; // 重用聊天室氣泡 UI

// 1. 面試設定
class InterviewSetupScreen extends StatefulWidget {
  final AppUser user;
  final String? inviteId; // 如果是接受邀請來的
  const InterviewSetupScreen({super.key, required this.user, this.inviteId});
  @override
  State<InterviewSetupScreen> createState() => _InterviewSetupScreenState();
}

class _InterviewSetupScreenState extends State<InterviewSetupScreen> {
  String type = '通用型';
  String interviewer = '保羅';
  String lang = '中文';
  bool saveVideo = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模擬面試設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _drop('問題類型', ['通用型', '科系專業', '學經歷'], (v) => type = v!),
            _drop('面試官', ['保羅', '林湘霖', '藍易振'], (v) => interviewer = v!),
            _drop('語言', ['中文', '英文'], (v) => lang = v!),
            SwitchListTile(
              title: const Text('儲存錄影'),
              value: saveVideo,
              onChanged: (v) => setState(() => saveVideo = v),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MockInterviewingScreen(
                    user: widget.user,
                    type: type,
                    interviewer: interviewer,
                    lang: lang,
                    saveVideo: saveVideo,
                  ),
                ),
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

  Widget _drop(String label, List<String> items, Function(String?) onChange) {
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

// 2. 面試進行中
class MockInterviewingScreen extends StatefulWidget {
  final AppUser user;
  final String type, interviewer, lang;
  final bool saveVideo;
  const MockInterviewingScreen({
    super.key,
    required this.user,
    required this.type,
    required this.interviewer,
    required this.lang,
    required this.saveVideo,
  });
  @override
  State<MockInterviewingScreen> createState() => _MockInterviewingScreenState();
}

class _MockInterviewingScreenState extends State<MockInterviewingScreen> {
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

  void _finish() async {
    _timer.cancel();
    // 存入 SQL
    int score = 70 + _sec % 30; // 模擬分數
    await SqlService.saveRecord(
      widget.user.id,
      _sec,
      widget.type,
      widget.interviewer,
      widget.lang,
      score,
      widget.saveVideo,
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InterviewResultScreen(score: score, duration: _sec),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Center(
            child: Icon(Icons.person_pin, size: 150, color: Colors.white54),
          ), // 模擬面試官畫面
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              width: 100,
              height: 140,
              color: Colors.grey,
              child: const Center(
                child: Text("學生", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Text(
              "🔴 紀錄中  ${_sec}s",
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("結束面試", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. 面試結果
class InterviewResultScreen extends StatelessWidget {
  final int score;
  final int duration;
  const InterviewResultScreen({
    super.key,
    required this.score,
    required this.duration,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試結果')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("總分", style: TextStyle(fontSize: 20)),
            Text(
              "$score",
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            Text("時長: $duration 秒"),
            const SizedBox(height: 20),
            // 這裡應該要放雷達圖 Widget，為了簡化先省略
            const Icon(Icons.radar, size: 100, color: Colors.blue),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("回首頁"),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. 面試紀錄中心 (含分頁)
class InterviewRecordCenter extends StatelessWidget {
  final AppUser user;
  final bool isTeacher;
  const InterviewRecordCenter({
    super.key,
    required this.user,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: isTeacher ? 2 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isTeacher ? '評語請求' : '評語/紀錄'),
          bottom: TabBar(
            tabs: isTeacher
                ? [const Tab(text: '班級紀錄'), const Tab(text: '平台紀錄')]
                : [
                    const Tab(text: '私人'),
                    const Tab(text: '班級'),
                    const Tab(text: '平台'),
                  ],
          ),
        ),
        body: TabBarView(
          children: isTeacher
              ? [
                  _RecordList(user: user, filter: 'Class'),
                  _RecordList(user: user, filter: 'Platform'),
                ]
              : [
                  _RecordList(user: user, filter: 'All'),
                  _RecordList(user: user, filter: 'Class'),
                  _RecordList(user: user, filter: 'Platform'),
                ],
        ),
      ),
    );
  }
}

class _RecordList extends StatefulWidget {
  final AppUser user;
  final String filter;
  const _RecordList({required this.user, required this.filter});
  @override
  State<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<_RecordList> {
  List<InterviewRecord> _list = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    var d = await SqlService.getRecords(widget.user.id, widget.filter);
    if (mounted) setState(() => _list = d);
  }

  @override
  Widget build(BuildContext context) {
    if (_list.isEmpty) return const Center(child: Text("尚無紀錄"));
    return ListView.builder(
      itemCount: _list.length,
      itemBuilder: (ctx, i) => Card(
        margin: const EdgeInsets.all(8),
        child: ListTile(
          leading: CircleAvatar(child: Text("${_list[i].overallScore}")),
          title: Text("${_list[i].type} (${_list[i].language})"),
          subtitle: Text(
            "${_list[i].date.toString().split(' ')[0]} | ${_list[i].studentName}",
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RecordDetailPage(record: _list[i], currentUser: widget.user),
            ),
          ),
        ),
      ),
    );
  }
}

// 5. 紀錄詳情頁 (詳情/評語/回放)
class RecordDetailPage extends StatefulWidget {
  final InterviewRecord record;
  final AppUser currentUser;
  const RecordDetailPage({
    super.key,
    required this.record,
    required this.currentUser,
  });
  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  void _loadComments() async {
    var c = await SqlService.getComments(widget.record.id);
    if (mounted) setState(() => _comments = c);
  }

  void _send() async {
    if (_commentCtrl.text.isEmpty) return;
    await SqlService.sendComment(
      widget.record.id,
      widget.currentUser.id,
      _commentCtrl.text,
    );
    _commentCtrl.clear();
    _loadComments();
  }

  void _updatePrivacy(String? v) async {
    if (v == null) return;
    await SqlService.updatePrivacy(widget.record.id, v);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("已改為 $v")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("紀錄詳情"),
          bottom: const TabBar(
            tabs: [
              Tab(text: '詳情'),
              Tab(text: '評語'),
              Tab(text: '回放'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 詳情
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (widget.currentUser.id == widget.record.studentId) ...[
                    const Text("公開設定："),
                    DropdownButton<String>(
                      value: widget.record.privacy,
                      items: const [
                        DropdownMenuItem(value: 'Private', child: Text('私人')),
                        DropdownMenuItem(value: 'Class', child: Text('班級')),
                        DropdownMenuItem(value: 'Platform', child: Text('平台')),
                      ],
                      onChanged: _updatePrivacy,
                    ),
                    const Divider(),
                  ],
                  ListTile(
                    title: const Text("總分"),
                    trailing: Text(
                      "${widget.record.overallScore}",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text("面試官"),
                    trailing: Text(widget.record.interviewer),
                  ),
                  const Expanded(child: Center(child: Text("這裡放雷達圖"))),
                ],
              ),
            ),
            // 評語 (對話式)
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (ctx, i) {
                      bool isMe =
                          _comments[i].senderName == widget.currentUser.name;
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
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(hintText: '寫評語...'),
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
            // 回放
            Center(
              child: widget.record.privacy == 'NoVideo'
                  ? const Text("本次無錄影")
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.play_circle, size: 80),
                        Text("播放影片"),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
