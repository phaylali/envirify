import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session.dart';
import '../services/targets.dart';
import '../services/writer.dart';
import 'widgets.dart';

class SaveResult {
  final bool ok;
  final String? path;
  final String applySummary;
  final String? error;

  const SaveResult({
    required this.ok,
    this.path,
    this.applySummary = '',
    this.error,
  });
}

/// Add (or edit) a variable. Writes the file — creating it when needed —
/// and optionally pushes the value into the running session.
Future<SaveResult?> showAddEditDialog(
  BuildContext context, {
  EnvDefinition? edit,
}) {
  return showDialog<SaveResult>(
    context: context,
    builder: (_) => _AddEditDialog(edit: edit),
  );
}

class _AddEditDialog extends StatefulWidget {
  final EnvDefinition? edit;

  const _AddEditDialog({this.edit});

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valCtrl;

  EnvScope _scope = EnvScope.user;
  WriteTarget? _target;
  bool _apply = true;
  bool _saving = false;
  String? _error;
  String? _fallbackCmd;

  EnvDefinition? get _edit => widget.edit;
  bool get isEdit => _edit != null;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: _edit?.key ?? '');
    _valCtrl = TextEditingController(text: _edit?.value ?? '');
    if (isEdit) {
      final s = _edit!.source;
      _scope = s.scope;
    } else {
      final targets = Targets.forScope(_scope);
      _target = targets.isNotEmpty ? targets.first : null;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  void _setScope(EnvScope scope) {
    if (_scope == scope) return;
    final targets = Targets.forScope(scope);
    setState(() {
      _scope = scope;
      _target = targets.isNotEmpty ? targets.first : null;
      _error = null;
      _fallbackCmd = null;
    });
  }

  // -- save --------------------------------------------------------------------

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _fallbackCmd = null;
    });

    final key = _keyCtrl.text.trim();
    var value = _valCtrl.text;
    if (value.contains('\n')) {
      setState(() => _error = 'Values must be on a single line.');
      return;
    }

    final String path;
    final EnvFormat format;
    final EnvScope scope;
    if (isEdit) {
      path = _edit!.source.path;
      format = _edit!.source.format;
      scope = _edit!.source.scope;
    } else {
      final t = _target;
      if (t == null) {
        setState(() => _error = 'Choose where to store the variable.');
        return;
      }
      path = t.path;
      format = t.format;
      scope = t.scope;
    }

    final file = File(path);
    final existed = await file.exists();
    String existing = '';
    if (existed) {
      try {
        existing = await file.readAsString();
      } catch (e) {
        setState(() => _error = 'Cannot read $path: $e');
        return;
      }
    }

    final newContent = EnvWriter.buildUpsert(
      existing: existing,
      format: format,
      key: key,
      value: value,
      existed: existed,
    );

    if (newContent == null) {
      // Nothing to change.
      if (mounted) {
        Navigator.of(context).pop(
          SaveResult(ok: true, path: path, applySummary: 'no changes'),
        );
      }
      return;
    }

    setState(() => _saving = true);
    _showProgress(
      scope == EnvScope.system
          ? 'Waiting for administrator authentication…'
          : 'Saving…',
    );

    final outcome = await EnvWriter.write(
      path: path,
      content: newContent,
      existed: existed,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // progress

    if (!outcome.ok) {
      setState(() {
        _saving = false;
        _error = outcome.error ?? 'Write failed';
        _fallbackCmd = outcome.fallbackCommand;
      });
      return;
    }

    var applySummary = '';
    if (_apply) {
      applySummary = _summarize(await SessionApplier.apply(key, value));
    }

    if (!mounted) return;
    Navigator.of(context).pop(SaveResult(
      ok: true,
      path: path,
      applySummary: applySummary,
    ));
  }

  String _summarize(List<String> results) {
    final failed = results.where((r) => !r.startsWith('ok')).toList();
    if (failed.isEmpty) return 'session updated';
    return 'session: ${failed.first}';
  }

  void _showProgress(String message) {
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
  }

  // -- build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final targets = isEdit ? const <WriteTarget>[] : Targets.forScope(_scope);

    return AlertDialog(
      title: Text(isEdit ? 'Edit variable' : 'Add variable'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key ----------------------------------------------------------
                TextFormField(
                  controller: _keyCtrl,
                  enabled: !_saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: mono(context, size: 14, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'MY_VARIABLE',
                    helperText: 'Letters, digits, underscore — cannot start '
                        'with a digit',
                    helperMaxLines: 2,
                    floatingLabelBehavior: labelFloatBehavior(),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Name is required';
                    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s)) {
                      return 'Invalid name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Value --------------------------------------------------------
                TextFormField(
                  controller: _valCtrl,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 3,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: mono(context, size: 13),
                  decoration: InputDecoration(
                    labelText: 'Value',
                    hintText: '/some/path:\$HOME/bin',
                    floatingLabelBehavior: labelFloatBehavior(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Value is required';
                    if (v.contains('\n')) return 'Single line only';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Scope --------------------------------------------------------
                if (!isEdit) ...[
                  Text('SCOPE',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: scheme.primary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<EnvScope>(
                      segments: const [
                        ButtonSegment(
                          value: EnvScope.user,
                          label: Text('User'),
                          icon: Icon(Icons.person_outline, size: 17),
                        ),
                        ButtonSegment(
                          value: EnvScope.system,
                          label: Text('System-wide'),
                          icon: Icon(Icons.computer, size: 17),
                        ),
                      ],
                      selected: {_scope},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => _setScope(s.first),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Target files ----------------------------------------------
                  Text('STORE IN',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: scheme.primary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 4),
                  for (final t in targets)
                    _targetTile(context, t, scheme),
                  if (_target != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 4),
                      child: Text(
                        EnvWriter.effectHint(_target!.format, _target!.scope),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.outline),
                      ),
                    ),
                ] else ...[
                  Text('LOCATION',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: scheme.primary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          '${_edit!.source.displayPath}:${_edit!.line}',
                          style: mono(context, size: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          EnvWriter.effectHint(
                              _edit!.source.format, _edit!.source.scope),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _apply,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _apply = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Apply to running session now',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'Updates systemd user services and D-Bus activated apps. '
                    'New shells read the file automatically either way.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),

                // Error / fallback ---------------------------------------------
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSystemPath(pathOf())
                              ? 'Administrator approval failed — run this '
                                  'command to apply the change:'
                              : 'Write failed',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        if (_fallbackCmd != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _fallbackCmd!,
                                    style: mono(context, size: 11.5),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy command',
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  icon: const Icon(Icons.copy_rounded),
                                  onPressed: () => copyValue(
                                      context, 'Command', _fallbackCmd!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your edit is staged in that temporary file. '
                            'Run the command, then press Save again to verify.',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  scheme.onErrorContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(isEdit ? Icons.check_rounded : Icons.add_rounded,
                  size: 18),
          label: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  String pathOf() => isEdit
      ? _edit!.source.path
      : (_target?.path ?? '');

  static bool isSystemPath(String p) => EnvWriter.needsRoot(p);

  Widget _targetTile(BuildContext context, WriteTarget t, ColorScheme scheme) {
    final selected = _target?.path == t.path;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _saving ? null : () => setState(() => _target = t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: mono(context,
                        size: 12.5,
                        weight:
                            selected ? FontWeight.w700 : FontWeight.w400),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${t.recommended ? 'Recommended — ' : ''}${t.subtitle}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color:
                              t.recommended ? scheme.primary : scheme.outline,
                          fontWeight:
                              t.recommended ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a privileged write could not complete — gives the user a
/// copy-paste command so no change is ever silently lost.
void showFallbackDialog(
  BuildContext context, {
  required String path,
  required String error,
  String? command,
  Future<void> Function()? onDone,
}) {
  final scheme = Theme.of(context).colorScheme;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Administrator approval needed'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error,
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            if (command != null) ...[
              const SizedBox(height: 14),
              Text('Run this in a terminal:',
                  style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(command, style: mono(ctx, size: 12))),
                    IconButton(
                      tooltip: 'Copy command',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => copyValue(ctx, 'Command', command),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 8),
            Text(
              'Target: $path',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onDone?.call();
          },
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
