import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'scanner.dart';

class WriteOutcome {
  final bool ok;
  final String path;
  final String? error;

  /// Shell command the user can run manually when privileged write failed.
  final String? fallbackCommand;

  /// Previous file content (for undo).
  final String? oldContent;
  final bool existed;
  final bool backupCreated;

  const WriteOutcome({
    required this.ok,
    required this.path,
    this.error,
    this.fallbackCommand,
    this.oldContent,
    required this.existed,
    this.backupCreated = false,
  });
}

/// Reads, transforms and writes environment files.
class EnvWriter {
  EnvWriter._();

  static String get home => Platform.environment['HOME'] ?? Directory.systemTemp.path;

  static bool needsRoot(String path) => !path.startsWith('$home/');

  /// Builds the new file content for an upsert. Returns null if nothing changes.
  static String? buildUpsert({
    required String existing,
    required EnvFormat format,
    required String key,
    required String value,
    required bool existed,
  }) {
    final lines = existing.isEmpty ? <String>[] : existing.split('\n');
    // Drop a trailing newline artifact from split.
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    var replaced = false;
    for (var i = 0; i < lines.length; i++) {
      final m = Scanner.matchLine(format, lines[i]);
      if (m != null && m.$1 == key) {
        lines[i] = _render(format, key, value, indent: _indentOf(lines[i]));
        replaced = true;
      }
    }

    if (!replaced) {
      final newLine = _render(format, key, value);
      var inserted = false;
      if (format == EnvFormat.hyprLua) {
        // Keep new hl.env() calls inside the existing env block.
        var lastEnvIdx = -1;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('hl.env(')) lastEnvIdx = i;
        }
        if (lastEnvIdx >= 0) {
          lines.insert(lastEnvIdx + 1,
              _render(format, key, value, indent: _indentOf(lines[lastEnvIdx])));
          inserted = true;
        }
      }
      if (!inserted) {
        if (lines.isNotEmpty) {
          lines.add('');
        } else if (!existed) {
          lines.add('# ${_header(format)}');
        }
        lines.add(newLine);
      }
    }

    final out = lines.join('\n');
    final result = '$out\n';
    // Compare against original to allow no-op detection.
    if (existed && !_differs(existing, result)) return null;
    return result;
  }

  /// Builds new content with [key] removed. Returns null if nothing changes.
  static String? buildRemove({
    required String existing,
    required EnvFormat format,
    required String key,
  }) {
    final lines = existing.split('\n');
    final kept = <String>[];
    var removed = false;
    for (final line in lines) {
      final m = Scanner.matchLine(format, line);
      if (m != null && m.$1 == key) {
        removed = true;
        continue;
      }
      kept.add(line);
    }
    if (!removed) return null;
    var out = kept.join('\n');
    // Collapse a couple of blank lines left behind at the end.
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    if (!out.endsWith('\n')) out = '$out\n';
    if (out == existing) return null;
    return out;
  }

  static bool _differs(String a, String b) => a != b;

  static String _indentOf(String line) {
    final m = RegExp(r'^(\s*)').firstMatch(line);
    return m?.group(1) ?? '';
  }

  static String _header(EnvFormat format) => switch (format) {
        EnvFormat.shell => 'Envirify — environment manager',
        EnvFormat.fish => 'Envirify — environment manager',
        _ => 'Written by Envirify',
      };

  /// Renders a single line in the syntax of [format].
  static String _render(EnvFormat format, String key, String value,
      {String indent = ''}) {
    switch (format) {
      case EnvFormat.shell:
        return '${indent}export $key=${_shellQuote(value)}';
      case EnvFormat.fish:
        return '${indent}set -gx $key ${_fishQuote(value)}';
      case EnvFormat.pam:
      case EnvFormat.pamConf:
        return '$indent$key=${_confQuote(value)}';
      case EnvFormat.hyprConf:
        return '${indent}env = $key,$value';
      case EnvFormat.hyprLua:
        return '${indent}hl.env(${_luaStr(key)}, ${_luaStr(value)})';
      case EnvFormat.fishUniversal:
      case EnvFormat.runtime:
        return '$key=$value';
    }
  }

  // -- quoting ---------------------------------------------------------------

  /// Shell: keep expansion semantics when `$` or backticks are present,
  /// otherwise emit a literal single-quoted string.
  static String _shellQuote(String v) {
    if (v.contains(r'$') || v.contains('`')) {
      return '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('`', r'\`')}"';
    }
    if (v.isEmpty) return "''";
    return "'${v.replaceAll("'", r"'\''")}'";
  }

  static String _fishQuote(String v) {
    if (v.contains(r'$')) {
      return '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    }
    if (v.isEmpty) return "''";
    return "'${v.replaceAll('\\', r'\\').replaceAll("'", r"\'")}'";
  }

  /// environment.d / pam: bare when safe, otherwise double-quoted.
  static String _confQuote(String v) {
    final needsQuote = v.isEmpty ||
        RegExp(r'[\s#"`$\\]').hasMatch(v) ||
        v.contains("'");
    if (!needsQuote) return v;
    return '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  static String _luaStr(String v) =>
      '"${v.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';

  // -- writing ----------------------------------------------------------------

  static Future<WriteOutcome> write({
    required String path,
    required String content,
    required bool existed,
  }) async {
    String? oldContent;
    if (existed) {
      try {
        oldContent = await File(path).readAsString();
      } catch (_) {}
    }

    if (needsRoot(path)) {
      return _writeWithPkexec(path, content, existed, oldContent);
    }

    var backupCreated = false;
    try {
      final dir = Directory(p.dirname(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (existed && oldContent != null) {
        final bak = File('$path.envirify.bak');
        if (!await bak.exists()) {
          await bak.writeAsString(oldContent);
          backupCreated = true;
        }
      }
      await File(path).writeAsString(content);
      if (!existed) {
        await Process.run('chmod', ['600', path]);
      }
      return WriteOutcome(
        ok: true,
        path: path,
        oldContent: oldContent,
        existed: existed,
        backupCreated: backupCreated,
      );
    } catch (e) {
      return WriteOutcome(
        ok: false,
        path: path,
        error: '$e',
        existed: existed,
        oldContent: oldContent,
      );
    }
  }

  static Future<WriteOutcome> _writeWithPkexec(
    String path,
    String content,
    bool existed,
    String? oldContent,
  ) async {
    final pkexec = await _which('pkexec');
    if (pkexec == null) {
      return _fallback(path, content, existed, oldContent,
          error: 'pkexec is not installed');
    }

    const script = r'''
target="$1"
if [ -f "$target" ] && [ ! -f "$target.envirify.bak" ]; then
  cp -p "$target" "$target.envirify.bak" || true
fi
cat > "$target"
''';
    Future<(int, String)> attempt() async {
      try {
        final proc = await Process.start(
          'pkexec',
          ['sh', '-c', script, 'envirify', path],
          environment: {'LANG': 'C'},
        );
        proc.stdin.add(utf8.encode(content));
        await proc.stdin.close();
        final code = await proc.exitCode.timeout(const Duration(minutes: 3),
            onTimeout: () {
          proc.kill();
          return -1;
        });
        final err = (await proc.stderr.transform(utf8.decoder).join()).trim();
        return (code, err);
      } on Exception catch (e) {
        return (-1, '$e');
      }
    }

    var (code, err) = await attempt();
    if (code != 0 && await _startAgentIfMissing()) {
      // A polkit authentication agent was missing (common on tiling WMs) —
      // one has been started now, so the prompt can work.
      (code, err) = await attempt();
    }

    if (code == 0) {
      return WriteOutcome(
        ok: true,
        path: path,
        oldContent: oldContent,
        existed: existed,
      );
    }
    return await _fallback(
      path,
      content,
      existed,
      oldContent,
      error: err.isEmpty ? 'Authentication failed (exit $code)' : err,
    );
  }

  static const _polkitAgents = [
    '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1',
    '/usr/libexec/polkit-gnome-authentication-agent-1',
    '/usr/lib/lxqt-policykit/lxqt-policykit-agent',
    '/usr/lib/polkit-kde-authentication-agent-1',
    '/usr/libexec/polkit-kde-authentication-agent-1',
    '/usr/lib/mate-polkit/polkit-mate-authentication-agent-1',
  ];

  /// Starts the desktop's polkit agent when none is running.
  /// Returns true when it is worth retrying pkexec.
  static Future<bool> _startAgentIfMissing() async {
    try {
      final r = await Process.run('pgrep', [
        '-f',
        'polkit.*authentication-agent|policykit.*agent|lxqt-policykit',
      ]);
      if (r.exitCode != 1) return false; // running, or cannot tell → no retry
      for (final a in _polkitAgents) {
        if (File(a).existsSync()) {
          await Process.start(a, const [],
              mode: ProcessStartMode.detached);
          await Future.delayed(const Duration(milliseconds: 800));
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Keeps the pending content on disk + provides a sudo command to apply it.
  static Future<WriteOutcome> _fallback(
    String path,
    String content,
    bool existed,
    String? oldContent, {
    required String error,
  }) async {
    String? cmd;
    try {
      final pendingDir =
          Directory('${Directory.systemTemp.path}/envirify-pending');
      await pendingDir.create(recursive: true);
      final tmp = File('${pendingDir.path}/${p.basename(path)}');
      await tmp.writeAsString(content);
      await Process.run('chmod', ['644', tmp.path]);
      var mode = '644';
      if (existed) {
        try {
          final st = await File(path).stat();
          mode = (st.mode & 0x3FF).toRadixString(8).padLeft(3, '0');
        } catch (_) {}
      }
      cmd = 'sudo install -m $mode ${_shellQuote(tmp.path)} ${_shellQuote(path)}';
    } catch (_) {}
    return WriteOutcome(
      ok: false,
      path: path,
      error: error,
      fallbackCommand: cmd,
      oldContent: oldContent,
      existed: existed,
    );
  }

  static Future<String?> _which(String bin) async {
    try {
      final r = await Process.run('which', [bin]);
      if (r.exitCode == 0) {
        final out = r.stdout.toString().trim();
        return out.isEmpty ? null : out.split('\n').first;
      }
    } catch (_) {}
    return null;
  }

  /// Human hint about what a given format line means for the running system.
  static String effectHint(EnvFormat format, EnvScope scope) {
    if (scope == EnvScope.system) {
      return switch (format) {
        EnvFormat.pam => 'Applies to every login session (PAM) after you log out and back in.',
        _ => 'Applies to login shells after you log out and back in.',
      };
    }
    return switch (format) {
      EnvFormat.pam => 'Applies to user services and GUI apps on next login.',
      EnvFormat.shell => 'Picked up by new shells automatically.',
      EnvFormat.fish => 'Picked up by new fish shells automatically.',
      EnvFormat.hyprConf || EnvFormat.hyprLua =>
        'Applies to apps launched by Hyprland after it reloads.',
      _ => 'Picked up by new shells automatically.',
    };
  }
}
