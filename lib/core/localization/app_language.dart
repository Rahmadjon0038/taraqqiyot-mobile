import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _languagePrefKey = 'app_language_code';

class AppLanguageController extends ValueNotifier<String> {
  AppLanguageController([super.value = 'uz']);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = _normalizeCode(prefs.getString(_languagePrefKey));
  }

  Future<void> setLanguageCode(String languageCode) async {
    final normalized = _normalizeCode(languageCode);
    if (normalized == value) return;

    value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, normalized);
  }

  static String _normalizeCode(String? code) {
    final normalized = (code ?? '').trim().toLowerCase();
    return normalized == 'en' ? 'en' : 'uz';
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

class AppText {
  AppText._(this.languageCode);

  final String languageCode;

  static AppText of(BuildContext context) {
    return AppText._(AppLanguageScope.of(context).value);
  }

  bool get isEnglish => languageCode == 'en';
  String _s(String uz, String en) => isEnglish ? en : uz;

  String get settings => _s('Sozlamalar', 'Settings');
  String get profileInformation =>
      _s('Profil ma\'lumotlari', 'Profile details');
  String get profileAvatar => _s('Profil avatari', 'Profile avatar');
  String get changePassword => _s('Parolni almashtirish', 'Change password');
  String get uploadAvatars => _s('Avatarlarni yuklash', 'Upload avatars');
  String get avatarList => _s('Avatarlar ro‘yxati', 'Avatar list');
  String get pushNotifications => _s('Push notification', 'Push notifications');
  String get aboutApp => _s('Ilova haqida', 'About app');
  String get deleteAccount => _s('Akkauntni o\'chirish', 'Delete account');
  String get logout => _s('Chiqish', 'Log out');
  String get language => _s('Til', 'Language');
  String get languageSubtitle => _s('Interfeys tili', 'Interface language');
  String get currentLanguageName => _s('O\'zbek tili', 'English');
  String get chooseLanguage => _s('Til tanlang', 'Choose language');
  String get uzbek => 'O\'zbek tili';
  String get english => 'English';
  String get save => _s('Saqlash', 'Save');
  String get close => _s('Yopish', 'Close');
  String get confirm => _s('Tasdiqlash', 'Confirm');
  String get delete => _s('O\'chirish', 'Delete');

  String get profileEditorTitle =>
      _s('Profil ma\'lumotlarini tahrirlash', 'Edit profile details');
  String get username => _s('Foydalanuvchi nomi', 'Username');
  String get name => _s('Ism', 'Name');
  String get surname => _s('Familiya', 'Surname');
  String get phone => _s('Telefon', 'Phone');
  String get phone2 => _s('Qo\'shimcha telefon', 'Secondary phone');
  String get oldPassword => _s('Eski parol', 'Old password');
  String get newPassword => _s('Yangi parol', 'New password');
  String get confirmNewPassword =>
      _s('Yangi parolni tasdiqlang', 'Confirm new password');
  String get passwordChangeTitle =>
      _s('Parolni almashtirish', 'Change password');
  String get passwordChangeButton => _s('Parolni yangilash', 'Update password');
  String get passwordChangeSuccess =>
      _s('Parol muvaffaqiyatli yangilandi', 'Password updated');
  String get passwordChangeError =>
      _s('Parolni yangilashda xatolik yuz berdi', 'Failed to update password');
  String get passwordMismatch =>
      _s('Yangi parol tasdiqlash bilan mos emas', 'Passwords do not match');
  String get passwordRequired =>
      _s('Eski va yangi parolni kiriting', 'Enter old and new passwords');
  String get passwordTooShort => _s(
    'Yangi parol kamida 4 ta belgidan iborat bo\'lsin',
    'New password must be at least 4 characters',
  );
  String get aboutTitle => _s('Ilova haqida', 'About app');
  String get aboutStudentTitle => _s('Ilova haqida', 'About');
  String get aboutStudentDescription => _s(
    'Taraqqiyot Teaching Center mobil ilovasi studentlar uchun mo\'ljallangan bo\'lib, guruhlar, davomat, ballar, to\'lovlar va profil ma\'lumotlarini ko\'rish imkonini beradi.',
    'The Taraqqiyot Teaching Center mobile app is designed for students and provides access to groups, attendance, points, payments, and profile information.',
  );
  String get appName => 'Taraqqiyot Teaching Center';
  String get appDescription => _s(
    'Mobil ilova orqali profilingiz, guruhlaringiz va to\'lovlaringizni boshqaring.',
    'Manage your profile, groups, and payments from the mobile app.',
  );
  String get deleteAccountTitle => _s('Akkauntni o\'chirish', 'Delete account');
  String get deleteAccountWarningTitle =>
      _s('Bu amalni qaytarib bo\'lmaydi!', 'This action cannot be undone!');
  String get deleteAccountWarningBody => _s(
    'Akkauntingiz va unga bog\'liq barcha ma\'lumotlar (guruhlar, davomat, ballar, to\'lov tarixi) butunlay o\'chib ketadi. Qayta tiklash imkoni yo\'q.',
    'Your account and all related data (groups, attendance, points, payment history) will be deleted permanently. This cannot be restored.',
  );
  String get deleteAccountButton =>
      _s('Akkauntni o\'chirish', 'Delete account');
  String get deleteAccountSuccess =>
      _s('Akkaunt o\'chirildi', 'Account deleted');
  String get deleteAccountError => _s(
    'Akkauntni o\'chirishda xatolik yuz berdi',
    'Failed to delete account',
  );
  String get deleteAccountConfirmHint => _s(
    'Hisobingizni o\'chirish uchun tasdiqlang',
    'Confirm to delete your account',
  );

  String get studentPanel => _s('Student paneli', 'Student panel');
  String get studentActiveSubtitle =>
      _s('Student hisobingiz faol', 'Your student account is active');
  String get studentProfile => _s('Profil', 'Profile');
  String get studentGroup => _s('Guruh', 'Group');
  String get unavailable => _s('Mavjud emas', 'Not available');
  String get role => _s('Roli', 'Role');
  String get teacher => _s("O'qituvchi", 'Teacher');
  String get subject => _s('Fan', 'Subject');
  String get room => _s('Xona', 'Room');
  String get status => _s('Holat', 'Status');
  String get groupName => _s('Guruh nomi', 'Group name');
  String get myGroups => _s('Mening guruhlarim', 'My groups');
  String get attendance => _s('Davomat', 'Attendance');
  String get myPayments => _s("To'lovlarim", 'My payments');
  String get home => _s('Asosiy', 'Home');
  List<String> get studentTabTitles => [
    home,
    myGroups,
    attendance,
    myPayments,
    settings,
  ];
}
