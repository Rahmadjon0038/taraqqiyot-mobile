import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../services/app_update_service.dart';

/// Backend orqali boshqariladigan "yangi versiya" xabarnomasi.
/// [info.forceUpdate] true bo'lsa, foydalanuvchi dialogni yopa olmaydi —
/// faqat Play Market/App Store'ga o'tib yangilashi kerak.
Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
) async {
  if (!info.updateAvailable || info.storeUrl.trim().isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (dialogContext) {
      return PopScope(
        canPop: !info.forceUpdate,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  info.latestVersionName.trim().isEmpty
                      ? 'Yangi versiya chiqdi'
                      : 'Yangi versiya: ${info.latestVersionName}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.message.trim().isEmpty
                      ? "Ilovaning yangi versiyasi chiqdi. Yangilab, yangi imkoniyatlardan foydalaning."
                      : info.message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A6478),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (!info.forceUpdate)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5A6478),
                            side: const BorderSide(color: Color(0xFFD4DAE6)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Keyinroq'),
                        ),
                      ),
                    if (!info.forceUpdate) const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final uri = Uri.tryParse(info.storeUrl.trim());
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                          if (!info.forceUpdate && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Yangilash'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
