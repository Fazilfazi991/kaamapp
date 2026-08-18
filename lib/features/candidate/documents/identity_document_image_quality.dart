import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// A fast, privacy-preserving first gate. The authoritative decision remains
/// the server validation function; this only prevents obviously unusable scans
/// from being uploaded.
class IdentityDocumentImageQuality {
  const IdentityDocumentImageQuality._();

  static const minWidth = 900;
  static const minHeight = 600;
  // The former single 3.5 edge-score cutoff rejected readable JPEGs.  Keep a
  // local block only for clearly unusable images; Azure remains authoritative.
  static const hardBlurRejectEdgeScore = 1.2;
  static const borderlineBlurEdgeScore = 2.2;

  static Future<String?> rejectionReason(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      if (image.width < minWidth || image.height < minHeight) {
        return 'This image is too low resolution. Use a clearer, closer photo.';
      }
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) {
        return 'We could not inspect this image. Please try another one.';
      }
      final pixels = raw.buffer.asUint8List();
      final step = (image.width * image.height ~/ 12000).clamp(1, 80);
      var count = 0;
      var total = 0.0;
      var squared = 0.0;
      var nearWhite = 0;
      var edgeTotal = 0.0;
      var edgeCount = 0;
      for (var pixel = 0; pixel < image.width * image.height; pixel += step) {
        final offset = pixel * 4;
        final luminance = (pixels[offset] * 0.2126) +
            (pixels[offset + 1] * 0.7152) +
            (pixels[offset + 2] * 0.0722);
        total += luminance;
        squared += luminance * luminance;
        if (luminance > 248) nearWhite += 1;
        final x = pixel % image.width;
        if (x + 1 < image.width) {
          final nextOffset = offset + 4;
          final next = (pixels[nextOffset] * 0.2126) +
              (pixels[nextOffset + 1] * 0.7152) +
              (pixels[nextOffset + 2] * 0.0722);
          edgeTotal += (luminance - next).abs();
          edgeCount += 1;
        }
        count += 1;
      }
      final mean = total / count;
      final variance = (squared / count) - (mean * mean);
      if (mean < 35) {
        return 'This image is too dark. Improve lighting and try again.';
      }
      if (nearWhite / count > 0.96) {
        return 'This image is mostly blank or overexposed.';
      }
      if (variance < 55) {
        return 'This image has too little contrast. Use a clearer document photo.';
      }
      final edgeScore = edgeCount == 0 ? 0.0 : edgeTotal / edgeCount;
      if (edgeScore < hardBlurRejectEdgeScore) {
        return 'This image is too blurry. Retake the document photo in good lighting.';
      }
      if (kDebugMode && edgeScore < borderlineBlurEdgeScore) {
        debugPrint(
          '[DocumentQuality] ${image.width}x${image.height} '
          'edge=${edgeScore.toStringAsFixed(2)} contrast=${variance.toStringAsFixed(1)} result=borderline',
        );
      }
      return null;
    } catch (_) {
      return 'We could not inspect this image. Please try another one.';
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
