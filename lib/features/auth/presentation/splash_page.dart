import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 204,
              height: 204,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(44),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA70E07).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFA70E07).withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/logo.png',
                width: 168,
                height: 168,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Taraqqiyot Teaching\nCenter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA70E07),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sessiya tekshirilmoqda...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
