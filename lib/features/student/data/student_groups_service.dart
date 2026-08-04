import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/models/auth_session.dart';

class StudentGroupsException implements Exception {
  const StudentGroupsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StudentGroupsService {
  StudentGroupsService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<List<StudentGroupSummary>> fetchMyGroups(AuthSession session) async {
    final response = await _client
        .get(
          _uri('/api/students/my-groups'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudentGroupsException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Guruhlar yuklanmadi',
        statusCode: response.statusCode,
      );
    }

    final data = payload['data'];
    final groups = data is Map ? data['groups'] : payload['groups'];
    if (groups is! List) {
      return const <StudentGroupSummary>[];
    }

    return groups
        .whereType<Map>()
        .map(
          (group) =>
              StudentGroupSummary.fromJson(Map<String, dynamic>.from(group)),
        )
        .toList();
  }

  Future<StudentGroupDetails> fetchMyGroupInfo(
    AuthSession session,
    int groupId, {
    String? month,
  }) async {
    var uri = _uri('/api/students/my-group-info/$groupId');
    if (month != null && month.trim().isNotEmpty) {
      uri = uri.replace(queryParameters: {'month': month.trim()});
    }
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer ${session.accessToken}'})
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudentGroupsException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Guruh ma\'lumotlari yuklanmadi',
        statusCode: response.statusCode,
      );
    }

    final data = payload['data'];
    if (data is! Map) {
      throw const StudentGroupsException('Guruh ma\'lumotlari topilmadi');
    }

    return StudentGroupDetails.fromJson(
      Map<String, dynamic>.from(data),
      currentUserId: session.user.id,
    );
  }

  Future<StudentPointReportsData> fetchMyPointReports(
    AuthSession session, {
    String? month,
    int? groupId,
  }) async {
    final params = <String, String>{};
    if (month != null && month.trim().isNotEmpty) {
      params['month'] = month.trim();
    }
    if (groupId != null) {
      params['group_id'] = groupId.toString();
    }

    final response = await _client
        .get(
          _uri(
            '/api/students/my-point-reports',
          ).replace(queryParameters: params),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudentGroupsException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Ballar tarixi yuklanmadi',
        statusCode: response.statusCode,
      );
    }

    final data = payload['data'];
    if (data is! Map) {
      throw const StudentGroupsException('Ballar ma\'lumotlari topilmadi');
    }

    return StudentPointReportsData.fromJson(Map<String, dynamic>.from(data));
  }

  Future<StudentPointEvent?> createPointEvent(
    AuthSession session, {
    required int studentId,
    required int groupId,
    required int points,
    required String title,
    String? description,
    String? sourceType,
  }) async {
    final response = await _client
        .post(
          _uri('/api/students/point-events'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'student_id': studentId,
            'group_id': groupId,
            'points': points,
            'title': title,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            if (sourceType != null && sourceType.trim().isNotEmpty)
              'source_type': sourceType.trim(),
          }),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudentGroupsException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Ball qo\'shilmadi',
        statusCode: response.statusCode,
      );
    }

    final data = payload['data'];
    if (data is! Map) return null;
    return StudentPointEvent.fromJson(Map<String, dynamic>.from(data));
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

class StudentGroupSummary {
  const StudentGroupSummary({
    required this.groupId,
    required this.groupName,
    required this.uniqueCode,
    required this.price,
    required this.subjectName,
    required this.teacherName,
    required this.teacherPhone,
    required this.roomNumber,
    required this.groupStatus,
    required this.classStatus,
    required this.startDate,
    required this.totalStudents,
    required this.createdDate,
    required this.myStatus,
    required this.myJoinDate,
    required this.myLeaveDate,
    required this.monthlyPoints,
    required this.monthlyRank,
    required this.groupMaxPoints,
    required this.lastPointDate,
    required this.lastDayPoints,
    required this.scheduleDays,
    required this.scheduleTime,
    required this.availableMonths,
  });

