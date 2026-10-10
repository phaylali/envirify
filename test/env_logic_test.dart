import 'dart:io';

import 'package:envirify/models/models.dart';
import 'package:envirify/services/scanner.dart';
import 'package:envirify/services/writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scanner.matchLine', () {
    test('pam format', () {
      expect(Scanner.matchLine(EnvFormat.pam, 'FOO=bar'), ('FOO', 'bar'));
      expect(Scanner.matchLine(EnvFormat.pam, 'FOO="bar baz"'),
          ('FOO', 'bar baz'));
      expect(Scanner.matchLine(EnvFormat.pam, "A='x y'"), ('A', 'x y'));
      expect(Scanner.matchLine(EnvFormat.pam, '  B=1  '), ('B', '1'));
      expect(Scanner.matchLine(EnvFormat.pam, '#FOO=bar'), isNull);
      expect(Scanner.matchLine(EnvFormat.pam, ''), isNull);
      expect(Scanner.matchLine(EnvFormat.pam, 'export FOO=bar'), isNull);
    });

    test('shell format', () {
      expect(Scanner.matchLine(EnvFormat.shell, 'export FOO=bar'),
          ('FOO', 'bar'));
      expect(Scanner.matchLine(EnvFormat.shell, "FOO='a b'"), ('FOO', 'a b'));
      expect(Scanner.matchLine(EnvFormat.shell, 'FOO="x"'), ('FOO', 'x'));
      expect(Scanner.matchLine(EnvFormat.shell, '  export A=1'), ('A', '1'));
      expect(Scanner.matchLine(EnvFormat.shell, 'readonly X=1'), ('X', '1'));
      expect(Scanner.matchLine(EnvFormat.shell, '# export FOO=1'), isNull);
      expect(Scanner.matchLine(EnvFormat.shell, r'PATH=$PATH:/x'),
          ('PATH', r'$PATH:/x'));
      // Append lines are intentionally ignored (cannot be set safely).
      expect(Scanner.matchLine(EnvFormat.shell, 'FOO+=bar'), isNull);
      expect(
          Scanner.matchLine(EnvFormat.shell, r'if [ -n "$X" ]; then'), isNull);
    });

    test('fish format', () {
      expect(Scanner.matchLine(EnvFormat.fish, 'set -gx PNPM_HOME "/home/u"'),
          ('PNPM_HOME', '/home/u'));
      expect(Scanner.matchLine(EnvFormat.fish, 'set --export A b'), ('A', 'b'));
      expect(Scanner.matchLine(EnvFormat.fish, 'set -l local_var x'), isNull);
      expect(Scanner.matchLine(EnvFormat.fish, '# set -gx A b'), isNull);
    });

    test('fish universal format', () {
      expect(
          Scanner.matchLine(
              EnvFormat.fishUniversal, 'SETUVAR --export VK_DRIVER:amd_icd64'),
          ('VK_DRIVER', 'amd_icd64'));
      expect(Scanner.matchLine(
              EnvFormat.fishUniversal, 'SETUVAR __fish_initialized:4300'),
          isNull);
      // \x7e is fish's escape for ~
      expect(
          Scanner.matchLine(
              EnvFormat.fishUniversal, r'SETUVAR --export K:\x7e/x'),
          ('K', '~/x'));
    });

    test('hyprland formats', () {
      expect(Scanner.matchLine(EnvFormat.hyprConf, 'env = FOO,bar,baz'),
          ('FOO', 'bar,baz'));
      expect(Scanner.matchLine(EnvFormat.hyprConf, 'monitor = DP-1,1920x1080'),
          isNull);
      expect(Scanner.matchLine(
              EnvFormat.hyprLua, 'hl.env("XCURSOR_SIZE", "24")'),
          ('XCURSOR_SIZE', '24'));
      expect(
          Scanner.matchLine(EnvFormat.hyprLua, '-- hl.env("A", "b")'), isNull);
    });
  });

  group('EnvWriter.buildUpsert', () {
    test('creates a new shell file with header + export', () {
      final out = EnvWriter.buildUpsert(
        existing: '',
        format: EnvFormat.shell,
        key: 'MY_VAR',
        value: 'hello',
        existed: false,
      );
      expect(out, contains('export MY_VAR=\'hello\''));
      expect(out, startsWith('#'));
      expect(out, endsWith('\n'));
    });

    test('appends to an existing shell file, keeps old content', () {
      final out = EnvWriter.buildUpsert(
        existing: 'export OLD=1\n',
        format: EnvFormat.shell,
        key: 'MY_VAR',
        value: '2',
        existed: true,
      );
      expect(out, startsWith('export OLD=1\n'));
      expect(out, contains('export MY_VAR=\'2\''));
    });

    test('replaces existing shell line and preserves indentation', () {
      final out = EnvWriter.buildUpsert(
        existing: '  export FOO=old\n',
        format: EnvFormat.shell,
        key: 'FOO',
        value: 'new',
        existed: true,
      );
      expect(out, '  export FOO=\'new\'\n');
    });

    test('shell quoting: literal vs expansion-aware', () {
      expect(
        EnvWriter.buildUpsert(
          existing: '',
          format: EnvFormat.shell,
          key: 'A',
          value: 'it\'s',
          existed: false,
        ),
        contains(r"'it'\''s'"),
      );
      // $ present → double quotes so expansion still works (PATH-style).
      expect(
        EnvWriter.buildUpsert(
          existing: '',
          format: EnvFormat.shell,
          key: 'P',
          value: r'$HOME/bin',
          existed: false,
        ),
        contains(r'export P="$HOME/bin"'),
      );
    });

    test('no-op when value unchanged', () {
      final out = EnvWriter.buildUpsert(
        existing: 'export FOO=\'bar\'\n',
        format: EnvFormat.shell,
        key: 'FOO',
        value: 'bar',
        existed: true,
      );
      expect(out, isNull);
    });

    test('pam/environment.d quoting', () {
      final out = EnvWriter.buildUpsert(
        existing: '',
        format: EnvFormat.pam,
        key: 'GREETING',
        value: 'hello world',
        existed: false,
      );
      expect(out, contains('GREETING="hello world"'));

      final simple = EnvWriter.buildUpsert(
        existing: '',
        format: EnvFormat.pam,
        key: 'SIMPLE',
        value: 'value123',
        existed: false,
      );
      expect(simple, contains('SIMPLE=value123'));
    });

    test('fish format', () {
      final out = EnvWriter.buildUpsert(
        existing: '',
        format: EnvFormat.fish,
        key: 'FISHY',
        value: 'deep',
        existed: false,
      );
      expect(out, contains("set -gx FISHY 'deep'"));
    });

    test('hyprland lua: inserts inside existing hl.env block', () {
      final existing = 'hl.env("A", "1")\nhl.window.rule(...)\n';
      final out = EnvWriter.buildUpsert(
        existing: existing,
        format: EnvFormat.hyprLua,
        key: 'B',
        value: '2',
        existed: true,
      )!;
      final lines = out.split('\n');
      expect(lines.first, 'hl.env("A", "1")');
      expect(lines[1], 'hl.env("B", "2")');
      expect(lines[2], startsWith('hl.window.rule'));
    });

    test('hyprland conf format', () {
      final out = EnvWriter.buildUpsert(
        existing: 'env = A,1\n',
        format: EnvFormat.hyprConf,
        key: 'B',
        value: '2',
        existed: true,
      );
      expect(out, contains('env = B,2'));
      expect(out, startsWith('env = A,1'));
    });
  });

  group('EnvWriter.buildRemove', () {
    test('removes the matching line', () {
      final out = EnvWriter.buildRemove(
        existing: 'export A=1\nexport B=2\n',
        format: EnvFormat.shell,
        key: 'A',
      );
      expect(out, isNot(contains('export A=1')));
      expect(out, contains('export B=2'));
    });

    test('returns null when key missing', () {
      expect(
        EnvWriter.buildRemove(
          existing: 'export A=1\n',
          format: EnvFormat.shell,
          key: 'NOPE',
        ),
        isNull,
      );
    });
  });

  group('needsRoot', () {
    test('classifies paths', () {
      final home = Platform.environment['HOME']!;
      expect(EnvWriter.needsRoot('/etc/environment'), isTrue);
      expect(EnvWriter.needsRoot('/etc/profile.d/x.sh'), isTrue);
      expect(EnvWriter.needsRoot('$home/.profile'), isFalse);
    });
  });
}
