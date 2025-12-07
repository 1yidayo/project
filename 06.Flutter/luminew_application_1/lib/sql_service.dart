import 'dart:async';
import 'dart:convert'; // 用於 JSON 處理
import 'dart:math';
import 'package:mysql1/mysql1.dart';
import 'models.dart';

class SqlService {
  // ★ MySQL 設定 (模擬器連電腦專用 IP)
  static const String _host = "10.0.2.2";
  static const int _port = 3306;
  static const String _user = "root"; // XAMPP 預設帳號
  static const String _pass = "";     // XAMPP 預設無密碼
  static const String _dbName = "LuminewDB";

  static MySqlConnection? _conn;

  // 連線機制
  static Future<void> connect() async {
    if (_conn != null) return;
    try {
      var settings = ConnectionSettings(
        host: _host,
        port: _port,
        user: _user,
        password: _pass,
        db: _dbName,
      );
      _conn = await MySqlConnection.connect(settings);
      print("✅ MySQL 連線成功");
    } catch (e) {
      print("❌ MySQL 連線失敗: $e");
      _conn = null;
      // 不拋出錯誤，讓 App 可以繼續嘗試重連
    }
  }

  // 內部通用查詢方法 (自動處理連線與結果轉換)
  static Future<List<Map<String, dynamic>>> _query(String sql, [List<Object?>? params]) async {
    try {
      if (_conn == null) await connect();
      // 執行查詢
      var results = await _conn!.query(sql, params);
      
      // 將 MySQL Results 轉換為 List<Map> 供 Model 使用
      final List<Map<String, dynamic>> list = [];
      for (var row in results) {
        list.add(row.fields);
      }
      return list;
    } catch (e) {
      print("⚠️ SQL 執行錯誤: $e");
      // 簡單重連機制
      _conn = null;
      await connect();
      if (_conn != null) {
         var results = await _conn!.query(sql, params);
         final List<Map<String, dynamic>> list = [];
         for (var row in results) {
           list.add(row.fields);
         }
         return list;
      }
      return []; // 若失敗回傳空陣列，避免 App 崩潰
    }
  }

  // 內部通用寫入方法
  static Future<void> _exec(String sql, [List<Object?>? params]) async {
    try {
      if (_conn == null) await connect();
      await _conn!.query(sql, params);
    } catch (e) {
      print("⚠️ 寫入異常，嘗試重連: $e");
      _conn = null;
      await connect();
      if (_conn != null) {
        await _conn!.query(sql, params);
      } else {
        throw e; // 寫入失敗必須拋出錯誤讓 UI 知道
      }
    }
  }

  // ==========================
  // 使用者驗證 (Auth)
  // ==========================
  static Future<AppUser?> login(String email, String password) async {
    // 使用 ? 作為參數 placeholder，防止 SQL Injection
    String sql = "SELECT * FROM Users WHERE Email = ? AND PasswordHash = ?";
    var res = await _query(sql, [email, password]);
    
    if (res.isEmpty) return null;
    return AppUser.fromMap(res.first);
  }

  static Future<void> registerUser(
    String email,
    String password,
    String name,
    String role,
  ) async {
    String sql = "INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES (?, ?, ?, ?)";
    await _exec(sql, [email, password, name, role]);
  }

  // ==========================
  // 班級管理
  // ==========================
  static Future<List<Class>> getTeacherClasses(String email) async {
    String sql = "SELECT * FROM Classes WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = ?)";
    var res = await _query(sql, [email]);
    return res.map((x) => Class.fromMap(x)).toList();
  }

  static Future<void> createClass(String name, String teacherEmail) async {
    // 1. 查 ID
    String idSql = "SELECT UserID FROM Users WHERE Email = ?";
    var idRes = await _query(idSql, [teacherEmail]);
    
    if (idRes.isEmpty) {
      throw Exception("找不到您的帳號資料 ($teacherEmail)");
    }
    
    var teacherId = idRes.first['UserID'];
    
    // 2. 產生代碼
    String code = (Random().nextInt(900000) + 100000).toString();

    // 3. 寫入
    String sql = "INSERT INTO Classes (ClassName, TeacherID, InvitationCode) VALUES (?, ?, ?)";
    await _exec(sql, [name, teacherId, code]);
  }

  static Future<List<Student>> getClassStudents(String classId) async {
    // 注意：傳入的 classId 是 String，轉換為 int 比較保險
    String sql = "SELECT u.UserID, u.Name FROM Users u JOIN ClassMembers cm ON u.UserID = cm.StudentID WHERE cm.ClassID = ?";
    var res = await _query(sql, [int.tryParse(classId) ?? 0]);
    return res.map((j) => Student(id: j['UserID'].toString(), name: j['Name'])).toList();
  }

