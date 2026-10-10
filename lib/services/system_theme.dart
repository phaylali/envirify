import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Canonical Catppuccin palette values (https://catppuccin.com).
class CatppuccinPalette {
  final String name;
  final bool isDark;
  final Color base;
  final Color mantle;
  final Color crust;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color overlay0;
  final Color overlay1;
  final Color overlay2;
  final Color subtext0;
  final Color subtext1;
  final Color text;
  final Map<String, Color> accents;

  const CatppuccinPalette({
    required this.name,
    required this.isDark,
    required this.base,
    required this.mantle,
    required this.crust,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.overlay0,
    required this.overlay1,
    required this.overlay2,
    required this.subtext0,
    required this.subtext1,
    required this.text,
    required this.accents,
  });

  Color accent(String name) =>
      accents[name.toLowerCase()] ?? accents['mauve']!;
}

const _mocha = CatppuccinPalette(
  name: 'Mocha',
  isDark: true,
  base: Color(0xFF1E1E2E),
  mantle: Color(0xFF181825),
  crust: Color(0xFF11111B),
  surface0: Color(0xFF313244),
  surface1: Color(0xFF45475A),
  surface2: Color(0xFF585B70),
  overlay0: Color(0xFF6C7086),
  overlay1: Color(0xFF7F849C),
  overlay2: Color(0xFF9399B2),
  subtext0: Color(0xFFA6ADC8),
  subtext1: Color(0xFFBAC2DE),
  text: Color(0xFFCDD6F4),
  accents: {
    'rosewater': Color(0xFFF5E0DC),
    'flamingo': Color(0xFFF2CDCD),
    'pink': Color(0xFFF5C2E7),
    'mauve': Color(0xFFCBA6F7),
    'red': Color(0xFFF38BA8),
    'maroon': Color(0xFFEBA0AC),
    'peach': Color(0xFFFAB387),
    'yellow': Color(0xFFF9E2AF),
    'green': Color(0xFFA6E3A1),
    'teal': Color(0xFF94E2D5),
    'sky': Color(0xFF89DCEB),
    'sapphire': Color(0xFF74C7EC),
    'blue': Color(0xFF89B4FA),
    'lavender': Color(0xFFB4BEFE),
  },
);

const _macchiato = CatppuccinPalette(
  name: 'Macchiato',
  isDark: true,
  base: Color(0xFF24273A),
  mantle: Color(0xFF1E2030),
  crust: Color(0xFF181926),
  surface0: Color(0xFF363A4F),
  surface1: Color(0xFF494D64),
  surface2: Color(0xFF5B6078),
  overlay0: Color(0xFF6E738D),
  overlay1: Color(0xFF8087A2),
  overlay2: Color(0xFF939AB7),
  subtext0: Color(0xFFA5ADCB),
  subtext1: Color(0xFFB8C0E0),
  text: Color(0xFFCAD3F5),
  accents: {
    'rosewater': Color(0xFFF4DBD6),
    'flamingo': Color(0xFFF0C6C6),
    'pink': Color(0xFFF5BDE6),
    'mauve': Color(0xFFC6A0F6),
    'red': Color(0xFFED8796),
    'maroon': Color(0xFFEE99A0),
    'peach': Color(0xFFF5A97F),
    'yellow': Color(0xFFEED49F),
    'green': Color(0xFFA6DA95),
    'teal': Color(0xFF8BD5CA),
    'sky': Color(0xFF91D7E3),
    'sapphire': Color(0xFF7DC4E4),
    'blue': Color(0xFF8AADF4),
    'lavender': Color(0xFFB7BDF8),
  },
);

const _frappe = CatppuccinPalette(
  name: 'Frappé',
  isDark: true,
  base: Color(0xFF303446),
  mantle: Color(0xFF292C3C),
  crust: Color(0xFF232634),
  surface0: Color(0xFF414559),
  surface1: Color(0xFF51576D),
  surface2: Color(0xFF626880),
  overlay0: Color(0xFF737994),
  overlay1: Color(0xFF838BA7),
  overlay2: Color(0xFF949CBB),
  subtext0: Color(0xFFA5ADCE),
  subtext1: Color(0xFFB5BFE2),
  text: Color(0xFFC6D0F5),
  accents: {
    'rosewater': Color(0xFFF2D5CF),
    'flamingo': Color(0xFFEEBEBE),
    'pink': Color(0xFFF4B8E4),
    'mauve': Color(0xFFCA9EE6),
    'red': Color(0xFFE78284),
    'maroon': Color(0xFFEA999C),
    'peach': Color(0xFFEF9F76),
    'yellow': Color(0xFFE5C890),
    'green': Color(0xFFA6D189),
    'teal': Color(0xFF81C8BE),
    'sky': Color(0xFF99D1DB),
    'sapphire': Color(0xFF85C1DC),
    'blue': Color(0xFF8CAAEE),
    'lavender': Color(0xFFBABBf1),
  },
);

const _latte = CatppuccinPalette(
  name: 'Latte',
  isDark: false,
  base: Color(0xFFEFF1F5),
  mantle: Color(0xFFE6E9EF),
  crust: Color(0xFFDCE0E8),
  surface0: Color(0xFFCCD0DA),
  surface1: Color(0xFFBCC0CC),
  surface2: Color(0xFFACB0BE),
  overlay0: Color(0xFF9CA0B0),
  overlay1: Color(0xFF8C8FA1),
  overlay2: Color(0xFF7C7F93),
  subtext0: Color(0xFF6C6F85),
  subtext1: Color(0xFF5C5F77),
  text: Color(0xFF4C4F69),
  accents: {
    'rosewater': Color(0xFFDC8A78),
    'flamingo': Color(0xFFDD7878),
    'pink': Color(0xFFEA76CB),
    'mauve': Color(0xFF8839EF),
    'red': Color(0xFFD20F39),
    'maroon': Color(0xFFE64553),
    'peach': Color(0xFFFE640B),
    'yellow': Color(0xFFDF8E1D),
    'green': Color(0xFF40A02B),
    'teal': Color(0xFF179299),
    'sky': Color(0xFF04A5E5),
    'sapphire': Color(0xFF209FB5),
    'blue': Color(0xFF1E66F5),
    'lavender': Color(0xFF7287FD),
  },
);

CatppuccinPalette paletteFor(String flavor) => switch (flavor.toLowerCase()) {
      'macchiato' => _macchiato,
      'frappe' || 'frappé' => _frappe,
      'latte' => _latte,
      _ => _mocha,
    };

/// Everything Envirify knows about the desktop theme right now.
class ThemeInfo {
  final Brightness brightness;

  /// Catppuccin flavor when the GTK theme is a Catppuccin variant.
  final String? flavor;

  /// Catppuccin accent name (e.g. `lavender`).
  final String? accentName;

  final String? fontFamily;
  final String gtkTheme;
  final String colorScheme;
  final Color? gnomeAccent;

  const ThemeInfo({
    required this.brightness,
    this.flavor,
    this.accentName,
    this.fontFamily,
    this.gtkTheme = '',
    this.colorScheme = '',
    this.gnomeAccent,
  });

  bool get isCatppuccin => flavor != null;

  CatppuccinPalette? get palette => flavor == null ? null : paletteFor(flavor!);

  Color get accent {
    if (palette != null && accentName != null) {
      return palette!.accent(accentName!);
    }
    if (gnomeAccent != null) return gnomeAccent!;
    if (palette != null) return palette!.accents['mauve']!;
    return const Color(0xFF6750A4);
  }

  String get description {
    final parts = <String>[];
    if (flavor != null && accentName != null) {
      parts.add('Catppuccin ${paletteFor(flavor!).name} · $accentName');
    }
    if (gtkTheme.isNotEmpty && flavor == null) parts.add(gtkTheme);
    parts.add(brightness == Brightness.dark ? 'Dark' : 'Light');
    return parts.join(' · ');
  }

  ThemeInfo copyWith({Brightness? brightness}) => ThemeInfo(
        brightness: brightness ?? this.brightness,
        flavor: flavor,
        accentName: accentName,
        fontFamily: fontFamily,
        gtkTheme: gtkTheme,
        colorScheme: colorScheme,
        gnomeAccent: gnomeAccent,
      );
}

const _gnomeAccents = <String, Color>{
  'blue': Color(0xFF3584E4),
  'teal': Color(0xFF2190A4),
  'green': Color(0xFF33D17A),
  'yellow': Color(0xFFE5A50A),
  'orange': Color(0xFFFF7800),
  'red': Color(0xFFE61D4B),
  'pink': Color(0xFFFF882C),
  'purple': Color(0xFF9141AC),
  'slate': Color(0xFF6F8396),
};

/// Reads and watches the desktop theme through `gsettings`.
class SystemThemeWatcher {
  Process? _proc;
  final StreamController<ThemeInfo> _controller =
      StreamController<ThemeInfo>.broadcast();

  ThemeInfo _current = ThemeInfo(
    brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  ThemeInfo get current => _current;
  Stream<ThemeInfo> get changes => _controller.stream;

  Future<String> _get(String key) async {
    try {
      final r = await Process.run('gsettings', [
        'get',
        'org.gnome.desktop.interface',
        key,
      ]).timeout(const Duration(seconds: 3));
      if (r.exitCode != 0) return '';
      var s = r.stdout.toString().trim();
      if (s.length >= 2 &&
          ((s.startsWith("'") && s.endsWith("'")) ||
              (s.startsWith('"') && s.endsWith('"')))) {
        s = s.substring(1, s.length - 1);
      }
      return s;
    } catch (_) {
      return '';
    }
  }

  /// Initial read of the current GTK / GNOME interface settings.
  Future<ThemeInfo> readInitial() async {
    final results = await Future.wait([
      _get('gtk-theme'),
      _get('color-scheme'),
      _get('font-name'),
      _get('accent-color'),
    ]);
    _current = _build(
      gtkTheme: results[0],
      colorScheme: results[1],
      fontName: results[2],
      accentName: results[3],
      fallbackBrightness:
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    return _current;
  }

  /// Long-running `gsettings monitor` so theme switches are reflected live.
  void start() {
    if (_proc != null) return;
    try {
      Process.start('gsettings', ['monitor', 'org.gnome.desktop.interface'])
          .then((p) {
        _proc = p;
        p.stdout
            .transform(const Utf8Decoder())
            .transform(const LineSplitter())
            .listen(_onLine);
        p.stderr.drain();
      }).catchError((_) {});
    } catch (_) {}
  }

  void _onLine(String line) {
    // Sample: 'gtk-theme' string 'catppuccin-mocha-lavender-standard+default'
    String? key;
    final m = RegExp(r"^'([^']+)'").firstMatch(line.trim());
    if (m != null) key = m.group(1);
    if (key == null) return;

    switch (key) {
      case 'gtk-theme':
        _emit(gtkTheme: _valueOf(line));
      case 'color-scheme':
        _emit(colorScheme: _valueOf(line));
      case 'font-name':
        _emit(fontName: _valueOf(line));
      case 'accent-color':
        _emit(accentName: _valueOf(line));
      default:
        break;
    }
  }

  String _valueOf(String line) {
    final idx = line.indexOf(' string ');
    if (idx < 0) return '';
    var v = line.substring(idx + 8).trim();
    if (v.length >= 2 &&
        ((v.startsWith("'") && v.endsWith("'")) ||
            (v.startsWith('"') && v.endsWith('"')))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }

  void _emit({
    String? gtkTheme,
    String? colorScheme,
    String? fontName,
    String? accentName,
  }) {
    _current = _build(
      gtkTheme: gtkTheme ?? _current.gtkTheme,
      colorScheme: colorScheme ?? _current.colorScheme,
      fontName: fontName ?? _current.fontFamily ?? '',
      accentName: accentName ??
          (_current.gnomeAccent == null
              ? ''
              : _gnomeAccents.entries
                  .where((e) => e.value == _current.gnomeAccent)
                  .map((e) => e.key)
                  .join()),
      fallbackBrightness: _current.brightness,
    );
    _controller.add(_current);
  }

  ThemeInfo _build({
    required String gtkTheme,
    required String colorScheme,
    required String fontName,
    required String accentName,
    required Brightness fallbackBrightness,
  }) {
    final lower = gtkTheme.toLowerCase();
    String? flavor;
    String? accentNameParsed;

    final fm = RegExp(r'catppuccin[-_](mocha|macchiato|frapp[eé]|latte)')
        .firstMatch(lower);
    if (fm != null) {
      flavor = fm.group(1)!;
      // e.g. catppuccin-mocha-lavender-standard+default → "lavender"
      final rest = lower.substring(fm.end);
      final known = [
        'rosewater',
        'flamingo',
        'pink',
        'mauve',
        'red',
        'maroon',
        'peach',
        'yellow',
        'green',
        'teal',
        'sky',
        'sapphire',
        'blue',
        'lavender',
      ];
      for (final a in known) {
        if (rest.contains(a)) {
          accentNameParsed = a;
          break;
        }
      }
      accentNameParsed ??= 'mauve';
    }

    // Brightness: explicit color-scheme wins, then flavor default, then GTK/-dark.
    Brightness brightness;
    if (colorScheme == 'prefer-dark') {
      brightness = Brightness.dark;
    } else if (colorScheme == 'prefer-light') {
      brightness = Brightness.light;
    } else if (flavor != null) {
      brightness = paletteFor(flavor).isDark ? Brightness.dark : Brightness.light;
    } else if (lower.contains('-dark')) {
      brightness = Brightness.dark;
    } else {
      brightness = fallbackBrightness;
    }

    String? family;
    if (fontName.isNotEmpty) {
      final idx = fontName.lastIndexOf(' ');
      final candidate =
          idx > 0 && RegExp(r'^\d+$').hasMatch(fontName.substring(idx + 1))
              ? fontName.substring(0, idx)
              : fontName;
      if (candidate.trim().isNotEmpty) family = candidate.trim();
    }

    Color? gnomeAccent;
    if (flavor == null && _gnomeAccents.containsKey(accentName)) {
      gnomeAccent = _gnomeAccents[accentName];
    }

    return ThemeInfo(
      brightness: brightness,
      flavor: flavor,
      accentName: accentNameParsed,
      fontFamily: family,
      gtkTheme: gtkTheme,
      colorScheme: colorScheme,
      gnomeAccent: gnomeAccent,
    );
  }

  void dispose() {
    _proc?.kill();
    _proc = null;
    _controller.close();
  }
}
