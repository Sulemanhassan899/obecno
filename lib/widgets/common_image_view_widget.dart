// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:obecno/core/animations/app_shimmer.dart';

class CommonImageView extends StatelessWidget {
  final String? url;
  final String? imagePath;
  final String? svgPath;
  final File? file;

  final double? height;
  final double? width;

  final double? radius;

  final double topLeftRadius;
  final double topRightRadius;
  final double bottomLeftRadius;
  final double bottomRightRadius;

  final BoxFit fit;

  /// Default placeholder (used when everything fails)
  final String placeHolder;

  /// ✅ NEW: Optional custom error image
  final String? errorImage;

  const CommonImageView({
    super.key,
    this.url,
    this.imagePath,
    this.svgPath,
    this.file,
    this.height,
    this.width,
    this.radius = 0.0,
    this.topLeftRadius = 0.0,
    this.topRightRadius = 0.0,
    this.bottomLeftRadius = 0.0,
    this.bottomRightRadius = 0.0,
    this.fit = BoxFit.cover,
    this.placeHolder = 'assets/images/userimage.png',
    this.errorImage,
  });

  BorderRadius get _borderRadius {
    if (topLeftRadius != 0 ||
        topRightRadius != 0 ||
        bottomLeftRadius != 0 ||
        bottomRightRadius != 0) {
      return BorderRadius.only(
        topLeft: Radius.circular(topLeftRadius),
        topRight: Radius.circular(topRightRadius),
        bottomLeft: Radius.circular(bottomLeftRadius),
        bottomRight: Radius.circular(bottomRightRadius),
      );
    }
    return BorderRadius.circular(radius ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: _borderRadius, child: _buildImageView());
  }

  /// CENTRALIZED ERROR HANDLER — never throws if the fallback asset is missing.
  Widget _errorWidget() {
    return Image.asset(
      errorImage ?? placeHolder,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height,
        width: width,
        child: const Icon(Icons.broken_image_outlined, size: 18),
      ),
    );
  }

  Widget _buildImageView() {
    /// =========================
    /// SVG (fallback)
    /// =========================
    if (svgPath != null && svgPath!.isNotEmpty) {
      return _errorWidget();
    }

    /// =========================
    /// FILE IMAGE
    /// =========================
    if (file != null && file!.path.isNotEmpty) {
      return Image.file(
        file!,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorWidget(),
      );
    }

    /// =========================
    /// ASSET IMAGE
    /// =========================
    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.asset(
        imagePath!,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorWidget(),
      );
    }

    /// =========================
    /// NETWORK IMAGE (WITH SHIMMER)
    /// =========================
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        height: height,
        width: width,
        fit: fit,

        /// Loading shimmer
        placeholder: (context, url) => AppShimmer(
          height: height ?? 100,
          width: width ?? double.infinity,
          isLoading: true,
        ),

        /// Error fallback
        errorWidget: (_, __, ___) => _errorWidget(),
      );
    }

    /// =========================
    /// NOTHING PROVIDED → DEFAULT
    /// =========================
    return _errorWidget();
  }
}
