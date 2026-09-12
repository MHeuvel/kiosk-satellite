import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/ui/app_launcher_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app launcher wall under a dpad (issue #377): its first tile takes
/// focus even when the menu row that opened it still holds focus, and the
/// arrows never leave the wall for whatever sits underneath it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FocusNode other;

  Future<AppContainer> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'ks.launcher.enabled': true,
      'ks.launcher.apps':
          '[{"package":"a","label":"Alpha"},'
          '{"package":"b","label":"Beta"},'
          '{"package":"c","label":"Gamma"}]',
    });
    final container = AppContainer();
    await container.settings.init();
    other = FocusNode(debugLabel: 'menu row');
    addTearDown(other.dispose);
    tester.view.physicalSize = const Size(1200, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            // Stands in for the menu row the dpad pressed to open the wall:
            // focused before the wall exists, and still focused through the
            // wall's first frame.
            Focus(
              focusNode: other,
              autofocus: true,
              child: const SizedBox.expand(),
            ),
            AppLauncherOverlay(container: container),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(other.hasPrimaryFocus, isTrue);
    container.launcher.visible.value = true;
    await tester.pump();
    await tester.pump();
    return container;
  }

  /// Whether the tile labelled [label] holds the primary focus: the label
  /// sits beside the tile's InkWell, so walk up from the focused element
  /// to the tile's column and look for the label inside it.
  bool focused(WidgetTester tester, String label) {
    final ctx = tester.binding.focusManager.primaryFocus?.context;
    if (ctx == null) return false;
    final column = find
        .ancestor(
          of: find.byElementPredicate((e) => identical(e, ctx)),
          matching: find.byType(Column),
        )
        .first;
    return find
        .descendant(of: column, matching: find.text(label))
        .evaluate()
        .isNotEmpty;
  }

  testWidgets('the first tile takes focus from whatever held it', (
    tester,
  ) async {
    await open(tester);
    expect(focused(tester, 'Alpha'), isTrue);
    expect(other.hasPrimaryFocus, isFalse);
  });

  testWidgets('the arrows walk the tiles and stop at the wall', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(tester, 'Beta'), isTrue);
    // Nothing below the single row: the search must not fall through to
    // the focusable underneath.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'Beta'), isTrue);
    expect(other.hasPrimaryFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focused(tester, 'Alpha'), isTrue);
  });
}
