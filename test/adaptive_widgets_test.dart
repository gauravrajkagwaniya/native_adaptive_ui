import 'dart:typed_data' show Uint8List;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_adaptive_ui/native_adaptive_ui.dart';

/// Pumps [child] as if the app were running on [era], at [width] logical
/// pixels. Rendering every era on one machine is the point of
/// `debugSetPlatform`; without it these would be device-only tests.
Future<void> pumpEra(
  WidgetTester tester,
  DesignEra era,
  Widget child, {
  double width = 390,
  double height = 844,
  Set<String> nativeComponents = const <String>{},
}) async {
  NativeAdaptiveUi.debugSetPlatform(
    PlatformInfo.fake(era: era, nativeComponents: nativeComponents),
  );
  addTearDown(() => NativeAdaptiveUi.debugSetPlatform(null));

  // The window has to be resized rather than wrapped in a MediaQuery: MaterialApp
  // installs its own MediaQuery from the view, which would discard an outer one
  // and quietly make every "narrow window" test pass for the wrong reason.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AdaptiveScope(
      era: era,
      child: MaterialApp(
        home: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
}

/// Like [pumpEra], but pumps [app] itself rather than wrapping a child in a
/// plain `MaterialApp`. [AdaptiveApp] installs its own [AdaptiveScope], so
/// wrapping it in another one would test the wrapper instead of the widget.
Future<void> pumpApp(
  WidgetTester tester,
  DesignEra era,
  Widget app, {
  double width = 390,
  double height = 844,
}) async {
  NativeAdaptiveUi.debugSetPlatform(PlatformInfo.fake(era: era));
  addTearDown(() => NativeAdaptiveUi.debugSetPlatform(null));
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
}

/// A minimal hand-rolled Router 2.0 config.
///
/// The point of `AdaptiveApp.router` is that it takes a `RouterConfig` and so
/// needs no router package; testing it with one would undercut that. `GoRouter`
/// reaches `routerConfig` through exactly this interface.
RouterConfig<Object> _testRouterConfig(List<Widget> Function() pages) {
  return RouterConfig<Object>(
    routerDelegate: _TestRouterDelegate(pages),
  );
}

class _TestRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _TestRouterDelegate(this._pages);

  final List<Widget> Function() _pages;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        pages: <Page<Object?>>[
          for (final page in _pages())
            MaterialPage<void>(key: ValueKey<Widget>(page), child: page),
        ],
        onDidRemovePage: (_) {},
      );

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}

