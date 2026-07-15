import 'package:flutter/material.dart';

class CustomBottomNavigationBarWidget extends StatelessWidget {
  final List<Widget> children;

  const CustomBottomNavigationBarWidget({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [...children],
    );
  }
}