  final int groupId;
  final String groupName;
  final String uniqueCode;
  final double price;
  final String subjectName;
  final String teacherName;
  final String teacherPhone;
  final String roomNumber;
  final String groupStatus;
  final String classStatus;
  final String startDate;
  final int totalStudents;
  final String createdDate;
  final String myStatus;
  final String myJoinDate;
  final String myLeaveDate;
  final int monthlyPoints;
  final int monthlyRank;
  final int groupMaxPoints;

  /// Shu oyda oxirgi ball qo'yilgan sana (DD.MM.YYYY), bo'lmasa bo'sh
  final String lastPointDate;

  /// O'sha oxirgi kunda olingan ballar yig'indisi (kunlik hisobot uchun)
  final int lastDayPoints;

  /// Dars kunlari — hafta kunlari nomlari ("Dushanba", "Chorshanba", ...)
  final List<String> scheduleDays;

  /// Dars vaqti, masalan "14:00-16:00" (bo'lmasa bo'sh)
  final String scheduleTime;

  /// Backenddan keladigan oylar ro'yxati (YYYY-MM)
  final List<String> availableMonths;

  /// Oylik o'zlashtirish foizi — guruhdagi eng yuqori balga nisbatan (lider 100%)
  double get masteryPercent {
    if (groupMaxPoints <= 0 || monthlyPoints <= 0) return 0;
    final ratio = monthlyPoints / groupMaxPoints;
    return ratio > 1 ? 100 : ratio * 100;
  }

  bool get isActive => myStatus == 'active';
  bool get isStopped => myStatus == 'stopped';
  bool get isFinished => myStatus == 'finished';

  factory StudentGroupSummary.fromJson(Map<String, dynamic> json) {
    final groupInfo = Map<String, dynamic>.from(
      json['group_info'] as Map? ?? const {},
    );
    final subjectInfo = Map<String, dynamic>.from(
      json['subject_info'] as Map? ?? const {},
    );
    final teacherInfo = Map<String, dynamic>.from(
      json['teacher_info'] as Map? ?? const {},
    );
    final roomInfo = Map<String, dynamic>.from(
      json['room_info'] as Map? ?? const {},
    );
    final myStatus = Map<String, dynamic>.from(
      json['my_status'] as Map? ?? const {},
    );

    return StudentGroupSummary(
      groupId: _asInt(groupInfo['id']),
      groupName: _asString(groupInfo['name']),
      uniqueCode: _asString(groupInfo['unique_code']),
      price: _asDouble(groupInfo['price']),
      subjectName: _asString(subjectInfo['name']),
      teacherName: _asString(teacherInfo['name']),
      teacherPhone: _asString(teacherInfo['phone']),
      roomNumber: _asString(roomInfo['room_number']),
      groupStatus: _asString(groupInfo['status']),
      classStatus: _asString(groupInfo['class_status']),
      startDate: _asString(groupInfo['start_date']),
      totalStudents: _asInt(groupInfo['total_students']),
      createdDate: _asString(groupInfo['created_date']),
      myStatus: _asString(myStatus['status']),
      myJoinDate: _asString(myStatus['join_date']),
      myLeaveDate: _asString(myStatus['leave_date']),
      monthlyPoints: _asInt(groupInfo['monthly_points']),
      monthlyRank: _asInt(groupInfo['monthly_rank']),
      groupMaxPoints: _asInt(groupInfo['group_max_points']),
      lastPointDate: _asString(groupInfo['last_point_date']),
      lastDayPoints: _asInt(groupInfo['last_day_points']),
      scheduleDays: _parseScheduleDays(groupInfo['schedule']),
      scheduleTime: _parseScheduleTime(groupInfo['schedule']),
      availableMonths: _parseMonthList(groupInfo['available_months']),
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

  static List<String> _parseMonthList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => RegExp(r'^\d{4}-\d{2}$').hasMatch(item))
        .toList();
  }
}

