import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/models/auth_session.dart';

class StudentAttendanceException implements Exception {
  const StudentAttendanceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StudentAttendanceService {
  StudentAttendanceService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query);
  }

  Future<StudentAttendanceDetail> fetchAttendanceDetail(
    AuthSession session, {
    required int groupId,
    required String month,
    int? studentId,
  }) async {
    final response = await _client
        .get(
          _uri('/api/snapshots/attendance', {
            'group_id': groupId.toString(),
            'month': month,
            if (studentId != null) 'student_id': studentId.toString(),
          }),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudentAttendanceException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Davomat ma\'lumotlari yuklanmadi',
        statusCode: response.statusCode,
      );
    }

    final data = payload['data'];
    if (data is! Map) {
      throw const StudentAttendanceException('Davomat ma\'lumotlari topilmadi');
    }

    return StudentAttendanceDetail.fromJson(Map<String, dynamic>.from(data));
  }

  void dispose() {
    _client.close();
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{'data': decoded};
  }
}

class StudentAttendanceDetail {
  const StudentAttendanceDetail({
    required this.studentInfo,
    required this.groupInfo,
    required this.month,
    required this.monthlyStatus,
    required this.statistics,
    required this.breakdown,
    required this.dailyAttendance,
    required this.snapshotInfo,
  });

  final StudentAttendanceStudentInfo studentInfo;
  final StudentAttendanceGroupInfo groupInfo;
  final String month;
  final String monthlyStatus;
  final StudentAttendanceStatistics statistics;
  final StudentAttendanceBreakdown breakdown;
  final List<StudentAttendanceDailyLesson> dailyAttendance;
  final StudentAttendanceSnapshotInfo snapshotInfo;

  factory StudentAttendanceDetail.fromJson(Map<String, dynamic> json) {
    final studentInfo = Map<String, dynamic>.from(
      json['student_info'] as Map? ?? const {},
    );
    final groupInfo = Map<String, dynamic>.from(
      json['group_info'] as Map? ?? const {},
    );
    final statistics = Map<String, dynamic>.from(
      json['attendance_statistics'] as Map? ?? const {},
    );
    final breakdown = Map<String, dynamic>.from(
      json['attendance_breakdown'] as Map? ?? const {},
    );
    final snapshotInfo = Map<String, dynamic>.from(
      json['snapshot_info'] as Map? ?? const {},
    );
    final dailyAttendanceRaw = json['daily_attendance'];
    final dailyAttendance = dailyAttendanceRaw is List
        ? dailyAttendanceRaw
              .whereType<Map>()
              .map(
                (item) => StudentAttendanceDailyLesson.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <StudentAttendanceDailyLesson>[];

    return StudentAttendanceDetail(
      studentInfo: StudentAttendanceStudentInfo.fromJson(studentInfo),
      groupInfo: StudentAttendanceGroupInfo.fromJson(groupInfo),
      month: _asString(json['month']),
      monthlyStatus: _asString(json['monthly_status']),
      statistics: StudentAttendanceStatistics.fromJson(statistics),
      breakdown: StudentAttendanceBreakdown.fromJson(breakdown),
      dailyAttendance: dailyAttendance,
      snapshotInfo: StudentAttendanceSnapshotInfo.fromJson(snapshotInfo),
    );
  }
}

extension StudentAttendanceDetailStyle on StudentAttendanceDetail {
  String get monthlyStatusLabel {
    switch (monthlyStatus.toLowerCase()) {
      case 'active':
        return 'Faol';
      case 'stopped':
        return 'To\'xtagan';
      case 'finished':
        return 'Bitirgan';
      default:
        return monthlyStatus.isEmpty ? 'Noma\'lum' : monthlyStatus;
    }
  }

  Color get statusBackground {
    switch (monthlyStatus.toLowerCase()) {
      case 'active':
        return const Color(0xFFEAF8EE);
      case 'stopped':
        return const Color(0xFFFFF4D6);
      case 'finished':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get statusForeground {
    switch (monthlyStatus.toLowerCase()) {
      case 'active':
        return const Color(0xFF0E8C45);
      case 'stopped':
        return const Color(0xFFB45309);
      case 'finished':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class StudentAttendanceStudentInfo {
  const StudentAttendanceStudentInfo({
    required this.id,
    required this.name,
    required this.surname,
    required this.phone,
  });

  final int id;
  final String name;
  final String surname;
  final String phone;

  String get fullName =>
      [surname, name].where((part) => part.trim().isNotEmpty).join(' ');

  factory StudentAttendanceStudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceStudentInfo(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      surname: _asString(json['surname']),
      phone: _asString(json['phone']),
    );
  }
}

class StudentAttendanceGroupInfo {
  const StudentAttendanceGroupInfo({
    required this.id,
    required this.name,
    required this.subject,
    required this.teacher,
  });

  final int id;
  final String name;
  final String subject;
  final String teacher;

  factory StudentAttendanceGroupInfo.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceGroupInfo(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      subject: _asString(json['subject']),
      teacher: _asString(json['teacher']),
    );
  }
}

class StudentAttendanceStatistics {
  const StudentAttendanceStatistics({
    required this.totalLessons,
    required this.attendedLessons,
    required this.missedLessons,
    required this.attendancePercentage,
    required this.status,
  });

  final int totalLessons;
  final int attendedLessons;
  final int missedLessons;
  final int attendancePercentage;
  final String status;

  factory StudentAttendanceStatistics.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceStatistics(
      totalLessons: _asInt(json['total_lessons']),
      attendedLessons: _asInt(json['attended_lessons']),
      missedLessons: _asInt(json['missed_lessons']),
      attendancePercentage: _asInt(json['attendance_percentage']),
      status: _asString(json['status']),
    );
  }
}

class StudentAttendanceBreakdown {
  const StudentAttendanceBreakdown({
    required this.keldi,
    required this.kelmadi,
    required this.kechikdi,
    required this.kelmagan,
    required this.notJoinedYet,
  });

  final int keldi;
  final int kelmadi;
  final int kechikdi;
  final int kelmagan;
  final int notJoinedYet;

  factory StudentAttendanceBreakdown.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceBreakdown(
      keldi: _asInt(json['keldi']),
      kelmadi: _asInt(json['kelmadi']),
      kechikdi: _asInt(json['kechikdi']),
      kelmagan: _asInt(json['kelmagan']),
      notJoinedYet: _asInt(json['not_joined_yet']),
    );
  }
}

class StudentAttendanceSnapshotInfo {
  const StudentAttendanceSnapshotInfo({
    required this.createdAt,
    required this.updatedAt,
    required this.isNewStudent,
  });

  final String createdAt;
  final String updatedAt;
  final bool isNewStudent;

  factory StudentAttendanceSnapshotInfo.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceSnapshotInfo(
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
      isNewStudent: json['is_new_student'] == true,
    );
  }
}

class StudentAttendanceDailyLesson {
  const StudentAttendanceDailyLesson({
    required this.lessonDate,
    required this.status,
    required this.isHoliday,
    required this.formattedDate,
    required this.markedAt,
  });

  final String lessonDate;
  final String? status;
  final bool isHoliday;
  final String formattedDate;
  final String markedAt;

  factory StudentAttendanceDailyLesson.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceDailyLesson(
      lessonDate: _asString(json['lesson_date']),
      status: json['status']?.toString(),
      isHoliday: json['is_holiday'] == true,
      formattedDate: _asString(json['formatted_date']),
      markedAt: _asString(json['marked_at']),
    );
  }
}

String _asString(Object? value) => value?.toString().trim() ?? '';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
