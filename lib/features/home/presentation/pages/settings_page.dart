import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/models/auth_session.dart';
import '../../../profile/data/avatar_library_service.dart';
import '../../../profile/presentation/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final name = user.fullName.isEmpty ? user.username : user.fullName;
    final role = user.role.isEmpty ? 'user' : user.role;
    final normalizedRole = role.toLowerCase();
    final avatarKey = user.avatarKey;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.brandColor, Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              ProfileAvatar(
                avatarKey: avatarKey,
                avatarUrl: user.avatarUrl,
                role: role,
                seed: user.username,
                size: 60,
                showBorder: true,
                elevation: 8,
                onTap: () {
                  AvatarPickerModal.show(
                    context: context,
                    session: session,
                    onSessionUpdated: onSessionUpdated,
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                   
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          children: [
            _SettingsTile(
              icon: Icons.badge_outlined,
              title: 'Profil ma\'lumotlari',
              onTap: () =>
                  _openProfileEditor(context, session, onSessionUpdated),
            ),
            _SettingsTile(
              icon: Icons.account_circle_outlined,
              title: 'Profil avatari',
              onTap: () =>
                  _openAvatarPicker(context, session, onSessionUpdated),
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Parolni almashtirish',
              onTap: () => _openPasswordChange(context, session),
            ),
          ],
        ),
        if (normalizedRole == 'admin' || normalizedRole == 'super_admin') ...[
          const SizedBox(height: 14),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.file_upload_outlined,
                title: 'Avatarlarni yuklash',
                onTap: () => _openAvatarUploader(context, session),
              ),
              _SettingsTile(
                icon: Icons.collections_outlined,
                title: 'Avatarlar ro‘yxati',
                onTap: () =>
                    _openAvatarPicker(context, session, onSessionUpdated),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _SettingsSection(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: NotificationService.instance.pushEnabled,
              builder: (context, enabled, _) => _SwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Push notification',
                value: enabled,
                onChanged: (value) =>
                    NotificationService.instance.setPushEnabled(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsSection(
          children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Ilova haqida',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Chiqish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _openProfileEditor(
    BuildContext context,
    AuthSession session,
    Future<void> Function(AuthSession session) onSessionUpdated,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompactModalSheet(
        child: _ProfileEditSheet(session: session),
      ),
    );

    if (result == null) return;

    try {
      final service = AuthService();
      final updatedUser = await service.updateProfile(
        session.accessToken,
        result,
      );
      await onSessionUpdated(session.copyWith(user: updatedUser));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil ma\'lumotlari yangilandi')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  static Future<void> _openAvatarPicker(
    BuildContext context,
    AuthSession session,
    Future<void> Function(AuthSession session) onSessionUpdated, {
    String? forcedKey,
  }) async {
    await AvatarPickerModal.show(
      context: context,
      session: session,
      onSessionUpdated: onSessionUpdated,
      forcedKey: forcedKey,
    );
  }

  static Future<void> _openPasswordChange(
    BuildContext context,
    AuthSession session,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompactModalSheet(
        child: _PasswordChangeSheet(session: session),
      ),
    );

    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parol muvaffaqiyatli yangilandi')),
      );
    }
  }

  static Future<void> _openAvatarUploader(
    BuildContext context,
    AuthSession session,
  ) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompactModalSheet(
        child: _AvatarUploadSheet(session: session),
      ),
    );

    if (result == null) return;

    final filePath = result['path']?.trim() ?? '';
    if (filePath.isEmpty) return;

    try {
      final service = AvatarLibraryService();
      await service.uploadAvatar(
        accessToken: session.accessToken,
        filePath: filePath,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Avatar yuklandi')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _CompactModalSheet extends StatelessWidget {
  const _CompactModalSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({required this.session});

  final AuthSession session;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _phone2Controller;

  @override
  void initState() {
    super.initState();
    final user = widget.session.user;
    _usernameController = TextEditingController(text: user.username);
    _nameController = TextEditingController(text: user.name);
    _surnameController = TextEditingController(text: user.surname);
    _phoneController = TextEditingController(text: _text(user.raw['phone']));
    _phone2Controller = TextEditingController(text: _text(user.raw['phone2']));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Profil ma\'lumotlarini tahrirlash',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _field(_usernameController, 'Foydalanuvchi nomi'),
          _field(_nameController, 'Ism'),
          _field(_surnameController, 'Familiya'),
          _field(_phoneController, 'Telefon'),
          _field(_phone2Controller, 'Qo\'shimcha telefon'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final payload = <String, dynamic>{
                  'username': _usernameController.text.trim(),
                  'name': _nameController.text.trim(),
                  'surname': _surnameController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'phone2': _phone2Controller.text.trim(),
                };
                Navigator.of(context).pop(
                  Map<String, dynamic>.from(
                    payload..removeWhere(
                      (key, value) =>
                          value == null || value.toString().trim().isEmpty,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Saqlash',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.brandColor,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  static String _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? '' : text;
  }
}

class _PasswordChangeSheet extends StatefulWidget {
  const _PasswordChangeSheet({required this.session});

  final AuthSession session;

  @override
  State<_PasswordChangeSheet> createState() => _PasswordChangeSheetState();
}

class _PasswordChangeSheetState extends State<_PasswordChangeSheet> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty) {
      setState(() => _errorText = 'Eski va yangi parolni kiriting');
      return;
    }
    if (newPassword.length < 4) {
      setState(
        () => _errorText = 'Yangi parol kamida 4 ta belgidan iborat bo\'lsin',
      );
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorText = 'Yangi parol tasdiqlash bilan mos emas');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final service = AuthService();
      await service.changePassword(
        accessToken: widget.session.accessToken,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = error is AuthException
            ? error.message
            : 'Parolni yangilashda xatolik yuz berdi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Parolni almashtirish',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _passwordField(
            controller: _oldPasswordController,
            label: 'Eski parol',
            obscure: _obscureOld,
            onToggle: () => setState(() => _obscureOld = !_obscureOld),
          ),
          _passwordField(
            controller: _newPasswordController,
            label: 'Yangi parol',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          _passwordField(
            controller: _confirmPasswordController,
            label: 'Yangi parolni tasdiqlang',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 2),
            Text(
              _errorText!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA70E07),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Parolni yangilash',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.brandColor,
              width: 1.4,
            ),
          ),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: const Color(0xFF7B8495),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarUploadSheet extends StatefulWidget {
  const _AvatarUploadSheet({required this.session});

  final AuthSession session;

  @override
  State<_AvatarUploadSheet> createState() => _AvatarUploadSheetState();
}

class _AvatarUploadSheetState extends State<_AvatarUploadSheet> {
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (!mounted) return;
    setState(() {
      _pickedFile = result?.files.single;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Avatar yuklash',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: AppTheme.brandColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pickedFile?.name ?? 'Rasm tanlash',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _pickedFile == null
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF182033),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9AA2B2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final path = _pickedFile?.path;
                if (path == null || path.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avval rasm tanlang')),
                  );
                  return;
                }
                Navigator.of(context).pop({'path': path});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Yuklash',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: child,
          ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: AppTheme.brandColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF182033),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA2B2)),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: AppTheme.brandColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF182033),
                ),
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppTheme.brandColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
