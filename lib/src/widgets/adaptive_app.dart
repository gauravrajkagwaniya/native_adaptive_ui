import '../core/adaptive_config.dart';
import '../core/design_era.dart';
import '../core/render_strategy.dart';
import '../design_systems/design_imports.dart';

/// The application root: a `CupertinoApp` on Apple eras, a `MaterialApp`
/// elsewhere, with an [AdaptiveScope] installed above the navigator.
///
/// One detail here is worth knowing about, because it is the crash every
/// adaptive Flutter app eventually hits: Material widgets require a `Material`
/// ancestor, and a `CupertinoApp` does not provide one. Drop a `ListTile` or a
/// `Tooltip` into an iOS build and it throws *"No Material widget found"*.
/// [AdaptiveApp] inserts a transparent `Material` above the navigator on Apple
/// eras, so mixing the two systems is safe without changing how anything looks.
///
/// For go_router — or any other Router 2.0 package — use [AdaptiveApp.router].
class AdaptiveApp extends StatelessWidget {
  const AdaptiveApp({
    super.key,
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.navigatorKey,
    this.title = '',
    this.materialTheme,
    this.materialDarkTheme,
    this.cupertinoTheme,
    this.themeMode = ThemeMode.system,
    this.debugShowCheckedModeBanner = true,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.eraOverride,
    this.policy,
    this.builder,
  })  : routerConfig = null,
        routerDelegate = null,
        routeInformationParser = null,
        routeInformationProvider = null,
        backButtonDispatcher = null,
        _useRouter = false;

  /// The Router 2.0 counterpart, for go_router and friends.
  ///
  /// This package does not depend on go_router, and does not need to:
  /// `GoRouter implements RouterConfig<RouteMatchList>`, so a router drops
  /// straight into [routerConfig] — as does a Beamer or auto_route delegate,
  /// or a hand-rolled [RouterDelegate].
  ///
  /// ```dart
  /// AdaptiveApp.router(
  ///   routerConfig: GoRouter(routes: [...]),
  /// )
  /// ```
  ///
  /// Everything the default constructor does still applies — the era-based
  /// Cupertino/Material split, the transparent `Material`, and the
  /// `MaterialLocalizations` delegate — because `WidgetsApp` applies its
  /// `builder` around the `Router`, which leaves the [AdaptiveScope] above the
  /// router's navigator. Route bodies and `pageBuilder` callbacks alike resolve
  /// it, so `adaptivePage` works inside a `GoRoute`.
  ///
  /// The era itself is resolved once, in [build], from `NativeAdaptiveUi.era`.
  /// Changing [eraOverride] therefore rebuilds the app and swaps `CupertinoApp`
  /// for `MaterialApp`, but never rebuilds the router config or disturbs the
  /// current location.
  const AdaptiveApp.router({
    super.key,
    this.routerConfig,
    this.routerDelegate,
    this.routeInformationParser,
    this.routeInformationProvider,
    this.backButtonDispatcher,
    this.title = '',
    this.materialTheme,
    this.materialDarkTheme,
    this.cupertinoTheme,
    this.themeMode = ThemeMode.system,
    this.debugShowCheckedModeBanner = true,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.eraOverride,
    this.policy,
    this.builder,
  })  : assert(
          routerDelegate != null || routerConfig != null,
          'Either routerDelegate or routerConfig must be provided.',
        ),
        home = null,
        routes = const <String, WidgetBuilder>{},
        initialRoute = null,
        onGenerateRoute = null,
        // The router owns the navigator, so there is no key to hand it, and
        // MaterialApp.router takes no navigatorKey either. Reach the navigator
        // through the router instead — GoRouter takes its own navigatorKey.
        navigatorKey = null,
        _useRouter = true;

  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final String title;

  /// The whole routing configuration in one object. A `GoRouter` goes here.
  final RouterConfig<Object>? routerConfig;

  /// Used instead of [routerConfig] when the pieces are supplied separately.
  final RouterDelegate<Object>? routerDelegate;
  final RouteInformationParser<Object>? routeInformationParser;
  final RouteInformationProvider? routeInformationProvider;
  final BackButtonDispatcher? backButtonDispatcher;

  final ThemeData? materialTheme;
  final ThemeData? materialDarkTheme;
  final CupertinoThemeData? cupertinoTheme;
  final ThemeMode themeMode;

