/// The go_router counterpart to `main.dart`, runnable on its own:
///
/// ```sh
/// flutter run -t lib/router_example.dart
/// ```
///
/// `main.dart` owns its selected tab with `setState`. This one hands the same
/// job to go_router and changes nothing else — `AdaptiveNavigationScaffold`
/// documents `selectedIndex` as caller-owned precisely so a router can be that
/// caller. The three pieces worth copying are marked below:
///
/// 1. [AdaptiveApp.router] instead of `AdaptiveApp`.
/// 2. `StatefulShellRoute.indexedStack` driving the navigation scaffold, with
///    `detailNavigator: false`.
/// 3. `adaptivePage` in a `pageBuilder`, and `canPop`/`onBack` on a pushed
///    [AdaptiveScaffold].
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:native_adaptive_ui/native_adaptive_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeAdaptiveUi.ensureInitialized();
  runApp(const RouterExampleApp());
}

const _destinations = <AdaptiveDestination>[
  AdaptiveDestination(
    label: 'Library',
    icon: Icon(Icons.library_music),
    appleIcon: Icon(CupertinoIcons.music_albums),
    sfSymbol: 'music.note.list',
  ),
  AdaptiveDestination(
    label: 'Search',
    icon: Icon(Icons.search),
    appleIcon: Icon(CupertinoIcons.search),
    sfSymbol: 'magnifyingglass',
  ),
  AdaptiveDestination(
    label: 'Settings',
    icon: Icon(Icons.settings),
    appleIcon: Icon(CupertinoIcons.gear),
    sfSymbol: 'gearshape',
  ),
];

class RouterExampleApp extends StatefulWidget {
  const RouterExampleApp({super.key});

  @override
  State<RouterExampleApp> createState() => _RouterExampleAppState();
}

class _RouterExampleAppState extends State<RouterExampleApp> {
  DesignEra? _eraOverride;

  /// Built once, in a field, rather than inside `build`. A `GoRouter` owns the
  /// current location, so rebuilding it on every era change would send the app
  /// back to `/` each time the picker moves.
  late final GoRouter _router = GoRouter(
    initialLocation: '/library',
    routes: [
      // (2) The shell. `navigationShell.currentIndex` and `goBranch` map
      // one-to-one onto the scaffold's `selectedIndex` and
      // `onDestinationSelected` — no adapter, no mirrored state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveNavigationScaffold(
          title: 'Router gallery',
          destinations: _destinations,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: navigationShell.goBranch,
          style: AdaptiveNavigationStyle.sidebarAdaptable,
          // Required with any outer router. Left at its default (true), the
          // iPad sidebar layout installs a nested Navigator of its own, which
          // would swallow every `context.go`/`context.push` below.
          detailNavigator: false,
          body: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const _LibraryPage(),
                routes: [
                  GoRoute(
                    path: 'album/:id',
                    // (3) adaptivePage, not a bare MaterialPage: this is what
                    // keeps the iOS edge-swipe back gesture on Apple eras.
                    pageBuilder: (context, state) => adaptivePage(
                      context: context,
                      title: 'Library',
                      child: _AlbumPage(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const _SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => _SettingsPage(
                  era: _eraOverride,
                  onEraChanged: (era) => setState(() => _eraOverride = era),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // (1) The only change from `main.dart`'s AdaptiveApp: a routerConfig in
    // place of `home`. go_router is not a dependency of native_adaptive_ui —
    // `GoRouter implements RouterConfig<RouteMatchList>`, and that is the
    // entire integration.
    return AdaptiveApp.router(
      title: 'native_adaptive_ui + go_router',
      eraOverride: _eraOverride,
      routerConfig: _router,
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage();

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Library',
      body: AdaptiveListSection(
        header: 'Albums',
        children: [
          for (var i = 1; i <= 3; i++)
            AdaptiveListTile(
              title: 'Album $i',
              subtitle: 'Tap to push a detail route',
              onTap: () => context.go('/library/album/$i'),
            ),
        ],
      ),
    );
  }
}

class _AlbumPage extends StatelessWidget {
  const _AlbumPage({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Album $id',
      // (3) The back button asks the router, not the enclosing Navigator.
      // Inside a shell branch those two disagree often enough that guessing is
      // not worth it — `GoRouter.of(context).canPop()` is the real answer.
      canPop: context.canPop(),
      onBack: context.pop,
      body: Center(child: Text('Album $id')),
    );
  }
}

class _SearchPage extends StatelessWidget {
  const _SearchPage();

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Search',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: AdaptiveSearchField(placeholder: 'Search'),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.era, required this.onEraChanged});

  final DesignEra? era;
  final ValueChanged<DesignEra?> onEraChanged;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Settings',
      // A section is a Column, not a scroller, and the era list is longer than
      // a phone screen — same reason every page in main.dart wraps one in a
      // ListView.
      body: Builder(
        builder: (context) => ListView(
          padding: context.adaptiveScrollPadding(),
          children: [
            AdaptiveListSection(
              header: 'Preview era',
              // Switching era rebuilds AdaptiveApp.router — swapping
              // CupertinoApp for MaterialApp — without rebuilding the router,
              // so the app stays on /settings across the change.
              children: [
                AdaptiveListTile(
                  title: 'Automatic',
                  trailing: era == null ? const Icon(Icons.check) : null,
                  onTap: () => onEraChanged(null),
                ),
                for (final option in DesignEra.values)
                  AdaptiveListTile(
                    title: option.name,
                    trailing: era == option ? const Icon(Icons.check) : null,
                    onTap: () => onEraChanged(option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
