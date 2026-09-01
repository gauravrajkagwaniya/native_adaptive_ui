import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../core/native_bridge.dart';
import '../core/native_component_view.dart';
import '../design_systems/design_imports.dart';
import '../effects/liquid_glass.dart';
import '../tokens/adaptive_tokens.dart';
import 'adaptive_base.dart';
import 'adaptive_dialog.dart';

/// A single screen with a title bar, in the host platform's idiom.
///
/// On Apple eras the navigation bar keeps Cupertino's own translucency, so
/// content scrolls beneath it the way iOS expects. That translucency is also
/// what makes `CupertinoPageScaffold` report the bar's height through
/// `MediaQuery.padding` — which is how a scrollable body knows where to start.
///
/// A body that passes its own `padding` to a `ListView` overrides that
/// automatic inset and its first rows end up hidden behind the bar. Use
/// [AdaptiveContext.adaptiveScrollPadding] from a context *inside* the scaffold
/// when you need custom padding:
///
/// ```dart
/// AdaptiveScaffold(
///   title: 'Settings',
///   body: Builder(
///     builder: (context) => ListView(
///       padding: context.adaptiveScrollPadding(horizontal: 16, vertical: 12),
///       children: rows,
///     ),
///   ),
/// )
/// ```
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.centerActions = const <Widget>[],
    this.prominentAction,
    this.floatingAction,
    this.bottomBar,
    this.backgroundColor,
    this.grouped = false,
    this.scrollEdgeEffect = false,
    this.leadingSfSymbol,
    this.actionSfSymbols,
    this.onLeadingPressed,
    this.onActionPressed,
    this.canPop,
    this.onBack,
  });

  final Widget body;
  final String? title;
  final Widget? leading;
  final List<Widget> actions;

  /// Opts into a real `UINavigationBar` instead of `CupertinoNavigationBar`,
  /// the same way `AdaptiveDestination.sfSymbol` opts a tab into the real
  /// `UITabBar`: a `UIBarButtonItem` needs a `UIImage`, and [leading] cannot
  /// cross that boundary, so the native bar is used only when this — not
  /// [leading] — supplies the leading item. Set either this or [leading], not
  /// both; [leading] takes precedence if both are set.
  final String? leadingSfSymbol;

  /// The trailing bar buttons for the native bar, as SF Symbol names — the
  /// native counterpart to [actions]. Set either this or [actions]/
  /// [centerActions]/[prominentAction], not both; any of those widget-based
  /// params being non-empty falls back to `CupertinoNavigationBar`.
  final List<String>? actionSfSymbols;

  /// Fires when the native bar's leading button (from [leadingSfSymbol]) is
  /// tapped. Unused otherwise.
  final VoidCallback? onLeadingPressed;

  /// Fires with the tapped button's index into [actionSfSymbols]. Unused
  /// otherwise.
  final ValueChanged<int>? onActionPressed;

  /// Whether a back affordance is shown. Defaults to `Navigator.canPop`.
  ///
  /// That default is right whenever the enclosing `Navigator` is the whole
  /// story, and wrong as soon as a router splits navigation across more than
  /// one — a go_router screen pushed on the *root* navigator from inside a
  /// shell can pop, but `Navigator.canPop` asked from the shell says it cannot,
  /// and a branch root that `context.pop()` would return to another branch
  /// reports the reverse. Pass the router's own answer here in that case:
  ///
  /// ```dart
  /// AdaptiveScaffold(
  ///   title: 'Detail',
  ///   canPop: context.canPop(),
  ///   onBack: context.pop,
  ///   body: ...,
  /// )
  /// ```
  final bool? canPop;

  /// What the back affordance does. Defaults to
  /// `Navigator.of(context).maybePop()`. See [canPop].
  final VoidCallback? onBack;

  /// The toolbar's center region. HIG: "customisable on macOS/iPadOS,
  /// collapses into a system overflow menu" — folded into the trailing group
  /// on iPhone, where the center region has no separate customisation.
  final List<Widget> centerActions;

  /// The one primary action HIG allows per bar: "Keep... to one or two
  /// prominent buttons per view" and "`.prominent` style, on the trailing
  /// side." Always laid out as the rightmost trailing item, styled distinctly
  /// from [actions].
  final Widget? prominentAction;

  /// Material's floating action button. On Apple eras there is no FAB idiom, so
  /// this is promoted into the navigation bar's trailing slot instead of being
  /// dropped or floated where iOS never floats anything.
  final Widget? floatingAction;

  final Widget? bottomBar;
  final Color? backgroundColor;

  /// Uses the platform's grouped-content background instead of the plain one.
  ///
  /// Set this on any screen built from [AdaptiveListSection]. On iOS a grouped
  /// list is a stack of white cards floating on a grey field; without the grey
  /// the cards sit on white and the grouping stops reading, which is the single
  /// most common way a Settings-style screen comes out looking wrong.
  final bool grouped;

  /// Fades a soft scrim in behind the bar as content scrolls under it, instead
  /// of painting the bar an opaque background.
  ///
  /// HIG's toolbars page: "Reduce the use of toolbar backgrounds... Use the
  /// content layer's colour and a `ScrollEdgeEffectStyle` instead." This is a
  /// Dart approximation of that effect — a gradient scrim, not the system's
  /// own edge treatment — for the same reason [GlassSurface] is a look and not
  /// the material.
  final bool scrollEdgeEffect;

  bool get _hasBar =>
      title != null ||
      actions.isNotEmpty ||
      leading != null ||
      centerActions.isNotEmpty ||
      prominentAction != null ||
      leadingSfSymbol != null ||
      (actionSfSymbols?.isNotEmpty ?? false);

  /// Whether every trailing/leading param is symbol-based rather than a
  /// widget, which is what the native bar requires — see [leadingSfSymbol].
  bool get _wantsNativeBar =>
      leading == null &&
      actions.isEmpty &&
      centerActions.isEmpty &&
      prominentAction == null;

  @override
  Widget build(BuildContext context) {
    final era = context.era;
    final tokens = context.adaptiveTokens;

    if (title != null && title!.length > 15) _warnTitleLength(title!);

    final surface = backgroundColor ??
        (grouped && era.isApple
            ? CupertinoColors.systemGroupedBackground
            : (tokens.hasGlass && era.isApple && !grouped
                ? const Color(0xFFF7F7FA)
                : null));

    Widget effectiveBody = body;
    if (scrollEdgeEffect) {
      effectiveBody = _ScrollEdgeEffect(
        tokens: tokens,
        showBottom: bottomBar != null,
        child: effectiveBody,
      );
    }

    if (era.isApple) {
      Widget content = effectiveBody;
      if (bottomBar != null) {
        if (tokens.hasGlass) {
          // On glass eras the body must extend underneath the bar so that
          // GlassSurface's BackdropFilter has content to blur. A Column would
          // end the body where the bar begins, leaving the glass with nothing
          // behind it — the same reason _GlassTabScaffold uses a Stack.
          content = Stack(
            children: [
              Positioned.fill(child: content),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: GlassSurface(
                    tokens: tokens,
                    interactive: true,
                    child: bottomBar!,
                  ),
                ),
              ),
            ],
          );
        } else {
          content = Column(
            children: [
              Expanded(child: content),
              SafeArea(top: false, child: bottomBar!),
            ],
          );
        }
      }

      final nativeBar = _hasBar &&
          _wantsNativeBar &&
          tokens.hasGlass &&
          context.adaptive.strategyFor(NativeComponents.navigationBar).isNative;

      // CupertinoNavigationBar auto-generates its own back chevron from
      // Navigator.canPop when leading is null — standard Flutter behaviour
      // that needs nothing extra here. The native bar has no such thing to
      // fall back on: it is a bare UINavigationBar with no UINavigationController
      // above it, so nothing supplies a back button unless this does.
      final effectiveCanPop = canPop ?? Navigator.canPop(context);
      final autoBack =
          leadingSfSymbol == null && leading == null && effectiveCanPop;
      final effectiveLeadingSfSymbol =
          leadingSfSymbol ?? (autoBack ? 'chevron.backward' : null);
      final effectiveOnLeadingPressed = leadingSfSymbol != null
          ? onLeadingPressed
          : (autoBack
              ? (onBack ?? () => Navigator.of(context).maybePop())
              : onLeadingPressed);

      return CupertinoPageScaffold(
        backgroundColor: surface,
        navigationBar: !_hasBar
            ? null
            : nativeBar
                ? _NativeNavigationBar(
                    title: title,
                    leadingSfSymbol: effectiveLeadingSfSymbol,
                    actionSfSymbols: actionSfSymbols,
                    onLeadingPressed: effectiveOnLeadingPressed,
                    onActionPressed: onActionPressed,
                  )
                : CupertinoNavigationBar(
                    middle: title == null ? null : Text(title!),
                    // CupertinoNavigationBar auto-generates a plain
                    // chevron+"Back" leading from Navigator.canPop when
                    // `leading` is null — the correct look for
                    // iosClassic/macosClassic, and the reason this is only
                    // overridden below. Gating it on [effectiveCanPop] is what
                    // lets `canPop: false` suppress a chevron the enclosing
                    // navigator would otherwise imply.
                    automaticallyImplyLeading: effectiveCanPop,
                    leading: _appleLeading(context, tokens, effectiveCanPop),
                    trailing: _appleTrailing(context, tokens),
                  ),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: surface,
      appBar: _hasBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              // When canPop/onBack are supplied (e.g. by a router), override the
              // default ModalRoute/Navigator heuristics and render a back
              // affordance explicitly.
              automaticallyImplyLeading: canPop == null && onBack == null,
              leading: leading ??
                  ((canPop != null || onBack != null) &&
                          (canPop ?? Navigator.canPop(context))
                      ? BackButton(
                          onPressed:
                              onBack ?? () => Navigator.of(context).maybePop(),
                        )
                      : null),
              actions: [
                ...centerActions,
                ...actions,
                if (prominentAction != null) prominentAction!,
              ],
            )
          : null,
      body: effectiveBody,
      floatingActionButton: floatingAction,
      bottomNavigationBar: bottomBar,
    );
  }

  static final Set<String> _warnedTitles = <String>{};

  /// Debug-only, once per unique title. HIG frames the 15-character figure as
  /// guidance ("Titles... under 15 characters"), not the hard cap that alerts
  /// (3 buttons) and segmented controls (5 segments) already assert on.
  void _warnTitleLength(String title) {
    if (!kDebugMode || !_warnedTitles.add(title)) return;
    debugPrint(
      '[native_adaptive_ui] AdaptiveScaffold title "$title" is longer than '
      "HIG's guidance of under 15 characters for a toolbar title.",
    );
  }

  /// The leading widget for `CupertinoNavigationBar`.
  ///
  /// Returning null hands the decision back to the bar's own
  /// `automaticallyImplyLeading`, which is the right answer on a classic Apple
  /// era with no overrides. Two cases have to be built by hand instead: a glass
  /// era, whose default chevron+"Back" predates Liquid Glass, and a caller who
  /// supplied [canPop]/[onBack] — the bar would consult the enclosing navigator
  /// rather than the router, and pop the wrong thing.
  Widget? _appleLeading(
    BuildContext context,
    AdaptiveTokens tokens,
    bool effectiveCanPop,
  ) {
    if (leading != null) return leading;
    if (leadingSfSymbol != null || !effectiveCanPop) return null;
    if (tokens.hasGlass) {
      return _GlassBackButton(tokens: tokens, onPressed: onBack);
    }
    if (canPop != null || onBack != null) {
      return CupertinoNavigationBarBackButton(onPressed: onBack);
    }
    return null;
  }

  /// Cupertino navigation bars take exactly one trailing widget, so
  /// [centerActions], [actions] and [prominentAction] are laid out in a row —
  /// folding [centerActions] in here too, since iPhone's HIG gives the center
  /// region no separate customisation from the trailing one.
  ///
  /// On compact Apple windows, extra [actions] beyond the first collapse into
  /// a system-style overflow button rather than being crammed into the bar —
  /// an approximation of "The system automatically adds an overflow menu...
  /// when items no longer fit," without measuring actual pixel widths.
  Widget? _appleTrailing(BuildContext context, AdaptiveTokens tokens) {
    final compact = context.adaptive.formFactor.isCompact;
    final visibleCount = compact ? 1 : 3;

    final visible = actions.length > visibleCount
        ? actions.sublist(0, visibleCount)
        : actions;
    final overflowed = actions.length > visibleCount
        ? actions.sublist(visibleCount)
        : const <Widget>[];

    final items = <Widget>[
      if (centerActions.isNotEmpty)
        _CenterActionsGroup(actions: centerActions, tokens: tokens),
      ...visible,
      if (overflowed.isNotEmpty)
        _OverflowButton(actions: overflowed, tokens: tokens),
      if (floatingAction != null) floatingAction!,
      if (prominentAction != null) prominentAction!,
    ];
    if (items.isEmpty) return null;
    if (items.length == 1) return items.first;
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

/// [AdaptiveScaffold.centerActions], grouped in a pill on glass eras.
///
/// The pill's own corner radius is derived from the bar's — HIG's toolbars
/// page: corner radii of bar-embedded components "are concentric with the
/// bar's corners" — using [AdaptiveTokens.concentricRadius] rather than the
/// widget's own flat [AdaptiveTokens.radius], which every other bar-embedded
/// element in this package still uses.
class _CenterActionsGroup extends StatelessWidget {
  const _CenterActionsGroup({required this.actions, required this.tokens});

  final List<Widget> actions;
  final AdaptiveTokens tokens;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
    if (!tokens.hasGlass) return row;

    final inset = tokens.spacing * 0.5;
    final radius = tokens.concentricRadius(tokens.cornerRadius, inset);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: row,
      ),
    );
  }
}