  final bool debugShowCheckedModeBanner;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<Object?>>? localizationsDelegates;
  final Iterable<Locale> supportedLocales;

  /// Pins the whole app to one era. Intended for screenshots and design review.
  final DesignEra? eraOverride;

  /// Native-rendering policy for the whole app.
  final NativePolicy? policy;

  /// Wraps every route, after the adaptive scope is installed.
  final TransitionBuilder? builder;

  /// Set by [AdaptiveApp.router]. Selects the `.router` flavour of whichever
  /// app widget the era picks.
  final bool _useRouter;

  @override
  Widget build(BuildContext context) {
    final era = eraOverride ?? NativeAdaptiveUi.era;

    Widget wrap(BuildContext innerContext, Widget? child) {
      Widget content = child ?? const SizedBox.shrink();

      // Neither CupertinoApp nor MaterialApp dismisses the keyboard on an
      // outside tap by default — a genuinely common surprise, not specific to
      // this package. `translucent` lets the tap still reach whatever
      // widget is under it (a button, a list row) instead of swallowing it;
      // unfocusing first and then letting the tap continue is how iOS and
      // Android both actually behave.
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: content,
      );

      if (era.isApple) {
        // See the class doc: keeps Material-based widgets usable inside a
        // Cupertino app without tinting or shadowing anything.
        //
        // `textStyle` is not optional here. Material wraps its child in
        // `AnimatedDefaultTextStyle(style: widget.textStyle ??
        // Theme.of(context).textTheme.bodyMedium!)`, so leaving it null hands
        // every unstyled string in the app Material's Roboto instead of San
        // Francisco. Nothing else about the screen has to be wrong for that
        // alone to make an iOS build look like an Android one.
        content = Material(
          type: MaterialType.transparency,
          textStyle: CupertinoTheme.of(innerContext).textTheme.textStyle,
          child: content,
        );
      }
      content = AdaptiveScope(era: eraOverride, policy: policy, child: content);
      return builder?.call(innerContext, content) ?? content;
    }

    if (era.isApple) {
      // Material widgets used as fallbacks inside a Cupertino app assert on
      // MaterialLocalizations, which CupertinoApp does not install: the iPad
      // popover menu, Tooltip and ListTile all throw without it. Same class of
      // problem as the missing Material ancestor above, and it belongs in the
      // same place — on the router path too, which is just as capable of
      // showing a ListTile.
      final appleDelegates = <LocalizationsDelegate<dynamic>>[
        ...?localizationsDelegates,
        DefaultMaterialLocalizations.delegate,
      ];

      if (_useRouter) {
        return CupertinoApp.router(
          routerConfig: routerConfig,
          routerDelegate: routerDelegate,
          routeInformationParser: routeInformationParser,
          routeInformationProvider: routeInformationProvider,
          backButtonDispatcher: backButtonDispatcher,
          title: title,
          theme: cupertinoTheme,
          debugShowCheckedModeBanner: debugShowCheckedModeBanner,
          locale: locale,
          localizationsDelegates: appleDelegates,
          supportedLocales: supportedLocales,
          builder: wrap,
        );
      }

      return CupertinoApp(
        navigatorKey: navigatorKey,
        title: title,
        home: home,
        routes: routes,
        initialRoute: initialRoute,
        onGenerateRoute: onGenerateRoute,
        theme: cupertinoTheme,
        debugShowCheckedModeBanner: debugShowCheckedModeBanner,
        locale: locale,
        localizationsDelegates: appleDelegates,
        supportedLocales: supportedLocales,
        builder: wrap,
      );
    }

    if (_useRouter) {
      return MaterialApp.router(
        routerConfig: routerConfig,
        routerDelegate: routerDelegate,
        routeInformationParser: routeInformationParser,
        routeInformationProvider: routeInformationProvider,
        backButtonDispatcher: backButtonDispatcher,
        title: title,
        theme: materialTheme,
        darkTheme: materialDarkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: debugShowCheckedModeBanner,
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        builder: wrap,
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: title,
      home: home,
      routes: routes,
      initialRoute: initialRoute,
      onGenerateRoute: onGenerateRoute,
      theme: materialTheme,
      darkTheme: materialDarkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      builder: wrap,
    );
  }
}
