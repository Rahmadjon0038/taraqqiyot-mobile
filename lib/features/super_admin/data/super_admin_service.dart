import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/models/auth_session.dart';

class SuperAdminServiceException implements Exception {
  const SuperAdminServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Super admin roli uchun API chaqiruvlar:
/// dashboard statistikasi, adminlar boshqaruvi va davomat nazorati.
class SuperAdminService {
  SuperAdminService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(AuthSession session) => {
    'Authorization': 'Bearer ${session.accessToken}',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decode(http.Response response) {
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
      throw SuperAdminServiceException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            fallbackMessage,
        statusCode: response.statusCode,
      );
    }
  }

  /// Tizim ish boshlagan oy — bir marta yuklanib keshlanadi
  /// (barcha super admin sahifalari oy filtrlarida ishlatadi)
  static String? _cachedStartMonth;

  Future<String> fetchSystemStartMonth(AuthSession session) async {
    final cached = _cachedStartMonth;
    if (cached != null) return cached;

    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    try {
      final response = await _client
          .get(_uri('/api/dashboard/system-start'), headers: _headers(session))
          .timeout(_timeout);
      final payload = _decode(response);
      final data = payload['data'];
      final raw = data is Map ? _asString(data['start_month']) : '';
      final valid = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(raw);
      _cachedStartMonth = valid ? raw : currentMonth;
    } catch (_) {
      // Endpoint hali deploy qilinmagan bo'lsa joriy oydan boshlaymiz
      return currentMonth;
    }
    return _cachedStartMonth!;
  }

  /// [startMonth] (YYYY-MM) dan joriy oygacha oylar ro'yxati
  /// (joriy oy birinchi, xavfsizlik uchun 48 oy bilan cheklangan)
  static List<String> monthsFrom(String startMonth) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final parts = startMonth.split('-');
    final startYear = int.tryParse(parts.isNotEmpty ? parts[0] : '');
    final startMonthNum = int.tryParse(parts.length > 1 ? parts[1] : '');
    var start = (startYear != null && startMonthNum != null)
        ? DateTime(startYear, startMonthNum)
        : current;
    if (start.isAfter(current)) start = current;

    final months = <String>[];
    var cursor = current;
    while (!cursor.isBefore(start) && months.length < 48) {
      months.add('${cursor.year}-${cursor.month.toString().padLeft(2, '0')}');
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
  }

