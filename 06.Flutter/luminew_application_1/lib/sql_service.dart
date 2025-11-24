import 'dart:convert';
import 'package:sql_conn/sql_conn.dart';
import 'models.dart';

class SqlService {
  static const String _ip = "10.0.2.2";
  static const String _port = "1433";
  static const String _dbName = "LuminewDB";
  static const String _user = "sa";
  static const String _pass = "112233";

  static Future<void> connect({bool force = false}) async {
    try {
      if (force) {
        try {
          await SqlConn.disconnect();
        } catch (_) {}
      }
      if (!SqlConn.isConnected || force) {
        await SqlConn.connect(
          ip: _ip,
          port: _port,
          databaseName: _dbName,
          username: _user,
          password: _pass,
        );
      }
    } catch (e) {
      print("Connect Err: $e");
      // 這裡不 rethrow，讓其他 function 處理重連邏輯
    }
  }

  // 萬用執行器
  static Future<dynamic> _exec(Future<dynamic> Function() action) async {
    try {
      await connect();
      return await action();
    } catch (e) {
      print("執行失敗，嘗試重連: $e");
      await connect(force: true);
      return await action();
    }
  }

  // --- User ---
  static Future<AppUser?> login(String email, String password) async {
    String res = await _exec(
      () => SqlConn.readData(
        "SELECT * FROM Users WHERE Email='$email' AND PasswordHash='$password'",
      ),
    );
    if (res == "[]" || res.isEmpty) return null;
    return AppUser.fromMap(jsonDecode(res)[0]);
  }

  static Future<void> registerUser(
    String email,
    String pass,
    String name,
    String role,
  ) async {
    await _exec(
      () => SqlConn.writeData(
        "INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES ('$email', '$pass', N'$name', '$role')",
      ),
    );
  }

  static Future<void> updateUserName(String email, String newName) async {
    await _exec(
      () => SqlConn.writeData(
        "UPDATE Users SET Name = N'$newName' WHERE Email = '$email'",
      ),
    );
  }

  // --- Class ---
  static Future<void> createClass(String name, String teacherEmail) async {
    var res = await _exec(
      () => SqlConn.readData(
        "SELECT UserID FROM Users WHERE Email = '$teacherEmail'",
      ),
    );
    if (res == "[]") throw Exception("找不到使用者");
    var uid = jsonDecode(res)[0]['UserID'];

    String code =
        'C${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}';
    await _exec(
      () => SqlConn.writeData(
        "INSERT INTO Classes (ClassName, TeacherID, InvitationCode) VALUES (N'$name', $uid, '$code')",
      ),
    );
  }

  static Future<List<Class>> getTeacherClasses(String email) async {
    String sql =
        "SELECT * FROM Classes WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '$email')";
    return _parseClasses(await _exec(() => SqlConn.readData(sql)));
  }

  static Future<List<Student>> getClassStudents(String classId) async {
    String sql =
        "SELECT u.UserID, u.Name FROM Users u JOIN ClassMembers cm ON u.UserID = cm.StudentID WHERE cm.ClassID = $classId";
    var res = await _exec(() => SqlConn.readData(sql));
    if (res.isEmpty || res == "[]") return [];
    return (jsonDecode(res) as List)
        .map((j) => Student(id: j['UserID'].toString(), name: j['Name']))
        .toList();
  }

  static Future<List<Class>> getStudentClasses(String email) async {
    String sql =
        "SELECT c.* FROM Classes c JOIN ClassMembers cm ON c.ClassID = cm.ClassID WHERE cm.StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    return _parseClasses(await _exec(() => SqlConn.readData(sql)));
  }

  static Future<Class?> joinClass(String code, String email) async {
    var classes = _parseClasses(
      await _exec(
        () => SqlConn.readData(
          "SELECT * FROM Classes WHERE InvitationCode = '$code'",
        ),
      ),
    );
    if (classes.isEmpty) throw Exception("找不到班級");
    Class target = classes.first;
    await _exec(
      () => SqlConn.writeData(
        "INSERT INTO ClassMembers (ClassID, StudentID) VALUES (${target.id}, (SELECT UserID FROM Users WHERE Email = '$email'))",
      ),
    );
    return target;
  }

  // --- Interview ---
  static Future<void> saveRecord(
    String sid,
    int duration,
    String type,
    String interviewer,
    String lang,
    int score,
    bool saveVideo,
  ) async {
    String privacy = 'Private';
    String sql =
        """
      INSERT INTO InterviewRecords (StudentID, DurationSeconds, QuestionType, Interviewer, Language, HasVideo, PrivacyLevel, OverallScore, EmotionScore, CompletenessScore, FluencyScore, ConfidenceScore)
      VALUES ($sid, $duration, N'$type', N'$interviewer', '$lang', ${saveVideo ? 1 : 0}, '$privacy', $score, 80, 70, 90, 75)
    """;
    await _exec(() => SqlConn.writeData(sql));
  }

