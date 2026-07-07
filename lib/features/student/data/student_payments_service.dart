import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/models/auth_session.dart';

class StudentPaymentsException implements Exception {
  const StudentPaymentsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StudentPaymentsService {
  StudentPaymentsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Future<StudentPaymentsResponse> fetchMyPayments(
    AuthSession session, {
    String? month,
  }) async {
    final response = await _client
        .get(
          _uri('/api/payments/my', {
            if (month != null && month.trim().isNotEmpty) 'month': month.trim(),
          }),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudentPaymentsException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'To\'lov ma\'lumotlari yuklanmadi',
        statusCode: response.statusCode,
      );
    }

    final data = payload['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : payload;
    final enrollmentsRaw = map['enrollments'];
    final transactionsRaw = map['transactions'];
    final summaryRaw = map['summary'];

    final enrollments = enrollmentsRaw is List
        ? enrollmentsRaw
            .whereType<Map>()
            .map((item) => StudentPaymentEnrollment.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <StudentPaymentEnrollment>[];

    final transactions = transactionsRaw is List
        ? transactionsRaw
            .whereType<Map>()
            .map((item) => StudentPaymentTransaction.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <StudentPaymentTransaction>[];

    return StudentPaymentsResponse(
      enrollments: enrollments,
      transactions: transactions,
      summary: StudentPaymentsSummary.fromJson(
        summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : const {},
      ),
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

class StudentPaymentsResponse {
  const StudentPaymentsResponse({
    required this.enrollments,
    required this.transactions,
    required this.summary,
  });

  final List<StudentPaymentEnrollment> enrollments;
  final List<StudentPaymentTransaction> transactions;
  final StudentPaymentsSummary summary;
}

class StudentPaymentsSummary {
  const StudentPaymentsSummary({
    required this.totalEnrollments,
    required this.activeEnrollments,
    required this.totalRequired,
    required this.totalPaid,
    required this.totalDiscount,
    required this.totalDebt,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
  });

  final int totalEnrollments;
  final int activeEnrollments;
  final double totalRequired;
  final double totalPaid;
  final double totalDiscount;
  final double totalDebt;
  final int paidCount;
  final int partialCount;
  final int unpaidCount;

  factory StudentPaymentsSummary.fromJson(Map<String, dynamic> json) {
    return StudentPaymentsSummary(
      totalEnrollments: _asInt(json['total_enrollments']),
      activeEnrollments: _asInt(json['active_enrollments']),
      totalRequired: _asDouble(json['total_required']),
      totalPaid: _asDouble(json['total_paid']),
      totalDiscount: _asDouble(json['total_discount']),
      totalDebt: _asDouble(json['total_debt']),
      paidCount: _asInt(json['paid_count']),
      partialCount: _asInt(json['partial_count']),
      unpaidCount: _asInt(json['unpaid_count']),
    );
  }
}

class StudentPaymentEnrollment {
  const StudentPaymentEnrollment({
    required this.month,
    required this.groupName,
    required this.subjectName,
    required this.teacherName,
    required this.monthlyStatus,
    required this.paymentStatus,
    required this.requiredAmount,
    required this.paidAmount,
    required this.discountAmount,
    required this.debtAmount,
    required this.lastPaymentDate,
    required this.totalLessons,
    required this.attendedLessons,
    required this.attendancePercentage,
    required this.snapshotDate,
  });

  final String month;
  final String groupName;
  final String subjectName;
  final String teacherName;
  final String monthlyStatus;
  final String paymentStatus;
  final double requiredAmount;
  final double paidAmount;
  final double discountAmount;
  final double debtAmount;
  final String lastPaymentDate;
  final int totalLessons;
  final int attendedLessons;
  final double attendancePercentage;
  final String snapshotDate;

  factory StudentPaymentEnrollment.fromJson(Map<String, dynamic> json) {
    return StudentPaymentEnrollment(
      month: _asString(json['month']),
      groupName: _asString(json['group_name']),
      subjectName: _asString(json['subject_name']),
      teacherName: _asString(json['teacher_name']),
      monthlyStatus: _asString(json['monthly_status']),
      paymentStatus: _asString(json['payment_status']),
      requiredAmount: _asDouble(json['required_amount']),
      paidAmount: _asDouble(json['paid_amount']),
      discountAmount: _asDouble(json['discount_amount']),
      debtAmount: _asDouble(json['debt_amount']),
      lastPaymentDate: _asString(json['last_payment_date']),
      totalLessons: _asInt(json['total_lessons']),
      attendedLessons: _asInt(json['attended_lessons']),
      attendancePercentage: _asDouble(json['attendance_percentage']),
      snapshotDate: _asString(json['snapshot_date']),
    );
  }
}

class StudentPaymentTransaction {
  const StudentPaymentTransaction({
    required this.month,
    required this.amount,
    required this.paymentMethod,
    required this.description,
    required this.groupName,
    required this.paymentDate,
  });

  final String month;
  final double amount;
  final String paymentMethod;
  final String description;
  final String groupName;
  final String paymentDate;

  factory StudentPaymentTransaction.fromJson(Map<String, dynamic> json) {
    return StudentPaymentTransaction(
      month: _asString(json['month']),
      amount: _asDouble(json['amount']),
      paymentMethod: _asString(json['payment_method']),
      description: _asString(json['description']),
      groupName: _asString(json['group_name']),
      paymentDate: _asString(json['payment_date']),
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

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
