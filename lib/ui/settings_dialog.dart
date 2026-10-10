import 'package:flutter/material.dart';

import '../services/system_theme.dart';

/// Small dialog: theme mode + what Envirify detected from the desktop.
class SettingsDialog extends StatelessWidget {
  final ThemeMode mode;
  final ThemeInfo info;
  final ValueChanged<ThemeMode> onMode;

  const SettingsDialog({
    super.key,
    required this.mode,
    required this.info,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onMode(s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 15, color: scheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detected: ${info.description}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Text('About',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Envirify 1.0 — Arch GUI Environment Manager',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'by Omniversify. Scans /etc/environment, profile.d, environment.d, '
              'shell configs, fish, Hyprland and the running session.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
