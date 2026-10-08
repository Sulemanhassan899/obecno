import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Compresses a profile photo before upload (resize + JPEG).
class ProfileImageCompressor {
  const ProfileImageCompressor({
    this.maxSide = 1024,
    this.quality = 70,
  });

  final int maxSide;
  final int quality;

  Future<CompressedProfileImage> compress(
    List<int> bytes, {
    String? fileName,
  }) async {
    final input = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (input.isEmpty) {
      return CompressedProfileImage(
        bytes: input,
        fileName: _fileName(fileName),
      );
    }

    try {
      final compressed = await compute(
        _compressSync,
        _CompressArgs(
          bytes: input,
          maxSide: maxSide,
          quality: quality.clamp(1, 100),
        ),
      );
      if (compressed == null || compressed.isEmpty) {
        return CompressedProfileImage(
          bytes: input,
          fileName: _fileName(fileName),
        );
      }
      // Keep the smaller payload if re-encode grew the file.
      if (compressed.lengthInBytes >= input.lengthInBytes) {
        return CompressedProfileImage(
          bytes: input,
          fileName: _fileName(fileName),
        );
      }
      return CompressedProfileImage(
        bytes: compressed,
        fileName: 'photo.jpg',
      );
    } catch (_) {
      return CompressedProfileImage(
        bytes: input,
        fileName: _fileName(fileName),
      );
    }
  }

  static String _fileName(String? fileName) {
    final name = fileName?.trim();
    if (name == null || name.isEmpty) return 'photo.jpg';
    return name;
  }
}

class CompressedProfileImage {
  const CompressedProfileImage({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class _CompressArgs {
  const _CompressArgs({
    required this.bytes,
    required this.maxSide,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxSide;
  final int quality;
}

Uint8List? _compressSync(_CompressArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;

  img.Image framed = decoded;
  final longest = math.max(decoded.width, decoded.height);
  if (longest > args.maxSide) {
    final scale = args.maxSide / longest;
    framed = img.copyResize(
      decoded,
      width: math.max(1, (decoded.width * scale).round()),
      height: math.max(1, (decoded.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  return Uint8List.fromList(
    img.encodeJpg(framed, quality: args.quality),
  );
}