  static Future<List<Class>> getStudentClasses(String email) async {
    String sql = "SELECT c.* FROM Classes c JOIN ClassMembers cm ON c.ClassID = cm.ClassID WHERE cm.StudentID = (SELECT UserID FROM Users WHERE Email = ?)";
    var res = await _query(sql, [email]);
    return res.map((x) => Class.fromMap(x)).toList();
  }

  static Future<Class?> joinClass(String code, String email) async {
    String findSql = "SELECT * FROM Classes WHERE InvitationCode = ?";
    var res = await _query(findSql, [code]);
    
    if (res.isEmpty) throw Exception("找不到班級，請確認代碼是否正確");
    Class cls = Class.fromMap(res.first);

    // 檢查是否已加入
    String checkSql = "SELECT * FROM ClassMembers WHERE ClassID = ? AND StudentID = (SELECT UserID FROM Users WHERE Email = ?)";
    var check = await _query(checkSql, [cls.id, email]);
    
    if (check.isNotEmpty) throw Exception("您已加入此班級");

    // 加入
    String insertSql = "INSERT INTO ClassMembers (ClassID, StudentID) VALUES (?, (SELECT UserID FROM Users WHERE Email = ?))";
    await _exec(insertSql, [cls.id, email]);
    return cls;
  }

  // ==========================
  // 面試紀錄
  // ==========================
  static Future<List<InterviewRecord>> getRecords(String userId, String filter) async {
    String sql;
    // 判斷 userId 是 ID 還是 Email
    if (userId.contains('@')) {
      sql = "SELECT * FROM InterviewRecords WHERE StudentID = (SELECT UserID FROM Users WHERE Email = ?) ORDER BY Date DESC";
    } else {
      sql = "SELECT * FROM InterviewRecords WHERE StudentID = ? ORDER BY Date DESC";
    }
    
    var res = await _query(sql, [userId]);
    return res.map((d) => InterviewRecord.fromMap(d)).toList();
  }

  static Future<void> saveRecord(InterviewRecord r) async {
    // 將 Map 轉為 JSON 字串存入 DB
    String scoresJson = jsonEncode(r.scores);
    
    String sql = "INSERT INTO InterviewRecords (StudentID, Date, DurationSeconds, Type, Interviewer, Language, OverallScore, ScoresDetail, Privacy) VALUES ((SELECT UserID FROM Users WHERE Email = ?), NOW(), ?, ?, ?, ?, ?, ?, ?)";
    
    await _exec(sql, [
      r.studentId,
      r.durationSec,
      r.type,
      r.interviewer,
      r.language,
      r.overallScore,
      scoresJson,
      r.privacy
    ]);
  }

  // ==========================
  // 邀請與時段
  // ==========================
  static Future<void> sendInvitation(String teacherEmail, String studentId, String msg) async {
    String sql = "INSERT INTO Invitations (TeacherID, StudentID, Message, SentAt) VALUES ((SELECT UserID FROM Users WHERE Email = ?), ?, ?, NOW())";
    await _exec(sql, [teacherEmail, studentId, msg]);
  }

  static Future<void> sendBulkInvitations(String teacherEmail, List<String> studentIds, String msg) async {
    if (studentIds.isEmpty) return;
    
    var tRes = await _query("SELECT UserID FROM Users WHERE Email = ?", [teacherEmail]);
    if (tRes.isEmpty) return;
    var tid = tRes.first['UserID'];

    for (String sid in studentIds) {
      // 檢查重複
      var check = await _query("SELECT * FROM Invitations WHERE TeacherID = ? AND StudentID = ? AND Status = 'Pending'", [tid, sid]);
      if (check.isEmpty) {
        await _exec(
          "INSERT INTO Invitations (TeacherID, StudentID, Message, SentAt, Status) VALUES (?, ?, ?, NOW(), 'Pending')",
          [tid, sid, msg]
        );
      }
    }
  }

