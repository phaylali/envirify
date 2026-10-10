import 'dart:io';

import '../models/models.dart';

/// Candidate destinations for new variables, per scope.
class Targets {
  Targets._();

  static String get home =>
      Platform.environment['HOME'] ?? Directory.systemTemp.path;

  static List<WriteTarget> system() => const [
        WriteTarget(
          path: '/etc/profile.d/envirify.sh',
          title: '/etc/profile.d/envirify.sh',
          subtitle: 'POSIX login shells · .sh file created automatically',
          format: EnvFormat.shell,
          scope: EnvScope.system,
          recommended: true,
          kind: EnvKind.profileD,
        ),
        WriteTarget(
          path: '/etc/environment',
          title: '/etc/environment',
          subtitle: 'Every login session system-wide (pam_env)',
          format: EnvFormat.pam,
          scope: EnvScope.system,
          kind: EnvKind.etcEnvironment,
        ),
        WriteTarget(
          path: '/etc/environment.d/90-envirify.conf',
          title: '/etc/environment.d/90-envirify.conf',
          subtitle: 'systemd system services · file created automatically',
          format: EnvFormat.pam,
          scope: EnvScope.system,
          kind: EnvKind.etcEnvironmentD,
        ),
      ];

  static List<WriteTarget> user() {
    final shell = (Platform.environment['SHELL'] ?? '').split('/').last;
    final list = <WriteTarget>[
      WriteTarget(
        path: '$home/.config/environment.d/90-envirify.conf',
        title: '~/.config/environment.d/90-envirify.conf',
        subtitle: 'GUI apps & user services · directory created automatically',
        format: EnvFormat.pam,
        scope: EnvScope.user,
        recommended: true,
        kind: EnvKind.userEnvironmentD,
      ),
    ];

    // The user's own interactive shell config first.
    if (shell == 'fish') {
      final fish = '$home/.config/fish/config.fish';
      if (File(fish).existsSync()) {
        list.add(WriteTarget(
          path: fish,
          title: '~/.config/fish/config.fish',
          subtitle: 'New fish shells pick it up',
          format: EnvFormat.fish,
          scope: EnvScope.user,
          kind: EnvKind.fishConfig,
        ));
      }
    } else if (shell == 'zsh') {
      final zsh = '$home/.zshrc';
      list.add(WriteTarget(
        path: zsh,
        title: '~/.zshrc',
        subtitle: 'New zsh shells pick it up',
        format: EnvFormat.shell,
        scope: EnvScope.user,
        kind: EnvKind.shellRc,
      ));
    } else {
      list.add(WriteTarget(
        path: '$home/.bashrc',
        title: '~/.bashrc',
        subtitle: 'New bash shells pick it up',
        format: EnvFormat.shell,
        scope: EnvScope.user,
        kind: EnvKind.shellRc,
      ));
    }

    list.add(WriteTarget(
      path: '$home/.profile',
      title: '~/.profile',
      subtitle: 'POSIX login shells (all users of this account)',
      format: EnvFormat.shell,
      scope: EnvScope.user,
      kind: EnvKind.userProfile,
    ));

    final hyprLua = '$home/.config/hypr/hyprland.lua';
    if (File(hyprLua).existsSync()) {
      list.add(WriteTarget(
        path: hyprLua,
        title: '~/.config/hypr/hyprland.lua',
        subtitle: 'hl.env() — apps launched by Hyprland',
        format: EnvFormat.hyprLua,
        scope: EnvScope.user,
        kind: EnvKind.hyprland,
      ));
    }
    final hyprConf = '$home/.config/hypr/hyprland.conf';
    if (File(hyprConf).existsSync()) {
      list.add(WriteTarget(
        path: hyprConf,
        title: '~/.config/hypr/hyprland.conf',
        subtitle: 'env = KEY,VALUE — apps launched by Hyprland',
        format: EnvFormat.hyprConf,
        scope: EnvScope.user,
        kind: EnvKind.hyprland,
      ));
    }

    return list;
  }

  static List<WriteTarget> forScope(EnvScope scope) =>
      scope == EnvScope.system ? system() : user();
}
