import 'dart:io';

import 'package:flutter/material.dart';

import 'services/system_theme.dart';
import 'theme/app_theme.dart';
import 'ui/home_page.dart';
import 'ui/settings_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnvirifyApp());
}

class EnvirifyApp extends StatefulWidget {
  const EnvirifyApp({super.key});

  @override
  State<EnvirifyApp> createState() => _EnvirifyAppState();
}

class _EnvirifyAppState extends State<EnvirifyApp> {
  final SystemThemeWatcher _watcher = SystemThemeWatcher();
  ThemeInfo? _info;
  ThemeMode _mode = ThemeMode.system;

  static File get _prefFile {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/envirify/pref');
  }

  @override
  void initState() {
    super.initState();
    _loadPref();
    _watcher.readInitial().then((info) {
      if (mounted) setState(() => _info = info);
    });
    _watcher.start();
    _watcher.changes.listen((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  Future<void> _loadPref() async {
    try {
      final f = _prefFile;
      if (await f.exists()) {
        final v = (await f.readAsString()).trim();
        final m = switch (v) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        if (mounted) setState(() => _mode = m);
      }
    } catch (_) {}
  }

  Future<void> _setMode(ThemeMode mode) async {
    setState(() => _mode = mode);
    try {
      final f = _prefFile;
      await f.parent.create(recursive: true);
      await f.writeAsString(switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _watcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    var info = _info ??
        ThemeInfo(
          brightness: platformBrightness,
          flavor: null,
        );

    // User-forced theme mode wins over the detected system brightness.
    if (_mode != ThemeMode.system) {
      final desired =
          _mode == ThemeMode.dark ? Brightness.dark : Brightness.light;
      if (info.brightness != desired) info = info.copyWith(brightness: desired);
    }

    final data = AppTheme.build(info);
    final resolved = info.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    return MaterialApp(
      title: 'Envirify',
      debugShowCheckedModeBanner: false,
      theme: data,
      darkTheme: data,
      themeMode: resolved,
      home: HomePage(onOpenSettings: _openSettings),
    );
  }

  void _openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SettingsDialog(
        mode: _mode,
        info: _info ??
            ThemeInfo(
              brightness:
                  WidgetsBinding.instance.platformDispatcher.platformBrightness,
            ),
        onMode: (m) {
          _setMode(m);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}
