import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/scanner.dart';
import '../services/session.dart';
import '../services/writer.dart';
import 'add_edit_dialog.dart';
import 'entry_sheet.dart';
import 'widgets.dart';

enum _Filter { all, system, user, session }

class HomePage extends StatefulWidget {
  final void Function(BuildContext) onOpenSettings;

  const HomePage({super.key, required this.onOpenSettings});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ScanResult? _result;
  bool _loading = true;
  String? _error;
  String _query = '';
  _Filter _filter = _Filter.all;

  /// Session changes made during this run (survives re-scans).
  final Map<String, String?> _sessionOverlay = {};

  /// Remembered content for undo of destructive edits.
  final Map<String, String> _undoStack = {};

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  Future<void> _rescan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Scanner.scan(sessionOverlay: _sessionOverlay);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<EnvEntry> get _visible {
    final result = _result;
    if (result == null) return const [];
    final q = _query.trim().toLowerCase();
    return result.entries.where((e) {
      if (_filter != _Filter.all && !e.scopes.contains(_switchScope(_filter))) {
        return false;
      }
      if (q.isEmpty) return true;
      if (e.key.toLowerCase().contains(q)) return true;
      final v = e.displayValue;
      if (v != null && v.toLowerCase().contains(q)) return true;
      return e.defs.any((d) => d.source.path.toLowerCase().contains(q));
    }).toList();
  }

  EnvScope _switchScope(_Filter f) => switch (f) {
        _Filter.system => EnvScope.system,
        _Filter.user => EnvScope.user,
        _Filter.session => EnvScope.session,
        _Filter.all => EnvScope.session,
      };

  // -- actions -----------------------------------------------------------------

  Future<void> _addVariable() async {
    final saved = await showAddEditDialog(context);
    if (saved == null || !saved.ok || !mounted) return;
    await _rescan();
    if (!mounted) return;
    final applyLine = saved.applySummary;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'Saved to ${saved.path!.replaceFirst(RegExp('^/home/[^/]+'), '~')}'
          '${applyLine.isEmpty ? '' : ' · $applyLine'}',
        ),
        duration: const Duration(seconds: 5),
      ));
  }

  Future<void> _editDefinition(EnvDefinition def) async {
    final saved = await showAddEditDialog(context, edit: def);
    if (saved == null || !saved.ok || !mounted) return;
    await _rescan();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Updated ${def.key}'),
        duration: const Duration(seconds: 4),
      ));
  }

  Future<void> _removeDefinition(EnvDefinition def) async {
    final key = def.key;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove variable?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove this line?', style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                def.raw.trim(),
                style: mono(ctx, size: 12),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'from ${def.source.displayPath}:${def.line}',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final content = await _readFile(def.source.path);
    if (content == null) return;
    final newContent = EnvWriter.buildRemove(
      existing: content,
      format: def.source.format,
      key: key,
    );
    if (newContent == null) return;

    final outcome = await _runWrite(
      message: def.source.scope == EnvScope.system
          ? 'Waiting for administrator authentication…'
          : 'Saving…',
      path: def.source.path,
      content: newContent,
      existed: true,
    );
    if (!mounted) return;

    if (outcome.ok) {
      _undoStack['${def.source.path}|$key'] = content;
      await _rescan();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Removed $key from ${def.source.displayPath}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoRemove(def.source.path, key),
          ),
          duration: const Duration(seconds: 8),
        ));
    } else {
      showFallbackDialog(
        context,
        path: def.source.path,
        error: outcome.error ?? 'Write failed',
        command: outcome.fallbackCommand,
        onDone: _rescan,
      );
    }
  }

  Future<void> _undoRemove(String path, String key) async {
    final old = _undoStack.remove('$path|$key');
    if (old == null || !mounted) return;
    final outcome = await _runWrite(
      message: 'Restoring…',
      path: path,
      content: old,
      existed: true,
    );
    if (!mounted) return;
    if (outcome.ok) {
      await _rescan();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Restored')));
    } else {
      showFallbackDialog(
        context,
        path: path,
        error: outcome.error ?? 'Write failed',
        command: outcome.fallbackCommand,
      );
    }
  }

  Future<String?> _readFile(String path) async {
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Shared modal progress wrapper around a file write.
  Future<WriteOutcome> _runWrite({
    required String message,
    required String path,
    required String content,
    required bool existed,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    final outcome = await EnvWriter.write(
      path: path,
      content: content,
      existed: existed,
    );
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    return outcome;
  }

  // -- build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;
    final total = _result?.entries.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envirify'),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            onPressed: _loading ? null : _rescan,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => widget.onOpenSettings(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search keys, values or file paths…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _query = ''),
                      ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                for (final f in _Filter.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.all => 'All',
                        _Filter.system => 'System',
                        _Filter.user => 'User',
                        _Filter.session => 'Session',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                const Spacer(),
                if (total != null && !_loading)
                  Text(
                    '${visible.length} / $total',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Divider(color: scheme.outlineVariant),
          Expanded(child: _buildList(context, visible)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVariable,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add variable'),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<EnvEntry> visible) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text('Scanning system and user sources…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Scan failed: $_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error)),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text('No variables match',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 96),
      itemCount: visible.length,
      itemBuilder: (context, i) => _EntryTile(
        entry: visible[i],
        onTap: () => showEntrySheet(
          context,
          entry: visible[i],
          onEdit: _editDefinition,
          onRemove: _removeDefinition,
          onRescan: _rescan,
          onApply: _applyToSession,
        ),
        onCopy: () => copyValue(context, 'Value', visible[i].displayValue ?? ''),
      ),
    );
  }

  Future<void> _applyToSession(String key, String value) async {
    final results = await SessionApplier.apply(key, value);
    if (!mounted) return;
    _sessionOverlay[key] = value;
    await _rescan();
    if (!mounted) return;
    final failed = results.where((r) => !r.startsWith('ok')).toList();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(failed.isEmpty
            ? '$key applied to the running session'
            : 'Session apply: ${failed.join(', ')}'),
        duration: const Duration(seconds: 5),
      ));
  }
}

class _EntryTile extends StatelessWidget {
  final EnvEntry entry;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scopes = entry.scopes.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final primaryDef = entry.defs.isEmpty ? null : entry.defs.last;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono(context,
                          size: 14.5, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final s in scopes) ...[
                    ScopePill(s, tiny: true),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copy value',
                    iconSize: 17,
                    onPressed: onCopy,
                    icon: Icon(Icons.copy_rounded, color: scheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                entry.displayValue ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(context,
                    size: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    primaryDef == null
                        ? Icons.bolt_rounded
                        : kindIcon(primaryDef.source),
                    size: 13,
                    color: scheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      primaryDef == null
                          ? 'running session only — not registered in any file'
                          : '${primaryDef.source.displayPath}:${primaryDef.line}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono(context, size: 11, color: scheme.outline),
                    ),
                  ),
                  if (entry.defs.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '+${entry.defs.length - 1} more',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.outline),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