/// The "more" button a collapsed trailing region opens, since HIG says the
/// system — not the app — owns overflow presentation. There is no way to
/// recover the caller's own labels for arbitrary action widgets, so this
/// exposes their indices as a generic numbered menu rather than pretending to
/// read a `Widget` for text.
class _OverflowButton extends StatelessWidget {
  const _OverflowButton({required this.actions, required this.tokens});

  final List<Widget> actions;
  final AdaptiveTokens tokens;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(tokens.minTapTarget, tokens.minTapTarget),
      onPressed: () => showAdaptiveActionSheet(
        context,
        title: 'More',
        actions: [
          for (final (index, _) in actions.indexed)
            AdaptiveAction(
              label: 'Item ${index + 1}',
              onPressed: () {},
            ),
        ],
      ),
      child: const Icon(CupertinoIcons.ellipsis_circle),
    );
  }
}

/// The Dart-rendered counterpart to the native bar's automatic back button.
///
/// `UIBarButtonItem`s with just an image already render as a circular glass
/// button on iOS 26 — free system behaviour, nothing this package draws. This
/// is that same look built by hand, for the one path with no real
/// `UIBarButtonItem` to lean on: `CupertinoNavigationBar`'s own default
/// leading is a plain chevron-and-label predating Liquid Glass entirely.
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.tokens, this.onPressed});

  final AdaptiveTokens tokens;

  /// Defaults to `maybePop` on the enclosing navigator. See
  /// [AdaptiveScaffold.onBack].
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const size = 32.0;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        width: size,
        height: size,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(size, size),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          child: GlassSurface(
            tokens: tokens,
            interactive: true,
            borderRadius: BorderRadius.circular(size / 2),
            child: const SizedBox(
              width: size,
              height: size,
              child: Icon(CupertinoIcons.chevron_back, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Dart approximation of `ScrollEdgeEffectStyle`: a gradient scrim that
/// fades in behind the bar region as [child] scrolls underneath it, instead
/// of a painted bar background.
class _ScrollEdgeEffect extends StatefulWidget {
  const _ScrollEdgeEffect({
    required this.child,
    required this.tokens,
    required this.showBottom,
  });

  final Widget child;
  final AdaptiveTokens tokens;
  final bool showBottom;

  @override
  State<_ScrollEdgeEffect> createState() => _ScrollEdgeEffectState();
}

class _ScrollEdgeEffectState extends State<_ScrollEdgeEffect> {
  double _topOpacity = 0;
  double _bottomOpacity = 0;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    final fromTop =
        ((metrics.pixels - metrics.minScrollExtent) / 24).clamp(0.0, 1.0);
    final fromBottom =
        ((metrics.maxScrollExtent - metrics.pixels) / 24).clamp(0.0, 1.0);
    final nextTop = fromTop;
    final nextBottom =
        widget.showBottom ? (1 - fromBottom).clamp(0.0, 1.0) : 0.0;
    if (nextTop != _topOpacity || nextBottom != _bottomOpacity) {
      setState(() {
        _topOpacity = nextTop;
        _bottomOpacity = nextBottom;
      });
    }
    return false;
  }

  Color _scrimBase(BuildContext context) {
    final isDark =
        (MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light) ==
            Brightness.dark;
    return isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final base = _scrimBase(context);
    final topHeight = media.padding.top + widget.tokens.controlHeight;
    final bottomHeight = media.padding.bottom + widget.tokens.controlHeight;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topHeight,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _topOpacity,
                duration: const Duration(milliseconds: 150),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        base.withValues(alpha: 0.55),
                        base.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showBottom)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomHeight,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _bottomOpacity,
                  duration: const Duration(milliseconds: 150),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          base.withValues(alpha: 0.55),
                          base.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A real `UINavigationBar`, embedded as a platform view — the counterpart to
/// `_NativeTabBar` in `adaptive_navigation.dart`. See
/// [AdaptiveScaffold.leadingSfSymbol] for when this is used instead of
/// `CupertinoNavigationBar`.
class _NativeNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const _NativeNavigationBar({
    required this.title,
    required this.leadingSfSymbol,
    required this.actionSfSymbols,
    required this.onLeadingPressed,
    required this.onActionPressed,
  });

  final String? title;
  final String? leadingSfSymbol;
  final List<String>? actionSfSymbols;
  final VoidCallback? onLeadingPressed;
  final ValueChanged<int>? onActionPressed;

  static const double _kBarHeight = 44;

  // Matches CupertinoNavigationBar's own convention (nav_bar.dart's
  // `preferredSize`): the *static* getter excludes the safe-area top inset,
  // because a plain `Size get` has no BuildContext to read MediaQuery from.
  // CupertinoPageScaffold adds `MediaQuery.of(context).padding.top` back in
  // itself when it computes the body's own top inset (page_scaffold.dart's
  // `topPadding = navigationBar.preferredSize.height + padding.top`) — so the
  // two only agree if this widget's *rendered* height also independently
  // includes that inset, which is what `build` does below.
  @override
  Size get preferredSize => const Size.fromHeight(_kBarHeight);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    // CupertinoPageScaffold positions the navigation bar with
    // `Positioned(top: 0, ...)` and no explicit height, so it renders however
    // tall its own build() makes it — exactly like the real UINavigationBar
    // this replaces would, sitting under the status bar/Dynamic Island rather
    // than starting content beneath it. Without this padding the platform
    // view's title and buttons render pinned to the very top of the screen.
    final topPadding = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: SizedBox(
        height: _kBarHeight,
        child: NativeComponentView(
          viewType: 'dev.gauravraj/${NativeComponents.navigationBar}',
          creationParams: <String, Object?>{
            'title': title ?? '',
            'leadingSfSymbol': leadingSfSymbol,
            'actionSfSymbols': actionSfSymbols,
          },
          fallbackSize: const Size(double.infinity, _kBarHeight),
          onEvent: (event, payload) {
            if (event == 'leadingPressed') onLeadingPressed?.call();
            if (event == 'actionPressed' && payload is int) {
              onActionPressed?.call(payload);
            }
          },
        ),
      ),
    );
  }
}