  static Future<List<Invitation>> getInvitations(String userId, bool isTeacher) async {
    String sql;
    if (isTeacher) {
      sql = "SELECT i.*, u.Name as StudentName FROM Invitations i JOIN Users u ON i.StudentID = u.UserID WHERE i.TeacherID = ? ORDER BY i.SentAt DESC";
    } else {
      sql = "SELECT i.*, u.Name as TeacherName FROM Invitations i JOIN Users u ON i.TeacherID = u.UserID WHERE i.StudentID = ? ORDER BY i.SentAt DESC";
    }
    
    var res = await _query(sql, [userId]);
    return res.map((x) => Invitation(
      id: x['InvitationID'].toString(),
      teacherName: x['TeacherName'] ?? '',
      studentName: x['StudentName'] ?? '',
      message: x['Message'],
      status: x['Status'],
      date: x['SentAt'].toString(),
    )).toList();
  }

  static Future<void> updateInvitation(String id, String status) async {
    await _exec("UPDATE Invitations SET Status = ? WHERE InvitationID = ?", [status, id]);
  }

  static Future<void> addInterviewSlot(String teacherEmail, DateTime start, DateTime end) async {
    String sql = "INSERT INTO InterviewSlots (TeacherID, StartTime, EndTime, IsBooked) VALUES ((SELECT UserID FROM Users WHERE Email = ?), ?, ?, 0)";
    await _exec(sql, [teacherEmail, start, end]);
  }

  static Future<List<InterviewSlot>> getTeacherSlots(String teacherEmail) async {
    String sql = "SELECT s.*, u.Name as StudentName FROM InterviewSlots s LEFT JOIN Users u ON s.BookedByStudentID = u.UserID WHERE s.TeacherID = (SELECT UserID FROM Users WHERE Email = ?) ORDER BY s.StartTime ASC";
    var res = await _query(sql, [teacherEmail]);
    return res.map((x) => InterviewSlot.fromMap(x)).toList();
  }

  static Future<void> deleteSlot(String slotId) async {
    await _exec("DELETE FROM InterviewSlots WHERE SlotID = ?", [slotId]);
  }

  static Future<List<InterviewSlot>> getAvailableSlots(String teacherEmail) async {
    String sql = "SELECT * FROM InterviewSlots WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = ?) AND IsBooked = 0 AND StartTime > NOW() ORDER BY StartTime ASC";
    var res = await _query(sql, [teacherEmail]);
    return res.map((x) => InterviewSlot.fromMap(x)).toList();
  }

  static Future<void> bookSlot(String slotId, String studentEmail) async {
    var check = await _query("SELECT IsBooked FROM InterviewSlots WHERE SlotID = ?", [slotId]);
    
    if (check.isNotEmpty) {
      var isBooked = check.first['IsBooked'];
      // MySQL 的 BIT 或 TINYINT 可能回傳 1 或 true
      if (isBooked == 1 || isBooked == true) {
         throw Exception("時段已被搶走");
      }
    }
    
    String sql = "UPDATE InterviewSlots SET IsBooked = 1, BookedByStudentID = (SELECT UserID FROM Users WHERE Email = ?) WHERE SlotID = ?";
    await _exec(sql, [studentEmail, slotId]);
  }

  // ==========================
  // 評論與學習歷程
  // ==========================
  static Future<List<Comment>> getComments(String recordId) async {
    String sql = "SELECT c.*, u.Name as SenderName FROM RecordComments c JOIN Users u ON c.SenderID = u.UserID WHERE c.RecordID = ? ORDER BY c.SentAt ASC";
    try {
      var res = await _query(sql, [recordId]);
      return res.map((x) => Comment(
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
    String sql = "INSERT INTO RecordComments (RecordID, SenderID, Content, SentAt) VALUES (?, (SELECT UserID FROM Users WHERE Email = ?), ?, NOW())";
    await _exec(sql, [recordId, userEmail, content]);
  }

  static Future<void> updatePrivacy(String recordId, String privacy) async {
    await _exec("UPDATE InterviewRecords SET Privacy = ? WHERE RecordID = ?", [privacy, recordId]);
  }

  static Future<List<LearningPortfolio>> getPortfolios(String email) async {
    String sql = "SELECT * FROM LearningPortfolios WHERE StudentID = (SELECT UserID FROM Users WHERE Email = ?) ORDER BY UploadDate DESC";
    var res = await _query(sql, [email]);
    return res.map((x) => LearningPortfolio(
      id: x['PortfolioID'].toString(),
      title: x['Title'],
      uploadDate: x['UploadDate'].toString(),
    )).toList();
  }

  static Future<void> addPortfolio(String email, String title) async {
    String sql = "INSERT INTO LearningPortfolios (StudentID, Title, UploadDate) VALUES ((SELECT UserID FROM Users WHERE Email = ?), ?, NOW())";
    await _exec(sql, [email, title]);
  }
}