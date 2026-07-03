import 'package:flutter/material.dart';

class AvatarOption {
  const AvatarOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.colors,
    this.imageUrl,
  });

  final String key;
  final String label;
  final IconData icon;
  final List<Color> colors;
  final String? imageUrl;
}

const defaultAvatarOption = AvatarOption(
  key: 'default_avatar',
  label: 'Default',
  icon: Icons.school_rounded,
  colors: [Color(0xFFA70E07), Color(0xFFCB3A31)],
);

const avatarOptions = <AvatarOption>[defaultAvatarOption];

class AvatarRegistry {
  AvatarRegistry._();

  static final AvatarRegistry instance = AvatarRegistry._();

  final Map<String, AvatarOption> _optionsByKey = {
    defaultAvatarOption.key: defaultAvatarOption,
  };

  void registerAll(Iterable<AvatarOption> options) {
    for (final option in options) {
      if (option.key.trim().isEmpty) continue;
      _optionsByKey[option.key.trim()] = option;
    }
  }

  void register(AvatarOption option) {
    if (option.key.trim().isEmpty) return;
    _optionsByKey[option.key.trim()] = option;
  }

  AvatarOption? resolve(String? key) {
    final normalizedKey = key?.trim();
    if (normalizedKey == null || normalizedKey.isEmpty) {
      return null;
    }
    return _optionsByKey[normalizedKey];
  }
}

AvatarOption resolveAvatarOption({
  String? avatarKey,
  String? role,
  String? seed,
}) {
  final registered = AvatarRegistry.instance.resolve(avatarKey);
  if (registered != null) {
    return registered;
  }

  final normalizedKey = avatarKey?.trim();
  if (normalizedKey != null && normalizedKey.isNotEmpty) {
    for (final option in avatarOptions) {
      if (option.key == normalizedKey) {
        return option;
      }
    }
  }

  return defaultAvatarOption;
}
