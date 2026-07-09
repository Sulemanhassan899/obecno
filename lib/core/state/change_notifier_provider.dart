import 'package:flutter/widgets.dart';

/// Minimal, dependency-free replacement for the `provider` pub.dev package.
///
/// Exposes the same call-site ergonomics apps typically rely on —
/// `context.watch<T>()` to rebuild on change, `context.read<T>()` for a
/// one-off read — implemented on top of Flutter's own [InheritedNotifier],
/// which already ships in the SDK.
///
/// Usage:
/// ```dart
/// ChangeNotifierProvider<ThemeProvider>(
///   notifier: themeProvider,
///   child: const MyApp(),
/// )
/// ...
/// final theme = context.watch<ThemeProvider>();
/// context.read<ThemeProvider>().toggleTheme();
/// ```
class ChangeNotifierProvider<T extends ChangeNotifier> extends InheritedNotifier<T> {
  const ChangeNotifierProvider({
    super.key,
    required T notifier,
    required super.child,
  }) : super(notifier: notifier);

  static T _of<T extends ChangeNotifier>(BuildContext context, {required bool listen}) {
    final element = context.getElementForInheritedWidgetOfExactType<ChangeNotifierProvider<T>>();
    assert(element != null, 'No ChangeNotifierProvider<$T> found in context');

    if (listen) {
      context.dependOnInheritedElement(element!);
    }

    final widget = element!.widget as ChangeNotifierProvider<T>;
    return widget.notifier as T;
  }
}

/// Context extensions mirroring the familiar `provider` package API.
extension ChangeNotifierProviderContext on BuildContext {
  /// Reads [T] and subscribes this widget to rebuild whenever it notifies.
  T watch<T extends ChangeNotifier>() => ChangeNotifierProvider._of<T>(this, listen: true);

  /// Reads [T] once without subscribing to future rebuilds.
  T read<T extends ChangeNotifier>() => ChangeNotifierProvider._of<T>(this, listen: false);
}
