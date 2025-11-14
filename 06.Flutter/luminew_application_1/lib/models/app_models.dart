import 'package:cloud_firestore/cloud_firestore.dart';

// 模擬用戶角色
enum UserRole { unauthenticated, student, teacher }

// 班級資料模型
class Class {
  final String id;
  final String name;
  final String teacherId;
  final String invitationCode;
  final List<String> studentIds; // 班級內學生列表

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.invitationCode,
    this.studentIds = const [],
  });

  // Factory 函式：將 Firestore Map 轉換為 Dart Class 物件 (讀取)
  factory Class.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Class(
      id: doc.id,
      name: data['className'] ?? '未知班級',
      teacherId: data['teacherId'] ?? '',
      invitationCode: data['invitationCode'] ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
    );
  }

  // 將 Dart Class 物件轉換為 Firestore Map (寫入)
  Map<String, dynamic> toFirestore() {
    return {
      'className': name,
      'teacherId': teacherId,
      'invitationCode': invitationCode,
      'studentIds': studentIds,
      'createdAt': FieldValue.serverTimestamp(), // 新增時自動加入時間戳
    };
  }
}

// 學生資料模型
class Student {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  // 從 Firestore 讀取
  factory Student.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Student(
      id: doc.id,
      name: data['userName'] ?? '未知使用者',
      email: data['email'] ?? '',
      role: (data['role'] == 'teacher') ? UserRole.teacher : UserRole.student,
    );
  }
}

// 面試紀錄模型
class InterviewRecord {
  final String id;
  final String studentId;
  final DateTime date;
  final int durationSec;
  final int overallScore;
  final Map<String, int> scores; // 雷達圖分數
  final String interviewType;
  final String? videoUrl;

  InterviewRecord({
    required this.id,
    required this.studentId,
    required this.date,
    this.durationSec = 0,
    this.overallScore = 0,
    this.scores = const {},
    this.interviewType = '通用型',
    this.videoUrl,
  });

  // 從 Firestore 讀取
  factory InterviewRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return InterviewRecord(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      durationSec: data['durationSec'] ?? 0,
      overallScore: data['overallScore'] ?? 0,
      scores: Map<String, int>.from(data['scores'] ?? {}),
      interviewType: data['type'] ?? '通用型',
      videoUrl: data['videoUrl'],
    );
  }

  // 寫入 Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'date': Timestamp.fromDate(date),
      'durationSec': durationSec,
      'overallScore': overallScore,
      'scores': scores,
      'type': interviewType,
      'videoUrl': videoUrl,
    };
  }
}

// 學習歷程檔案模型
class LearningPortfolio {
  final String id;
  final String fileName;
  final String fileUrl;
  final String storagePath;
  final DateTime uploadedAt;
  final String studentId;

  LearningPortfolio({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.storagePath,
    required this.uploadedAt,
    required this.studentId,
  });

  // 從 Firestore 讀取
  factory LearningPortfolio.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return LearningPortfolio(
      id: doc.id,
      fileName: data['fileName'] ?? '未知檔案',
      fileUrl: data['fileUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp? ?? Timestamp.now())
          .toDate(),
      studentId: data['studentId'] ?? '',
    );
  }

  // 寫入 Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'studentId': studentId,
    };
  }
}
