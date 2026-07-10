import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';

class ThemePresets {
  static const pastelMeadow = AppTheme(
    id: 'pastel_meadow',
    name: 'Pastel Meadow',
    background: Color(0xFF1A2E1A),
    surface: Color(0xFF243824),
    accent: Color(0xFFA8D5BA),
    accentSecondary: Color(0xFFC5E8D0),
    accentMuted: Color(0xFF5A7A62),
    onBackground: Color(0xFFF0F7F2),
    onBackgroundMuted: Color(0xFF9BB8A3),
    favorite: Color(0xFFE8A0BF),
    isDark: true,
  );

  static const midnight = AppTheme(
    id: 'midnight',
    name: 'Midnight',
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    accent: Color(0xFF79C0FF),
    accentSecondary: Color(0xFFA5D6FF),
    accentMuted: Color(0xFF484F58),
    onBackground: Color(0xFFF0F6FC),
    onBackgroundMuted: Color(0xFF8B949E),
    favorite: Color(0xFFFF7B72),
    isDark: true,
  );

  static const warmSand = AppTheme(
    id: 'warm_sand',
    name: 'Warm Sand',
    background: Color(0xFF2A2118),
    surface: Color(0xFF3A2F24),
    accent: Color(0xFFE8C9A0),
    accentSecondary: Color(0xFFF5DFC0),
    accentMuted: Color(0xFF8A7358),
    onBackground: Color(0xFFFFF8F0),
    onBackgroundMuted: Color(0xFFC4B5A5),
    favorite: Color(0xFFE07A5F),
    isDark: true,
  );

  static const ocean = AppTheme(
    id: 'ocean',
    name: 'Ocean',
    background: Color(0xFF0F1F2E),
    surface: Color(0xFF1A2F42),
    accent: Color(0xFF7EC8E3),
    accentSecondary: Color(0xFFB8E0F0),
    accentMuted: Color(0xFF4A6B7C),
    onBackground: Color(0xFFE8F4F8),
    onBackgroundMuted: Color(0xFF94B8C8),
    favorite: Color(0xFFFF6B9D),
    isDark: true,
  );

  static const lightMeadow = AppTheme(
    id: 'light_meadow',
    name: 'Light Meadow',
    background: Color(0xFFF0F7F2),
    surface: Color(0xFFE2EFE6),
    accent: Color(0xFF4A8F65),
    accentSecondary: Color(0xFF6BAF82),
    accentMuted: Color(0xFFB8D4C4),
    onBackground: Color(0xFF1A2E1A),
    onBackgroundMuted: Color(0xFF5A7A62),
    favorite: Color(0xFFD45D8C),
    isDark: false,
  );

  static List<AppTheme> get builtIn => [
        pastelMeadow,
        midnight,
        warmSand,
        ocean,
        lightMeadow,
      ];

  static AppTheme byId(String id) {
    return builtIn.firstWhere(
      (t) => t.id == id,
      orElse: () => pastelMeadow,
    );
  }
}