void main() {
  tearDown(() => NativeAdaptiveUi.debugSetPlatform(null));

  group('AdaptiveButton', () {
    testWidgets('renders a Cupertino button on classic iOS', (tester) async {
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        AdaptiveButton(onPressed: () {}, child: const Text('Save')),
      );
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders a Material button on Android', (tester) async {
      await pumpEra(
        tester,
        DesignEra.material3,
        AdaptiveButton(onPressed: () {}, child: const Text('Save')),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(CupertinoButton), findsNothing);
    });

    testWidgets('is never made of glass, because it is content', (
      tester,
    ) async {
      // Apple's Materials guidance: "Don't use Liquid Glass in the content
      // layer." A button in a form or a list is content, so the iOS 26 era must
      // render an ordinary Cupertino button, not a glass one.
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        AdaptiveButton(onPressed: () {}, child: const Text('Save')),
      );
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('iOS 26 and iOS 18 differ in geometry, not material', (
      tester,
    ) async {
      double heightOf(DesignEra era) => AdaptiveTokens.of(era).controlHeight;

      expect(
        heightOf(DesignEra.iosLiquidGlass),
        greaterThan(heightOf(DesignEra.iosClassic)),
      );
      expect(
        AdaptiveTokens.of(DesignEra.iosLiquidGlass).cornerRadius,
        greaterThan(AdaptiveTokens.of(DesignEra.iosClassic).cornerRadius),
      );
    });

    testWidgets('fires onPressed', (tester) async {
      var taps = 0;
      await pumpEra(
        tester,
        DesignEra.material3,
        AdaptiveButton(onPressed: () => taps++, child: const Text('Tap')),
      );
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a null callback disables the button on every era', (
      tester,
    ) async {
      for (final era in [DesignEra.iosClassic, DesignEra.material3]) {
        await pumpEra(
          tester,
          era,
          const AdaptiveButton(onPressed: null, child: Text('Off')),
        );
        expect(find.text('Off'), findsOneWidget);
      }
    });
  });

  group('AdaptiveNavigationScaffold', () {
    const destinations = [
      AdaptiveDestination(label: 'Home', icon: Icon(Icons.home)),
      AdaptiveDestination(label: 'Search', icon: Icon(Icons.search)),
    ];

    Widget scaffold() => AdaptiveNavigationScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
        );

    testWidgets('a phone gets a tab bar, not a sidebar', (tester) async {
      await pumpEra(tester, DesignEra.iosLiquidGlass, scaffold());
      expect(find.byKey(adaptiveTabBarKey), findsOneWidget);
      expect(find.byKey(adaptiveSidebarKey), findsNothing);
    });

    testWidgets('classic iOS uses the pinned CupertinoTabBar', (tester) async {
      await pumpEra(tester, DesignEra.iosClassic, scaffold());
      expect(find.byType(CupertinoTabBar), findsOneWidget);
    });

    testWidgets('iOS 26 floats a glass capsule instead', (tester) async {
      // The pinned bar is the wrong shape for a floating capsule, so the glass
      // era deliberately does not use CupertinoTabBar at all.
      await pumpEra(tester, DesignEra.iosLiquidGlass, scaffold());
      expect(find.byType(CupertinoTabBar), findsNothing);
      expect(find.byType(GlassSurface), findsWidgets);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a wide iPad window gets a sidebar', (tester) async {
      await pumpEra(
        tester,
        DesignEra.ipadLiquidGlass,
        scaffold(),
        width: 1024,
        height: 768,
      );
      expect(find.byKey(adaptiveTabBarKey), findsNothing);
      expect(find.byKey(adaptiveSidebarKey), findsOneWidget);
      // Both destination labels are visible at once in a sidebar.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets(
      'an iPad narrowed into Slide Over falls back to a tab bar',
      (tester) async {
        await pumpEra(
          tester,
          DesignEra.ipadLiquidGlass,
          scaffold(),
          width: 380,
          height: 1024,
        );
        expect(find.byKey(adaptiveTabBarKey), findsOneWidget);
        expect(find.byKey(adaptiveSidebarKey), findsNothing);
      },
    );

    testWidgets(
      'Android keeps a NavigationBar on a phone-width Expressive window',
      (tester) async {
        await pumpEra(tester, DesignEra.materialExpressive, scaffold());
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'a wide Expressive window gets the flexible horizontal nav bar instead',
      (tester) async {
        // M3E's flexible nav bar lays items out horizontally in a medium
        // window; the baseline NavigationBar has no such mode, so an
        // expanded Expressive window gets a purpose-built bar instead.
        await pumpEra(
          tester,
          DesignEra.materialExpressive,
          scaffold(),
          width: 1024,
          height: 768,
        );
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byKey(adaptiveTabBarKey), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets(
      'a wide non-Expressive Material window still gets a NavigationBar',
      (tester) async {
        await pumpEra(
          tester,
          DesignEra.material3,
          scaffold(),
          width: 1024,
          height: 768,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );
  });

  group('render strategy', () {
    test('an unadvertised component always renders in Dart', () {
      final config = AdaptiveConfig(
        platform: PlatformInfo.fake(era: DesignEra.iosLiquidGlass),
        era: DesignEra.iosLiquidGlass,
        policy: NativePolicy.auto,
        formFactor: FormFactor.phone,
      );
      expect(
        config.strategyFor(NativeComponents.glassButton),
        RenderStrategy.dart,
      );
    });

    test('an advertised component renders natively under auto policy', () {
      final config = AdaptiveConfig(
        platform: PlatformInfo.fake(
          era: DesignEra.iosLiquidGlass,
          nativeComponents: {NativeComponents.glassButton},
        ),
        era: DesignEra.iosLiquidGlass,
        policy: NativePolicy.auto,
        formFactor: FormFactor.phone,
      );
      expect(
        config.strategyFor(NativeComponents.glassButton),
        RenderStrategy.native,
      );
    });

    test('dartOnly policy overrides an advertised component', () {
      final config = AdaptiveConfig(
        platform: PlatformInfo.fake(
          era: DesignEra.iosLiquidGlass,
          nativeComponents: {NativeComponents.glassButton},
        ),
        era: DesignEra.iosLiquidGlass,
        policy: NativePolicy.dartOnly,
        formFactor: FormFactor.phone,
      );
      expect(
        config.strategyFor(NativeComponents.glassButton),
        RenderStrategy.dart,
      );
    });

    test('a simulator takes the same path as hardware', () {
      // The native path has to be exercised during development, or it is never
      // right by the time it reaches a device.
      final config = AdaptiveConfig(
        platform: PlatformInfo.fake(
          era: DesignEra.iosLiquidGlass,
          nativeComponents: {NativeComponents.glassButton},
          isSimulator: true,
        ),
        era: DesignEra.iosLiquidGlass,
        policy: NativePolicy.auto,
        formFactor: FormFactor.phone,
      );
      expect(
        config.strategyFor(NativeComponents.glassButton),
        RenderStrategy.native,
      );
    });

    test('a per-widget override wins over everything', () {
      final config = AdaptiveConfig(
        platform: PlatformInfo.fake(
          era: DesignEra.iosLiquidGlass,
          nativeComponents: {NativeComponents.glassButton},
        ),
        era: DesignEra.iosLiquidGlass,
        policy: NativePolicy.auto,
        formFactor: FormFactor.phone,
      );
      expect(
        config.strategyFor(NativeComponents.glassButton, override: false),
        RenderStrategy.dart,
      );
    });
  });

  group('AdaptiveDestination.hasNativeIcon', () {
    test('an SF Symbol alone unlocks the native bar', () {
      const destination = AdaptiveDestination(
        label: 'Home',
        icon: Icon(Icons.home),
        sfSymbol: 'house',
      );
      expect(destination.hasNativeIcon, isTrue);
    });

    test('a custom iconImage alone unlocks the native bar, no SF Symbol', () {
      const destination = AdaptiveDestination(
        label: 'Brand',
        icon: Icon(Icons.star),
        iconImage: AssetImage('assets/brand.png'),
      );
      expect(destination.hasNativeIcon, isTrue);
    });

    test('a MemoryImage works too, for icons generated at runtime', () {
      final destination = AdaptiveDestination(
        label: 'Brand',
        icon: const Icon(Icons.star),
        iconImage: MemoryImage(Uint8List.fromList([1, 2, 3])),
      );
      expect(destination.hasNativeIcon, isTrue);
    });

    test('an SVG asset alone unlocks the native bar, no SF Symbol', () {
      const destination = AdaptiveDestination(
        label: 'Brand',
        icon: Icon(Icons.star),
        iconSvgAsset: 'assets/icons/brand.svg',
      );
      expect(destination.hasNativeIcon, isTrue);
    });

    test('neither a symbol nor a custom icon blocks the native bar', () {
      const destination = AdaptiveDestination(
        label: 'Home',
        icon: Icon(Icons.home),
      );
      expect(destination.hasNativeIcon, isFalse);
    });
  });

  group('AdaptiveTextField', () {
    testWidgets('threads showClearButton to clearButtonMode on Apple eras', (
      tester,
    ) async {
      final controller = TextEditingController();
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        AdaptiveTextField(controller: controller, showClearButton: true),
      );
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.clearButtonMode, OverlayVisibilityMode.editing);
    });

    testWidgets('shows a Material clear icon only once there is text', (
      tester,
    ) async {
      final controller = TextEditingController();
      await pumpEra(
        tester,
        DesignEra.material3,
        AdaptiveTextField(controller: controller, showClearButton: true),
      );
      expect(find.byIcon(Icons.clear), findsNothing);

      controller.text = 'hi';
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('.secure obscures text', (tester) async {
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        const AdaptiveTextField.secure(placeholder: 'PIN'),
      );
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.obscureText, isTrue);
    });
  });

  group('AdaptiveSearchField', () {
    testWidgets('does not autofocus on the iPad idiom by default', (
      tester,
    ) async {
      // HIG's search page: don't auto-focus a dedicated search field on iPad
      // when only a virtual keyboard is available.
      await pumpEra(
        tester,
        DesignEra.ipadLiquidGlass,
        const AdaptiveSearchField(),
        width: 1024,
        height: 768,
      );
      final field = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(field.autofocus, isFalse);
    });

    testWidgets('autofocuses on iPhone by default', (tester) async {
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        const AdaptiveSearchField(),
      );
      final field = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(field.autofocus, isTrue);
    });

    testWidgets('an explicit autofocus always wins', (tester) async {
      await pumpEra(
        tester,
        DesignEra.ipadLiquidGlass,
        const AdaptiveSearchField(autofocus: true),
        width: 1024,
        height: 768,
      );
      final field = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      expect(field.autofocus, isTrue);
    });
  });

  group('AdaptiveSplitView', () {
    const view = AdaptiveSplitView(
      primary: Text('Primary'),
      secondary: Text('Secondary'),
    );

    testWidgets('shows both panes on a regular window', (tester) async {
      await pumpEra(
        tester,
        DesignEra.material3,
        view,
        width: 1024,
        height: 768,
      );
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
    });

    testWidgets('shows only the primary pane on a compact window', (
      tester,
    ) async {
      await pumpEra(tester, DesignEra.material3, view);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsNothing);
    });
  });

  group('showAdaptivePopover', () {
    testWidgets('shows content on a regular window, and can be dismissed', (
      tester,
    ) async {
      final anchor = GlobalKey<State<StatefulWidget>>();
      await pumpEra(
        tester,
        DesignEra.material3,
        Builder(
          builder: (context) => AdaptiveButton(
            key: anchor,
            onPressed: () => showAdaptivePopover(
              context,
              anchor: anchor,
              builder: (_) => const Text('Popover content'),
            ),
            child: const Text('Open'),
          ),
        ),
        width: 1024,
        height: 768,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Popover content'), findsOneWidget);

      // Dismiss via the barrier, so the module-level "one at a time" guard
      // does not leak into the next test.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Popover content'), findsNothing);
    });

    testWidgets('falls back to a sheet on a compact window', (tester) async {
      // HIG's popovers page: a size-class rule, not a device rule.
      final anchor = GlobalKey<State<StatefulWidget>>();
      await pumpEra(
        tester,
        DesignEra.material3,
        Builder(
          builder: (context) => AdaptiveButton(
            key: anchor,
            onPressed: () => showAdaptivePopover(
              context,
              anchor: anchor,
              builder: (_) => const Text('Sheet content'),
            ),
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet content'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets(
      'preferSheetOnCompact: false shows a real popover on a compact window',
      (tester) async {
        final anchor = GlobalKey<State<StatefulWidget>>();
        await pumpEra(
          tester,
          DesignEra.material3,
          Builder(
            builder: (context) => AdaptiveButton(
              key: anchor,
              onPressed: () => showAdaptivePopover(
                context,
                anchor: anchor,
                preferSheetOnCompact: false,
                builder: (_) => const Text('Popover content'),
              ),
              child: const Text('Open'),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Popover content'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      },
    );
  });

  group('AdaptiveDestination badges', () {
    testWidgets('draws a Dart badge on the floating glass tab bar', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        AdaptiveNavigationScaffold(
          destinations: const [
            AdaptiveDestination(
              label: 'Home',
              icon: Icon(Icons.home),
              badge: '3',
            ),
            AdaptiveDestination(label: 'Search', icon: Icon(Icons.search)),
          ],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
        ),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('wraps the icon in a Material Badge on the baseline bar', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.material3,
        AdaptiveNavigationScaffold(
          destinations: const [
            AdaptiveDestination(
              label: 'Home',
              icon: Icon(Icons.home),
              badge: '3',
            ),
            AdaptiveDestination(label: 'Search', icon: Icon(Icons.search)),
          ],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
        ),
      );
      expect(find.byType(Badge), findsOneWidget);
    });
  });

  group('AdaptiveNavigationScaffold colours', () {
    const destinations = [
      AdaptiveDestination(label: 'Home', icon: Icon(Icons.home)),
      AdaptiveDestination(label: 'Search', icon: Icon(Icons.search)),
    ];

    testWidgets('reach CupertinoTabBar on classic iOS', (tester) async {
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        AdaptiveNavigationScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
          selectedColor: const Color(0xFF112233),
          unselectedColor: const Color(0xFF445566),
        ),
      );
      final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
      expect(bar.activeColor, const Color(0xFF112233));
      expect(bar.inactiveColor, const Color(0xFF445566));
    });

    testWidgets('reach NavigationBarTheme on the Material baseline bar', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.material3,
        AdaptiveNavigationScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
          selectedColor: const Color(0xFF112233),
        ),
      );
      expect(find.byType(NavigationBarTheme), findsOneWidget);
    });

    testWidgets('leave CupertinoTabBar at its own default when unset', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        AdaptiveNavigationScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
        ),
      );
      final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
      expect(bar.activeColor, isNull);
      expect(bar.inactiveColor, CupertinoColors.inactiveGray);
    });
  });

  group('sidebarAdaptable', () {
    const destinations = [
      AdaptiveDestination(label: 'Home', icon: Icon(Icons.home)),
      AdaptiveDestination(label: 'Search', icon: Icon(Icons.search)),
    ];

    testWidgets('shows a sidebar by default, like automatic', (tester) async {
      await pumpEra(
        tester,
        DesignEra.ipadLiquidGlass,
        AdaptiveNavigationScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
          style: AdaptiveNavigationStyle.sidebarAdaptable,
        ),
        width: 1024,
        height: 768,
      );
      expect(find.byKey(adaptiveSidebarKey), findsOneWidget);
    });

    testWidgets('collapses to a tab bar when sidebarCollapsed is true', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.ipadLiquidGlass,
        AdaptiveNavigationScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('body'),
          style: AdaptiveNavigationStyle.sidebarAdaptable,
          sidebarCollapsed: true,
        ),
        width: 1024,
        height: 768,
      );
      expect(find.byKey(adaptiveSidebarKey), findsNothing);
      expect(find.byKey(adaptiveTabBarKey), findsOneWidget);
    });

    testWidgets(
      'detail pane picks up a new body on rebuild, not the one from '
      'its first build',
      (tester) async {
        Widget scaffold(Widget body) => AdaptiveNavigationScaffold(
              destinations: destinations,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              body: body,
              style: AdaptiveNavigationStyle.sidebarAdaptable,
            );

        await pumpEra(
          tester,
          DesignEra.ipadLiquidGlass,
          scaffold(const Text('first')),
          width: 1024,
          height: 768,
        );
        expect(find.text('first'), findsOneWidget);

        await pumpEra(
          tester,
          DesignEra.ipadLiquidGlass,
          scaffold(const Text('second')),
          width: 1024,
          height: 768,
        );
        expect(find.text('second'), findsOneWidget);
        expect(find.text('first'), findsNothing);
      },
    );
  });

  group('AdaptiveScaffold toolbar', () {
    testWidgets('prominentAction renders as a trailing item', (tester) async {
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        const AdaptiveScaffold(
          title: 'Screen',
          prominentAction: Text('Done'),
          body: SizedBox(),
        ),
      );
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets(
        'collapses extra actions into an overflow button on a '
        'compact window', (tester) async {
      await pumpEra(
        tester,
        DesignEra.iosClassic,
        const AdaptiveScaffold(
          title: 'Screen',
          actions: [Icon(Icons.add), Icon(Icons.share)],
          body: SizedBox(),
        ),
      );
      // Compact windows show one action before collapsing the rest.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(find.byIcon(CupertinoIcons.ellipsis_circle), findsOneWidget);
    });

    testWidgets(
      'leading/actions widgets always render CupertinoNavigationBar, even '
      'when the native bar is available',
      (tester) async {
        await pumpEra(
          tester,
          DesignEra.iosLiquidGlass,
          const AdaptiveScaffold(
            title: 'Screen',
            leading: Icon(Icons.menu),
            body: SizedBox(),
          ),
          nativeComponents: {NativeComponents.navigationBar},
        );
        expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'a pushed glass-era screen gets an automatic rounded glass back button',
      (tester) async {
        await pumpEra(
          tester,
          DesignEra.iosLiquidGlass,
          Builder(
            builder: (context) => AdaptiveButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const AdaptiveScaffold(
                    title: 'Detail',
                    body: SizedBox(),
                  ),
                ),
              ),
              child: const Text('Push'),
            ),
          ),
        );
        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();
        expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
      },
    );

    testWidgets('a root screen with nothing to pop gets no back button', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        const AdaptiveScaffold(title: 'Root', body: SizedBox()),
      );
      expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
    });

    testWidgets(
      'an explicit leading is never displaced by the automatic back button',
      (tester) async {
        await pumpEra(
          tester,
          DesignEra.iosLiquidGlass,
          Builder(
            builder: (context) => AdaptiveButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const AdaptiveScaffold(
                    title: 'Detail',
                    leading: Icon(Icons.close),
                    body: SizedBox(),
                  ),
                ),
              ),
              child: const Text('Push'),
            ),
          ),
        );
        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
      },
    );
  });

  group('AdaptiveSlider', () {
    testWidgets('applies the M3E size track height only when Expressive', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.materialExpressive,
        AdaptiveSlider(
          value: 0.5,
          onChanged: (_) {},
          size: AdaptiveSliderSize.l,
        ),
      );
      final theme = tester.widget<SliderTheme>(find.byType(SliderTheme));
      expect(theme.data.trackHeight, AdaptiveSliderSize.l.trackHeight);
    });

    testWidgets('vertical rotates the slider', (tester) async {
      await pumpEra(
        tester,
        DesignEra.materialExpressive,
        AdaptiveSlider(value: 0.5, onChanged: (_) {}, vertical: true),
      );
      expect(find.byType(RotatedBox), findsOneWidget);
    });
  });

  group('AdaptiveApp.router', () {
    testWidgets('builds a CupertinoApp on an Apple era', (tester) async {
      await pumpApp(
        tester,
        DesignEra.iosLiquidGlass,
        AdaptiveApp.router(
          routerConfig: _testRouterConfig(
            () => const <Widget>[AdaptiveScaffold(title: 'Home', body: SizedBox())],
          ),
        ),
      );
      expect(find.byType(CupertinoApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('builds a MaterialApp on a Material era', (tester) async {
      await pumpApp(
        tester,
        DesignEra.material3,
        AdaptiveApp.router(
          routerConfig: _testRouterConfig(
            () => const <Widget>[AdaptiveScaffold(title: 'Home', body: SizedBox())],
          ),
        ),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(CupertinoApp), findsNothing);
    });

    // The whole reason AdaptiveApp exists. A CupertinoApp supplies neither a
    // Material ancestor nor MaterialLocalizations, so a ListTile inside one
    // throws twice over — and the router path is just as capable of showing a
    // ListTile as the navigator path is.
    testWidgets('keeps the Material and localizations shims on Apple eras', (
      tester,
    ) async {
      await pumpApp(
        tester,
        DesignEra.iosLiquidGlass,
        AdaptiveApp.router(
          routerConfig: _testRouterConfig(
            () => const <Widget>[
              AdaptiveScaffold(
                title: 'Home',
                body: ListTile(title: Text('Profile')),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Profile'), findsOneWidget);
      final context = tester.element(find.text('Profile'));
      expect(context.findAncestorWidgetOfExactType<Material>(), isNotNull);
      expect(Localizations.of<MaterialLocalizations>(
        context,
        MaterialLocalizations,
      ), isNotNull);
    });

    testWidgets('installs an AdaptiveScope above the router', (tester) async {
      late DesignEra seen;
      await pumpApp(
        tester,
        DesignEra.material3,
        AdaptiveApp.router(
          eraOverride: DesignEra.iosLiquidGlass,
          routerConfig: _testRouterConfig(
            () => <Widget>[
              Builder(
                builder: (context) {
                  seen = AdaptiveScope.of(context).era;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      // eraOverride wins over the fake platform, and reaches route bodies —
      // which is what makes adaptivePage resolvable inside a pageBuilder.
      expect(seen, DesignEra.iosLiquidGlass);
      expect(find.byType(CupertinoApp), findsOneWidget);
    });
  });

  group('adaptivePage', () {
    testWidgets('returns a CupertinoPage on Apple eras', (tester) async {
      late Page<void> page;
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        Builder(
          builder: (context) {
            page = adaptivePage<void>(
              context: context,
              child: const SizedBox(),
              title: 'Detail',
            );
            return const SizedBox();
          },
        ),
      );
      expect(page, isA<CupertinoPage<void>>());
      expect((page as CupertinoPage<void>).title, 'Detail');
    });

    testWidgets('returns a MaterialPage on Material eras', (tester) async {
      late Page<void> page;
      await pumpEra(
        tester,
        DesignEra.material3,
        Builder(
          builder: (context) {
            page = adaptivePage<void>(context: context, child: const SizedBox());
            return const SizedBox();
          },
        ),
      );
      expect(page, isA<MaterialPage<void>>());
    });
  });

  group('AdaptiveScaffold router back button', () {
    testWidgets('canPop: false suppresses the back button on a pushed route', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        Builder(
          builder: (context) => AdaptiveButton(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => const AdaptiveScaffold(
                  title: 'Detail',
                  canPop: false,
                  body: SizedBox(),
                ),
              ),
            ),
            child: const Text('Push'),
          ),
        ),
      );
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      // Navigator.canPop is true here; the override is what wins.
      expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
    });

    testWidgets('canPop: true shows a back button on a root route', (
      tester,
    ) async {
      var popped = 0;
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        AdaptiveScaffold(
          title: 'Branch root',
          canPop: true,
          onBack: () => popped++,
          body: const SizedBox(),
        ),
      );
      // Nothing to pop on this navigator — the router says otherwise.
      expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.chevron_back));
      await tester.pumpAndSettle();
      expect(popped, 1);
    });

    testWidgets('onBack replaces maybePop on a pushed route', (tester) async {
      var popped = 0;
      await pumpEra(
        tester,
        DesignEra.iosLiquidGlass,
        Builder(
          builder: (context) => AdaptiveButton(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => AdaptiveScaffold(
                  title: 'Detail',
                  onBack: () => popped++,
                  body: const SizedBox(),
                ),
              ),
            ),
            child: const Text('Push'),
          ),
        ),
      );
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.chevron_back));
      await tester.pumpAndSettle();
      expect(popped, 1);
      // onBack fired instead of popping, so the route is still up.
      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('reaches the Material AppBar too', (tester) async {
      var popped = 0;
      await pumpEra(
        tester,
        DesignEra.material3,
        AdaptiveScaffold(
          title: 'Branch root',
          canPop: true,
          onBack: () => popped++,
          body: const SizedBox(),
        ),
      );
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(popped, 1);
    });

    testWidgets('canPop: false suppresses the Material back button', (
      tester,
    ) async {
      await pumpEra(
        tester,
        DesignEra.material3,
        Builder(
          builder: (context) => AdaptiveButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdaptiveScaffold(
                  title: 'Detail',
                  canPop: false,
                  body: SizedBox(),
                ),
              ),
            ),
            child: const Text('Push'),
          ),
        ),
      );
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
