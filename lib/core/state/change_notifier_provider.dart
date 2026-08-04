import 'package:flutter/widgets.dart';

class ChangeNotifierProvider<T extends ChangeNotifier>
    extends InheritedNotifier<T> {
  const ChangeNotifierProvider({
    super.key,
    required T notifier,
    required super.child,
  }) : super(notifier: notifier);

  static T _of<T extends ChangeNotifier>(
    BuildContext context, {
    required bool listen,
  }) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ChangeNotifierProvider<T>>();
    assert(element != null, 'No ChangeNotifierProvider<$T> found in context');

    if (listen) {
      context.dependOnInheritedElement(element!);
    }

    final widget = element!.widget as ChangeNotifierProvider<T>;
    return widget.notifier as T;
  }
}

extension ChangeNotifierProviderContext on BuildContext {
  /// Reads [T] and subscribes this widget to rebuild whenever it notifies.
  T watch<T extends ChangeNotifier>() =>
      ChangeNotifierProvider._of<T>(this, listen: true);

  /// Reads [T] once without subscribing to future rebuilds.
  T read<T extends ChangeNotifier>() =>
      ChangeNotifierProvider._of<T>(this, listen: false);
}
