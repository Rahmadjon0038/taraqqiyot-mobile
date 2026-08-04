import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/models/auth_session.dart';

class TeacherServiceException implements Exception {
  const TeacherServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Teacher roli uchun barcha API chaqiruvlar:
/// guruhlar, davomat, ball qo'yish va to'lov snapshotlari.
class TeacherService {
  TeacherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(AuthSession session) => {
    'Authorization': 'Bearer ${session.accessToken}',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (_) {
      return const {};
    }
  }

  void _ensureSuccess(
    http.Response response,
    Map<String, dynamic> payload,
    String fallbackMessage,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TeacherServiceException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            fallbackMessage,
        statusCode: response.statusCode,
      );
    }
  }

  /// Teacherning o'z guruhlari (bugungi davomat holati bilan)
  Future<List<TeacherGroup>> fetchMyGroups(AuthSession session) async {
    final response = await _client
        .get(_uri('/api/attendance/my-groups'), headers: _headers(session))
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Guruhlar yuklanmadi');

    final data = payload['data'];
    if (data is! List) return const <TeacherGroup>[];
    return data
        .whereType<Map>()
        .map((item) => TeacherGroup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Guruh tafsilotlari va o'quvchilar ro'yxati.
  /// [month] berilsa o'quvchilarning balli o'sha oy uchun keladi (YYYY-MM).
  Future<TeacherGroupDetail> fetchGroupDetail(
    AuthSession session,
    int groupId, {
    String? month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/groups/$groupId', {
            if (month != null && month.isNotEmpty) 'month': month,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Guruh ma\'lumotlari yuklanmadi');

    return TeacherGroupDetail.fromJson(payload);
  }

  /// O'quvchiga ball qo'shish/ayirish
  Future<void> createPointEvent(
    AuthSession session, {
    required int studentId,
    required int groupId,
    required int points,
    required String title,
    String? description,
    String sourceType = 'bonus',
  }) async {
    final response = await _client
        .post(
          _uri('/api/students/point-events'),
          headers: _headers(session),
          body: jsonEncode({
            'student_id': studentId,
            'group_id': groupId,
            'points': points,
            'title': title,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            'source_type': sourceType,
          }),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Ball qo\'shilmadi');
  }

  /// Tanlangan guruhning oylik darslari (schedule bo'yicha avto-generate)
  Future<List<TeacherLesson>> fetchGroupLessons(
    AuthSession session,
    int groupId, {
    String? month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/attendance/groups/$groupId/lessons', {
            if (month != null && month.isNotEmpty) 'month': month,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Darslar yuklanmadi');

    final data = payload['data'];
    final lessons = data is Map ? (data['lessons'] ?? data['data']) : data;
    if (lessons is! List) return const <TeacherLesson>[];
    return lessons
        .whereType<Map>()
        .map((item) => TeacherLesson.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Dars ichidagi o'quvchilar (davomat belgilash uchun)
  Future<List<LessonStudent>> fetchLessonStudents(
    AuthSession session,
    int lessonId,
  ) async {
    final response = await _client
        .get(
          _uri('/api/attendance/lessons/$lessonId/students'),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'O\'quvchilar yuklanmadi');

    final data = payload['data'];
    final students = data is Map ? (data['students'] ?? data['data']) : data;
    if (students is! List) return const <LessonStudent>[];
    return students
        .whereType<Map>()
        .map((item) => LessonStudent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Davomatni belgilash: {attendance_id: 'keldi'|'kelmadi'|'kechikdi'}
  Future<String> markAttendance(
    AuthSession session,
    int lessonId,
    Map<int, String> records,
  ) async {
    final response = await _client
        .put(
          _uri('/api/attendance/lessons/$lessonId/mark'),
          headers: _headers(session),
          body: jsonEncode({
            'attendance_records': [
              for (final entry in records.entries)
                {'attendance_id': entry.key, 'status': entry.value},
            ],
          }),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Davomat saqlanmadi');
    return payload['message']?.toString() ?? 'Davomat saqlandi';
  }

  /// O'z guruhlaridagi o'quvchilarning to'lov snapshotlari (faqat ko'rish)
  Future<TeacherPaymentsResponse> fetchPaymentSnapshots(
    AuthSession session, {
    required String month,
    int? groupId,
    int page = 1,
    int limit = 100,
    String? search,
  }) async {
    final response = await _client
        .get(
          _uri('/api/snapshots', {
            'month': month,
            if (groupId != null) 'group_id': groupId.toString(),
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            'page': page.toString(),
            'limit': limit.toString(),
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'To\'lov ma\'lumotlari yuklanmadi');

    return TeacherPaymentsResponse.fromJson(payload);
  }

  /// Guruh va oy bo'yicha oldin yuborilgan statistika hisobotlari.
  Future<List<TeacherLessonStatisticsReport>> fetchGroupLessonReports(
    AuthSession session,
    int groupId, {
    String? month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/teacher-statistics/groups/$groupId/reports', {
            if (month != null && month.isNotEmpty) 'month': month,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Statistikalar yuklanmadi');

    final data = payload['data'];
    if (data is! List) return const <TeacherLessonStatisticsReport>[];
    return data
        .whereType<Map>()
        .map(
          (item) => TeacherLessonStatisticsReport.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<TeacherLessonStatisticsReport> saveLessonStatistics(
    AuthSession session, {
    required int lessonId,
    required TeacherLessonStatisticsReport report,
  }) async {
    final response = await _client
        .post(
          _uri('/api/teacher-statistics/lessons/$lessonId'),
          headers: _headers(session),
          body: jsonEncode(report.toJson()),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Statistika saqlanmadi');

    final data = payload['data'];
    if (data is Map) {
      return TeacherLessonStatisticsReport.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return report;
  }

  Future<void> deleteLessonStatistics(
    AuthSession session,
    int lessonId,
  ) async {
    final response = await _client
        .delete(
          _uri('/api/teacher-statistics/lessons/$lessonId'),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Statistika o\'chirilmadi');
  }

  Future<List<ManagerTeacherStatistics>> fetchEnglishManagerTeacherStatistics(
    AuthSession session, {
    String? month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/teacher-statistics/manager/teachers', {
            if (month != null && month.isNotEmpty) 'month': month,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Teacherlar yuklanmadi');

    final data = payload['data'];
    if (data is! List) return const <ManagerTeacherStatistics>[];
    return data
        .whereType<Map>()
        .map(
          (item) => ManagerTeacherStatistics.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<ManagerDailyTeacherReport>> fetchEnglishManagerReports(
    AuthSession session, {
    required String month,
    int? teacherId,
    int? groupId,
  }) async {
    final params = <String, String>{'month': month};
    if (teacherId != null) params['teacher_id'] = teacherId.toString();
    if (groupId != null) params['group_id'] = groupId.toString();

    final response = await _client
        .get(
          _uri('/api/teacher-statistics/manager/reports', params),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    _ensureSuccess(response, payload, 'Statistikalar yuklanmadi');

    final data = payload['data'];
    if (data is! List) return const <ManagerDailyTeacherReport>[];
    return data
        .whereType<Map>()
        .map(
          (item) => ManagerDailyTeacherReport.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  void dispose() {
    _client.close();
  }
}

/// ---------------------------------------------------------------------------
/// Modellar
/// ---------------------------------------------------------------------------

class TeacherGroup {
  const TeacherGroup({
    required this.id,
    required this.name,
    required this.subjectName,
    required this.roomNumber,
    required this.studentsCount,
    required this.classStartDate,
    required this.todayLessonsCount,
    required this.todayActiveStudentsCount,
    required this.todayMarkedStudentsCount,
    required this.todayAttendanceCompleted,
    required this.todayAttendanceFullyCompleted,
    required this.todayReportSent,
    required this.todayReportFullySent,
    required this.scheduleDays,
    required this.scheduleTime,
  });

  final int id;
  final String name;
  final String subjectName;
  final String roomNumber;
  final int studentsCount;

  /// Dars kunlari ("dushanba", "chorshanba", ...) va vaqti ("14:00-16:00")
  final List<String> scheduleDays;
  final String scheduleTime;

  /// Guruhda dars boshlangan sana (davomat oylari shu oydan boshlanadi)
  final String classStartDate;
  final int todayLessonsCount;
  final int todayActiveStudentsCount;
  final int todayMarkedStudentsCount;
  final bool todayAttendanceCompleted;
  final bool todayAttendanceFullyCompleted;
  final bool todayReportSent;
  final bool todayReportFullySent;

  /// Dars boshlangan oyning birinchi kuni (parse bo'lmasa null)
  DateTime? get classStartMonth {
    final parsed = DateTime.tryParse(classStartDate);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month);
  }

  factory TeacherGroup.fromJson(Map<String, dynamic> json) {
    return TeacherGroup(
      id: _asInt(json['id'] ?? json['group_id']),
      name: _asString(json['name'] ?? json['group_name']),
      subjectName: _asString(json['subject_name']),
      roomNumber: _asString(json['room_number']),
      studentsCount: _asInt(json['students_count']),
      classStartDate: _asString(json['class_start_date']),
      todayLessonsCount: _asInt(json['today_lessons_count']),
      todayActiveStudentsCount: _asInt(json['today_active_students_count']),
      todayMarkedStudentsCount: _asInt(json['today_marked_students_count']),
      todayAttendanceCompleted: _asBool(json['today_attendance_completed']),
      todayAttendanceFullyCompleted: _asBool(
        json['today_attendance_fully_completed'],
      ),
      todayReportSent: _asBool(
        json['today_report_sent'],
      ),
      todayReportFullySent: _asBool(
        json['today_report_fully_sent'],
      ),
      scheduleDays: _parseScheduleDays(json['schedule']),
      scheduleTime: _parseScheduleTime(json['schedule']),
    );
  }

  static List<String> _parseScheduleDays(Object? schedule) {
    if (schedule is! Map) return const [];
    final days = schedule['days'];
    if (days is! List) return const [];
    return days
        .map((day) => day.toString().trim())
        .where((day) => day.isNotEmpty)
        .toList();
  }

  static String _parseScheduleTime(Object? schedule) {
    if (schedule is! Map) return '';
    return schedule['time']?.toString().trim() ?? '';
  }
}

class TeacherGroupDetail {
  const TeacherGroupDetail({
    required this.groupId,
    required this.groupName,
    required this.subjectName,
    required this.teacherName,
    required this.roomNumber,
    required this.students,
  });

  final int groupId;
  final String groupName;
  final String subjectName;
  final String teacherName;
  final String roomNumber;
  final List<TeacherGroupStudent> students;

  factory TeacherGroupDetail.fromJson(Map<String, dynamic> json) {
    final group = Map<String, dynamic>.from(json['group'] as Map? ?? const {});
    final studentsRaw = json['students'];
    return TeacherGroupDetail(
      groupId: _asInt(group['id']),
      groupName: _asString(group['name']),
      subjectName: _asString(group['subject_name']),
      teacherName: _asString(group['teacher_name']),
      roomNumber: _asString(group['room_number']),
      students: studentsRaw is List
          ? studentsRaw
                .whereType<Map>()
                .map(
                  (item) => TeacherGroupStudent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <TeacherGroupStudent>[],
    );
  }
}

class TeacherGroupStudent {
  const TeacherGroupStudent({
    required this.id,
    required this.name,
    required this.surname,
    required this.phone,
    required this.groupStatus,
    required this.avatarKey,
    required this.avatarUrl,
    required this.monthlyPoints,
  });

  final int id;
  final String name;
  final String surname;
  final String phone;

  /// active | stopped | finished
  final String groupStatus;
  final String avatarKey;
  final String avatarUrl;

  /// Joriy oyda yig'ilgan ball
  final int monthlyPoints;

  /// Familiya birinchi ko'rsatiladi
  String get fullName =>
      [surname, name].where((part) => part.trim().isNotEmpty).join(' ');

  bool get isActive => groupStatus == 'active';

  factory TeacherGroupStudent.fromJson(Map<String, dynamic> json) {
    return TeacherGroupStudent(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      surname: _asString(json['surname']),
      phone: _asString(json['phone']),
      groupStatus: _asString(json['group_status']),
      avatarKey: _asString(json['avatar_key']),
      avatarUrl: _asString(json['avatar_url']),
      monthlyPoints: _asInt(json['monthly_points']),
    );
  }
}

class TeacherLesson {
  const TeacherLesson({
    required this.id,
    required this.date,
    required this.formattedDate,
    required this.startTime,
    required this.endTime,
    required this.lessonStatus,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.activeStudentsCount,
    required this.markedStudentsCount,
    required this.attendanceState,
    required this.attendanceCompleted,
  });

  final int id;

  /// YYYY-MM-DD — saralash va hafta kunini aniqlash uchun
  final String date;
  final String formattedDate;
  final String startTime;
  final String endTime;
  final String lessonStatus;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int activeStudentsCount;
  final int markedStudentsCount;

  /// not_marked | partial | marked | completed
  final String attendanceState;
  final bool attendanceCompleted;

  /// Hafta kuni nomi (Dushanba, Seshanba, ...)
  String get weekdayName {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    const names = [
      'Dushanba',
      'Seshanba',
      'Chorshanba',
      'Payshanba',
      'Juma',
      'Shanba',
      'Yakshanba',
    ];
    return names[parsed.weekday - 1];
  }

  factory TeacherLesson.fromJson(Map<String, dynamic> json) {
    return TeacherLesson(
      id: _asInt(json['id'] ?? json['lesson_id']),
      date: _asString(json['date'] ?? json['lesson_date']),
      formattedDate: _asString(json['formatted_date'] ?? json['lesson_date']),
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
      lessonStatus: _asString(json['lesson_status']),
      presentCount: _asInt(json['present_count']),
      absentCount: _asInt(json['absent_count']),
      lateCount: _asInt(json['late_count']),
      activeStudentsCount: _asInt(json['active_students_count']),
      markedStudentsCount: _asInt(json['marked_students_count']),
      attendanceState: _asString(json['attendance_state']),
      attendanceCompleted: _asBool(json['attendance_completed']),
    );
  }
}

class LessonStudent {
  const LessonStudent({
    required this.attendanceId,
    required this.studentId,
    required this.studentName,
    required this.phone,
    required this.monthlyStatus,
    required this.status,
    required this.canMark,
  });

  final int attendanceId;
  final int studentId;
  final String studentName;
  final String phone;
  final String monthlyStatus;

  /// keldi | kelmadi | kechikdi | '' (belgilanmagan)
  final String status;
  final bool canMark;

  factory LessonStudent.fromJson(Map<String, dynamic> json) {
    final name = _asString(json['student_name']);
    return LessonStudent(
      attendanceId: _asInt(json['attendance_id']),
      studentId: _asInt(json['student_id']),
      studentName: name.isNotEmpty
          ? name
          : '${_asString(json['name'])} ${_asString(json['surname'])}'.trim(),
      phone: _asString(json['phone']),
      monthlyStatus: _asString(json['monthly_status']),
      status: _asString(json['status']),
      canMark: _asBool(json['can_mark'], fallback: true),
    );
  }
}

class TeacherPaymentsResponse {
  const TeacherPaymentsResponse({
    required this.snapshots,
    required this.summary,
  });

  final List<PaymentSnapshot> snapshots;
  final TeacherPaymentsSummary summary;

  factory TeacherPaymentsResponse.fromJson(Map<String, dynamic> json) {
    // Backend: { data: { students: [...], summary: {...} } }
    final data = json['data'];
    final inner = data is Map ? Map<String, dynamic>.from(data) : json;
    final studentsRaw = data is List
        ? data
        : (inner['students'] ?? inner['data']);
    final summaryRaw = inner['summary'] ?? json['summary'];
    return TeacherPaymentsResponse(
      snapshots: studentsRaw is List
          ? studentsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      PaymentSnapshot.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <PaymentSnapshot>[],
      summary: TeacherPaymentsSummary.fromJson(
        summaryRaw is Map
            ? Map<String, dynamic>.from(summaryRaw)
            : const <String, dynamic>{},
      ),
    );
  }
}

class PaymentSnapshot {
  const PaymentSnapshot({
    required this.studentId,
    required this.studentName,
    required this.studentSurname,
    required this.studentPhone,
    required this.groupId,
    required this.groupName,
    required this.subjectName,
    required this.monthlyStatus,
    required this.paymentStatus,
    required this.requiredAmount,
    required this.paidAmount,
    required this.discountAmount,
    required this.debtAmount,
    required this.lastPaymentDate,
    required this.attendedLessons,
    required this.totalLessons,
    required this.attendancePercentage,
    required this.markedLessons,
    required this.attendedMarkedLessons,
    required this.missedMarkedLessons,
  });

  final int studentId;
  final String studentName;
  final String studentSurname;
  final String studentPhone;
  final int groupId;
  final String groupName;
  final String subjectName;
  final String monthlyStatus;

  /// paid | partial | unpaid
  final String paymentStatus;
  final double requiredAmount;
  final double paidAmount;
  final double discountAmount;
  final double debtAmount;
  final String lastPaymentDate;
  final int attendedLessons;
  final int totalLessons;
  final double attendancePercentage;

  /// Faqat davomat qilingan (belgilangan) darslar — hali belgilanmagan
  /// kunlar "qoldirilgan" deb sanalmasligi uchun shulardan foydalaniladi
  final int markedLessons;
  final int attendedMarkedLessons;
  final int missedMarkedLessons;

  /// Familiya birinchi
  String get fullName => [
    studentSurname,
    studentName,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  factory PaymentSnapshot.fromJson(Map<String, dynamic> json) {
    return PaymentSnapshot(
      studentId: _asInt(json['student_id']),
      studentName: _asString(json['student_name']),
      studentSurname: _asString(json['student_surname']),
      studentPhone: _asString(json['student_phone']),
      groupId: _asInt(json['group_id']),
      groupName: _asString(json['group_name']),
      subjectName: _asString(json['subject_name']),
      monthlyStatus: _asString(json['monthly_status']),
      paymentStatus: _asString(json['payment_status']),
      requiredAmount: _asDouble(json['required_amount']),
      paidAmount: _asDouble(json['paid_amount']),
      discountAmount: _asDouble(json['discount_amount']),
      debtAmount: _asDouble(json['debt_amount']),
      lastPaymentDate: _asString(json['last_payment_date']),
      attendedLessons: _asInt(json['attended_lessons']),
      totalLessons: _asInt(json['total_lessons']),
      attendancePercentage: _asDouble(json['attendance_percentage']),
      markedLessons: _asInt(json['marked_lessons']),
      attendedMarkedLessons: _asInt(json['attended_marked_lessons']),
      missedMarkedLessons: _asInt(json['missed_marked_lessons']),
    );
  }
}

class TeacherLessonStatisticsReport {
  const TeacherLessonStatisticsReport({
    required this.lessonId,
    required this.lessonLabel,
    required this.groupName,
    required this.createdAt,
    required this.rows,
  });

  final int lessonId;
  final String lessonLabel;
  final String groupName;
  final String createdAt;
  final List<TeacherLessonStatisticsRowReport> rows;

  Map<String, dynamic> toJson() => {
    'lesson_id': lessonId,
    'lesson_label': lessonLabel,
    'group_name': groupName,
    'created_at': createdAt,
    'rows': rows.map((row) => row.toJson()).toList(),
  };

  factory TeacherLessonStatisticsReport.fromJson(Map<String, dynamic> json) {
    final rowsRaw = json['rows'];
    return TeacherLessonStatisticsReport(
      lessonId: _asInt(json['lesson_id']),
      lessonLabel: _asString(json['lesson_label']),
      groupName: _asString(json['group_name']),
      createdAt: _asString(json['created_at']),
      rows: rowsRaw is List
          ? rowsRaw
                .whereType<Map>()
                .map(
                  (item) => TeacherLessonStatisticsRowReport.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <TeacherLessonStatisticsRowReport>[],
    );
  }
}

class TeacherLessonStatisticsRowReport {
  const TeacherLessonStatisticsRowReport({
    required this.studentId,
    required this.studentName,
    required this.homework,
    required this.vocabulary,
    required this.attendance,
    required this.participation,
    required this.total,
    required this.percent,
    required this.feedback,
  });

  final int studentId;
  final String studentName;
  final int homework;
  final int vocabulary;
  final int attendance;
  final int participation;
  final int total;
  final int percent;
  final String feedback;

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'student_name': studentName,
    'homework': homework,
    'vocabulary': vocabulary,
    'attendance': attendance,
    'participation': participation,
    'total': total,
    'percent': percent,
    'feedback': feedback,
  };

  factory TeacherLessonStatisticsRowReport.fromJson(Map<String, dynamic> json) {
    return TeacherLessonStatisticsRowReport(
      studentId: _asInt(json['student_id']),
      studentName: _asString(json['student_name']),
      homework: _asInt(json['homework']),
      vocabulary: _asInt(json['vocabulary']),
      attendance: _asInt(json['attendance']),
      participation: _asInt(json['participation']),
      total: _asInt(json['total']),
      percent: _asInt(json['percent']),
      feedback: _asString(json['feedback']),
    );
  }
}

class TeacherPaymentsSummary {
  const TeacherPaymentsSummary({
    required this.totalStudents,
    required this.paidStudents,
    required this.partialStudents,
    required this.unpaidStudents,
    required this.totalRequired,
    required this.totalPaid,
    required this.totalDebt,
  });

  final int totalStudents;
  final int paidStudents;
  final int partialStudents;
  final int unpaidStudents;
  final double totalRequired;
  final double totalPaid;
  final double totalDebt;

  factory TeacherPaymentsSummary.fromJson(Map<String, dynamic> json) {
    return TeacherPaymentsSummary(
      totalStudents: _asInt(json['total_students']),
      paidStudents: _asInt(json['paid_students']),
      partialStudents: _asInt(json['partial_students']),
      unpaidStudents: _asInt(json['unpaid_students']),
      totalRequired: _asDouble(json['total_required']),
      totalPaid: _asDouble(json['total_paid']),
      totalDebt: _asDouble(json['total_debt']),
    );
  }
}

class ManagerTeacherStatistics {
  const ManagerTeacherStatistics({
    required this.teacherId,
    required this.teacherName,
    required this.groupsCount,
    required this.reportsCount,
    required this.lastReportAt,
  });

  final int teacherId;
  final String teacherName;
  final int groupsCount;
  final int reportsCount;
  final String lastReportAt;

  factory ManagerTeacherStatistics.fromJson(Map<String, dynamic> json) {
    return ManagerTeacherStatistics(
      teacherId: _asInt(json['teacher_id']),
      teacherName: _asString(json['teacher_name']),
      groupsCount: _asInt(json['groups_count']),
      reportsCount: _asInt(json['reports_count']),
      lastReportAt: _asString(json['last_report_at']),
    );
  }
}

class ManagerDailyTeacherReport {
  const ManagerDailyTeacherReport({
    required this.id,
    required this.lessonId,
    required this.lessonDate,
    required this.lessonTime,
    required this.groupId,
    required this.groupName,
    required this.teacherId,
    required this.teacherName,
    required this.subjectName,
    required this.reportMonth,
    required this.total,
    required this.percent,
    required this.feedback,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int lessonId;
  final String lessonDate;
  final String lessonTime;
  final int groupId;
  final String groupName;
  final int teacherId;
  final String teacherName;
  final String subjectName;
  final String reportMonth;
  final int total;
  final int percent;
  final String feedback;
  final String createdAt;
  final String updatedAt;

  factory ManagerDailyTeacherReport.fromJson(Map<String, dynamic> json) {
    return ManagerDailyTeacherReport(
      id: _asInt(json['id']),
      lessonId: _asInt(json['lesson_id']),
      lessonDate: _asString(json['lesson_date']),
      lessonTime: _asString(json['lesson_time']),
      groupId: _asInt(json['group_id']),
      groupName: _asString(json['group_name']),
      teacherId: _asInt(json['teacher_id']),
      teacherName: _asString(json['teacher_name']),
      subjectName: _asString(json['subject_name']),
      reportMonth: _asString(json['report_month']),
      total: _asInt(json['total']),
      percent: _asInt(json['percent']),
      feedback: _asString(json['feedback']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }
}

String _asString(Object? value) {
  final text = value?.toString() ?? '';
  return text == 'null' ? '' : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase() ?? '';
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}
