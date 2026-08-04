import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/data/auth_service.dart';
import '../features/auth/data/auth_storage.dart';
import '../features/auth/models/auth_session.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/home/presentation/pages/role_aware_home_page.dart';
import '../features/notifications/presentation/notification_detail_page.dart';
import '../core/localization/app_language.dart';
import '../features/profile/data/avatar_library_service.dart';
import '../core/services/notification_service.dart';
import '../core/navigation/app_route_observer.dart';
import 'theme/app_theme.dart';

class TaraqqiyotApp extends StatefulWidget {
  const TaraqqiyotApp({super.key});

  @override
  State<TaraqqiyotApp> createState() => _TaraqqiyotAppState();
}

class _TaraqqiyotAppState extends State<TaraqqiyotApp> {
  final AuthService _authService = AuthService();
  final AuthStorage _authStorage = AuthStorage();
  final AvatarLibraryService _avatarLibraryService =
      const AvatarLibraryService();
  final AppLanguageController _languageController = AppLanguageController('uz');

  AuthSession? _session;
  bool _bootstrapping = true;
  bool _startedBootstrap = false;
  bool _scheduledNotificationFlush = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedBootstrap) return;
    _startedBootstrap = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    try {
      await _languageController.load();
      final savedSession = await _authStorage.loadSession();

      if (savedSession == null) {
        if (!mounted) return;
        NotificationService.instance.clearSession();
        setState(() {
          _session = null;
        });
        return;
      }

      try {
        final profile = await _authService.fetchProfile(
          savedSession.accessToken,
        );
        final refreshedSession = savedSession.copyWith(user: profile);
        await _authStorage.saveSession(refreshedSession);

        if (!mounted) return;
        setState(() {
          _session = refreshedSession;
        });
        await _warmAvatarRegistry(refreshedSession);
        await NotificationService.instance.bindSession(refreshedSession);
      } catch (error) {
        final freshAccessToken = await _authService.refreshAccessToken(
          savedSession.refreshToken,
        );
        final profile = await _authService.fetchProfile(freshAccessToken);
        final refreshedSession = savedSession.copyWith(
          accessToken: freshAccessToken,
          user: profile,
        );
        await _authStorage.saveSession(refreshedSession);

        if (!mounted) return;
        setState(() {
          _session = refreshedSession;
        });
        await _warmAvatarRegistry(refreshedSession);
        await NotificationService.instance.bindSession(refreshedSession);
      }
    } catch (error) {
      await _authStorage.clearSession();
      NotificationService.instance.clearSession();
      if (!mounted) return;
      setState(() {
        _session = null;
        _bootstrapping = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapping = false;
        });
      }
    }
  }

  Future<void> _handleLogin(String username, String password) async {
    final loginSession = await _authService.login(
      username: username,
      password: password,
    );

    final profile = await _authService.fetchProfile(loginSession.accessToken);
    final fullSession = loginSession.copyWith(user: profile);

    await _authStorage.saveSession(fullSession);

    if (!mounted) return;
    setState(() {
      _session = fullSession;
    });
    await _warmAvatarRegistry(fullSession);
    await NotificationService.instance.bindSession(fullSession);
  }

  Future<void> _handleLogout() async {
    await _authStorage.clearSession();
    NotificationService.instance.clearSession();
    if (!mounted) return;
    setState(() {
      _session = null;
    });
  }

  Future<void> _handleSessionUpdated(AuthSession updatedSession) async {
    await _authStorage.saveSession(updatedSession);
    if (!mounted) return;
    setState(() {
      _session = updatedSession;
    });
    await _warmAvatarRegistry(updatedSession);
    await NotificationService.instance.bindSession(updatedSession);
  }

  Future<void> _warmAvatarRegistry(AuthSession session) async {
    try {
      await _avatarLibraryService.fetchPublishedAvatars(session.accessToken);
    } catch (_) {
      // Avatar registry may already be warm or temporarily unavailable.
    }
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduledNotificationFlush) {
      _scheduledNotificationFlush = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.flushPendingNotification();
      });
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taraqqiyot Teaching Center',
      theme: AppTheme.light(),
      navigatorKey: NotificationService.instance.navigatorKey,
      navigatorObservers: [appRouteObserver],
      builder: (context, child) => AppLanguageScope(
        controller: _languageController,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == NotificationDetailPage.routeName) {
          final payload = settings.arguments;
          return MaterialPageRoute(
            builder: (_) => NotificationDetailPage(
              payload: payload is Map<String, dynamic>
                  ? payload
                  : <String, dynamic>{},
            ),
            settings: settings,
          );
        }
        return null;
      },
      // Splash ham switcher ichida — keyingi sahifaga silliq fade bilan o'tadi
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _bootstrapping
            ? const SplashPage(key: ValueKey('splash'))
            : _session == null
            ? LoginPage(key: const ValueKey('login'), onLogin: _handleLogin)
            : RoleAwareHomePage(
                key: const ValueKey('main-home'),
                session: _session!,
                onSessionUpdated: _handleSessionUpdated,
                onLogout: _handleLogout,
              ),
      ),
    );
  }
}
