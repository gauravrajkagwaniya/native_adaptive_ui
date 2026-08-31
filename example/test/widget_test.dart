import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_adaptive_ui/native_adaptive_ui.dart';

import 'package:native_adaptive_ui_example/main.dart';

void main() {
  testWidgets('gallery renders and switches destinations', (tester) async {
    // The example calls NativeAdaptiveUi.ensureInitialized() from main(), which
    // a widget test never runs, so the era is injected here instead.
    NativeAdaptiveUi.debugSetPlatform(
      PlatformInfo.fake(era: DesignEra.material3),
    );
    addTearDown(() => NativeAdaptiveUi.debugSetPlatform(null));

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('Show alert'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.list));
    // Deliberately not pumpAndSettle: the gallery shows an indeterminate
    // progress indicator, which never settles and would hang the test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Account'), findsOneWidget);
  });
}
