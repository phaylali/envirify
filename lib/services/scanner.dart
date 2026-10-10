import 'dart:io';

import '../models/models.dart';

/// Discovers and parses every place environment variables are registered.
class Scanner {
  Scanner._();

  static String get home => Platform.environment['HOME'] ?? Directory.systemTemp.path;
  static String get shell =>
      (Platform.environment['SHELL'] ?? '').split('/').last;

  /// All candidate sources for this machine (existence-filtered).
  static Future<List<EnvSource>> discoverSources() async {
    final sources = <EnvSource>[];
    Future<bool> exists(String p) async {
      try {
        return await File(p).exists();
      } catch (_) {
        return false;
      }
    }

    Future<List<String>> glob(String dir, String ext) async {
      try {
        final d = Directory(dir);
        if (!await d.exists()) return [];
        final out = <String>[];
        await for (final e in d.list(followLinks: false)) {
          if (e is File && e.path.endsWith(ext)) out.add(e.path);
        }
        out.sort();
        return out;
      } catch (_) {
        return [];
      }
    }

    // ---- System ----
    if (await exists('/etc/environment')) {
      sources.add(const EnvSource(
        path: '/etc/environment',
        scope: EnvScope.system,
        format: EnvFormat.pam,
        kind: EnvKind.etcEnvironment,
        rank: 10,
      ));
    }
    if (await exists('/etc/profile')) {
      sources.add(const EnvSource(
        path: '/etc/profile',
        scope: EnvScope.system,
        format: EnvFormat.shell,
        kind: EnvKind.etcProfile,
        readOnly: true,
        rank: 20,
      ));
    }
    for (final p in await glob('/etc/profile.d', '.sh')) {
      // Symlinks point into /usr/lib (package-managed) → read-only.
      final link = Link(p);
      final isLink = await link.exists();
      sources.add(EnvSource(
        path: p,
        scope: EnvScope.system,
        format: EnvFormat.shell,
        kind: EnvKind.profileD,
        readOnly: isLink,
        rank: 21,
      ));
    }
    for (final p in await glob('/etc/environment.d', '.conf')) {
      sources.add(EnvSource(
        path: p,
        scope: EnvScope.system,
        format: EnvFormat.pam,
        kind: EnvKind.etcEnvironmentD,
        rank: 30,
      ));
    }
    if (await exists('/etc/security/pam_env.conf')) {
      sources.add(const EnvSource(
        path: '/etc/security/pam_env.conf',
        scope: EnvScope.system,
        format: EnvFormat.pamConf,
        kind: EnvKind.pamEnvConf,
        readOnly: true,
        rank: 15,
      ));
    }

    // ---- User: shell profiles ----
    const userProfiles = [
      ('.profile', EnvKind.userProfile, 50),
      ('.bash_profile', EnvKind.userProfile, 51),
      ('.bash_login', EnvKind.userProfile, 52),
      ('.zshenv', EnvKind.shellRc, 53),
    ];
    for (final (name, kind, rank) in userProfiles) {
      final p = '$home/$name';
      if (await exists(p)) {
        sources.add(EnvSource(
          path: p,
          scope: EnvScope.user,
          format: EnvFormat.shell,
          kind: kind,
          rank: rank,
        ));
      }
    }

    // Interactive rc files.
    const rcFiles = [
      ('.bashrc', 'bash'),
      ('.zshrc', 'zsh'),
    ];
    for (final (name, _) in rcFiles) {
      final p = '$home/$name';
      if (await exists(p)) {
        sources.add(EnvSource(
          path: p,
          scope: EnvScope.user,
          format: EnvFormat.shell,
          kind: EnvKind.shellRc,
          rank: 80,
        ));
      }
    }

    final fishConfig = '$home/.config/fish/config.fish';
    if (await exists(fishConfig)) {
      sources.add(EnvSource(
        path: fishConfig,
        scope: EnvScope.user,
        format: EnvFormat.fish,
        kind: EnvKind.fishConfig,
        rank: 81,
      ));
    }
    final fishVars = '$home/.config/fish/fish_variables';
    if (await exists(fishVars)) {
      sources.add(EnvSource(
        path: fishVars,
        scope: EnvScope.user,
        format: EnvFormat.fishUniversal,
        kind: EnvKind.fishVariables,
        readOnly: true,
        rank: 95,
      ));
    }

    // ---- User: systemd environment.d ----
    for (final p in await glob('$home/.config/environment.d', '.conf')) {
      sources.add(EnvSource(
        path: p,
        scope: EnvScope.user,
        format: EnvFormat.pam,
        kind: EnvKind.userEnvironmentD,
        rank: 60,
      ));
    }

    if (await exists('$home/.pam_environment')) {
      sources.add(EnvSource(
        path: '$home/.pam_environment',
        scope: EnvScope.user,
        format: EnvFormat.pam,
        kind: EnvKind.pamEnvironment,
        readOnly: true,
        rank: 40,
      ));
    }

    // ---- User: envman (managed by a third-party tool → read-only) ----
    for (final name in ['ENV.env', 'PATH.env']) {
      final p = '$home/.config/envman/$name';
      if (await exists(p)) {
        sources.add(EnvSource(
          path: p,
          scope: EnvScope.user,
          format: EnvFormat.pam,
          kind: EnvKind.envman,
          readOnly: true,
          rank: 70,
        ));
      }
    }

    // ---- User: Hyprland ----
    final hyprLua = '$home/.config/hypr/hyprland.lua';
    if (await exists(hyprLua)) {
      sources.add(EnvSource(
        path: hyprLua,
        scope: EnvScope.user,
        format: EnvFormat.hyprLua,
        kind: EnvKind.hyprland,
        rank: 90,
      ));
    }
    final hyprConf = '$home/.config/hypr/hyprland.conf';
    if (await exists(hyprConf)) {
      sources.add(EnvSource(
        path: hyprConf,
        scope: EnvScope.user,
        format: EnvFormat.hyprConf,
        kind: EnvKind.hyprland,
        rank: 90,
      ));
    }
    for (final p in await glob('$home/.config/hypr/conf/environments', '.conf')) {
      sources.add(EnvSource(
        path: p,
        scope: EnvScope.user,
        format: EnvFormat.hyprConf,
        kind: EnvKind.hyprland,
        rank: 91,
      ));
    }

    return sources;
  }

