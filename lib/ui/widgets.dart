import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// How a text field should float its label.
///
/// Normally the label starts *inside* the empty field and rises onto the border
/// when the field is focused or filled — an animated transition. When the
/// system asks Flutter to reduce motion (GNOME `enable-animations=false`),
/// [AnimationController]s finish in a single frame, so that rise happens
/// instantly and reads as a flicker over the field.
///
/// In that case we keep the label floated from the start: focusing a field
/// then only changes its border and cursor, and nothing jumps.
FloatingLabelBehavior labelFloatBehavior() =>
    SemanticsBinding.instance.disableAnimations
        ? FloatingLabelBehavior.always
        : FloatingLabelBehavior.auto;

/// Monospace text style used for keys, values and paths.
TextStyle mono(BuildContext context, {double size = 13, Color? color, FontWeight? weight}) =>
    TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      height: 1.35,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// Small pill showing which scope(s) a variable belongs to.
class ScopePill extends StatelessWidget {
  final EnvScope scope;
  final bool tiny;

  const ScopePill(this.scope, {super.key, this.tiny = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (scope) {
      EnvScope.system => ('System', scheme.tertiaryContainer, scheme.onTertiaryContainer),
      EnvScope.user => ('User', scheme.primaryContainer, scheme.onPrimaryContainer),
      EnvScope.session => ('Session', scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tiny ? 6 : 8, vertical: tiny ? 2 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: tiny ? 10 : 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: fg,
        ),
      ),
    );
  }
}

/// Icon for a source file kind.
IconData kindIcon(EnvSource src) => switch (src.format) {
      EnvFormat.shell || EnvFormat.fish => Icons.terminal_rounded,
      EnvFormat.pam || EnvFormat.pamConf => Icons.article_outlined,
      EnvFormat.fishUniversal => Icons.water_drop_outlined,
      EnvFormat.hyprConf || EnvFormat.hyprLua => Icons.desktop_windows_rounded,
      EnvFormat.runtime => Icons.bolt_rounded,
    };

void copyValue(BuildContext context, String label, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('$label copied'),
      duration: const Duration(seconds: 2),
    ));
}
