import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

double _safeIconSize(double? width, double? height) {
  for (final v in [width, height]) {
    if (v != null && v.isFinite && v > 0) {
      return v.clamp(16.0, 256.0);
    }
  }
  return 48.0;
}

/// Web: blob / network URLs; local `file:` paths show unsupported (no dart:io).
Widget localImageFile(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  final iconSize = _safeIconSize(width, height);
  final isNetworkLike = path.startsWith('blob:') ||
      path.startsWith('http://') ||
      path.startsWith('https://');
  if (kIsWeb && isNetworkLike) {
    return Image.network(
      path,
      width: width != null && width.isFinite ? width : null,
      height: height != null && height.isFinite ? height : null,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image_outlined, size: iconSize),
    );
  }
  return Icon(Icons.image_not_supported_outlined, size: iconSize);
}
