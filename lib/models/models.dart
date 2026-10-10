/// Core data model for Envirify.
library;

/// Where a variable applies.
enum EnvScope {
  system,
  user,
  session,
}

/// Syntax used by the file a variable is registered in.
enum EnvFormat {
  /// `KEY=value` / `KEY="value"` — pam_env & systemd environment.d.
  pam,

  /// `export KEY='value'` — POSIX shell files (`/etc/profile.d`, `~/.profile`, rc files).
  shell,

  /// `set -gx KEY 'value'` — fish config.
  fish,

  /// `SETUVAR --export KEY:value` — fish universal variables (read-only).
  fishUniversal,

  /// `KEY DEFAULT=value` — `/etc/security/pam_env.conf` (read-only).
  pamConf,

  /// `env = KEY,VALUE` — hyprland.conf style.
  hyprConf,

  /// `hl.env("KEY", "VALUE")` — Hyprland Lua config.
  hyprLua,

  /// Live value inherited by this process.
  runtime,
}

/// What a source file contains / how it is labelled in the UI.
enum EnvKind {
  etcEnvironment,
  etcProfile,
  profileD,
  etcEnvironmentD,
  pamEnvConf,
  userProfile,
  shellRc,
  fishConfig,
  fishVariables,
  userEnvironmentD,
  pamEnvironment,
  envman,
  hyprland,
  runtime,
}

extension EnvKindInfo on EnvKind {
  String get label => switch (this) {
        EnvKind.etcEnvironment => '/etc/environment',
        EnvKind.etcProfile => '/etc/profile',
        EnvKind.profileD => 'System profile scripts',
        EnvKind.etcEnvironmentD => 'System environment.d',
        EnvKind.pamEnvConf => 'pam_env.conf',
        EnvKind.userProfile => 'User profile',
        EnvKind.shellRc => 'Shell startup',
        EnvKind.fishConfig => 'Fish config',
        EnvKind.fishVariables => 'Fish universal vars',
        EnvKind.userEnvironmentD => 'User environment.d',
        EnvKind.pamEnvironment => '~/.pam_environment',
        EnvKind.envman => 'envman',
        EnvKind.hyprland => 'Hyprland',
        EnvKind.runtime => 'Running session',
      };
}

/// A file (or the live session) where variables can be registered.
class EnvSource {
  final String path;
  final EnvScope scope;
  final EnvFormat format;
  final EnvKind kind;

  /// Sources owned by the OS / other tools are shown but never edited.
  final bool readOnly;

  /// Display ordering — lower ranks are applied earlier (later overrides).
  final int rank;

  /// True when the file does not exist yet but may be created.
  final bool creatable;

  const EnvSource({
    required this.path,
    required this.scope,
    required this.format,
    required this.kind,
    this.readOnly = false,
    required this.rank,
    this.creatable = false,
  });

  String get displayPath => path.replaceFirst(RegExp('^/home/[^/]+'), '~');
}

/// One registration of a variable inside a specific file.
class EnvDefinition {
  final String key;
  final EnvSource source;

  /// 1-based line number inside the file.
  final int line;

  /// Raw line as written in the file.
  final String raw;

  /// Parsed (unquoted) value.
  final String value;

  const EnvDefinition({
    required this.key,
    required this.source,
    required this.line,
    required this.raw,
    required this.value,
  });
}

/// A variable, merged across every location it is registered in.
class EnvEntry {
  final String key;

  /// Definitions sorted by precedence rank (system → user → session).
  final List<EnvDefinition> defs;

  /// Value visible in the running session (file values + session applies).
  final String? sessionValue;

  const EnvEntry({
    required this.key,
    required this.defs,
    this.sessionValue,
  });

  bool get inSession => sessionValue != null;

  bool get isSessionOnly => sessionValue != null && defs.isEmpty;

  /// Best value to display: live session value wins, else last registered file value.
  String? get displayValue {
    if (sessionValue != null) return sessionValue;
    if (defs.isNotEmpty) return defs.last.value;
    return null;
  }

  Set<EnvScope> get scopes {
    final s = <EnvScope>{};
    for (final d in defs) {
      s.add(d.source.scope);
    }
    if (inSession) s.add(EnvScope.session);
    return s;
  }
}

/// A candidate destination when adding / editing a variable.
class WriteTarget {
  final String path;
  final String title;
  final String subtitle;
  final EnvFormat format;
  final EnvScope scope;
  final bool recommended;
  final EnvKind kind;

  const WriteTarget({
    required this.path,
    required this.title,
    required this.subtitle,
    required this.format,
    required this.scope,
    this.recommended = false,
    required this.kind,
  });

  String get displayPath => path.replaceFirst(RegExp('^/home/[^/]+'), '~');
}

/// Result of a scan over all known sources.
class ScanResult {
  final List<EnvSource> sources;
  final List<EnvEntry> entries;
  final Map<String, String> sessionEnv;

  const ScanResult({
    required this.sources,
    required this.entries,
    required this.sessionEnv,
  });
}
