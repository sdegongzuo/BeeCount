import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:path/path.dart' as p;

bool isAvifPath(String path) => p.extension(path).toLowerCase() == '.avif';

class AdaptiveImageFile extends StatelessWidget {
  final File file;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  const AdaptiveImageFile({
    super.key,
    required this.file,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isAvifPath(file.path)) {
      return AvifImage.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }

    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}

class AdaptiveImageMemory extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  const AdaptiveImageMemory({
    super.key,
    required this.bytes,
    required this.fileName,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isAvifPath(fileName)) {
      return AvifImage.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }

    return Image.memory(
      bytes,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
