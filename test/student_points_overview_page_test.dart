import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taraqqiyot_mobile/features/auth/models/auth_session.dart';
import 'package:taraqqiyot_mobile/features/auth/models/auth_user.dart';
import 'package:taraqqiyot_mobile/features/student/data/student_groups_service.dart';
import 'package:taraqqiyot_mobile/features/student/presentation/student_points_overview_page.dart';

void main() {
  testWidgets(
    'Ballarim sahifasi: umumiy ball, oylar va teacherlar ko\'rinadi',
    (tester) async {
      final payload = {
        'success': true,
        'data': {
          'month': 'all',
          'summary': {
            'total_points': 340,
            'total_events': 120,
            'attendance_events': 100,
            'manual_events': 20,
            'first_event_date': '2025-09-02',
            'last_event_date': '2026-07-10',
          },
          'breakdown': const [],
          'monthly_breakdown': const [
            {'month_name': '2026-07', 'total_points': 42, 'total_events': 14},
            {'month_name': '2026-06', 'total_points': 88, 'total_events': 30},
          ],
          'teacher_breakdown': const [
            {
              'month_name': '2026-07',
              'teacher_id': 8,
              'teacher_name': 'Ali Valiyev',
              'total_points': 30,
              'total_events': 10,
            },
            {
              'month_name': '2026-06',
              'teacher_id': 9,
              'teacher_name': 'Vali Aliyev',
              'total_points': 88,
              'total_events': 30,
            },
          ],
          'daily_breakdown': const [],
          'events': const [],
        },
      };

      String? requestedPath;
      String? requestedMonth;
      final mockClient = MockClient((request) async {
        requestedPath = request.url.path;
        requestedMonth = request.url.queryParameters['month'];
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      const session = AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        user: AuthUser(
          id: 1,
          name: 'Aziz',
          surname: 'Karimov',
          username: 'aziz',
          role: 'student',
          raw: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentPointsOverviewPage(
            session: session,
            service: StudentGroupsService(client: mockClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // To'g'ri endpoint va butun o'qish davri so'rovi
      expect(requestedPath, '/api/students/my-point-reports');
      expect(requestedMonth, 'all');

      // Umumiy (boshidan beri) ball
      expect(find.text('Umumiy ball'), findsOneWidget);
      // Hero sarlavhasi (+ joriy oy shu ro'yxatda bo'lsa oy kartasidagi belgi)
      expect(find.text('Joriy oy'), findsWidgets);
      expect(find.text('340'), findsOneWidget);

      // Oylar bo'yicha ro'yxat (oy yorlig'i hero'da ham chiqishi mumkin)
      expect(find.text('Iyul 2026'), findsWidgets);
      expect(find.text('Iyun 2026'), findsWidgets);
      // Oy kartasidagi jami ball badge'lari — noyob
      expect(find.text('+42 ball'), findsOneWidget);
      expect(find.text('+88 ball'), findsOneWidget);

      // Har oyda qaysi teacher qancha ball qo'ygani
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.text('Vali Aliyev'), findsOneWidget);
    },
  );
}
