import 'package:flutter/material.dart';

class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.accent,
    required this.accentSecondary,
    required this.accentMuted,
    required this.onBackground,
    required this.onBackgroundMuted,
    required this.favorite,
    required this.isDark,
  });

  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color accent;
  final Color accentSecondary;
  final Color accentMuted;
  final Color onBackground;
  final Color onBackgroundMuted;
  final Color favorite;
  final bool isDark;

  ThemeData toMaterialTheme() {
    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: background,
      secondary: accentSecondary,
      onSecondary: background,
      error: const Color(0xFFE57373),
      onError: Colors.white,
      surface: surface,
      onSurface: onBackground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      extensions: [this],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: onBackgroundMuted, fontSize: 12),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return IconThemeData(color: onBackgroundMuted);
        }),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.3),
        labelStyle: TextStyle(color: onBackground),
        secondaryLabelStyle: TextStyle(color: onBackgroundMuted),
        side: BorderSide(color: accentMuted.withValues(alpha: 0.4)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: onBackgroundMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: accentMuted,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.2),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        titleLarge: TextStyle(
          color: onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          color: onBackground,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(color: onBackground, fontSize: 16),
        bodyMedium: TextStyle(color: onBackgroundMuted, fontSize: 14),
        labelLarge: TextStyle(
          color: onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  AppTheme copyWith({
    String? id,
    String? name,
    Color? background,
    Color? surface,
    Color? accent,
    Color? accentSecondary,
    Color? accentMuted,
    Color? onBackground,
    Color? onBackgroundMuted,
    Color? favorite,
    bool? isDark,
  }) {
    return AppTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentMuted: accentMuted ?? this.accentMuted,
      onBackground: onBackground ?? this.onBackground,
      onBackgroundMuted: onBackgroundMuted ?? this.onBackgroundMuted,
      favorite: favorite ?? this.favorite,
      isDark: isDark ?? this.isDark,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'background': background.toARGB32(),
        'surface': surface.toARGB32(),
        'accent': accent.toARGB32(),
        'accentSecondary': accentSecondary.toARGB32(),
        'accentMuted': accentMuted.toARGB32(),
        'onBackground': onBackground.toARGB32(),
        'onBackgroundMuted': onBackgroundMuted.toARGB32(),
        'favorite': favorite.toARGB32(),
        'isDark': isDark,
      };

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    Color c(int value) => Color(value);
    return AppTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      background: c(json['background'] as int),
      surface: c(json['surface'] as int),
      accent: c(json['accent'] as int),
      accentSecondary: c(json['accentSecondary'] as int),
      accentMuted: c(json['accentMuted'] as int),
      onBackground: c(json['onBackground'] as int),
      onBackgroundMuted: c(json['onBackgroundMuted'] as int),
      favorite: c(json['favorite'] as int),
      isDark: json['isDark'] as bool? ?? true,
    );
  }

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) return this;
    return AppTheme(
      id: t < 0.5 ? id : other.id,
      name: t < 0.5 ? name : other.name,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      onBackgroundMuted:
          Color.lerp(onBackgroundMuted, other.onBackgroundMuted, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppTheme get appTheme => Theme.of(this).extension<AppTheme>()!;
}
