import 'dart:convert';
import 'package:sql_conn/sql_conn.dart';
import 'models.dart';

class SqlService {
  static const String _ip = "10.0.2.2";
  static const String _port = "1433";
  static const String _dbName = "LuminewDB";
  static const String _user = "sa";
  static const String _pass = "112233";

  // 1. 強制連線邏輯
  static Future<void> connect({bool force = false}) async {
    try {
      // 如果強制重連，先斷開
      if (force) {
        try {
          await SqlConn.disconnect();
        } catch (_) {}
      }

      // 只有在沒連線時才連
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

  // 🛡️ 核心保護機制：讀取資料 (自動重連)
  static Future<String> _safeRead(String sql) async {
    try {
      await connect(); // 確保有連線
      return await SqlConn.readData(sql);
    } catch (e) {
      // 偵測是否為連線中斷錯誤
      String err = e.toString().toLowerCase();
      if (err.contains("closed") ||
          err.contains("invalid state") ||
          err.contains("connection")) {
        print("⚠️ 連線中斷，正在嘗試重連...");
        await connect(force: true); // 強制重連
        return await SqlConn.readData(sql); // 再試一次
      }
      throw e; // 其他錯誤直接拋出
    }
  }

  // 🛡️ 核心保護機制：寫入資料 (自動重連)
  static Future<void> _safeWrite(String sql) async {
    try {
      await connect();
      await SqlConn.writeData(sql);
    } catch (e) {
      String err = e.toString().toLowerCase();
      if (err.contains("closed") ||
          err.contains("invalid state") ||
          err.contains("connection")) {
        print("⚠️ 連線中斷，正在嘗試重連...");
        await connect(force: true);
        await SqlConn.writeData(sql);
      } else {
        throw e;
      }
    }
  }

  // --- 以下功能全部改用 _safeRead 和 _safeWrite ---

  // 2. 登入
  static Future<AppUser?> login(String email, String password) async {
    String sql =
        "SELECT * FROM Users WHERE Email = '$email' AND PasswordHash = '$password'";
    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return null;
      return AppUser.fromMap(jsonDecode(res)[0]);
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // 3. 註冊
  static Future<void> registerUser(
    String email,
    String password,
    String name,
    String role,
  ) async {
    String check = await _safeRead(
      "SELECT * FROM Users WHERE Email = '$email'",
    );
    if (check != "[]" && check.isNotEmpty) throw Exception("此 Email 已被註冊");

    String sql =
        "INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES ('$email', '$password', N'$name', '$role')";
    await _safeWrite(sql);
  }

  // 4. 更新姓名
  static Future<void> updateUserName(String email, String newName) async {
    String sql = "UPDATE Users SET Name = N'$newName' WHERE Email = '$email'";
    await _safeWrite(sql);
  }

  // --- 班級相關 ---
  static Future<void> createClass(String name, String teacherEmail) async {
    var res = await _safeRead(
      "SELECT UserID FROM Users WHERE Email = '$teacherEmail'",
    );
    if (res == "[]") throw Exception("找不到使用者");
    var uid = jsonDecode(res)[0]['UserID'];

    String code =
        'C' + DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13);
    String sql =
        "INSERT INTO Classes (ClassName, TeacherID, InvitationCode) VALUES (N'$name', $uid, '$code')";
    await _safeWrite(sql);
  }

  static Future<List<Class>> getTeacherClasses(String email) async {
    String sql =
        "SELECT * FROM Classes WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '$email')";
    return _parseClasses(await _safeRead(sql));
  }

  static Future<List<Student>> getClassStudents(String classId) async {
    String sql =
        "SELECT u.UserID, u.Name FROM Users u JOIN ClassMembers cm ON u.UserID = cm.StudentID WHERE cm.ClassID = $classId";
    var res = await _safeRead(sql);
    if (res.isEmpty || res == "[]") return [];
    return (jsonDecode(res) as List)
        .map((j) => Student(id: j['UserID'].toString(), name: j['Name']))
        .toList();
  }

  static Future<List<Class>> getStudentClasses(String email) async {
    String sql =
        "SELECT c.* FROM Classes c JOIN ClassMembers cm ON c.ClassID = cm.ClassID WHERE cm.StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    return _parseClasses(await _safeRead(sql));
  }

  static Future<Class?> joinClass(String code, String email) async {
    String findSql = "SELECT * FROM Classes WHERE InvitationCode = '$code'";
    var classes = _parseClasses(await _safeRead(findSql));
    if (classes.isEmpty) throw Exception("找不到班級");

    Class target = classes.first;
    try {
      String joinSql =
          "INSERT INTO ClassMembers (ClassID, StudentID) VALUES (${target.id}, (SELECT UserID FROM Users WHERE Email = '$email'))";
      await _safeWrite(joinSql);
      return target;
    } catch (e) {
      throw Exception("已加入過或發生錯誤");
    }
  }

  // --- 其他 ---
  static Future<void> addPortfolio(String email, String title) async {
    String sql =
        "INSERT INTO LearningPortfolios (StudentID, Title, StoragePath) VALUES ((SELECT UserID FROM Users WHERE Email = '$email'), N'$title', 'path')";
    await _safeWrite(sql);
  }

  static Future<List<LearningPortfolio>> getPortfolios(String email) async {
    String sql =
        "SELECT * FROM LearningPortfolios WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    var res = await _safeRead(sql);
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
    String sql =
        "INSERT INTO Invitations (TeacherID, StudentID, Message) VALUES ((SELECT UserID FROM Users WHERE Email = '$teacherEmail'), $studentId, N'$msg')";
    await _safeWrite(sql);
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
