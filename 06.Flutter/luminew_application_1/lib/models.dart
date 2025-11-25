// fileName: lib/models.dart

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String subscription; 

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.subscription = 'Free',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['UserID'].toString(),
      name: map['Name'],
      email: map['Email'],
      role: map['Role'],
      subscription: map['Subscription'] ?? 'Free',
    );
  }
}

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
      name: map['ClassName'],
      teacherId: map['TeacherID'].toString(),
      invitationCode: map['InvitationCode'],
    );
  }
}

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

class InterviewRecord {
  final String id;
  final String studentId;
  final DateTime date;
  final int durationSec;
  final Map<String, int> scores;
  final String type;
  final String interviewer;
  final String language;
  final String privacy;
  final String studentName; 

  InterviewRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.durationSec,
    required this.scores,
    required this.type,
    this.interviewer = 'AI 面試官', 
    this.language = '中文',
    this.privacy = 'Private',
    this.studentName = '',
  });

  int get overallScore => scores['overall'] ?? 0;

  factory InterviewRecord.fromMap(Map<String, dynamic> map) {
    return InterviewRecord(
      id: map['RecordID']?.toString() ?? '',
      studentId: map['StudentID']?.toString() ?? '',
      date: DateTime.tryParse(map['Date'].toString()) ?? DateTime.now(),
      durationSec: int.tryParse(map['Duration'].toString()) ?? 0,
      scores: {}, 
      type: map['Type'] ?? '通用型',
      interviewer: map['Interviewer'] ?? 'AI 面試官',
      language: map['Language'] ?? '中文',
      privacy: map['Privacy'] ?? 'Private',
      studentName: map['StudentName'] ?? '',
    );
  }
}

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

// ★ 修改：將 id 設為選填 (預設空字串)，解決 sql_service 沒傳 id 的報錯
class Comment {
  final String id;
  final String senderName;
  final String content;
  final String date;

  Comment({
    this.id = '', // 變成選填，解決報錯
    required this.senderName,
    required this.content,
    required this.date,
  });
}

// ★ 修改：補齊 teacherName, studentName, message, status 解決 common_screens 報錯
class Invitation {
  final String id;
  final String teacherName; // 對應 sql_service 的 teacherName
  final String studentName; // 對應 common_screens 的 studentName
  final String message;     // 對應 common_screens 的 message
  final String status;      // 對應 common_screens 的 status
  final String date;

  Invitation({
    this.id = '',
    this.teacherName = '未知老師',
    this.studentName = '未知學生',
    this.message = '',
    this.status = 'Pending',
    this.date = '',
  });
}
