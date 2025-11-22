class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['UserID'].toString(),
      name: map['Name'],
      email: map['Email'],
      role: map['Role'],
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
  final int latestScore; // 暫時用 Mock
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

  InterviewRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.durationSec,
    required this.scores,
    required this.type,
  });

  int get overallScore => scores['overall'] ?? 0;
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
