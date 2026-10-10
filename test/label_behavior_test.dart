// Regression tests for the focus "flicker" on the dialog's text fields.
//
// When the system asks Flutter to reduce motion (GNOME
// `enable-animations=false`), AnimationControllers finish in a single frame.
// The Material 3 label would then jump from inside the field onto the border
// the moment the field is focused — an instant snap that reads as a flicker.
// Envirify keeps the label floated instead so nothing moves.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:envirify/services/system_theme.dart';
import 'package:envirify/theme/app_theme.dart';
import 'package:envirify/ui/add_edit_dialog.dart';

Future<void> _openDialog(WidgetTester tester) async {
  final data = AppTheme.build(const ThemeInfo(
    brightness: Brightness.dark,
    flavor: 'mocha',
    accentName: 'lavender',
    fontFamily: 'Noto Sans',
  ));

  await tester.pumpWidget(MaterialApp(
    theme: data,
    home: Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAddEditDialog(ctx),
            child: const Text('open'),
          ),
        ),
      );
    }),
  ));

  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Rect _valueLabelRect(WidgetTester tester) =>
    tester.getRect(find.text('Value'));

void main() {
  testWidgets('label does not move on focus when animations are disabled',
      (tester) async {
    debugSemanticsDisableAnimations = true;
    addTearDown(() => debugSemanticsDisableAnimations = null);

    await _openDialog(tester);

    final before = _valueLabelRect(tester);
    final field = tester.getRect(find.byType(TextFormField).last);

    // The label must already be floated while the field is idle, so it has
    // nowhere to jump to when focus arrives.
    expect(before.top, lessThan(field.top + 8),
        reason: 'label should sit on the border, not inside the field');

    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final moved = (_valueLabelRect(tester).top - before.top).abs();
    expect(moved, lessThan(4.0),
        reason: 'focusing must not move the label when motion is reduced '
            '(it would snap in one frame and read as a flicker)');
  });

  testWidgets('label still floats normally when animations are enabled',
      (tester) async {
    debugSemanticsDisableAnimations = false;
    addTearDown(() => debugSemanticsDisableAnimations = null);

    await _openDialog(tester);

    final before = _valueLabelRect(tester);

    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_valueLabelRect(tester).top, lessThan(before.top),
        reason: 'with animations on, the label should rise onto the border');
  });
}
