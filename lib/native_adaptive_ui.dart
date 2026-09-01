/// Adaptive Flutter widgets that resolve by platform, OS **version** and form
/// factor.
///
/// Most adaptive packages ask one question — "is this iOS or Android?" — and
/// stop there. That was enough when each platform had one current design
/// language. It is not enough now: iOS 26 and iOS 18 look nothing alike, and
/// neither do Android 16 and Android 12. This package asks three questions and
/// resolves a [DesignEra] from the answers.
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await NativeAdaptiveUi.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
///
/// Then use the adaptive widgets and never branch on `Platform.isIOS` again:
///
/// ```dart
/// AdaptiveScaffold(
///   title: 'Settings',
///   body: AdaptiveListSection(
///     header: 'Account',
///     children: [
///       AdaptiveListTile(title: 'Profile', onTap: _openProfile),
///       AdaptiveListTile(title: 'Notifications', onTap: _openNotifications),
///     ],
///   ),
/// )
/// ```
library;

export 'src/core/adaptive_config.dart'
    show AdaptiveConfig, AdaptiveScope, NativeAdaptiveUi;
export 'src/core/design_era.dart' show DesignEra, FormFactor;
export 'src/core/native_bridge.dart' show NativeComponents;
export 'src/core/platform_info.dart' show PlatformInfo;
export 'src/core/render_strategy.dart' show NativePolicy, RenderStrategy;
export 'src/effects/liquid_glass.dart' show ConditionalGlass, GlassSurface;
export 'src/tokens/adaptive_tokens.dart' show AdaptiveTokens;
export 'src/widgets/adaptive_app.dart' show AdaptiveApp;
export 'src/widgets/adaptive_base.dart'
    show AdaptiveContext, AdaptivePressable, AdaptiveRenderMixin;
export 'src/widgets/adaptive_button.dart'
    show AdaptiveButton, AdaptiveButtonStyle;
export 'src/widgets/adaptive_dialog.dart'
    show
        AdaptiveAction,
        AnchorKey,
        showAdaptiveActionSheet,
        showAdaptiveAlert,
        showAdaptivePopover;
export 'src/widgets/adaptive_list.dart'
    show AdaptiveListSection, AdaptiveListTile;
export 'src/widgets/adaptive_navigation.dart'
    show
        AdaptiveDestination,
        AdaptiveNavigationScaffold,
        AdaptiveNavigationStyle,
        AdaptiveSidebarToggleButton,
        adaptiveSidebarKey,
        adaptiveTabBarKey;
export 'src/widgets/adaptive_progress_indicator.dart'
    show AdaptiveProgressIndicator;
export 'src/widgets/adaptive_route.dart'
    show adaptivePage, adaptivePageRoute, pushAdaptive;
export 'src/widgets/adaptive_scaffold.dart' show AdaptiveScaffold;
export 'src/widgets/adaptive_search_field.dart'
    show AdaptiveSearchField, AdaptiveSearchToolbarButton;
export 'src/widgets/adaptive_segmented_control.dart'
    show AdaptiveSegmentedControl;
export 'src/widgets/adaptive_slider.dart'
    show AdaptiveSlider, AdaptiveSliderSize;
export 'src/widgets/adaptive_split_view.dart' show AdaptiveSplitView;
export 'src/widgets/adaptive_switch.dart' show AdaptiveSwitch;
export 'src/widgets/adaptive_text_field.dart' show AdaptiveTextField;