  static Future<List<InterviewRecord>> getRecords(
    String userId,
    String privacyFilter,
  ) async {
    String sql;
    if (privacyFilter == 'All') {
      sql =
          "SELECT r.*, u.Name as StudentName FROM InterviewRecords r JOIN Users u ON r.StudentID=u.UserID WHERE StudentID=$userId ORDER BY InterviewDate DESC";
    } else {
      sql =
          "SELECT r.*, u.Name as StudentName FROM InterviewRecords r JOIN Users u ON r.StudentID=u.UserID WHERE PrivacyLevel='$privacyFilter' OR PrivacyLevel='Platform' ORDER BY InterviewDate DESC";
    }
    String res = await _exec(() => SqlConn.readData(sql));
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map((x) => InterviewRecord.fromMap(x))
        .toList();
  }

  static Future<void> updatePrivacy(String recordId, String level) async {
    await _exec(
      () => SqlConn.writeData(
        "UPDATE InterviewRecords SET PrivacyLevel='$level' WHERE RecordID=$recordId",
      ),
    );
  }

  // --- Comments ---
  static Future<List<Comment>> getComments(String recordId) async {
    String sql =
        "SELECT c.Content, c.SentAt, u.Name FROM RecordComments c JOIN Users u ON c.SenderID=u.UserID WHERE RecordID=$recordId ORDER BY SentAt";
    String res = await _exec(() => SqlConn.readData(sql));
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map(
          (x) => Comment(
            senderName: x['Name'],
            content: x['Content'],
            date: x['SentAt'].toString().split('T')[1].substring(0, 5),
          ),
        )
        .toList();
  }

  static Future<void> sendComment(
    String recordId,
    String senderId,
    String content,
  ) async {
    await _exec(
      () => SqlConn.writeData(
        "INSERT INTO RecordComments (RecordID, SenderID, Content) VALUES ($recordId, $senderId, N'$content')",
      ),
    );
  }

  // --- Invitations ---
  static Future<List<Invitation>> getInvitations(
    String userId,
    bool isTeacher,
  ) async {
    String sql = isTeacher
        ? "SELECT i.InvitationID, i.Status, i.Message, u.Name as SName, 'Me' as TName FROM Invitations i JOIN Users u ON i.StudentID=u.UserID WHERE TeacherID=$userId"
        : "SELECT i.InvitationID, i.Status, i.Message, 'Me' as SName, u.Name as TName FROM Invitations i JOIN Users u ON i.TeacherID=u.UserID WHERE StudentID=$userId AND Status='Pending'";
    String res = await _exec(() => SqlConn.readData(sql));
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map(
          (x) => Invitation(
            id: x['InvitationID'].toString(),
            teacherName: x['TName'],
            studentName: x['SName'],
            status: x['Status'],
            message: x['Message'],
          ),
        )
        .toList();
  }

  static Future<void> updateInvitation(String id, String status) async {
    await _exec(
      () => SqlConn.writeData(
        "UPDATE Invitations SET Status='$status' WHERE InvitationID=$id",
      ),
    );
  }

  // --- Portfolio ---
  static Future<void> addPortfolio(String email, String title) async {
    await _exec(
      () => SqlConn.writeData(
        "INSERT INTO LearningPortfolios (StudentID, Title, StoragePath) VALUES ((SELECT UserID FROM Users WHERE Email = '$email'), N'$title', 'path')",
      ),
    );
  }

  static Future<List<LearningPortfolio>> getPortfolios(String email) async {
    String sql =
        "SELECT * FROM LearningPortfolios WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    var res = await _exec(() => SqlConn.readData(sql));
    if (res.isEmpty || res == "[]") return [];
    return (jsonDecode(res) as List)
        .map(
          (x) => LearningPortfolio(
            id: x['PortfolioID'].toString(),
            title: x['Title'],
            uploadDate: x['UploadDate'].toString().split('T')[0],
          ),
        )
        .toList();
  }

  static Future<void> sendInvitation(
    String teacherEmail,
    String studentId,
    String msg,
  ) async {
    await _exec(
      () => SqlConn.writeData(
        "INSERT INTO Invitations (TeacherID, StudentID, Message) VALUES ((SELECT UserID FROM Users WHERE Email = '$teacherEmail'), $studentId, N'$msg')",
      ),
    );
  }

  static List<Class> _parseClasses(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == "[]") return [];
    try {
      return (jsonDecode(jsonStr) as List)
          .map((x) => Class.fromMap(x))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
