import 'package:flutter/material.dart';

import '../services/system_theme.dart';

/// Color helpers ---------------------------------------------------------------

double _luminance(Color c) {
  double lin(double v) {
    v /= 255;
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055).pow24();
  }

  return 0.2126 * lin(c.r * 255) +
      0.7152 * lin(c.g * 255) +
      0.0722 * lin(c.b * 255);
}

extension on double {
  double pow24() {
    double result = 1;
    double base = this;
    int exp = 24;
    while (exp > 0) {
      if (exp.isOdd) result *= base;
      base *= base;
      exp >>= 1;
    }
    return result;
  }
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Picks the candidate that reads best on [bg].
Color _on(Color bg, List<Color> candidates) {
  var best = candidates.first;
  var bestScore = _contrast(bg, best);
  for (final c in candidates.skip(1)) {
    final score = _contrast(bg, c);
    if (score > bestScore) {
      best = c;
      bestScore = score;
    }
  }
  return best;
}

Color _blend(Color over, Color under, double alpha) =>
    Color.alphaBlend(over.withValues(alpha: alpha), under);

Color _darken(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;
Color _lighten(Color c, double t) =>
    Color.lerp(c, const Color(0xFFFFFFFF), t)!;

/// Theme construction ----------------------------------------------------------

class AppTheme {
  /// Builds the complete Material 3 theme for the detected desktop style.
  static ThemeData build(ThemeInfo info) {
    final brightness = info.brightness;
    final scheme = info.isCatppuccin
        ? _catppuccinScheme(info.palette!, info.accent, brightness)
        : ColorScheme.fromSeed(
            seedColor: info.gnomeAccent ?? const Color(0xFF6750A4),
            brightness: brightness,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: info.fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: scheme.onSurface,
          fontFamily: info.fontFamily,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  /// Hand-tuned Material 3 roles from a Catppuccin palette + accent.
  static ColorScheme _catppuccinScheme(
    CatppuccinPalette p,
    Color accent,
    Brightness brightness,
  ) {
    final surface = p.base;
    final onSurface = p.text;

    final secondary = Color.lerp(accent, p.subtext0, 0.45)!;
    final alt = accent == p.accents['mauve'] ? p.accents['blue']! : p.accents['mauve']!;
    final tertiary = Color.lerp(alt, p.subtext0, 0.25)!;

    final primaryContainer = _blend(accent, surface, 0.30);
    final secondaryContainer = _blend(secondary, surface, 0.30);
    final tertiaryContainer = _blend(tertiary, surface, 0.30);
    final error = p.accents['red']!;
    final errorContainer = _blend(error, surface, 0.30);

    final onPrimary = _on(accent, [surface, onSurface, Colors.white, Colors.black]);
    final onSecondary =
        _on(secondary, [surface, onSurface, Colors.white, Colors.black]);
    final onTertiary =
        _on(tertiary, [surface, onSurface, Colors.white, Colors.black]);
    final onError =
        _on(error, [surface, onSurface, Colors.white, Colors.black]);

    final onPrimaryContainer = _on(primaryContainer, [
      accent,
      _darken(accent, 0.30),
      onSurface,
      surface,
      Colors.white,
      Colors.black,
    ]);
    final onSecondaryContainer = _on(secondaryContainer, [
      secondary,
      _darken(secondary, 0.30),
      onSurface,
      surface,
      Colors.white,
      Colors.black,
    ]);
    final onTertiaryContainer = _on(tertiaryContainer, [
      tertiary,
      _darken(tertiary, 0.30),
      onSurface,
      surface,
      Colors.white,
      Colors.black,
    ]);
    final onErrorContainer = _on(errorContainer, [
      error,
      _darken(error, 0.30),
      onSurface,
      surface,
      Colors.white,
      Colors.black,
    ]);

    // Elevation surfaces.
    final Color surfaceDim;
    final Color surfaceBright;
    final Color containerLowest;
    final Color containerLow;
    final Color container;
    final Color containerHigh;
    final Color containerHighest;
    if (brightness == Brightness.dark) {
      surfaceDim = p.crust;
      surfaceBright = p.surface0;
      containerLowest = p.crust;
      containerLow = p.mantle;
      container = _blend(p.surface0, surface, 0.5);
      containerHigh = p.surface0;
      containerHighest = p.surface1;
    } else {
      surfaceDim = _blend(surface, p.text, 0.12);
      surfaceBright = _lighten(surface, 0.35);
      containerLowest = _lighten(surface, 0.4);
      containerLow = _lighten(surface, 0.18);
      container = _blend(surface, p.crust, 0.4);
      containerHigh = _blend(surface, p.text, 0.09);
      containerHighest = _blend(surface, p.text, 0.16);
    }

    final outline = p.overlay1;
    final outlineVariant =
        brightness == Brightness.dark ? _blend(surface, p.text, 0.14) : _blend(surface, p.text, 0.15);

    final primaryFixedDim = _blend(accent, surface, 0.25);
    final secondaryFixed = _blend(secondary, surface, 0.30);
    final secondaryFixedDim = _blend(secondary, surface, 0.50);
    final tertiaryFixed = _blend(tertiary, surface, 0.30);
    final tertiaryFixedDim = _blend(tertiary, surface, 0.50);

    // Build the seed-based scheme first, then override every role we care
    // about through copyWith (this Flutter version hides the constructor).
    return ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
        .copyWith(
      primary: accent,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      inversePrimary: _blend(accent, surface, 0.55),
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: p.subtext0,
      inverseSurface: p.text,
      onInverseSurface: p.base,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: accent,
      surfaceDim: surfaceDim,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: containerLowest,
      surfaceContainerLow: containerLow,
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
      primaryFixed: accent,
      primaryFixedDim: primaryFixedDim,
      onPrimaryFixed: _on(primaryFixedDim, [surface, onSurface]),
      onPrimaryFixedVariant: _on(primaryFixedDim, [surface, p.subtext0]),
      secondaryFixed: secondaryFixed,
      secondaryFixedDim: secondaryFixedDim,
      onSecondaryFixed: _on(secondaryFixedDim, [surface, onSurface]),
      onSecondaryFixedVariant: _on(secondaryFixedDim, [surface, p.subtext0]),
      tertiaryFixed: tertiaryFixed,
      tertiaryFixedDim: tertiaryFixedDim,
      onTertiaryFixed: _on(tertiaryFixedDim, [surface, onSurface]),
      onTertiaryFixedVariant: _on(tertiaryFixedDim, [surface, p.subtext0]),
    );
  }
}
