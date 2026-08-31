/// Single choke point for the two Flutter design systems.
///
/// Flutter froze `package:flutter/material.dart` and `package:flutter/cupertino.dart`
/// in April 2026 and shipped them as the standalone `material_ui` and
/// `cupertino_ui` packages (1.0, Flutter 3.47). The SDK copies are scheduled for
/// deprecation in November 2026.
///
/// Every file in this package imports Material and Cupertino **through this
/// file only**. Migrating to the standalone packages is therefore a one-file
/// change: swap the two exports below for
///
/// ```dart
/// export 'package:material_ui/material_ui.dart';
/// export 'package:cupertino_ui/cupertino_ui.dart' hide RefreshCallback;
/// ```
///
/// and add them to `pubspec.yaml`. Nothing else in the package needs to move.
///
/// `RefreshCallback` is declared by both libraries, so the Cupertino copy is
/// hidden here. If `flutter analyze` reports further ambiguous exports after a
/// Flutter upgrade, add the offending names to the `hide` list below — that is
/// the only place they need to be resolved.
library;

export 'package:cupertino_ui/cupertino_ui.dart' hide RefreshCallback;
export 'package:material_ui/material_ui.dart';
