import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/theme/theme_presets.dart';

const _activeThemeKey = 'active_theme_id';
const _customThemesKey = 'custom_themes';

class ThemeState {
  const ThemeState({
    required this.active,
    required this.customThemes,
  });

  final AppTheme active;
  final List<AppTheme> customThemes;

  List<AppTheme> get allThemes => [...ThemePresets.builtIn, ...customThemes];

  ThemeState copyWith({AppTheme? active, List<AppTheme>? customThemes}) {
    return ThemeState(
      active: active ?? this.active,
      customThemes: customThemes ?? this.customThemes,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(active: ThemePresets.pastelMeadow, customThemes: []));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeThemeKey) ?? ThemePresets.pastelMeadow.id;
    final customJson = prefs.getStringList(_customThemesKey) ?? [];
    final customThemes = customJson
        .map((e) => AppTheme.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();

    AppTheme active = ThemePresets.byId(activeId);
    for (final theme in customThemes) {
      if (theme.id == activeId) {
        active = theme;
        break;
      }
    }

    state = ThemeState(active: active, customThemes: customThemes);
  }

  Future<void> setActive(String themeId) async {
    final theme = state.allThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => ThemePresets.pastelMeadow,
    );
    state = state.copyWith(active: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeThemeKey, themeId);
  }

  Future<void> saveCustomTheme(AppTheme theme) async {
    final updated = [...state.customThemes];
    final index = updated.indexWhere((t) => t.id == theme.id);
    if (index >= 0) {
      updated[index] = theme;
    } else {
      updated.add(theme);
    }
    state = state.copyWith(customThemes: updated);
    await _persistCustomThemes(updated);
  }

  Future<void> deleteCustomTheme(String themeId) async {
    final updated = state.customThemes.where((t) => t.id != themeId).toList();
    var active = state.active;
    if (active.id == themeId) {
      active = ThemePresets.pastelMeadow;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeThemeKey, active.id);
    }
    state = state.copyWith(customThemes: updated, active: active);
    await _persistCustomThemes(updated);
  }

  Future<void> _persistCustomThemes(List<AppTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _customThemesKey,
      themes.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
