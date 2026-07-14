import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/taraqqiyot_app.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseEnabled = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Firebase/push init xatosi UI ochilishini to'sib qo'ymasligi kerak:
  // iOS simulatorda APNS token bo'lmagani uchun getToken() xato otadi,
  // shu sabab init runApp'dan KEYIN va xatoga chidamli qilib ishga tushiriladi.
  var firebaseReady = false;
  if (firebaseEnabled) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      firebaseReady = true;
    } catch (error) {
      debugPrint('Firebase init xatosi (app baribir ochiladi): $error');
    }
  }

  runApp(const TaraqqiyotApp());

  unawaited(
    NotificationService.instance
        .init(firebaseEnabled: firebaseReady)
        .catchError((Object error) {
      debugPrint('Notification init xatosi: $error');
    }),
  );
}
