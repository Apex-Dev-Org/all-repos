import 'dart:io';

import 'package:flutter/material.dart';

double _safeIconSize(double? width, double? height) {
  for (final v in [width, height]) {
    if (v != null && v.isFinite && v > 0) {
      return v.clamp(16.0, 256.0);
    }
  }
  return 48.0;
}

Widget localImageFile(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      final iconSize = _safeIconSize(width, height);
      return Icon(Icons.broken_image_outlined, size: iconSize);
    },
  );
}
