import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/writer.dart';
import 'widgets.dart';

/// Bottom sheet listing every location a variable is registered in.
Future<void> showEntrySheet(
  BuildContext context, {
  required EnvEntry entry,
  required void Function(EnvDefinition def) onEdit,
  required void Function(EnvDefinition def) onRemove,
  required Future<void> Function() onRescan,
  required Future<void> Function(String key, String value) onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _SheetBody(
            entry: entry,
            onEdit: onEdit,
            onRemove: onRemove,
            onRescan: onRescan,
            onApply: onApply,
          ),
        ),
      ),
    ),
  );
}

class _SheetBody extends StatefulWidget {
  final EnvEntry entry;
  final void Function(EnvDefinition def) onEdit;
  final void Function(EnvDefinition def) onRemove;
  final Future<void> Function() onRescan;
  final Future<void> Function(String key, String value) onApply;

  const _SheetBody({
    required this.entry,
    required this.onEdit,
    required this.onRemove,
    required this.onRescan,
    required this.onApply,
  });

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final defs = entry.defs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mono(context, size: 19, weight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Copy key',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () => copyValue(context, 'Key', entry.key),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Current session value -------------------------------------------------
        _sectionLabel(context, 'Running session'),
        const SizedBox(height: 6),
        _valueBox(
          context,
          value: entry.sessionValue,
          fallbackText: 'not present in this session',
          trailing: entry.inSession
              ? IconButton(
                  tooltip: 'Copy value',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  icon: Icon(Icons.copy_rounded, color: scheme.outline),
                  onPressed: () =>
                      copyValue(context, 'Value', entry.sessionValue!),
                )
              : null,
        ),
        if (entry.inSession && defs.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Inherited at runtime — not registered in any startup file, '
            'so it disappears on re-login.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (!entry.inSession && defs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Defined in files but not loaded into the running session.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _applying
                    ? null
                    : () async {
                        final value = entry.defs.last.value;
                        setState(() => _applying = true);
                        await widget.onApply(entry.key, value);
                        if (mounted) setState(() => _applying = false);
                      },
                icon: _applying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Apply now'),
              ),
            ],
          ),
        ],

        if (defs.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel(
              context,
              'Registered in ${defs.length} location'
              '${defs.length == 1 ? '' : 's'}'),
          const SizedBox(height: 4),
          Text(
            'Files apply in order — later entries override earlier ones.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 8),
          for (final def in defs) ...[
            _defCard(context, def),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _valueBox(
    BuildContext context, {
    required String? value,
    required String fallbackText,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value != null && value.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              hasValue ? value : fallbackText,
              style: hasValue
                  ? mono(context, size: 13)
                  : mono(context, size: 13, color: scheme.outline),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _defCard(BuildContext context, EnvDefinition def) {
    final scheme = Theme.of(context).colorScheme;
    final src = def.source;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScopePill(src.scope, tiny: true),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: src.path,
                  child: Text(
                    '${src.displayPath}:${def.line}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(context, size: 12, color: scheme.onSurface),
                  ),
                ),
              ),
              if (src.readOnly)
                IconButton(
                  tooltip: 'Read-only source — managed by the system or '
                      'another tool',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: null,
                  icon: Icon(Icons.lock_outline_rounded,
                      size: 16, color: scheme.outline),
                )
              else ...[
                IconButton(
                  tooltip: 'Edit value here',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onEdit(def);
                  },
                  icon: Icon(Icons.edit_outlined, size: 17, color: scheme.outline),
                ),
                IconButton(
                  tooltip: 'Remove from this file',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onRemove(def);
                  },
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 17, color: scheme.error),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(kindIcon(src), size: 13, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  def.value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: mono(context, size: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (!src.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                EnvWriter.effectHint(src.format, src.scope),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
