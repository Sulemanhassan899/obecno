import 'package:flutter/material.dart';

class DottedDivider extends StatelessWidget {
  final double height;
  final double dotWidth;
  final double spacing;
  final Color color;

  const DottedDivider({
    super.key,
    this.height = 1,
    this.dotWidth = 4,
    this.spacing = 4,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxCount = (constraints.maxWidth / (dotWidth + spacing)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(boxCount, (_) {
            return Container(
              width: dotWidth,
              height: height,
              color: color,
            );
          }),
        );
      },
    );
  }
}

class VerticalDottedDivider extends StatelessWidget {
  final double width;
  final double dotHeight;
  final double spacing;
  final Color color;

  const VerticalDottedDivider({
    super.key,
    this.width = 1,
    this.dotHeight = 4,
    this.spacing = 2,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure that maxHeight is valid before calculation
        final boxCount = constraints.maxHeight > 0
            ? (constraints.maxHeight / (dotHeight + spacing)).floor()
            : 0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(boxCount, (_) {
            return Container(
              width: width,
              height: dotHeight,
              color: color,
            );
          }),
        );
      },
    );
  }
}

class MultiColorDottedDivider extends StatelessWidget {
  final double height;
  final double dotWidth;
  final double spacing;
  final List<Color> colors;

  const MultiColorDottedDivider({
    super.key,
    this.height = 1,
    this.dotWidth = 4,
    this.spacing = 4,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxCount = (constraints.maxWidth / (dotWidth + spacing)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(boxCount, (index) {
            return Container(
              width: dotWidth,
              height: height,
              color: colors[index % colors.length],
            );
          }),
        );
      },
    );
  }
}