class StudentGroupDetails {
  const StudentGroupDetails({
    required this.groupId,
    required this.groupName,
    required this.uniqueCode,
    required this.price,
    required this.groupStatus,
    required this.classStatus,
    required this.startDate,
    required this.createdDate,
    required this.studentJoinedDate,
    required this.studentLeftDate,
    required this.subjectName,
    required this.teacherName,
    required this.teacherPhone,
    required this.totalMembers,
    required this.activeMembers,
    required this.monthlyPoints,
    required this.monthlyRank,
    required this.groupmates,
    required this.currentUserStatus,
    required this.lessonReports,
    required this.scheduleDays,
    required this.scheduleTime,
    required this.availableMonths,
  });

  final int groupId;
  final String groupName;
  final String uniqueCode;
  final double price;
  final String groupStatus;
  final String classStatus;
  final String startDate;
  final String createdDate;
  final String studentJoinedDate;
  final String studentLeftDate;
  final String subjectName;
  final String teacherName;
  final String teacherPhone;
  final int totalMembers;
  final int activeMembers;
  final int monthlyPoints;
  final int monthlyRank;
  final List<StudentGroupMate> groupmates;
  final StudentGroupMate? currentUserStatus;
  final List<StudentLessonReport> lessonReports;

  /// Dars kunlari va vaqti (group_details.schedule dan)
  final List<String> scheduleDays;
  final String scheduleTime;

  /// Backenddan keladigan oylar ro'yxati (YYYY-MM)
  final List<String> availableMonths;

  factory StudentGroupDetails.fromJson(
    Map<String, dynamic> json, {
    required int currentUserId,
  }) {
    final groupDetails = Map<String, dynamic>.from(
      json['group_details'] as Map? ?? const {},
    );
    final subject = Map<String, dynamic>.from(
      json['subject'] as Map? ?? const {},
    );
    final teacher = Map<String, dynamic>.from(
      json['teacher'] as Map? ?? const {},
    );
    final statistics = Map<String, dynamic>.from(
      json['group_statistics'] as Map? ?? const {},
    );
    final lessonReportsRaw = json['lesson_reports'];
    final groupmatesRaw = json['groupmates'];
    final groupmates = groupmatesRaw is List
        ? groupmatesRaw
              .whereType<Map>()
              .map(
                (mate) =>
                    StudentGroupMate.fromJson(Map<String, dynamic>.from(mate)),
              )
              .toList()
        : <StudentGroupMate>[];
    final lessonReports = lessonReportsRaw is List
        ? lessonReportsRaw
              .whereType<Map>()
              .map(
                (report) => StudentLessonReport.fromJson(
                  Map<String, dynamic>.from(report),
                ),
              )
              .toList()
        : <StudentLessonReport>[];

    StudentGroupMate? currentUserStatus;
    for (final mate in groupmates) {
      if (mate.id == currentUserId) {
        currentUserStatus = mate;
        break;
      }
    }

    return StudentGroupDetails(
      groupId: _asInt(groupDetails['id']),
      groupName: _asString(groupDetails['name']),
      uniqueCode: _asString(groupDetails['unique_code']),
      price: _asDouble(groupDetails['price']),
      groupStatus: _asString(groupDetails['status']),
      classStatus: _asString(groupDetails['class_status']),
      startDate: _asString(groupDetails['start_date']),
      createdDate: _asString(
        groupDetails['created_date'] ??
            groupDetails['createdDate'] ??
            groupDetails['start_date'] ??
            groupDetails['student_joined_date'],
      ),
      studentJoinedDate: _asString(
        groupDetails['student_joined_date'] ??
            groupDetails['studentJoinedDate'],
      ),
      studentLeftDate: _asString(
        groupDetails['student_left_date'] ??
            groupDetails['studentLeftDate'],
      ),
      subjectName: _asString(subject['name']),
      teacherName: _asString(teacher['name']),
      teacherPhone: _asString(teacher['phone']),
      totalMembers: _asInt(statistics['total_members']),
      activeMembers: _asInt(statistics['active_members']),
      monthlyPoints: _asInt(statistics['monthly_points']),
      monthlyRank: _asInt(
        json['my_rating'] is Map
            ? (json['my_rating'] as Map)['rank_in_group']
            : 0,
      ),
      groupmates: groupmates,
      currentUserStatus: currentUserStatus,
      lessonReports: lessonReports,
      scheduleDays: StudentGroupSummary._parseScheduleDays(
        groupDetails['schedule'],
      ),
      scheduleTime: StudentGroupSummary._parseScheduleTime(
        groupDetails['schedule'],
      ),
      availableMonths: StudentGroupSummary._parseMonthList(
        groupDetails['available_months'],
      ),
    );
  }
}

