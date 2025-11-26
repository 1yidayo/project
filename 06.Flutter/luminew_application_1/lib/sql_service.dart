// fileName: lib/sql_service.dart
import 'dart:convert';
import 'package:sql_conn/sql_conn.dart';
import 'models.dart';

class SqlService {
  // ★ 請確認您的 IP (模擬器: 10.0.2.2 / 真機: 電腦IPv4)
  static const String _ip = "10.0.2.2"; 
  static const String _port = "1433";
  static const String _dbName = "LuminewDB";
  static const String _user = "sa";
  static const String _pass = "112233";

  // 1. 連線與安全讀寫機制
  static Future<void> connect({bool force = false}) async {
    try {
      if (force) {
        try { await SqlConn.disconnect(); } catch (_) {}
      }
      if (!SqlConn.isConnected || force) {
        await SqlConn.connect(
          ip: _ip,
          port: _port,
          databaseName: _dbName,
          username: _user,
          password: _pass,
        );
        print("✅ SQL 連線成功");
      }
    } catch (e) {
      print("❌ 連線失敗: $e");
      throw e;
    }
  }

  static Future<String> _safeRead(String sql) async {
    try {
      await connect();
      return await SqlConn.readData(sql);
    } catch (e) {
      String err = e.toString().toLowerCase();
      if (err.contains("closed") || err.contains("connection")) {
        print("⚠️ 連線中斷，重連中...");
        await connect(force: true);
        return await SqlConn.readData(sql);
      }
      throw e;
    }
  }

  static Future<void> _safeWrite(String sql) async {
    try {
      await connect();
      await SqlConn.writeData(sql);
    } catch (e) {
      print("⚠️ 寫入中斷，重連中...");
      await connect(force: true);
      await SqlConn.writeData(sql);
    }
  }

  // ====================================================
  //  使用者與驗證 (User Auth)
  // ====================================================
  
  static Future<AppUser?> login(String email, String password) async {
    String sql = "SELECT * FROM Users WHERE Email = '$email' AND PasswordHash = '$password'";
    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return null;
      return AppUser.fromMap(jsonDecode(res)[0]);
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  static Future<void> registerUser(String email, String password, String name, String role) async {
    String check = await _safeRead("SELECT * FROM Users WHERE Email = '$email'");
    if (check != "[]" && check.isNotEmpty) throw Exception("此 Email 已被註冊");

    String sql = "INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES ('$email', '$password', N'$name', '$role')";
    await _safeWrite(sql);
  }

  static Future<void> updateUserName(String email, String newName) async {
    String sql = "UPDATE Users SET Name = N'$newName' WHERE Email = '$email'";
    await _safeWrite(sql);
  }

  // ====================================================
  //  面試紀錄 (AI Interview Records)
  // ====================================================

  static Future<void> saveRecord(InterviewRecord r) async {
    String scoresJson = jsonEncode(r.scores);
    
    String sql = """
      INSERT INTO InterviewRecords 
      (StudentID, Date, DurationSeconds, Type, Interviewer, Language, OverallScore, ScoresDetail, Privacy) 
      VALUES 
      (
        (SELECT UserID FROM Users WHERE Email = '${r.studentId}'), 
        GETDATE(), 
        ${r.durationSec}, 
        N'${r.type}', 
        N'${r.interviewer}', 
        N'${r.language}', 
        ${r.overallScore}, 
        '$scoresJson', 
        '${r.privacy}'
      )
    """;
    await _safeWrite(sql);
  }

  static Future<List<InterviewRecord>> getRecords(String userId, String filter) async {
    String sql;
    if (userId.contains('@')) {
       sql = "SELECT * FROM InterviewRecords WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '$userId') ORDER BY Date DESC";
    } else {
       sql = "SELECT * FROM InterviewRecords WHERE StudentID = '$userId' ORDER BY Date DESC";
    }

    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return [];
      
      List<dynamic> list = jsonDecode(res);
      return list.map((data) {
        return InterviewRecord(
          id: data['RecordID'].toString(),
          studentId: userId,
          date: DateTime.tryParse(data['Date'].toString()) ?? DateTime.now(),
          durationSec: data['DurationSeconds'] ?? 0,
          type: data['Type'] ?? '通用型',
          interviewer: data['Interviewer'] ?? 'AI',
          language: data['Language'] ?? '中文',
          privacy: data['Privacy'] ?? 'Private',
          scores: _parseScores(data['ScoresDetail']), 
        );
      }).toList();
    } catch (e) {
      print("讀取紀錄失敗: $e");
      return [];
    }
  }

  static Map<String, int> _parseScores(dynamic jsonStr) {
    try {
      if (jsonStr == null || jsonStr == "") return {'overall': 0};
      return Map<String, int>.from(jsonDecode(jsonStr));
    } catch (e) {
      return {'overall': 0};
    }
  }

  static Future<void> updatePrivacy(String recordId, String privacy) async {
    String sql = "UPDATE InterviewRecords SET Privacy = '$privacy' WHERE RecordID = $recordId";
    await _safeWrite(sql);
  }

  // ====================================================
  //  留言與評論 (Comments)
  // ====================================================

