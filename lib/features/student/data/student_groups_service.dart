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
  StudentGroupsService({http.Client? client}) : _client = client ?? http.Client();

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
        .map((group) => StudentGroupSummary.fromJson(Map<String, dynamic>.from(group)))
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
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
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
          _uri('/api/students/my-point-reports').replace(queryParameters: params),
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
    final groupInfo = Map<String, dynamic>.from(json['group_info'] as Map? ?? const {});
    final subjectInfo = Map<String, dynamic>.from(json['subject_info'] as Map? ?? const {});
    final teacherInfo = Map<String, dynamic>.from(json['teacher_info'] as Map? ?? const {});
    final roomInfo = Map<String, dynamic>.from(json['room_info'] as Map? ?? const {});
    final myStatus = Map<String, dynamic>.from(json['my_status'] as Map? ?? const {});

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
    required this.subjectName,
    required this.teacherName,
    required this.teacherPhone,
    required this.totalMembers,
    required this.activeMembers,
    required this.monthlyPoints,
    required this.monthlyRank,
    required this.groupmates,
    required this.currentUserStatus,
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
  final String subjectName;
  final String teacherName;
  final String teacherPhone;
  final int totalMembers;
  final int activeMembers;
  final int monthlyPoints;
  final int monthlyRank;
  final List<StudentGroupMate> groupmates;
  final StudentGroupMate? currentUserStatus;

  factory StudentGroupDetails.fromJson(
    Map<String, dynamic> json, {
    required int currentUserId,
  }) {
    final groupDetails = Map<String, dynamic>.from(json['group_details'] as Map? ?? const {});
    final subject = Map<String, dynamic>.from(json['subject'] as Map? ?? const {});
    final teacher = Map<String, dynamic>.from(json['teacher'] as Map? ?? const {});
    final statistics = Map<String, dynamic>.from(json['group_statistics'] as Map? ?? const {});
    final groupmatesRaw = json['groupmates'];
    final groupmates = groupmatesRaw is List
        ? groupmatesRaw
            .whereType<Map>()
            .map((mate) => StudentGroupMate.fromJson(Map<String, dynamic>.from(mate)))
            .toList()
        : <StudentGroupMate>[];

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
        groupDetails['student_joined_date'] ?? groupDetails['studentJoinedDate'],
      ),
      subjectName: _asString(subject['name']),
      teacherName: _asString(teacher['name']),
      teacherPhone: _asString(teacher['phone']),
      totalMembers: _asInt(statistics['total_members']),
      activeMembers: _asInt(statistics['active_members']),
      monthlyPoints: _asInt(statistics['monthly_points']),
      monthlyRank: _asInt(json['my_rating'] is Map ? (json['my_rating'] as Map)['rank_in_group'] : 0),
      groupmates: groupmates,
      currentUserStatus: currentUserStatus,
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

  String get displayName => [surname, name].where((part) => part.trim().isNotEmpty).join(' ');

  factory StudentGroupMate.fromJson(Map<String, dynamic> json) {
    return StudentGroupMate(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      surname: _asString(json['surname']),
      phone: _asString(json['phone']),
      avatarKey: _asString(json['avatar_key'] ?? json['avatarKey']),
      avatarUrl: _asString(
        json['avatar_url'] ?? json['avatarUrl'] ?? json['image_url'] ?? json['imageUrl'],
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

class StudentPointReportsData {
  const StudentPointReportsData({
    required this.month,
    required this.summary,
    required this.breakdown,
    required this.dailyBreakdown,
    required this.events,
  });

  final String month;
  final StudentPointSummary summary;
  final List<StudentPointBreakdown> breakdown;
  final List<StudentPointDailyBreakdown> dailyBreakdown;
  final List<StudentPointEvent> events;

  factory StudentPointReportsData.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map? ?? const {});
    final breakdownRaw = json['breakdown'];
    final dailyBreakdownRaw = json['daily_breakdown'];
    final eventsRaw = json['events'];

    return StudentPointReportsData(
      month: _asString(json['month']),
      summary: StudentPointSummary.fromJson(summary),
      breakdown: breakdownRaw is List
          ? breakdownRaw
              .whereType<Map>()
              .map((item) => StudentPointBreakdown.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <StudentPointBreakdown>[],
      dailyBreakdown: dailyBreakdownRaw is List
          ? dailyBreakdownRaw
              .whereType<Map>()
              .map((item) => StudentPointDailyBreakdown.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <StudentPointDailyBreakdown>[],
      events: eventsRaw is List
          ? eventsRaw
              .whereType<Map>()
              .map((item) => StudentPointEvent.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <StudentPointEvent>[],
    );
  }
}

class StudentPointSummary {
  const StudentPointSummary({
    required this.totalPoints,
    required this.totalEvents,
    required this.attendanceEvents,
    required this.manualEvents,
  });

  final int totalPoints;
  final int totalEvents;
  final int attendanceEvents;
  final int manualEvents;

  factory StudentPointSummary.fromJson(Map<String, dynamic> json) {
    return StudentPointSummary(
      totalPoints: _asInt(json['total_points']),
      totalEvents: _asInt(json['total_events']),
      attendanceEvents: _asInt(json['attendance_events']),
      manualEvents: _asInt(json['manual_events']),
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
