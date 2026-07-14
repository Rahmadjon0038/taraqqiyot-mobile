import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/super_admin_service.dart';

/// Adminlar boshqaruvi: ro'yxat, yaratish, bloklash/faollashtirish,
/// o'chirish, oylik to'lash va oyliklar tarixi.
class SuperAdminAdminsPage extends StatefulWidget {
  const SuperAdminAdminsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SuperAdminAdminsPage> createState() => _SuperAdminAdminsPageState();
}

class _SuperAdminAdminsPageState extends State<SuperAdminAdminsPage> {
  final SuperAdminService _service = SuperAdminService();
  late Future<List<AdminUser>> _adminsFuture;
  late String _month;
  late List<String> _months;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _months = [_month];
    _adminsFuture = _service.fetchAdmins(widget.session, monthName: _month);
    _loadMonths();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  /// Oy ro'yxati tizim ish boshlagan oydan boshlanadi
  Future<void> _loadMonths() async {
    final start = await _service.fetchSystemStartMonth(widget.session);
    if (!mounted) return;
    setState(() {
      _months = SuperAdminService.monthsFrom(start);
    });
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      _adminsFuture = _service.fetchAdmins(widget.session, monthName: month);
    });
  }

  Future<void> _reload() async {
    setState(() {
      _adminsFuture = _service.fetchAdmins(widget.session, monthName: _month);
    });
    await _adminsFuture;
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF16934F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CreateAdminSheet(session: widget.session, service: _service),
    );
    if (created == true) {
      _showSnack('Admin yaratildi');
      await _reload();
    }
  }

  Future<void> _openPaySheet(AdminUser admin) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaySalarySheet(
        session: widget.session,
        service: _service,
        admin: admin,
        monthName: _month,
      ),
    );
    if (paid == true) {
      _showSnack('Oylik to\'landi');
      await _reload();
    }
  }

  Future<void> _toggleStatus(AdminUser admin) async {
    try {
      await _service.updateAdminStatus(
        widget.session,
        admin.id,
        admin.isActive ? 'terminated' : 'active',
      );
      _showSnack(admin.isActive ? 'Admin bloklandi' : 'Admin faollashtirildi');
      await _reload();
    } catch (error) {
      _showSnack(error.toString(), error: true);
    }
  }

  Future<void> _deleteAdmin(AdminUser admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adminni o\'chirish'),
        content: Text(
          '${admin.fullName} o\'chirilsinmi? Bu amalni qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteAdmin(widget.session, admin.id);
      _showSnack('Admin o\'chirildi');
      await _reload();
    } catch (error) {
      _showSnack(error.toString(), error: true);
    }
  }

  void _openSalaryHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SalaryHistoryPage(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: AppTheme.brandColor,
      child: FutureBuilder<List<AdminUser>>(
        future: _adminsFuture,
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final admins = snapshot.data ?? const <AdminUser>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Oy tanlash — o'sha oyda oylik to'langanini ko'rish uchun
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _months.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final month = _months[index];
                    final selected = month == _month;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectMonth(month),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.brandColor.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AppTheme.brandColor
                                : const Color(0xFFD6DDEA),
                          ),
                        ),
                        child: Text(
                          _formatMonthLabel(month),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppTheme.brandColor
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Amallar qatori
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openCreateSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                      label: const Text(
                        'Admin qo\'shish',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openSalaryHistory,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brandColor,
                        side: const BorderSide(color: Color(0xFFD6DDEA)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 17),
                      label: const Text(
                        'Oyliklar tarixi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandColor,
                    ),
                  ),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Center(
                    child: Text(
                      snapshot.error is SuperAdminServiceException
                          ? (snapshot.error as SuperAdminServiceException)
                                .message
                          : 'Adminlar yuklanmadi',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else if (admins.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Center(
                    child: Text(
                      'Adminlar topilmadi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                for (final admin in admins) ...[
                  _AdminCard(
                    admin: admin,
                    onPay: () => _openPaySheet(admin),
                    onToggleStatus: () => _toggleStatus(admin),
                    onDelete: () => _deleteAdmin(admin),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.admin,
    required this.onPay,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final AdminUser admin;
  final VoidCallback onPay;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  admin.name.isNotEmpty ? admin.name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF182033),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${admin.username}'
                      '${admin.phone.isEmpty ? '' : ' • ${admin.phone}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8495),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qabul qilingan: ${admin.joinedDateLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A93A5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: admin.isActive
                      ? const Color(0xFF16934F).withValues(alpha: 0.10)
                      : const Color(0xFF8A93A5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  admin.isActive ? 'Faol' : 'Bloklangan',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: admin.isActive
                        ? const Color(0xFF16934F)
                        : const Color(0xFF6B7386),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tanlangan oy uchun oylik holati
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: admin.salaryAmount != null
                  ? const Color(0xFF16934F).withValues(alpha: 0.07)
                  : const Color(0xFFE9A23B).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(
                  admin.salaryAmount != null
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_bottom_rounded,
                  size: 13,
                  color: admin.salaryAmount != null
                      ? const Color(0xFF16934F)
                      : const Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    admin.salaryAmount != null
                        ? 'Oylik to\'langan: ${_formatMoney(admin.salaryAmount!)}'
                        : 'Bu oyda oylik to\'lanmagan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: admin.salaryAmount != null
                          ? const Color(0xFF16934F)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionChipButton(
                  icon: Icons.payments_rounded,
                  label: 'Oylik to\'lash',
                  color: const Color(0xFF16934F),
                  onTap: onPay,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionChipButton(
                  icon: admin.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                  label: admin.isActive ? 'Bloklash' : 'Faollashtirish',
                  color: const Color(0xFFB45309),
                  onTap: onToggleStatus,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionChipButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'O\'chirish',
                  color: const Color(0xFFDC2626),
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yangi admin yaratish bottom sheet
class _CreateAdminSheet extends StatefulWidget {
  const _CreateAdminSheet({required this.session, required this.service});

  final AuthSession session;
  final SuperAdminService service;

  @override
  State<_CreateAdminSheet> createState() => _CreateAdminSheetState();
}

class _CreateAdminSheetState extends State<_CreateAdminSheet> {
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || surname.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Ism, familiya, username va parol majburiy');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createAdmin(
        widget.session,
        name: name,
        surname: surname,
        username: username,
        password: password,
        phone: _phoneController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _saving = false;
        _error = error is SuperAdminServiceException
            ? error.message
            : 'Admin yaratilmadi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Yangi admin',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF182033),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration('Ism'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _surnameController,
                decoration: _inputDecoration('Familiya'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _usernameController,
                autocorrect: false,
                decoration: _inputDecoration('Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                autocorrect: false,
                decoration: _inputDecoration('Parol'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Telefon (ixtiyoriy)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Yaratish',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oylik to'lash bottom sheet
class _PaySalarySheet extends StatefulWidget {
  const _PaySalarySheet({
    required this.session,
    required this.service,
    required this.admin,
    required this.monthName,
  });

  final AuthSession session;
  final SuperAdminService service;
  final AdminUser admin;

  /// Qaysi oy uchun to'lanadi (ro'yxatda tanlangan oy)
  final String monthName;

  @override
  State<_PaySalarySheet> createState() => _PaySalarySheetState();
}

class _PaySalarySheetState extends State<_PaySalarySheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(
      _amountController.text.replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Summani to\'g\'ri kiriting');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.payAdminSalary(
        widget.session,
        adminId: widget.admin.id,
        monthName: widget.monthName,
        amount: amount,
        description: _descriptionController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _saving = false;
        _error = error is SuperAdminServiceException
            ? error.message
            : 'Oylik to\'lanmadi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Oylik to\'lash — ${widget.admin.fullName}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF182033),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_formatMonthLabel(widget.monthName)} oyi uchun',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7B8495),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('Summa (so\'m)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _inputDecoration('Izoh (ixtiyoriy)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16934F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'To\'lash',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
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

/// Oyliklar tarixi sahifasi
class _SalaryHistoryPage extends StatefulWidget {
  const _SalaryHistoryPage({required this.session});

  final AuthSession session;

  @override
  State<_SalaryHistoryPage> createState() => _SalaryHistoryPageState();
}

class _SalaryHistoryPageState extends State<_SalaryHistoryPage> {
  final SuperAdminService _service = SuperAdminService();
  late Future<List<AdminSalaryRecord>> _future;

  /// null — barcha oylar
  String? _month;
  List<String> _months = const [];

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAdminSalaries(widget.session);
    _loadMonths();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  /// Oy ro'yxati tizim ish boshlagan oydan boshlanadi
  Future<void> _loadMonths() async {
    final start = await _service.fetchSystemStartMonth(widget.session);
    if (!mounted) return;
    setState(() {
      _months = SuperAdminService.monthsFrom(start);
    });
  }

  void _selectMonth(String? month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      _future = _service.fetchAdminSalaries(widget.session, monthName: month);
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarixni tozalash'),
        content: Text(
          _month == null
              ? 'BARCHA to\'lov yozuvlari o\'chirilsinmi? Bu amalni qaytarib bo\'lmaydi.'
              : '${_formatMonthLabel(_month!)} oyidagi to\'lov yozuvlari o\'chirilsinmi? Bu amalni qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await _service.clearAdminSalaryHistory(
        widget.session,
        monthName: _month,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleted ta yozuv o\'chirildi'),
          backgroundColor: const Color(0xFF16934F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _future = _service.fetchAdminSalaries(
          widget.session,
          monthName: _month,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SuperAdminServiceException
                ? error.message
                : 'Tarix tozalanmadi',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Bitta adminning to'lov tarixini tozalash (tanlangan oy filtri bilan)
  Future<void> _clearAdminHistory(AdminSalaryRecord record) async {
    final adminLabel = record.adminName.isEmpty
        ? 'Admin #${record.adminId}'
        : record.adminName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin tarixini tozalash'),
        content: Text(
          _month == null
              ? '$adminLabel ning BARCHA to\'lov yozuvlari o\'chirilsinmi? Bu amalni qaytarib bo\'lmaydi.'
              : '$adminLabel ning ${_formatMonthLabel(_month!)} oyidagi to\'lov yozuvi o\'chirilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await _service.clearAdminSalaryHistory(
        widget.session,
        monthName: _month,
        adminId: record.adminId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleted ta yozuv o\'chirildi'),
          backgroundColor: const Color(0xFF16934F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _future = _service.fetchAdminSalaries(
          widget.session,
          monthName: _month,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SuperAdminServiceException
                ? error.message
                : 'Tarix tozalanmadi',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Adminlar oyliklari',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF182033),
          ),
        ),
        actions: [
          // Tarixni tozalash
          IconButton(
            onPressed: _clearHistory,
            tooltip: 'Tarixni tozalash',
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Color(0xFFDC2626),
              size: 22,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Oy filtri: "Hammasi" + oxirgi 12 oy
          SizedBox(
            height: 32,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _months.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final month = index == 0 ? null : _months[index - 1];
                final selected = month == _month;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectMonth(month),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.brandColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandColor
                            : const Color(0xFFD6DDEA),
                      ),
                    ),
                    child: Text(
                      month == null ? 'Hammasi' : _formatMonthLabel(month),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppTheme.brandColor
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<AdminSalaryRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandColor,
                    ),
                  );
                }
                final records = snapshot.data ?? const <AdminSalaryRecord>[];
                if (records.isEmpty) {
                  return const Center(
                    child: Text(
                      'To\'lovlar topilmadi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  );
                }
                return _SalaryList(
                  records: records,
                  onDeleteAdmin: _clearAdminHistory,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryList extends StatelessWidget {
  const _SalaryList({required this.records, required this.onDeleteAdmin});

  final List<AdminSalaryRecord> records;
  final ValueChanged<AdminSalaryRecord> onDeleteAdmin;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = records[index];
        return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E9F1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.adminName.isEmpty
                                ? 'Admin #${record.adminId}'
                                : record.adminName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF182033),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              record.monthName,
                              if (record.description.isNotEmpty)
                                record.description,
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A93A5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16934F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _formatMoney(record.amount),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16934F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Shu adminning tarixini tozalash
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDeleteAdmin(record),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              );
      },
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9AA2B2),
    ),
    filled: true,
    fillColor: const Color(0xFFF6F8FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppTheme.brandColor, width: 1.4),
    ),
  );
}

String _formatMoney(double value) {
  final rounded = value.round();
  final text = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(text[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer so\'m';
}

String _formatMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]) ?? 1;
  const names = [
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];
  final monthName = month >= 1 && month <= 12 ? names[month - 1] : monthKey;
  return '$monthName ${parts[0]}';
}
