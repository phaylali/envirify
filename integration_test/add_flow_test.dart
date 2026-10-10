import 'dart:io';

import 'package:envirify/main.dart';
import 'package:envirify/models/models.dart';
import 'package:envirify/services/session.dart';
import 'package:envirify/services/writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end: add / edit / remove a variable through the real GUI, verifying
/// file creation, syntax, list integration and session application.
/// Cleans up after itself.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const key = 'ENVIRIFY_E2E_TEST';
  final home = Platform.environment['HOME']!;
  final confDir = Directory('$home/.config/environment.d');
  final confFile = File('$home/.config/environment.d/90-envirify.conf');
  final dirExistedBefore = confDir.existsSync();
  final fileExistedBefore = confFile.existsSync();

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  Future<void> cleanup() async {
    try {
      if (fileExistedBefore) {
        final content = await confFile.readAsString();
        final newContent = EnvWriter.buildRemove(
          existing: content,
          format: EnvFormat.pam,
          key: key,
        );
        if (newContent != null) await confFile.writeAsString(newContent);
      } else if (await confFile.exists()) {
        await confFile.delete();
        final bak = File('${confFile.path}.envirify.bak');
        if (await bak.exists()) await bak.delete();
        if (!dirExistedBefore && await confDir.exists()) {
          final isEmpty = await confDir.list().length == 0;
          if (isEmpty) await confDir.delete();
        }
      }
    } catch (_) {}
    try {
      await SessionApplier.apply(key, null);
    } catch (_) {}
  }

  testWidgets('add variable end-to-end', (tester) async {
    addTearDown(cleanup);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const EnvirifyApp());
    await settle(tester); // initial scan

    // --- Open the add dialog --------------------------------------------------
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Add variable'), findsOneWidget);

    // --- Fill the form --------------------------------------------------------
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), key);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Value'), 'it works');

    // Default: User scope + environment.d target (recommended).
    expect(find.textContaining('90-envirify.conf'), findsWidgets);
    expect(find.textContaining('Recommended'), findsOneWidget);

    // --- Save -----------------------------------------------------------------
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.widgetWithText(AlertDialog, 'Add variable'), findsNothing,
        reason: 'dialog should close after a successful save');

    // --- File actually created with correct syntax ----------------------------
    expect(confFile.existsSync(), isTrue,
        reason: '${confFile.path} should have been created');
    final content = confFile.readAsStringSync();
    expect(content, contains('$key="it works"'));

    // --- Entry shows up with its location --------------------------------------
    await tester.enterText(find.byType(TextField).first, key);
    await settle(tester);
    expect(find.textContaining('90-envirify.conf'), findsWidgets);

    // Tap the tile (search field also contains the key → use .last).
    await tester.tap(find.text(key).last);
    await settle(tester);
    expect(find.textContaining('REGISTERED IN 1 LOCATION'), findsOneWidget);

    // Value was pushed into the running session too (systemctl quotes
    // values containing spaces as $'...').
    final applied = await Process.run(
        'systemctl', ['--user', 'show-environment']);
    final envOut = applied.stdout.toString();
    expect(envOut, contains('$key='));
    expect(envOut, contains('it works'));
  });

  testWidgets('edit and remove round-trip', (tester) async {
    addTearDown(cleanup);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Seed a file so there is something to edit.
    confFile.parent.createSync(recursive: true);
    confFile.writeAsStringSync('$key="seed"\n');

    await tester.pumpWidget(const EnvirifyApp());
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, key);
    await settle(tester);

    // Open detail sheet → edit.
    await tester.tap(find.text(key).last);
    await settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.edit_outlined)));
    await settle(tester);

    expect(find.text('Edit variable'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Value'), 'edited value');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Edit variable'), findsNothing);

    expect(confFile.readAsStringSync(), contains('$key="edited value"'));

    // Open detail sheet → remove.
    await tester.enterText(find.byType(TextField).first, key);
    await settle(tester);
    await tester.tap(find.text(key).last);
    await settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.delete_outline_rounded)));
    await settle(tester);

    expect(find.text('Remove variable?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);

    expect(confFile.readAsStringSync(), isNot(contains(key)));
  });
}
