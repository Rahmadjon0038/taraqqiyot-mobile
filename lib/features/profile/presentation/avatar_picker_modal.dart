import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/auth_session.dart';
import '../data/avatar_catalog.dart';
import '../data/avatar_library_service.dart';
import 'widgets/profile_avatar.dart';

class AvatarPickerModal {
  const AvatarPickerModal._();

  static Future<void> show({
    required BuildContext context,
    required AuthSession session,
    required Future<void> Function(AuthSession session) onSessionUpdated,
    String? forcedKey,
  }) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompactModalShell(
        child: _AvatarPickerSheet(
          session: session,
          forcedKey: forcedKey,
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final service = AuthService();
      final updatedUser = await service.updateProfile(session.accessToken, {
        'avatar_key': result,
      });
      await onSessionUpdated(session.copyWith(user: updatedUser));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Avatar yangilandi')));
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

class _CompactModalShell extends StatelessWidget {
  const _CompactModalShell({required this.child});

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

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.session, this.forcedKey});

  final AuthSession session;
  final String? forcedKey;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  String? _selectedKey;
  late final Future<List<AvatarOption>> _avatarsFuture;

  @override
  void initState() {
    super.initState();
    _avatarsFuture = _loadAvatars();
    _selectedKey = widget.forcedKey ?? widget.session.user.avatarKey;
  }

  Future<List<AvatarOption>> _loadAvatars() async {
    try {
      final service = AvatarLibraryService();
      final remote = await service.fetchPublishedAvatars(
        widget.session.accessToken,
      );
      return <AvatarOption>[
        defaultAvatarOption,
        ...remote.where((option) => option.key != defaultAvatarOption.key),
      ];
    } catch (_) {
      return const [defaultAvatarOption];
    }
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
                  'Profil avatari',
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
          FutureBuilder<List<AvatarOption>>(
            future: _avatarsFuture,
            builder: (context, snapshot) {
              final avatars = snapshot.data ?? avatarOptions;
              final selectedKey = _selectedKey ?? widget.session.user.avatarKey;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _AvatarGridSkeleton();
              }

              return GridView.builder(
                itemCount: avatars.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.02,
                    ),
                itemBuilder: (context, index) {
                  final option = avatars[index];
                  return AvatarGridTile(
                    option: option,
                    selected: option.key == selectedKey,
                    onTap: () {
                      setState(() {
                        _selectedKey = option.key;
                      });
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_selectedKey ?? widget.session.user.avatarKey);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Tanlash',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarGridSkeleton extends StatelessWidget {
  const _AvatarGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (context, index) {
        return const _AvatarSkeletonTile();
      },
    );
  }
}

class _AvatarSkeletonTile extends StatefulWidget {
  const _AvatarSkeletonTile();

  @override
  State<_AvatarSkeletonTile> createState() => _AvatarSkeletonTileState();
}

class _AvatarSkeletonTileState extends State<_AvatarSkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = 0.08 + (_controller.value * 0.06);
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFF3F4F6),
              const Color(0xFFE9ECF2),
              value,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
