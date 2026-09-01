import '../core/adaptive_config.dart';
import '../design_systems/design_imports.dart';

/// Builds a page route whose transition matches the host platform.
///
/// Apple eras get `CupertinoPageRoute` — including the interactive edge-swipe
/// back gesture — and Material eras get `MaterialPageRoute`. Using this instead
/// of `MaterialPageRoute` everywhere is what stops an iOS build from feeling
/// subtly wrong during navigation, which users notice long before they notice a
/// button's corner radius.
///
/// This is a factory rather than a `PageRoute` subclass on purpose: page routes
/// own transition state that is bound to the navigator that installed them, so
/// a wrapper that forwards to an uninstalled delegate route breaks the back
/// gesture in ways that only show up on a device.
PageRoute<T> adaptivePageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  RouteSettings? settings,
  String? title,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  final era = AdaptiveScope.of(context).era;
  if (era.isApple) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
      title: title,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
  );
}

/// The declarative counterpart to [adaptivePageRoute], for Router 2.0.
///
/// `GoRoute.pageBuilder` — and every other `Page`-based API — wants a [Page],
/// not a [Route], so [adaptivePageRoute] cannot be used there. This returns the
/// same platform split one level up: a `CupertinoPage` on Apple eras, including
/// the interactive edge-swipe back gesture, and a `MaterialPage` elsewhere.
///
/// ```dart
/// GoRoute(
///   path: 'detail',
///   pageBuilder: (context, state) => adaptivePage(
///     context: context,
///     child: const DetailScreen(),
///   ),
/// )
/// ```
///
/// The `context` handed to a `pageBuilder` sits below [AdaptiveApp.router]'s
/// scope — `WidgetsApp` wraps the `Router` in its `builder` — so the era
/// resolves here exactly as it does inside a route body.
///
/// [title] is Cupertino-only: it supplies the text that the *next* screen's
/// back button shows, and `MaterialPage` has no equivalent.
Page<T> adaptivePage<T>({
  required BuildContext context,
  required Widget child,
  LocalKey? key,
  String? name,
  Object? arguments,
  String? restorationId,
  String? title,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  final era = AdaptiveScope.of(context).era;
  if (era.isApple) {
    return CupertinoPage<T>(
      child: child,
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      title: title,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }
  return MaterialPage<T>(
    child: child,
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
  );
}

/// Pushes [page] with the platform's own transition.
///
/// ```dart
/// final saved = await pushAdaptive<bool>(context, (_) => const EditScreen());
/// ```
Future<T?> pushAdaptive<T>(
  BuildContext context,
  WidgetBuilder page, {
  String? title,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context).push<T>(
    adaptivePageRoute<T>(
      context: context,
      builder: page,
      settings: settings,
      title: title,
      fullscreenDialog: fullscreenDialog,
    ),
  );
}