class StudentGroupMate {
  const StudentGroupMate({
    required this.id,
    required this.name,
    required this.surname,
    required this.phone,
    required this.avatarKey,
    required this.avatarUrl,
    required this.status,
    required this.statusDescription,
    required this.joinDate,
    required this.leaveDate,
    required this.monthlyPoints,
    required this.rankInGroup,
  });

  final int id;
  final String name;
  final String surname;
  final String phone;
  final String avatarKey;
  final String avatarUrl;
  final String status;
  final String statusDescription;
  final String joinDate;
  final String leaveDate;
  final int monthlyPoints;
  final int rankInGroup;

  String get displayName =>
      [surname, name].where((part) => part.trim().isNotEmpty).join(' ');

  factory StudentGroupMate.fromJson(Map<String, dynamic> json) {
    return StudentGroupMate(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      surname: _asString(json['surname']),
      phone: _asString(json['phone']),
      avatarKey: _asString(json['avatar_key'] ?? json['avatarKey']),
      avatarUrl: _asString(
        json['avatar_url'] ??
            json['avatarUrl'] ??
            json['image_url'] ??
            json['imageUrl'],
      ),
      status: _asString(json['status']),
      statusDescription: _asString(json['status_description']),
      joinDate: _asString(json['join_date']),
      leaveDate: _asString(json['leave_date']),
      monthlyPoints: _asInt(json['monthly_points']),
      rankInGroup: _asInt(json['rank_in_group']),
    );
  }
}

class StudentLessonReport {
  const StudentLessonReport({
    required this.id,
    required this.lessonId,
    required this.groupId,
    required this.teacherId,
    required this.subjectName,
    required this.groupName,
    required this.teacherName,
    required this.lessonDate,
    required this.lessonStartTime,
    required this.lessonEndTime,
    required this.homework,
    required this.vocabulary,
    required this.attendance,
    required this.participation,
    required this.total,
    required this.percent,
    required this.feedback,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this.rows,
  });

  final int id;
  final int lessonId;
  final int groupId;
  final int? teacherId;
  final String subjectName;
  final String groupName;
  final String teacherName;
  final String lessonDate;
  final String lessonStartTime;
  final String lessonEndTime;
  final int homework;
  final int vocabulary;
  final int attendance;
  final int participation;
  final int total;
  final int percent;
  final String feedback;
  final String createdAtLabel;
  final String updatedAtLabel;
  final List<StudentLessonReportRow> rows;

