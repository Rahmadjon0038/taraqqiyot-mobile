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
    int groupId,
  ) async {
    final response = await _client
        .get(
          _uri('/api/students/my-group-info/$groupId'),
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
    );
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
