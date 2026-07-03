import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final Future<void> Function(String username, String password) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await widget.onLogin(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    } catch (error) {
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/authbg.png', fit: BoxFit.cover),
          Container(color: Colors.white.withValues(alpha: 0.26)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 36),
                        Image.asset(
                          'assets/logo.png',
                          width: 168,
                          height: 168,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Taraqqiyot',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.brandColor,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Teaching Center',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.brandColor,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _InputField(
                          controller: _usernameController,
                          label: 'Foydalanuvchi nomi',
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Foydalanuvchi nomini kiriting';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _InputField(
                          controller: _passwordController,
                          label: 'Parol',
                          icon: Icons.lock_outline_rounded,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscurePassword,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _submit();
                            }
                          },
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Parol kiriting';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _RememberCheckBox(
                              value: false,
                              label: 'Meni eslab qol',
                              onChanged: (_) {},
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.brandColor,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Parolni unutdingizmi?',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _isLoading ? 'Kutilmoqda' : 'Kirish',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 12,
                              shadowColor: AppTheme.brandColor.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _SocialRow(),
                        const SizedBox(height: 18),
                        if (_errorText != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFF1F2,
                              ).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF9F1239),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.textInputAction,
    required this.autofillHints,
    required this.validator,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputAction textInputAction;
  final List<String> autofillHints;
  final String? Function(String?) validator;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.hasError) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(
                    color: Color(0xFFD21F1F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            TextField(
              controller: controller,
              obscureText: obscureText,
              textInputAction: textInputAction,
              autofillHints: autofillHints,
              onSubmitted: onFieldSubmitted,
              style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
              onChanged: (value) {
                state.didChange(value);
              },
              decoration: InputDecoration(
                hintText: label,
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9E7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.brandColor, size: 22),
                ),
                suffixIcon: suffix,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.96),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFF2F2F2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppTheme.brandColor,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RememberCheckBox extends StatelessWidget {
  const _RememberCheckBox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppTheme.brandColor, width: 1.4),
              color: value ? AppTheme.brandColor : Colors.transparent,
            ),
            child: value
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: Color(0xFF111827), fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          icon: LucideIcons.instagram,
          backgroundColor: Colors.white,
          iconColor: const Color(0xFFE1306C),
        ),
        const SizedBox(width: 16),
        _SocialButton(
          icon: FontAwesomeIcons.youtube,
          backgroundColor: Colors.white,
          iconColor: const Color(0xFFFF0000),
        ),
        const SizedBox(width: 16),
        _SocialButton(
          icon: FontAwesomeIcons.telegram,
          backgroundColor: Colors.white,
          iconColor: const Color(0xFF229ED9),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: 30),
    );
  }
}
