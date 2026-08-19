import 'package:flutter/material.dart';

class MultiProvider extends StatelessWidget {
  const MultiProvider({
    super.key,
    required this.providers,
    required this.child,
  });

  final List<Widget Function(Widget child)> providers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return providers.reversed.fold(child, (widget, wrap) => wrap(widget));
  }
}
