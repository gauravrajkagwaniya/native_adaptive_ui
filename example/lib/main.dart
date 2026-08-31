import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:native_adaptive_ui/native_adaptive_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeAdaptiveUi.ensureInitialized();
  runApp(const ExampleApp());
}

/// A destination icon does not have to come from Material Icons, CupertinoIcons
/// or Apple's SF Symbols catalogue — a brand mark works too, on every
/// rendering path:
///
/// * `icon`/`selectedIcon` (the Dart-drawn capsule, the sidebar, every
///   Material bar) is a plain `Widget`, so a hand-drawn `CustomPainter` like
///   this one just works — no asset file needed.
/// * `iconSvgAsset`/`selectedIconSvgAsset` (the real native `UITabBar`) needs
///   actual pixels to ship across the platform channel, so those two point at
///   the same diamond mark exported to `assets/icons/*.svg` instead —
///   `iconImage`/`selectedIconImage` is the same idea for a raster PNG/JPEG.
///
/// Whatever is passed to `icon`/`selectedIcon` renders through the same
/// fixed-size box every built-in `Icon` does, so a custom mark lines up with
/// the rest of the bar without the caller having to size it themselves.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _BrandMarkPainter(
        color: IconTheme.of(context).color ?? const Color(0xFF000000),
        filled: filled,
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    // A simple diamond — deliberately not a system glyph, to prove the point.
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

/// Demonstrates the package, and doubles as its own design-review tool: the
/// era picker on the Settings tab re-renders the whole app as any supported OS
/// version, so a reviewer can compare iOS 26 against iOS 18 on one machine.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  DesignEra? _eraOverride;
  int _tab = 0;
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      title: 'native_adaptive_ui',
      eraOverride: _eraOverride,
      home: AdaptiveNavigationScaffold(
        title: 'Gallery',
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        // sidebarAdaptable, so the toggle button on the Controls tab can
        // convert the sidebar (iPad/macOS) back to a tab bar and restore it.
        style: AdaptiveNavigationStyle.sidebarAdaptable,
        sidebarCollapsed: _sidebarCollapsed,
        // extendContentBehindSidebar is left off (the default) — turning it
        // on floats the sidebar over full-width content instead of the two
        // sharing a row, which reads as the panel blocking the page rather
        // than a background bleeding through it. The gallery keeps the plain
        // side-by-side layout.
        minimizeOnScroll: true,
        accessory: const _NowPlayingAccessory(),
        // selectedColor/unselectedColor are left unset here on purpose, so
        // the bar keeps each platform's own default tint (iOS blue, Material
        // dynamic colour) rather than the gallery's own opinion. The "Design"
        // tab's tinted SVG demonstrates per-icon colour instead — see
        // AdaptiveDestination.tintNativeIcon below.
        // Material glyphs on an iOS tab bar are the fastest way to give a
        // build away, so each destination carries an SF-style counterpart.
        //
        // `sfSymbol` is what unlocks the real `UITabBar` on iOS 26 — the system
        // then owns the glass, the selection morph and the liquid press
        // response. Without it the Dart capsule renders instead, which is what
        // every other era gets.
        destinations: const [
          AdaptiveDestination(
            label: 'Controls',
            icon: Icon(Icons.tune),
            appleIcon: Icon(CupertinoIcons.slider_horizontal_3),
            sfSymbol: 'slider.horizontal.3',
          ),
          AdaptiveDestination(
            label: 'Lists',
            icon: Icon(Icons.list),
            appleIcon: Icon(CupertinoIcons.list_bullet),
            sfSymbol: 'list.bullet',
            badge: '3',
          ),
          AdaptiveDestination(
            label: 'More',
            icon: Icon(Icons.more_horiz),
            appleIcon: Icon(CupertinoIcons.ellipsis_circle),
            sfSymbol: 'ellipsis.circle',
          ),
          // No sfSymbol here on purpose — a custom brand mark is the case
          // `iconSvgAsset`/`iconImage` exist for. It still reaches the real
          // `UITabBar`: the SVG is rasterized once and shipped across as PNG
          // bytes instead of a system symbol name, and — because it's a
          // single-colour vector mark — `tintNativeIcon` defaults to true, so
          // it picks up the tab bar's own tint exactly like an SF Symbol
          // would, rather than keeping a fixed baked-in colour.
          AdaptiveDestination(
            label: 'Design',
            icon: _BrandMark(filled: false),
            selectedIcon: _BrandMark(filled: true),
            iconSvgAsset: 'assets/icons/brand_outline.svg',
            selectedIconSvgAsset: 'assets/icons/brand_filled.svg',
          ),
        ],
        body: switch (_tab) {
          0 => _ControlsPage(
              sidebarCollapsed: _sidebarCollapsed,
              onSidebarToggle: (value) =>
                  setState(() => _sidebarCollapsed = value),
            ),
          1 => const _ListsPage(),
          2 => const _MorePage(),
          _ => _DesignPage(
              era: _eraOverride,
              onEraChanged: (era) => setState(() => _eraOverride = era),
            ),
        },
      ),
    );
  }
}

