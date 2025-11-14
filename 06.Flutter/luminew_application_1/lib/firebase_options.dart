import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

// 修正：導入 app_models.dart 的絕對路徑
import 'package:luminew_application_1/models/app_models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 專案 ID，我們在 Console 中手動建立的
  final String _appId = 'Luminew';

  // --- Auth ---

  User? get currentUser => _auth.currentUser;

  // 註冊
  Future<void> signUp(
    String email,
    String password,
    UserRole role,
    String userName,
  ) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 註冊成功後，將角色和名稱寫入 User Profile
    if (userCredential.user != null) {
      final userId = userCredential.user!.uid;
      final userProfileRef = _db
          .collection('artifacts/$_appId/users/$userId/profiles')
          .doc(userId);
      await userProfileRef.set({
        'email': email,
        'role': role == UserRole.student ? 'student' : 'teacher',
        'userName': userName, // 儲存使用者名稱
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // 登入
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // 登出
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 獲取使用者角色
  Future<UserRole> getUserRole(String userId) async {
    final userProfileRef = _db
        .collection('artifacts/$_appId/users/$userId/profiles')
        .doc(userId);
    final doc = await userProfileRef.get();

    if (doc.exists && doc.data()!['role'] == 'teacher') {
      return UserRole.teacher;
    }
    // 預設為 student
    return UserRole.student;
  }

  // 獲取使用者名稱
  Future<String> getUserName(String userId) async {
    try {
      final userProfileRef = _db
          .collection('artifacts/$_appId/users/$userId/profiles')
          .doc(userId);
      final doc = await userProfileRef.get();
      if (doc.exists) {
        return doc.data()!['userName'] ?? '使用者';
      }
      return '使用者';
    } catch (e) {
      return '使用者';
    }
  }

  // --- 班級 (Classes) ---

  // 教師創建班級
  Future<Class> createClass(String className, String teacherId) async {
    final classRef = _db
        .collection('artifacts/$_appId/public/data/classes')
        .doc();
    final newClass = Class(
      id: classRef.id,
      name: className,
      teacherId: teacherId,
      invitationCode: (DateTime.now().millisecondsSinceEpoch % 1000000)
          .toString()
          .padLeft(6, '0'), // 簡易邀請碼
      studentIds: [],
    );

    await classRef.set(newClass.toFirestore());
    return newClass;
  }

  // 學生加入班級
  Future<Class> joinClass(String code, String studentId) async {
    final classQuery = await _db
        .collection('artifacts/$_appId/public/data/classes')
        .where('invitationCode', isEqualTo: code)
        .limit(1)
        .get();

    if (classQuery.docs.isEmpty) {
      throw Exception('無效的邀請碼');
    }

    final classDoc = classQuery.docs.first;
    final classRef = classDoc.reference;

    // 使用 Transaction 確保資料一致性
    await _db.runTransaction((transaction) async {
      transaction.update(classRef, {
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
    });

    return Class.fromFirestore(
      classDoc as DocumentSnapshot<Map<String, dynamic>>,
    );
  }

  // 獲取教師擁有的班級
  Stream<List<Class>> getTeacherClasses(String teacherId) {
    return _db
        .collection('artifacts/$_appId/public/data/classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Class.fromFirestore(doc)).toList(),
        );
  }

  // 獲取學生加入的班級
  Stream<List<Class>> getStudentClasses(String studentId) {
    return _db
        .collection('artifacts/$_appId/public/data/classes')
        .where('studentIds', arrayContains: studentId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Class.fromFirestore(doc)).toList(),
        );
  }

  // 獲取班級內的學生資料 (用於教師端)
  Future<List<Student>> getClassStudents(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];

    final List<Student> students = [];
    for (String id in studentIds) {
      try {
        final userProfileRef = _db
            .collection('artifacts/$_appId/users/$id/profiles')
            .doc(id);
        final doc = await userProfileRef.get();
        if (doc.exists) {
          students.add(Student.fromFirestore(doc));
        }
      } catch (e) {
        // Handle error
      }
    }
    return students;
  }

  // --- 面試紀錄 (Interviews) ---

  // 新增面試紀錄
  Future<void> addInterviewRecord(InterviewRecord record) async {
    await _db
        .collection('artifacts/$_appId/public/data/interviews')
        .add(record.toFirestore());
  }

  // 獲取學生的面試紀錄
  Stream<List<InterviewRecord>> getStudentInterviewRecords(String studentId) {
    return _db
        .collection('artifacts/$_appId/public/data/interviews')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InterviewRecord.fromFirestore(doc))
              .toList(),
        );
  }

  // --- 學習歷程檔案 (Portfolios) ---

  // 上傳檔案並新增紀錄
  Future<LearningPortfolio> addPortfolio(
    PlatformFile file,
    String studentId,
  ) async {
    final filePath =
        'artifacts/$_appId/users/$studentId/portfolios/${file.name}';
    final storageRef = _storage.ref(filePath);

    // 1. 上傳檔案到 Storage
    UploadTask uploadTask;
    if (file.bytes != null) {
      uploadTask = storageRef.putData(file.bytes!);
    } else {
      uploadTask = storageRef.putFile(File(file.path!));
    }

    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();

    // 2. 建立 Firestore 紀錄
    final docRef = _db
        .collection('artifacts/$_appId/users/$studentId/portfolios')
        .doc();
    final newPortfolio = LearningPortfolio(
      id: docRef.id,
      fileName: file.name,
      fileUrl: fileUrl,
      storagePath: filePath,
      uploadedAt: DateTime.now(),
      studentId: studentId,
    );

    await docRef.set(newPortfolio.toFirestore());
    return newPortfolio;
  }

  // 獲取學生的歷程檔案
  Stream<List<LearningPortfolio>> getPortfolios(String studentId) {
    return _db
        .collection('artifacts/$_appId/users/$studentId/portfolios')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LearningPortfolio.fromFirestore(doc))
              .toList(),
        );
  }

  // 刪除歷程檔案
  Future<void> deletePortfolio(LearningPortfolio portfolio) async {
    // 1. 從 Storage 刪除
    await _storage.ref(portfolio.storagePath).delete();

    // 2. 從 Firestore 刪除
    await _db
        .collection('artifacts/$_appId/users/${portfolio.studentId}/portfolios')
        .doc(portfolio.id)
        .delete();
  }

  // --- 聊天室 (Chats) ---

  // 獲取聊天訊息串流
  Stream<List<Map<String, dynamic>>> getChatStream(String chatKey) {
    return _db
        .collection('artifacts/$_appId/public/data/chats/$chatKey/messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  // 發送聊天訊息
  Future<void> sendChatMessage(
    String message,
    String userId,
    String chatKey,
    String userName,
  ) async {
    if (message.trim().isEmpty) return;

    await _db
        .collection('artifacts/$_appId/public/data/chats/$chatKey/messages')
        .add({
          'senderId': userId,
          'senderName': userName,
          'content': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
}

// 建立 FirebaseService 的單一實例
final firebaseService = FirebaseService();
