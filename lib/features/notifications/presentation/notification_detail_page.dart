import 'package:flutter/material.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.payload});

  static const String routeName = '/notification-detail';

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final title = payload['title']?.toString() ?? 'Notification';
    final body = payload['body']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(fontSize: 16, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Data payload',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  payload.toString(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
