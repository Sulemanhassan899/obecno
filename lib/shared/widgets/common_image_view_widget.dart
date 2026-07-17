

import 'dart:io';
import 'package:Obecno/core/animations/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:Obecno/core/constants/all_colors.dart';

class CommonImageView extends StatelessWidget {
  String? url;
  String? imagePath;
  String? svgPath;
  File? file;

  double? height;
  double? width;

  double? radius;

  double topLeftRadius;
  double topRightRadius;
  double bottomLeftRadius;
  double bottomRightRadius;

  final BoxFit fit;
  final String placeHolder;

  CommonImageView({
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
    this.placeHolder = 'assets/images/no_image_found.png',
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
    return _buildImageView();
  }

  Widget _wrap(Widget child) {
    return ClipRRect(borderRadius: _borderRadius, child: child);
  }

  Widget _buildImageView() {
    /// SVG
    if (svgPath != null && svgPath!.isNotEmpty) {
      return _wrap(_SvgFallback(height: height, width: width));
    }

    /// FILE
    if (file != null && file!.path.isNotEmpty) {
      return _wrap(
        Image.file(
          file!,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
        ),
      );
    }

    /// ✅ NETWORK (UPDATED → SHIMMER LOADER)
    if (url != null && url!.isNotEmpty) {
      return _wrap(
        CachedNetworkImage(
          imageUrl: url!,
          height: height,
          width: width,
          fit: fit,

          /// 🔥 SHIMMER LOADER (REPLACED)
          placeholder: (context, url) => AppShimmer(
            isLoading: true,
            height: height,
            width: width,
            borderRadius: _borderRadius,
          ),

          /// Error
          errorWidget: (context, url, error) => _errorPlaceholder(),
        ),
      );
    }

    /// ASSET
    if (imagePath != null && imagePath!.isNotEmpty) {
      return _wrap(
        Image.asset(
          imagePath!,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
        ),
      );
    }

    /// FALLBACK
    return SizedBox(
      height: height,
      width: width,
      child: Image.asset(
        placeHolder,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      height: height,
      width: width,
      color: kGreyContainerColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: kGreyColor,
        size: (height ?? 24) * 0.4,
      ),
    );
  }
}

class _SvgFallback extends StatelessWidget {
  final double? height;
  final double? width;

  const _SvgFallback({this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: kGreyContainerColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: kGreyColor,
        size: (height ?? 24) * 0.5,
      ),
    );
  }
}
