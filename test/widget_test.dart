import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/core/theme/theme_presets.dart';

void main() {
  test('Pastel Meadow is default theme preset', () {
    expect(ThemePresets.pastelMeadow.id, 'pastel_meadow');
    expect(ThemePresets.pastelMeadow.isDark, isTrue);
    expect(ThemePresets.builtIn.first.id, 'pastel_meadow');
  });

  test('Theme preset lookup falls back to Pastel Meadow', () {
    expect(ThemePresets.byId('unknown').id, 'pastel_meadow');
    expect(ThemePresets.byId('midnight').id, 'midnight');
  });
}
