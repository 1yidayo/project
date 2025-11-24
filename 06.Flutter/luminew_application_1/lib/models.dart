// lib/models.dart

/// 使用者資料模型
class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final int avatarIndex;
  final String subscription;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarIndex = 0,
    this.subscription = 'Free',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['UserID'].toString(),
      name: map['Name'] ?? '',
      email: map['Email'] ?? '',
      role: map['Role'] ?? 'Student',
      avatarIndex: map['AvatarIndex'] ?? 0,
      subscription: map['Subscription'] ?? 'Free',
    );
  }
}

/// 班級資料模型
class Class {
  final String id;
  final String name;
  final String teacherId;
  final String invitationCode;

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.invitationCode,
  });

  factory Class.fromMap(Map<String, dynamic> map) {
    return Class(
      id: map['ClassID'].toString(),
      name: map['ClassName'] ?? '',
      teacherId: map['TeacherID'].toString(),
      invitationCode: map['InvitationCode'] ?? '',
    );
  }
}

/// 學生資料模型 (老師查看用)
class Student {
  final String id;
  final String name;
  final int latestScore;
  final String latestInterviewDate;

  Student({
    required this.id,
    required this.name,
    this.latestScore = 0,
    this.latestInterviewDate = '無紀錄',
  });
}

/// 面試紀錄模型 (包含設定與分數)
class InterviewRecord {
  final String id;
  final String studentId;
  final String studentName; // 透過 SQL Join 取得
  final DateTime date;
  final int durationSec;

  // 設定欄位
  final String type; // SQL: QuestionType
  final String interviewer; // SQL: Interviewer
  final String language; // SQL: Language
  final String privacy; // SQL: PrivacyLevel

  // 分數欄位
  final int overallScore;
  final Map<String, int> scores;

  InterviewRecord({
    required this.id,
    required this.studentId,
    this.studentName = '',
    required this.date,
    required this.durationSec,
    required this.type,
    required this.interviewer,
    required this.language,
    required this.privacy,
    required this.overallScore,
    required this.scores,
  });

  factory InterviewRecord.fromMap(Map<String, dynamic> map) {
    return InterviewRecord(
      id: map['RecordID'].toString(),
      studentId: map['StudentID'].toString(),
      studentName: map['StudentName'] ?? '學生',
      date:
          DateTime.tryParse(map['InterviewDate'].toString()) ?? DateTime.now(),
      durationSec: map['DurationSeconds'] ?? 0,
      type: map['QuestionType'] ?? '通用型',
      interviewer: map['Interviewer'] ?? 'AI',
      language: map['Language'] ?? '中文',
      privacy: map['PrivacyLevel'] ?? 'Private',
      overallScore: map['OverallScore'] ?? 0,
      scores: {
        'emotion': map['EmotionScore'] ?? 0,
        'completeness': map['CompletenessScore'] ?? 0,
        'fluency': map['FluencyScore'] ?? 0,
        'confidence': map['ConfidenceScore'] ?? 0,
      },
    );
  }
}

/// 評語/留言模型
class Comment {
  final String senderName;
  final String content;
  final String date;

  Comment({
    required this.senderName,
    required this.content,
    required this.date,
  });
}

/// 面試邀請模型
class Invitation {
  final String id;
  final String teacherName;
  final String studentName;
  final String status;
  final String message;

  Invitation({
    required this.id,
    required this.teacherName,
    required this.studentName,
    required this.status,
    required this.message,
  });
}

/// 學習歷程檔案模型
class LearningPortfolio {
  final String id;
  final String title;
  final String uploadDate;

  LearningPortfolio({
    required this.id,
    required this.title,
    required this.uploadDate,
  });
}
