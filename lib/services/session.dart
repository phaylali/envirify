import 'dart:io';

/// Pushes changes into the *running* session so effects don't require a
/// re-login: systemd user manager + D-Bus activated services.
class SessionApplier {
  SessionApplier._();

  static Future<bool> _has(String bin) async {
    try {
      final r = await Process.run('which', [bin]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Applies (value != null) or unsets (value == null) [key] in the session.
  /// Returns human-readable result lines.
  static Future<List<String>> apply(String key, String? value) async {
    final results = <String>[];

    if (value != null) {
      if (await _has('dbus-update-activation-environment')) {
        final r = await _run('dbus-update-activation-environment',
            ['--systemd', '$key=$value']);
        results.add(r);
      }
      if (await _has('systemctl')) {
        final r =
            await _run('systemctl', ['--user', 'set-environment', '$key=$value']);
        results.add(r);
      }
    } else {
      if (await _has('systemctl')) {
        final r = await _run('systemctl', ['--user', 'unset-environment', key]);
        results.add(r);
      }
    }

    if (results.isEmpty) results.add('No session tools available');
    return results;
  }

  static Future<String> _run(String bin, List<String> args) async {
    try {
      final r = await Process.run(bin, args)
          .timeout(const Duration(seconds: 10));
      if (r.exitCode == 0) {
        return 'ok';
      }
      final err = (r.stderr.toString() + r.stdout.toString()).trim();
      final short = err.split('\n').first;
      return 'failed: ${short.isEmpty ? 'exit ${r.exitCode}' : short}';
    } on ProcessException catch (e) {
      return 'failed: ${e.message}';
    } on Exception catch (e) {
      return 'failed: $e';
    }
  }
}