  static Future<List<Comment>> getComments(String recordId) async {
    String sql = """
      SELECT c.*, u.Name as SenderName 
      FROM RecordComments c 
      JOIN Users u ON c.SenderID = u.UserID 
      WHERE c.RecordID = $recordId 
      ORDER BY c.SentAt ASC
    """;
    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return [];
      return (jsonDecode(res) as List).map((x) => Comment(
        id: x['CommentID'].toString(),
        senderName: x['SenderName'],
        content: x['Content'],
        date: x['SentAt'].toString(),
      )).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> sendComment(String recordId, String userEmail, String content) async {
    String userIdSql = userEmail.contains('@') 
        ? "(SELECT UserID FROM Users WHERE Email = '$userEmail')" 
        : "'$userEmail'";
        
    String sql = "INSERT INTO RecordComments (RecordID, SenderID, Content) VALUES ($recordId, $userIdSql, N'$content')";
    await _safeWrite(sql);
  }

  // ====================================================
  //  班級與成員 (Class Management)
  // ====================================================

  static Future<void> createClass(String name, String teacherEmail) async {
    String sql = "INSERT INTO Classes (ClassName, TeacherID, InvitationCode) VALUES (N'$name', (SELECT UserID FROM Users WHERE Email = '$teacherEmail'), 'C${DateTime.now().millisecondsSinceEpoch}')";
    await _safeWrite(sql);
  }

  static Future<List<Class>> getTeacherClasses(String email) async {
    String sql = "SELECT * FROM Classes WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '$email')";
    return _parseClasses(await _safeRead(sql));
  }

  static Future<List<Class>> getStudentClasses(String email) async {
    String sql = "SELECT c.* FROM Classes c JOIN ClassMembers cm ON c.ClassID = cm.ClassID WHERE cm.StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    return _parseClasses(await _safeRead(sql));
  }

  static Future<Class?> joinClass(String code, String email) async {
    String findSql = "SELECT * FROM Classes WHERE InvitationCode = '$code'";
    var classes = _parseClasses(await _safeRead(findSql));
    if (classes.isEmpty) throw Exception("找不到班級");
    
    Class target = classes.first;
    String checkSql = "SELECT * FROM ClassMembers WHERE ClassID = ${target.id} AND StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    String checkRes = await _safeRead(checkSql);
    if (checkRes != "[]" && checkRes.isNotEmpty) throw Exception("您已加入此班級");

    String joinSql = "INSERT INTO ClassMembers (ClassID, StudentID) VALUES (${target.id}, (SELECT UserID FROM Users WHERE Email = '$email'))";
    await _safeWrite(joinSql);
    return target;
  }

  static Future<List<Student>> getClassStudents(String classId) async {
    String sql = "SELECT u.UserID, u.Name FROM Users u JOIN ClassMembers cm ON u.UserID = cm.StudentID WHERE cm.ClassID = $classId";
    var res = await _safeRead(sql);
    if (res.isEmpty || res == "[]") return [];
    return (jsonDecode(res) as List).map((j) => Student(id: j['UserID'].toString(), name: j['Name'])).toList();
  }

  static List<Class> _parseClasses(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == "[]") return [];
    try {
      return (jsonDecode(jsonStr) as List).map((x) => Class.fromMap(x)).toList();
    } catch (e) {
      return [];
    }
  }

  // ====================================================
  //  ★ 邀請與學習歷程 (Invitations & Portfolios) - 修正重點
  // ====================================================

  static Future<void> sendInvitation(String teacherEmail, String studentId, String msg) async {
    String sql = "INSERT INTO Invitations (TeacherID, StudentID, Message) VALUES ((SELECT UserID FROM Users WHERE Email = '$teacherEmail'), $studentId, N'$msg')";
    await _safeWrite(sql);
  }

  // ★ 修正：支援 userId 和 isTeacher 參數，並正確返回 Invitation 物件
  static Future<List<Invitation>> getInvitations(String userId, bool isTeacher) async {
    String sql;
    if (isTeacher) {
      // 老師查看自己發出的邀請
      sql = """
        SELECT i.*, u.Name as StudentName 
        FROM Invitations i 
        JOIN Users u ON i.StudentID = u.UserID 
        WHERE i.TeacherID = $userId
        ORDER BY i.SentAt DESC
      """;
    } else {
      // 學生查看收到的邀請
      sql = """
        SELECT i.*, u.Name as TeacherName 
        FROM Invitations i 
        JOIN Users u ON i.TeacherID = u.UserID 
        WHERE i.StudentID = $userId
        ORDER BY i.SentAt DESC
      """;
    }
    
    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return [];
      return (jsonDecode(res) as List).map((x) => Invitation(
        id: x['InvitationID'].toString(),
        teacherName: x['TeacherName'] ?? '', // 學生看這欄
        studentName: x['StudentName'] ?? '', // 老師看這欄
        message: x['Message'],
        status: x['Status'],
        date: x['SentAt'].toString(),
      )).toList();
    } catch (e) {
      print("讀取邀請失敗: $e");
      return [];
    }
  }

  // ★ 新增：更新邀請狀態 (接受/拒絕)
  static Future<void> updateInvitation(String inviteId, String status) async {
    String sql = "UPDATE Invitations SET Status = '$status' WHERE InvitationID = $inviteId";
    await _safeWrite(sql);
  }

  static Future<void> addPortfolio(String email, String title) async {
    String sql = "INSERT INTO LearningPortfolios (StudentID, Title) VALUES ((SELECT UserID FROM Users WHERE Email = '$email'), N'$title')";
    await _safeWrite(sql);
  }

  static Future<List<LearningPortfolio>> getPortfolios(String email) async {
    String sql = "SELECT * FROM LearningPortfolios WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '$email') ORDER BY UploadDate DESC";
    var res = await _safeRead(sql);
    if (res.isEmpty || res == "[]") return [];
    return (jsonDecode(res) as List).map((x) => LearningPortfolio(
      id: x['PortfolioID'].toString(),
      title: x['Title'],
      uploadDate: x['UploadDate'].toString().split('T')[0],
    )).toList();
  }
}
