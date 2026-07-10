import 'package:flutter/material.dart';

/// Shared spacing scale — consistent rhythm across screens.
abstract final class UxSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Minimum touch targets per Material / iOS HIG.
abstract final class UxTouchTargets {
  static const double minimum = 48;
  static const double playButton = 68;
  static const double iconButton = 40;
}

/// Corner radii for cards, chips, and artwork.
abstract final class UxRadii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 24;
}

/// Horizontal screen padding.
abstract final class UxInsets {
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: UxSpacing.lg);
  static const EdgeInsets card = EdgeInsets.symmetric(
    horizontal: UxSpacing.sm,
    vertical: 10,
  );
}

/// Typography helpers for player surfaces.
abstract final class UxTypography {
  static const double trackTitle = 28;
  static const double artistName = 16;
  static const double caption = 12;
}

/// Motion durations for micro-interactions.
abstract final class UxMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration vinylRotation = Duration(seconds: 4);
}

/// UX guidelines encoded as constants:
/// - One primary action per surface (play/pause in control bar)
/// - 48dp minimum tap targets on all interactive elements
/// - Hero transitions for album art between mini and full player
/// - Muted secondary text for metadata; accent for active/playing state
/// - Bottom sheets for secondary actions (queue, sleep timer, repeat)
/// - Empty states always offer a recovery action