  /// Oylik KPI va fanlar tahlili
  Future<SuperAdminDashboard> fetchDashboard(
    AuthSession session, {
    required String month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/dashboard/super-admin', {'month': month}),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Statistika yuklanmadi');
    final data = payload['data'];
    return SuperAdminDashboard.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  /// Adminlar ro'yxati.
  /// [monthName] (YYYY-MM) berilsa o'sha oy uchun oylik to'langan-to'lanmagani
  /// ham keladi (salary_amount maydoni).
  Future<List<AdminUser>> fetchAdmins(
    AuthSession session, {
    String? status,
    String? monthName,
  }) async {
    final response = await _client
        .get(
          _uri('/api/users/admins', {
            if (status != null && status.isNotEmpty) 'status': status,
            if (monthName != null && monthName.isNotEmpty)
              'month_name': monthName,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Adminlar yuklanmadi');
    final data = payload['data'] ?? payload['admins'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => AdminUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Yangi admin yaratish
  Future<void> createAdmin(
    AuthSession session, {
    required String name,
    required String surname,
    required String username,
    required String password,
    String? phone,
  }) async {
    final response = await _client
        .post(
          _uri('/api/users/register-admin'),
          headers: _headers(session),
          body: jsonEncode({
            'name': name,
            'surname': surname,
            'username': username,
            'password': password,
            if (phone != null && phone.trim().isNotEmpty)
              'phone': phone.trim(),
          }),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Admin yaratilmadi');
  }

  /// Admin statusini o'zgartirish (active/inactive)
  Future<void> updateAdminStatus(
    AuthSession session,
    int adminId,
    String status,
  ) async {
    final response = await _client
        .patch(
          _uri('/api/users/admins/$adminId/status'),
          headers: _headers(session),
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Status o\'zgartirilmadi');
  }

  /// Adminni o'chirish
  Future<void> deleteAdmin(AuthSession session, int adminId) async {
    final response = await _client
        .delete(
          _uri('/api/users/admins/$adminId'),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Admin o\'chirilmadi');
  }

  /// Adminga oylik to'lash
  Future<void> payAdminSalary(
    AuthSession session, {
    required int adminId,
    required String monthName,
    required double amount,
    String? description,
  }) async {
    final response = await _client
        .post(
          _uri('/api/admin-salary/pay'),
          headers: _headers(session),
          body: jsonEncode({
            'admin_id': adminId,
            'month_name': monthName,
            'amount': amount,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
          }),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Oylik to\'lanmadi');
  }

  /// Adminlarga to'langan oyliklar tarixi
  Future<List<AdminSalaryRecord>> fetchAdminSalaries(
    AuthSession session, {
    int? adminId,
    String? monthName,
  }) async {
    final response = await _client
        .get(
          _uri('/api/admin-salary', {
            if (adminId != null) 'admin_id': adminId.toString(),
            if (monthName != null && monthName.isNotEmpty)
              'month_name': monthName,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Oyliklar tarixi yuklanmadi');
    final data = payload['data'] ?? payload['salaries'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => AdminSalaryRecord.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  /// To'lovlar tarixini tozalash: [monthName] berilsa faqat o'sha oy,
  /// [adminId] berilsa faqat o'sha adminning yozuvlari,
  /// ikkalasisiz — butun tarix o'chiriladi
  Future<int> clearAdminSalaryHistory(
    AuthSession session, {
    String? monthName,
    int? adminId,
  }) async {
    final response = await _client
        .delete(
          _uri('/api/admin-salary', {
            if (monthName != null && monthName.isNotEmpty)
              'month_name': monthName,
            if (adminId != null) 'admin_id': adminId.toString(),
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Tarix tozalanmadi');
    return _asInt(payload['deleted_count']);
  }

  /// Oylik to'lov jadvali (snapshot) bo'yicha qisqa statistika —
  /// saytdagi admin davomat sahifasidagi "Jami" va "To'xtatgan" manbasi
  Future<SnapshotSummary> fetchSnapshotSummary(
    AuthSession session, {
    required String month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/snapshots/summary', {'month': month}),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Statistika yuklanmadi');
    final summary = payload['summary'] ?? payload['data'];
    return SnapshotSummary.fromJson(
      summary is Map ? Map<String, dynamic>.from(summary) : const {},
    );
  }

  /// Davomat nazorati: teacherlar ro'yxati.
  /// [date] (YYYY-MM-DD) berilsa o'sha kunning holati, bo'lmasa bugungi.
  Future<List<AttendanceTeacher>> fetchAttendanceTeachers(
    AuthSession session, {
    String? date,
  }) async {
    final response = await _client
        .get(
          _uri('/api/attendance/teachers', {
            if (date != null && date.isNotEmpty) 'date': date,
          }),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Teacherlar yuklanmadi');
    final data = payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => AttendanceTeacher.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  /// Tanlangan teacherning guruhlari (davomat nazorati uchun)
  Future<List<AttendanceTeacherGroup>> fetchTeacherGroups(
    AuthSession session,
    int teacherId,
  ) async {
    final response = await _client
        .get(
          _uri('/api/attendance/teachers/$teacherId/groups'),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    _ensureSuccess(response, payload, 'Guruhlar yuklanmadi');
    final data = payload['data'];
    final groups = data is Map ? (data['groups'] ?? data['data']) : data;
    if (groups is! List) return const [];
    return groups
        .whereType<Map>()
        .map(
          (item) =>
              AttendanceTeacherGroup.fromJson(Map<String, dynamic>.from(item)),
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

class SuperAdminDashboard {
  const SuperAdminDashboard({
    required this.month,
    required this.totalRevenue,
    required this.totalTeacherSalary,
    required this.totalAdminSalary,
    required this.totalExpenses,
    required this.totalDiscounts,
    required this.newStudentsCount,
    required this.netProfit,
    required this.subjects,
    required this.totalTeachers,
    required this.students,
    required this.expensesByCategory,
  });

  final String month;
  final double totalRevenue;
  final double totalTeacherSalary;
  final double totalAdminSalary;
  final double totalExpenses;
  final double totalDiscounts;
  final int newStudentsCount;
  final double netProfit;
  final List<SubjectStat> subjects;
  final int totalTeachers;
  final StudentsBreakdown students;

  /// Rasxodlar kategoriyalar kesimida (summasi bo'yicha kamayish tartibida)
  final List<ExpenseCategoryStat> expensesByCategory;

  factory SuperAdminDashboard.fromJson(Map<String, dynamic> json) {
    final monthly = Map<String, dynamic>.from(json['monthly'] as Map? ?? {});
    final overall = Map<String, dynamic>.from(json['overall'] as Map? ?? {});
    final subjectsRaw = json['subjects'];
    return SuperAdminDashboard(
      month: _asString(monthly['current_month']),
      totalRevenue: _asDouble(monthly['total_revenue']),
      totalTeacherSalary: _asDouble(monthly['total_teacher_salary']),
      totalAdminSalary: _asDouble(monthly['total_admin_salary']),
      totalExpenses: _asDouble(monthly['total_expenses']),
      totalDiscounts: _asDouble(monthly['total_discounts']),
      newStudentsCount: _asInt(monthly['new_students_count']),
      netProfit: _asDouble(monthly['net_profit']),
      subjects: subjectsRaw is List
          ? subjectsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      SubjectStat.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      totalTeachers: _asInt(overall['total_teachers_count']),
      students: StudentsBreakdown.fromJson(
        json['students'] is Map
            ? Map<String, dynamic>.from(json['students'] as Map)
            : const {},
      ),
      expensesByCategory: monthly['expenses_by_category'] is List
          ? (monthly['expenses_by_category'] as List)
                .whereType<Map>()
                .map(
                  (item) => ExpenseCategoryStat.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.total > 0)
                .toList()
          : const [],
    );
  }
}

/// Bitta rasxod kategoriyasining oylik summasi
class ExpenseCategoryStat {
  const ExpenseCategoryStat({required this.name, required this.total});

  final String name;
  final double total;

  factory ExpenseCategoryStat.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryStat(
      name: _asString(json['category_name']),
      total: _asDouble(json['total']),
    );
  }
}

/// Talabalar tafsiloti — admin panel students sahifasi bilan aynan bir xil
/// hisob: bitta talaba ikkita guruhda o'qisa u ikki marta sanaladi
/// (davomat va oylik to'lovlar jadvalidagi kabi).
class StudentsBreakdown {
  const StudentsBreakdown({
    required this.total,
    required this.active,
    required this.stopped,
    required this.finished,
    required this.unassigned,
    required this.inSnapshot,
  });

  /// Jami: guruh a'zoliklari + guruhsizlar (saytdagi "Jami talabalar")
  final int total;

  /// Faol guruh a'zoliklari soni
  final int active;

  /// To'xtatilgan a'zoliklar soni
  final int stopped;

  /// Bitirgan a'zoliklar soni
  final int finished;

  /// Hech qanday guruhga biriktirilmaganlar
  final int unassigned;

  /// Shu oy to'lov jadvalidagi yozuvlar (monthly_snapshots) soni
  final int inSnapshot;

  factory StudentsBreakdown.fromJson(Map<String, dynamic> json) {
    return StudentsBreakdown(
      total: _asInt(json['total_students']),
      active: _asInt(json['active_students']),
      stopped: _asInt(json['stopped_students']),
      finished: _asInt(json['finished_students']),
      unassigned: _asInt(json['unassigned_students']),
      inSnapshot: _asInt(json['snapshot_students']),
    );
  }
}

class SubjectStat {
  const SubjectStat({
    required this.subjectName,
    required this.totalStudents,
    required this.totalRevenue,
    required this.totalRequired,
    required this.teachersCount,
    required this.teachers,
  });

  final String subjectName;
  final int totalStudents;

  /// Haqiqatda to'langan (yig'ilgan) summa
  final double totalRevenue;

  /// Yig'ilishi kerak bo'lgan summa (chegirmalar hisobga olingan)
  final double totalRequired;

  final int teachersCount;
  final List<SubjectTeacherStat> teachers;

  /// To'lov yig'ilish progresi: to'langan / kerak (0..1)
  double get collectionRatio => totalRequired > 0
      ? (totalRevenue / totalRequired).clamp(0.0, 1.0)
      : 0.0;

  factory SubjectStat.fromJson(Map<String, dynamic> json) {
    final teachersRaw = json['teachers'];
    return SubjectStat(
      subjectName: _asString(json['subject_name']),
      totalStudents: _asInt(json['total_students_count']),
      totalRevenue: _asDouble(json['total_revenue']),
      totalRequired: _asDouble(json['total_required']),
      teachersCount: _asInt(json['teachers_count']),
      teachers: teachersRaw is List
          ? teachersRaw
                .whereType<Map>()
                .map(
                  (item) => SubjectTeacherStat.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class SubjectTeacherStat {
  const SubjectTeacherStat({
    required this.teacherName,
    required this.totalStudents,
    required this.totalRevenue,
    required this.totalRequired,
  });

  final String teacherName;
  final int totalStudents;
  final double totalRevenue;
  final double totalRequired;

  /// Shu teacher o'quvchilarining to'lov yig'ilish progresi (0..1)
  double get collectionRatio => totalRequired > 0
      ? (totalRevenue / totalRequired).clamp(0.0, 1.0)
      : 0.0;

  factory SubjectTeacherStat.fromJson(Map<String, dynamic> json) {
    return SubjectTeacherStat(
      teacherName: _asString(json['teacher_name']),
      totalStudents: _asInt(json['total_students_count']),
      totalRevenue: _asDouble(json['total_revenue']),
      totalRequired: _asDouble(json['total_required']),
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.username,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.recoveryKey,
    required this.salaryAmount,
  });

  final int id;
  final String name;
  final String surname;
  final String username;
  final String phone;
  final String status;
  final String createdAt;
  final String recoveryKey;

  /// Oy filtri bilan so'ralganda: o'sha oyda to'langan oylik summasi
  /// (to'lanmagan bo'lsa null)
  final double? salaryAmount;

  String get fullName =>
      [surname, name].where((part) => part.trim().isNotEmpty).join(' ');

  bool get isActive => status == 'active';

  /// Qabul qilingan sana (DD.MM.YYYY), parse bo'lmasa xom qiymat
  String get joinedDateLabel {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return createdAt;
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    // Backend oy filtri bilan salary ni ichki obyekt qilib beradi:
    // salary: { month_name, amount, ... }; amount null bo'lsa to'lanmagan
    Object? salaryRaw = json['salary_amount'];
    final salary = json['salary'];
    if (salaryRaw == null && salary is Map) {
      salaryRaw = salary['amount'];
    }
    return AdminUser(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      surname: _asString(json['surname']),
      username: _asString(json['username']),
      phone: _asString(json['phone']),
      status: _asString(json['status']),
      createdAt: _asString(json['createdAt'] ?? json['created_at']),
      recoveryKey: _asString(json['recovery_key']),
      salaryAmount: salaryRaw == null ? null : _asDouble(salaryRaw),
    );
  }
}

class AdminSalaryRecord {
  const AdminSalaryRecord({
    required this.adminId,
    required this.adminName,
    required this.monthName,
    required this.amount,
    required this.description,
    required this.paidAt,
  });

  final int adminId;
  final String adminName;
  final String monthName;
  final double amount;
  final String description;
  final String paidAt;

  factory AdminSalaryRecord.fromJson(Map<String, dynamic> json) {
    final name = _asString(json['admin_name']);
    return AdminSalaryRecord(
      adminId: _asInt(json['admin_id']),
      adminName: name.isNotEmpty
          ? name
          : '${_asString(json['surname'])} ${_asString(json['name'])}'.trim(),
      monthName: _asString(json['month_name'] ?? json['month']),
      amount: _asDouble(json['amount']),
      description: _asString(json['description']),
      paidAt: _asString(json['paid_at'] ?? json['created_at']),
    );
  }
}

/// Oylik snapshot (to'lov jadvali) statistikasi
class SnapshotSummary {
  const SnapshotSummary({
    required this.totalStudents,
    required this.activeStudents,
    required this.stoppedStudents,
  });

  final int totalStudents;
  final int activeStudents;
  final int stoppedStudents;

  factory SnapshotSummary.fromJson(Map<String, dynamic> json) {
    return SnapshotSummary(
      totalStudents: _asInt(json['total_students']),
      activeStudents: _asInt(json['active_students']),
      stoppedStudents: _asInt(json['stopped_students']),
    );
  }
}

class AttendanceTeacher {
  const AttendanceTeacher({
    required this.teacherId,
    required this.fullName,
    required this.subjects,
    required this.roomNumbers,
    required this.groupsCount,
    required this.studentsCount,
    required this.activeStudentsCount,
    required this.todayGroupsCount,
    required this.todayMarkedGroupsCount,
  });

  final int teacherId;
  final String fullName;
  final List<String> subjects;
  final List<String> roomNumbers;
  final int groupsCount;

  /// Tanlangan kunda jadval bo'yicha darsi bor guruhlardagi talabalar soni
  final int studentsCount;
  final int activeStudentsCount;

  /// Bugun jadval bo'yicha darsi bor guruhlar soni
  final int todayGroupsCount;

  /// Bugun davomati to'liq belgilangan guruhlar soni
  final int todayMarkedGroupsCount;

  factory AttendanceTeacher.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(Object? value) => value is List
        ? value
              .map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : const [];

    return AttendanceTeacher(
      teacherId: _asInt(json['teacher_id'] ?? json['id']),
      fullName: _asString(json['full_name']),
      subjects: asStringList(json['subjects']),
      roomNumbers: asStringList(json['room_numbers']),
      groupsCount: _asInt(json['groups_count']),
      studentsCount: _asInt(json['students_count']),
      activeStudentsCount: _asInt(json['active_students_count']),
      todayGroupsCount: _asInt(json['today_groups_count']),
      todayMarkedGroupsCount: _asInt(json['today_marked_groups_count']),
    );
  }
}

class AttendanceTeacherGroup {
  const AttendanceTeacherGroup({
    required this.id,
    required this.name,
    required this.subjectName,
    required this.roomNumber,
    required this.studentsCount,
  });

  final int id;
  final String name;
  final String subjectName;
  final String roomNumber;
  final int studentsCount;

  factory AttendanceTeacherGroup.fromJson(Map<String, dynamic> json) {
    return AttendanceTeacherGroup(
      id: _asInt(json['group_id'] ?? json['id']),
      name: _asString(json['group_name'] ?? json['name']),
      subjectName: _asString(json['subject_name']),
      roomNumber: _asString(json['room_number']),
      studentsCount: _asInt(
        json['active_students_count'] ?? json['students_count'],
      ),
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
