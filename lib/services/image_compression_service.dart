import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CompressedImage {
  final Uint8List bytes;
  final String mimeType;
  final String path;
  final int originalBytes;
  final int compressedBytes;

  const CompressedImage({
    required this.bytes,
    required this.mimeType,
    required this.path,
    required this.originalBytes,
    required this.compressedBytes,
  });
}

class ImageCompressionService {
  /// Compresses an image for multimodal upload while keeping enough detail
  /// for Gemini vision quality.
  Future<CompressedImage> compressForUpload(String sourcePath) async {
    final originalSize = await File(sourcePath).length();

    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'vision_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      quality: 70,
      minWidth: 1280,
      minHeight: 1280,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (compressed == null) {
      throw StateError('Image compression failed.');
    }

    final bytes = await compressed.readAsBytes();
    final ratio = originalSize == 0 ? 0 : (bytes.length / originalSize) * 100;
    log(
      'Compressed image: ${originalSize}B -> ${bytes.length}B '
      '(${ratio.toStringAsFixed(1)}%)',
    );

    return CompressedImage(
      bytes: bytes,
      mimeType: 'image/jpeg',
      path: compressed.path,
      originalBytes: originalSize,
      compressedBytes: bytes.length,
    );
  }
}