  factory StudentLessonReport.fromJson(Map<String, dynamic> json) {
    final rowsRaw = json['rows'];
    return StudentLessonReport(
      id: _asInt(json['id']),
      lessonId: _asInt(json['lesson_id']),
      groupId: _asInt(json['group_id']),
      teacherId: json['teacher_id'] == null ? null : _asInt(json['teacher_id']),
      subjectName: _asString(json['subject_name']),
      groupName: _asString(json['group_name']),
      teacherName: _asString(json['teacher_name']),
      lessonDate: _asString(json['lesson_date']),
      lessonStartTime: _asString(json['lesson_start_time']),
      lessonEndTime: _asString(json['lesson_end_time']),
      homework: _asInt(json['homework']),
      vocabulary: _asInt(json['vocabulary']),
      attendance: _asInt(json['attendance']),
      participation: _asInt(json['participation']),
      total: _asInt(json['total']),
      percent: _asInt(json['percent']),
      feedback: _asString(json['feedback']),
      createdAtLabel: _asString(json['created_at_label']),
      updatedAtLabel: _asString(json['updated_at_label']),
      rows: rowsRaw is List
          ? rowsRaw
                .whereType<Map>()
                .map(
                  (row) => StudentLessonReportRow.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const <StudentLessonReportRow>[],
    );
  }
}

class StudentLessonReportRow {
  const StudentLessonReportRow({
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

  factory StudentLessonReportRow.fromJson(Map<String, dynamic> json) {
    return StudentLessonReportRow(
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

class StudentPointReportsData {
  const StudentPointReportsData({
    required this.month,
    required this.summary,
    required this.breakdown,
    required this.monthlyBreakdown,
    required this.teacherBreakdown,
    required this.dailyBreakdown,
    required this.events,
  });

  final String month;
  final StudentPointSummary summary;
  final List<StudentPointBreakdown> breakdown;

  /// Oyma-oy jami ball (month='all' so'rovida to'ladi)
  final List<StudentPointMonthlyBreakdown> monthlyBreakdown;

  /// Qaysi teacher qaysi oyda qancha ball qo'ygan (month='all' da to'ladi)
  final List<StudentPointTeacherBreakdown> teacherBreakdown;

  final List<StudentPointDailyBreakdown> dailyBreakdown;
  final List<StudentPointEvent> events;

  factory StudentPointReportsData.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(
      json['summary'] as Map? ?? const {},
    );
    final breakdownRaw = json['breakdown'];
    final monthlyBreakdownRaw = json['monthly_breakdown'];
    final teacherBreakdownRaw = json['teacher_breakdown'];
    final dailyBreakdownRaw = json['daily_breakdown'];
    final eventsRaw = json['events'];

    return StudentPointReportsData(
      month: _asString(json['month']),
      summary: StudentPointSummary.fromJson(summary),
      breakdown: breakdownRaw is List
          ? breakdownRaw
                .whereType<Map>()
                .map(
                  (item) => StudentPointBreakdown.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <StudentPointBreakdown>[],
      monthlyBreakdown: monthlyBreakdownRaw is List
          ? monthlyBreakdownRaw
                .whereType<Map>()
                .map(
                  (item) => StudentPointMonthlyBreakdown.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <StudentPointMonthlyBreakdown>[],
      teacherBreakdown: teacherBreakdownRaw is List
          ? teacherBreakdownRaw
                .whereType<Map>()
                .map(
                  (item) => StudentPointTeacherBreakdown.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <StudentPointTeacherBreakdown>[],
      dailyBreakdown: dailyBreakdownRaw is List
          ? dailyBreakdownRaw
                .whereType<Map>()
                .map(
                  (item) => StudentPointDailyBreakdown.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <StudentPointDailyBreakdown>[],
      events: eventsRaw is List
          ? eventsRaw
                .whereType<Map>()
                .map(
                  (item) => StudentPointEvent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <StudentPointEvent>[],
    );
  }
}

/// Oyma-oy jami ball — "oylar bo'yicha ballari" ko'rinishi uchun
class StudentPointMonthlyBreakdown {
  const StudentPointMonthlyBreakdown({
    required this.monthName,
    required this.totalPoints,
    required this.totalEvents,
  });

  /// YYYY-MM formatida
  final String monthName;
  final int totalPoints;
  final int totalEvents;

  factory StudentPointMonthlyBreakdown.fromJson(Map<String, dynamic> json) {
    return StudentPointMonthlyBreakdown(
      monthName: _asString(json['month_name']),
      totalPoints: _asInt(json['total_points']),
      totalEvents: _asInt(json['total_events']),
    );
  }
}

/// Har bir oyda qaysi teacher qancha ball qo'ygan
class StudentPointTeacherBreakdown {
  const StudentPointTeacherBreakdown({
    required this.monthName,
    required this.teacherId,
    required this.teacherName,
    required this.totalPoints,
    required this.totalEvents,
  });

  /// YYYY-MM formatida
  final String monthName;
  final int? teacherId;
  final String teacherName;
  final int totalPoints;
  final int totalEvents;

  factory StudentPointTeacherBreakdown.fromJson(Map<String, dynamic> json) {
    return StudentPointTeacherBreakdown(
      monthName: _asString(json['month_name']),
      teacherId: json['teacher_id'] == null ? null : _asInt(json['teacher_id']),
      teacherName: _asString(json['teacher_name']),
      totalPoints: _asInt(json['total_points']),
      totalEvents: _asInt(json['total_events']),
    );
  }
}

class StudentPointSummary {
  const StudentPointSummary({
    required this.totalPoints,
    required this.totalEvents,
    required this.attendanceEvents,
    required this.manualEvents,
    this.firstEventDate,
    this.lastEventDate,
  });

  final int totalPoints;
  final int totalEvents;
  final int attendanceEvents;
  final int manualEvents;

  /// Birinchi ball olingan sana (YYYY-MM-DD), bo'lmasa null
  final String? firstEventDate;

  /// Oxirgi ball olingan sana (YYYY-MM-DD), bo'lmasa null
  final String? lastEventDate;

  factory StudentPointSummary.fromJson(Map<String, dynamic> json) {
    String? date(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty || text == 'null' ? null : text;
    }

    return StudentPointSummary(
      totalPoints: _asInt(json['total_points']),
      totalEvents: _asInt(json['total_events']),
      attendanceEvents: _asInt(json['attendance_events']),
      manualEvents: _asInt(json['manual_events']),
      firstEventDate: date(json['first_event_date']),
      lastEventDate: date(json['last_event_date']),
    );
  }
}

class StudentPointBreakdown {
  const StudentPointBreakdown({
    required this.groupId,
    required this.groupName,
    required this.totalPoints,
    required this.totalEvents,
  });

  final int? groupId;
  final String groupName;
  final int totalPoints;
  final int totalEvents;

  factory StudentPointBreakdown.fromJson(Map<String, dynamic> json) {
    return StudentPointBreakdown(
      groupId: json['group_id'] == null ? null : _asInt(json['group_id']),
      groupName: _asString(json['group_name']),
      totalPoints: _asInt(json['total_points']),
      totalEvents: _asInt(json['total_events']),
    );
  }
}

class StudentPointEvent {
  const StudentPointEvent({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.lessonId,
    required this.monthName,
    required this.points,
    required this.sourceType,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.dayKey,
    required this.createdTime,
  });

  final int id;
  final int? groupId;
  final String groupName;
  final int? lessonId;
  final String monthName;
  final int points;
  final String sourceType;
  final String title;
  final String description;
  final String createdAt;
  final String dayKey;
  final String createdTime;

  factory StudentPointEvent.fromJson(Map<String, dynamic> json) {
    return StudentPointEvent(
      id: _asInt(json['id']),
      groupId: json['group_id'] == null ? null : _asInt(json['group_id']),
      groupName: _asString(json['group_name']),
      lessonId: json['lesson_id'] == null ? null : _asInt(json['lesson_id']),
      monthName: _asString(json['month_name']),
      points: _asInt(json['points']),
      sourceType: _asString(json['source_type']),
      title: _asString(json['title']),
      description: _asString(json['description']),
      createdAt: _asString(json['created_at']),
      dayKey: _asString(json['day_key']),
      createdTime: _asString(json['created_time']),
    );
  }
}

class StudentPointDailyBreakdown {
  const StudentPointDailyBreakdown({
    required this.dayKey,
    required this.totalPoints,
    required this.totalEvents,
    required this.firstTime,
    required this.lastTime,
  });

  final String dayKey;
  final int totalPoints;
  final int totalEvents;
  final String firstTime;
  final String lastTime;

  factory StudentPointDailyBreakdown.fromJson(Map<String, dynamic> json) {
    return StudentPointDailyBreakdown(
      dayKey: _asString(json['day_key']),
      totalPoints: _asInt(json['total_points']),
      totalEvents: _asInt(json['total_events']),
      firstTime: _asString(json['first_time']),
      lastTime: _asString(json['last_time']),
    );
  }
}

String _asString(Object? value) => value?.toString() ?? '';

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