/// The MiniPlayer-style view [AdaptiveNavigationScaffold.accessory] is meant
/// for — what gives `minimizeOnScroll` something to move alongside the bar.
class _NowPlayingAccessory extends StatelessWidget {
  const _NowPlayingAccessory();

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(AdaptiveScope.of(context).era);
    return ConditionalGlass(
      tokens: tokens,
      borderRadius: tokens.radius(),
      fallbackColor: CupertinoColors.secondarySystemBackground,
      padding: EdgeInsets.symmetric(horizontal: tokens.horizontalPadding),
      child: const Row(
        children: [
          Icon(CupertinoIcons.waveform, size: 18),
          SizedBox(width: 8),
          Text('Now syncing…', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ControlsPage extends StatefulWidget {
  const _ControlsPage({
    required this.sidebarCollapsed,
    required this.onSidebarToggle,
  });

  final bool sidebarCollapsed;
  final ValueChanged<bool> onSidebarToggle;

  @override
  State<_ControlsPage> createState() => _ControlsPageState();
}

class _ControlsPageState extends State<_ControlsPage> {
  bool _switchValue = true;
  double _sliderValue = 0.4;
  String _segment = 'day';
  final AnchorKey _anchorKey = GlobalKey();
  final TextEditingController _nameController =
      TextEditingController(text: 'Gaurav');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(AdaptiveScope.of(context).era);

    return AdaptiveScaffold(
      title: 'Controls',
      leading: AdaptiveSidebarToggleButton(
        collapsed: widget.sidebarCollapsed,
        onChanged: widget.onSidebarToggle,
      ),
      // Fades a scrim behind the bar on scroll instead of an opaque bar
      // background — HIG's stated alternative to painting a toolbar.
      scrollEdgeEffect: true,
      // A Builder is what puts this context *below* the scaffold, so the
      // navigation bar's height has reached MediaQuery by the time the padding
      // is computed. The other two pages pass no padding at all and get the
      // same inset automatically.
      body: Builder(
        builder: (context) => ListView(
          padding: context.adaptiveScrollPadding(
            horizontal: tokens.horizontalPadding,
            vertical: tokens.spacing * 2,
          ),
          children: [
            AdaptiveButton(
              onPressed: () => _showAlert(context),
              expand: true,
              child: const Text('Show alert'),
            ),
            SizedBox(height: tokens.spacing * 2),
            AdaptiveButton(
              key: _anchorKey,
              style: AdaptiveButtonStyle.tonal,
              onPressed: () => _showSheet(context),
              expand: true,
              child: const Text('Show choices'),
            ),
            SizedBox(height: tokens.spacing * 2),
            AdaptiveButton(
              style: AdaptiveButtonStyle.destructive,
              onPressed: () {},
              expand: true,
              child: const Text('Delete'),
            ),
            SizedBox(height: tokens.spacing * 3),
            AdaptiveSegmentedControl<String>(
              segments: const {
                'day': 'Day',
                'week': 'Week',
                'month': 'Month',
              },
              value: _segment,
              onChanged: (value) => setState(() => _segment = value),
            ),
            SizedBox(height: tokens.spacing * 3),
            Row(
              children: [
                const Text('Notifications'),
                const Spacer(),
                AdaptiveSwitch(
                  value: _switchValue,
                  onChanged: (value) => setState(() => _switchValue = value),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing * 2),
            AdaptiveSlider(
              value: _sliderValue,
              onChanged: (value) => setState(() => _sliderValue = value),
            ),
            SizedBox(height: tokens.spacing * 3),
            AdaptiveTextField(
              label: 'Display name',
              placeholder: 'Gaurav',
              controller: _nameController,
              showClearButton: true,
            ),
            SizedBox(height: tokens.spacing * 2),
            const AdaptiveTextField.secure(
              label: 'Passcode',
              placeholder: 'Required for sensitive changes',
            ),
            SizedBox(height: tokens.spacing * 3),
            const Center(child: AdaptiveProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlert(BuildContext context) {
    return showAdaptiveAlert(
      context,
      title: 'Discard changes?',
      message: 'This cannot be undone.',
      actions: [
        const AdaptiveAction(label: 'Cancel', isDefault: true),
        const AdaptiveAction(label: 'Discard', isDestructive: true),
      ],
    );
  }

  Future<void> _showSheet(BuildContext context) {
    // Passing the anchor is what turns a bottom sheet into a popover on iPad
    // and macOS. On a phone it is ignored.
    return showAdaptiveActionSheet(
      context,
      title: 'Sort by',
      cancelLabel: 'Cancel',
      anchor: _anchorKey,
      actions: const [
        AdaptiveAction(label: 'Name'),
        AdaptiveAction(label: 'Date added'),
        AdaptiveAction(label: 'Size'),
      ],
    );
  }
}

class _ListsPage extends StatelessWidget {
  const _ListsPage();

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Lists',
      grouped: true,
      // A center region (customisable on macOS/iPadOS, folded into the
      // trailing group on iPhone) plus enough trailing actions to exercise
      // the overflow button on a compact window.
      centerActions: [
        AdaptiveButton(
          style: AdaptiveButtonStyle.plain,
          onPressed: () {},
          child: const Icon(CupertinoIcons.arrow_up_arrow_down),
        ),
      ],
      actions: [
        AdaptiveButton(
          style: AdaptiveButtonStyle.plain,
          onPressed: () {},
          child: const Icon(CupertinoIcons.folder_badge_plus),
        ),
        AdaptiveButton(
          style: AdaptiveButtonStyle.plain,
          onPressed: () {},
          child: const Icon(CupertinoIcons.tag),
        ),
      ],
      prominentAction: AdaptiveButton(
        onPressed: () {},
        child: const Text('Done'),
      ),
      body: ListView(
        children: [
          AdaptiveListSection(
            header: 'Account',
            footer: 'Your name is visible to people you share with.',
            children: [
              AdaptiveListTile(
                title: 'Profile',
                subtitle: 'Gaurav Raj',
                onTap: () => pushAdaptive(
                  context,
                  (_) => const _DetailPage(title: 'Profile'),
                ),
              ),
              AdaptiveListTile(
                title: 'Notifications',
                onTap: () => pushAdaptive(
                  context,
                  (_) => const _DetailPage(title: 'Notifications'),
                ),
              ),
            ],
          ),
          const AdaptiveListSection(
            header: 'About',
            children: [
              AdaptiveListTile(title: 'Version', subtitle: '0.1.0'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Everything added past the original three-tab gallery: split views, a
/// general-purpose popover, search placements, and the M3E slider variants.
class _MorePage extends StatefulWidget {
  const _MorePage();

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage> {
  final AnchorKey _popoverAnchor = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  int _selectedItem = 0;
  double _sliderValue = 0.5;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(AdaptiveScope.of(context).era);

    return AdaptiveScaffold(
      title: 'More',
      // Opts into a real UINavigationBar on glass eras — the native
      // counterpart to leading/actions widgets, which this screen leaves
      // empty on purpose so the native path is actually taken.
      leadingSfSymbol: 'line.3.horizontal',
      actionSfSymbols: const ['magnifyingglass'],
      onLeadingPressed: () => showAdaptiveAlert(
        context,
        title: 'Menu',
        message: 'The native UINavigationBar leading button fired.',
        actions: const [AdaptiveAction(label: 'OK', isDefault: true)],
      ),
      onActionPressed: (_) => setState(() {}),
      body: Builder(
        builder: (context) => ListView(
          padding: context.adaptiveScrollPadding(
            horizontal: tokens.horizontalPadding,
            vertical: tokens.spacing * 2,
          ),
          children: [
            const Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: tokens.spacing),
            AdaptiveSearchField(controller: _searchController),
            SizedBox(height: tokens.spacing * 3),
            Row(
              children: [
                const Text('Toolbar search'),
                const Spacer(),
                const AdaptiveSearchToolbarButton(),
              ],
            ),
            SizedBox(height: tokens.spacing * 3),
            AdaptiveButton(
              key: _popoverAnchor,
              style: AdaptiveButtonStyle.tonal,
              expand: true,
              onPressed: () => showAdaptivePopover(
                context,
                anchor: _popoverAnchor,
                // HIG recommends a sheet on a compact window instead — this
                // gallery forces the real anchored popover everywhere so the
                // widget itself is easy to see on any device.
                preferSheetOnCompact: false,
                builder: (context) => SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Popover content',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Arbitrary content, anchored to the button.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Show popover'),
            ),
            SizedBox(height: tokens.spacing * 3),
            const Text(
              'Split view',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: tokens.spacing),
            SizedBox(
              height: 220,
              child: AdaptiveSplitView(
                primary: ListView(
                  children: [
                    for (final (index, label) in const [
                      'Inbox',
                      'Sent',
                      'Drafts',
                    ].indexed)
                      AdaptiveListTile(
                        title: label,
                        trailing: index == _selectedItem
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => setState(() => _selectedItem = index),
                      ),
                  ],
                ),
                secondary: Center(
                  child: Text('Selected: ${_selectedItem + 1}'),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing * 3),
            const Text(
              'M3E slider sizes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: tokens.spacing),
            AdaptiveSlider(
              value: _sliderValue,
              size: AdaptiveSliderSize.l,
              onChanged: (value) => setState(() => _sliderValue = value),
            ),
            SizedBox(height: tokens.spacing * 2),
            SizedBox(
              height: 120,
              child: AdaptiveSlider(
                value: _sliderValue,
                size: AdaptiveSliderSize.m,
                vertical: true,
                onChanged: (value) => setState(() => _sliderValue = value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: title,
      body: Center(child: Text('$title detail')),
    );
  }
}

class _DesignPage extends StatelessWidget {
  const _DesignPage({required this.era, required this.onEraChanged});

  final DesignEra? era;
  final ValueChanged<DesignEra?> onEraChanged;

  @override
  Widget build(BuildContext context) {
    final config = AdaptiveScope.of(context);

    return AdaptiveScaffold(
      title: 'Design',
      grouped: true,
      body: ListView(
        children: [
          AdaptiveListSection(
            header: 'Detected',
            children: [
              AdaptiveListTile(
                title: 'Platform',
                subtitle: config.platform.toString(),
              ),
              AdaptiveListTile(
                title: 'Form factor',
                subtitle: config.formFactor.name,
              ),
            ],
          ),
          AdaptiveListSection(
            header: 'Preview as',
            footer: 'Overrides the detected era for the whole app.',
            children: [
              AdaptiveListTile(
                title: 'Detected',
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
    );
  }
}
