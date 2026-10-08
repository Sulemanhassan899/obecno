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

  bool get _hasRadius {
    return (radius ?? 0) > 0 ||
        topLeftRadius > 0 ||
        topRightRadius > 0 ||
        bottomLeftRadius > 0 ||
        bottomRightRadius > 0;
  }

  /// One-sided decode size so aspect ratio is preserved (both sides stretch).
  ({int? width, int? height}) _decodeSize(BuildContext context) {
    final logicalWidth = width;
    final logicalHeight = height;
    final hasWidth =
        logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0;
    final hasHeight =
        logicalHeight != null && logicalHeight.isFinite && logicalHeight > 0;
    if (!hasWidth && !hasHeight) {
      return (width: null, height: null);
    }
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final pxWidth = hasWidth ? (logicalWidth! * ratio).round() : 0;
    final pxHeight = hasHeight ? (logicalHeight! * ratio).round() : 0;
    final maxSide = pxWidth >= pxHeight ? pxWidth : pxHeight;
    if (maxSide <= 0) {
      return (width: null, height: null);
    }
    return (width: maxSide, height: null);
  }

  @override
  Widget build(BuildContext context) {
    final image = _buildImageView(context);
    if (!_hasRadius) return image;
    return ClipRRect(borderRadius: _borderRadius, child: image);
  }

  /// CENTRALIZED ERROR HANDLER — never throws if the fallback asset is missing.
  Widget _errorWidget(BuildContext context) {
    final decode = _decodeSize(context);
    return Image.asset(
      errorImage ?? placeHolder,
      height: height,
      width: width,
      fit: fit,
      cacheWidth: decode.width,
      cacheHeight: decode.height,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height,
        width: width,
        child: const Icon(Icons.broken_image_outlined, size: 18),
      ),
    );
  }

  Widget _buildImageView(BuildContext context) {
    /// =========================
    /// SVG (fallback)
    /// =========================
    final decode = _decodeSize(context);

    if (svgPath != null && svgPath!.isNotEmpty) {
      return _errorWidget(context);
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
        cacheWidth: decode.width,
        cacheHeight: decode.height,
        errorBuilder: (_, __, ___) => _errorWidget(context),
      );
    }

    /// =========================
    /// NETWORK IMAGE (WITH SHIMMER)
    /// =========================
    final networkUrl = _networkUrl(url) ?? _networkUrl(imagePath);
    if (networkUrl != null) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        height: height,
        width: width,
        fit: fit,
        memCacheWidth: decode.width,
        memCacheHeight: decode.height,

        /// Loading shimmer
        placeholder: (context, url) => AppShimmer(
          height: height ?? 100,
          width: width ?? double.infinity,
          isLoading: true,
        ),

        /// Error fallback
        errorWidget: (_, __, ___) => _errorWidget(context),
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
        cacheWidth: decode.width,
        cacheHeight: decode.height,
        errorBuilder: (_, __, ___) => _errorWidget(context),
      );
    }

    /// =========================
    /// NOTHING PROVIDED → DEFAULT
    /// =========================
    return _errorWidget(context);
  }

  static String? _networkUrl(String? value) {
    if (value == null) return null;
    final path = value.trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('//')) return 'https:$path';
    return null;
  }
}