  /// Full scan: sources + parsed entries + running-session values.
  static Future<ScanResult> scan({Map<String, String?> sessionOverlay = const {}}) async {
    final sources = await discoverSources();
    final byKey = <String, List<EnvDefinition>>{};

    for (final src in sources) {
      final lines = await _readLines(src.path);
      if (lines == null) continue;
      for (var i = 0; i < lines.length; i++) {
        final m = matchLine(src.format, lines[i]);
        if (m != null) {
          byKey.putIfAbsent(m.$1, () => []).add(EnvDefinition(
            key: m.$1,
            source: src,
            line: i + 1,
            raw: lines[i],
            value: m.$2,
          ));
        }
      }
    }

    // Live session (this process inherits the desktop session environment),
    // overlaid with values Envirify applied during this run.
    final session = Map<String, String>.from(Platform.environment);
    for (final e in sessionOverlay.entries) {
      if (e.value == null) {
        session.remove(e.key);
      } else {
        session[e.key] = e.value!;
      }
    }

    final entries = <EnvEntry>[];
    for (final key in {...byKey.keys, ...session.keys}) {
      final defs = (byKey[key] ?? const <EnvDefinition>[])
          .toList()
        ..sort((a, b) => a.source.rank.compareTo(b.source.rank));
      entries.add(EnvEntry(
        key: key,
        defs: defs,
        sessionValue: session[key],
      ));
    }
    entries.sort((a, b) {
      final af = a.defs.isEmpty ? 1 : 0;
      final bf = b.defs.isEmpty ? 1 : 0;
      if (af != bf) return af - bf;
      return a.key.compareTo(b.key);
    });

    return ScanResult(sources: sources, entries: entries, sessionEnv: session);
  }

  static Future<List<String>?> _readLines(String path) async {
    try {
      return await File(path).readAsLines();
    } catch (_) {
      return null;
    }
  }

  /// Returns (key, value) when [line] registers a variable in [format].
  static (String, String)? matchLine(EnvFormat format, String line) {
    switch (format) {
      case EnvFormat.pam:
        final m = RegExp(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$')
            .firstMatch(line);
        if (m == null || line.trimLeft().startsWith('#')) return null;
        return (m.group(1)!, _unquote(m.group(2)!));

      case EnvFormat.shell:
        if (line.trimLeft().startsWith('#')) return null;
        final m = RegExp(
                r'^\s*(?:export\s+|readonly\s+|declare\s+(?:-\w+\s+)?|typeset\s+(?:-\w+\s+)?)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
            .firstMatch(line);
        if (m == null) return null;
        if (line.contains('+=')) return null;
        return (m.group(1)!, _unquote(m.group(2)!.trim()));

      case EnvFormat.fish:
        if (line.trimLeft().startsWith('#')) return null;
        final m = RegExp(
                r'^\s*set\s+((?:-\w+|--export)\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+(.+?)\s*$')
            .firstMatch(line);
        if (m == null) return null;
        final flags = m.group(1) ?? '';
        if (!flags.contains('x') && !flags.contains('--export')) return null;
        return (m.group(2)!, _unquote(m.group(3)!.trim()));

      case EnvFormat.fishUniversal:
        final m =
            RegExp(r'^SETUVAR\s+--export\s+([^\s:]+):(.*)$').firstMatch(line);
        if (m == null) return null;
        final value = m.group(2)!.replaceAllMapped(
            RegExp(r'\\x([0-9a-fA-F]{2})'),
            (mm) => String.fromCharCode(int.parse(mm.group(1)!, radix: 16)));
        return (m.group(1)!, value);

      case EnvFormat.pamConf:
        final m = RegExp(
                r'^\s*([A-Z][A-Z0-9_]*)\s+DEFAULT\s*=\s*(.+?)\s*$',
                caseSensitive: false)
            .firstMatch(line);
        if (m == null || line.trimLeft().startsWith('#')) return null;
        return (m.group(1)!, _unquote(m.group(2)!));

      case EnvFormat.hyprConf:
        final m = RegExp(r'^\s*env\s*=\s*([^,\s][^,]*),(.*)$').firstMatch(line);
        if (m == null || line.trimLeft().startsWith('#')) return null;
        return (m.group(1)!.trim(), m.group(2)!.trim());

      case EnvFormat.hyprLua:
        final m = RegExp(
                r"""hl\.env\s*\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]*)['"]\s*\)""")
            .firstMatch(line);
        if (m == null || line.trimLeft().startsWith('--')) return null;
        return (m.group(1)!, m.group(2)!);

      case EnvFormat.runtime:
        return null;
    }
  }

  static String _unquote(String v) {
    var s = v.trim();
    if (s.length >= 2) {
      final a = s[0];
      final b = s[s.length - 1];
      if ((a == '"' && b == '"') || (a == "'" && b == "'")) {
        s = s.substring(1, s.length - 1);
      }
    }
    return s;
  }
}
