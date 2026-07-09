import 'package:flutter/material.dart';

class BackgroundImageContainer extends StatelessWidget {
  final Widget child;
  final String imagePath;

  const BackgroundImageContainer({
    super.key,
    required this.child,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.fill),
      ),
      child: child,
    );
  }
}
