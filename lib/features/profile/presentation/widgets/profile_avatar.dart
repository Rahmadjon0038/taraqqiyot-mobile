import 'package:flutter/material.dart';

import '../../../../core/config/api_config.dart';
import '../../data/avatar_catalog.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarKey,
    required this.role,
    required this.seed,
    this.avatarUrl,
    this.onTap,
    this.size = 52,
    this.elevation = 0,
    this.showBorder = false,
  });

  final String? avatarKey;
  final String? role;
  final String? seed;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final double size;
  final double elevation;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final option = resolveAvatarOption(
      avatarKey: avatarKey,
      role: role,
      seed: seed,
    );

    final resolvedAvatarUrl = _normalizeAvatarUrl(avatarUrl);
    final hasRemoteImage = resolvedAvatarUrl.isNotEmpty;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.2)
            : null,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: elevation,
                  offset: Offset(0, elevation / 4),
                ),
              ]
            : null,
        gradient: LinearGradient(
          colors: option.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: hasRemoteImage
          ? ClipOval(
              child: Image.network(
                resolvedAvatarUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(option.icon, color: Colors.white, size: size * 0.48),
              ),
            )
          : Icon(option.icon, color: Colors.white, size: size * 0.48),
    );

    if (onTap == null) {
      return avatar;
    }

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 8,
        containedInkWell: false,
        child: avatar,
      ),
    );
  }

  String _normalizeAvatarUrl(String? rawUrl) {
    final raw = rawUrl?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      if (raw.contains('localhost') || raw.contains('127.0.0.1')) {
        final uri = Uri.tryParse(raw);
        if (uri != null) {
          return '${ApiConfig.baseUrl}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
        }
      }
      return raw;
    }
    return raw.startsWith('/') ? '${ApiConfig.baseUrl}$raw' : '${ApiConfig.baseUrl}/$raw';
  }
}

class AvatarGridTile extends StatelessWidget {
  const AvatarGridTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AvatarOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: option.imageUrl == null
              ? LinearGradient(
                  colors: option.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: option.imageUrl != null ? const Color(0xFFF3F4F6) : null,
          border: selected
              ? Border.all(color: const Color(0xFFA60E07), width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: ClipOval(
          child: option.imageUrl != null
              ? Image.network(
                  option.imageUrl!,
                  fit: BoxFit.cover,
                  width: 52,
                  height: 52,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(option.icon, color: Colors.white, size: 24),
                )
              : Icon(option.icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
