import 'package:flutter/cupertino.dart' show CupertinoApp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_adaptive_ui/native_adaptive_ui.dart';

import 'package:native_adaptive_ui_example/router_example.dart';

void main() {
  setUp(() {
    // router_example.dart calls NativeAdaptiveUi.ensureInitialized() from
    // main(), which a widget test never runs — same reason widget_test.dart
    // injects the era by hand.
    NativeAdaptiveUi.debugSetPlatform(
      PlatformInfo.fake(era: DesignEra.material3),
    );
    addTearDown(() => NativeAdaptiveUi.debugSetPlatform(null));
  });

  testWidgets('the shell route drives the navigation scaffold', (tester) async {
    await tester.pumpWidget(const RouterExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsWidgets);

    // goBranch, reached through onDestinationSelected.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Preview era'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.library_music));
    await tester.pumpAndSettle();
    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('a pushed route pops through onBack, not the Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(const RouterExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Album 2'));
    await tester.pumpAndSettle();
    expect(find.text('Album 2'), findsWidgets);

    // canPop/onBack came from the router; tapping the back button has to
    // return to the branch root rather than throwing or doing nothing.
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('changing era swaps the app widget without losing location', (
    tester,
  ) async {
    await tester.pumpWidget(const RouterExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    await tester.tap(find.text('iosLiquidGlass'));
    await tester.pumpAndSettle();

    // AdaptiveApp.router rebuilt as a CupertinoApp, and the router kept the
    // current branch — the settings list is still on screen.
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsNothing);
    expect(find.text('Preview era'), findsOneWidget);
  });
}
