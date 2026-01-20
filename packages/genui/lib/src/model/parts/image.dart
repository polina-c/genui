// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:flutter/material.dart';

/// An image part of a message.
///
/// Use the factory constructors to create an instance from different sources.
final class ImagePart implements Part {
  /// The raw image bytes. May be null if created from a URL or Base64.
  final Uint8List? bytes;

  /// The Base64 encoded image string. May be null if created from bytes or URL.
  final String? base64;

  /// The URL of the image. May be null if created from bytes or Base64.
  final Uri? url;

  /// The MIME type of the image (e.g., 'image/jpeg', 'image/png').
  /// Required when providing image data directly.
  final String mimeType;

  // Private constructor to enforce creation via factories.
  const ImagePart._({
    this.bytes,
    this.base64,
    this.url,
    required this.mimeType,
  });

  /// Creates an [ImagePart] from raw image bytes.
  const factory ImagePart.fromBytes(
    Uint8List bytes, {
    required String mimeType,
  }) = _ImagePartFromBytes;

  /// Creates an [ImagePart] from a Base64 encoded string.
  const factory ImagePart.fromBase64(
    String base64, {
    required String mimeType,
  }) = _ImagePartFromBase64;

  /// Creates an [ImagePart] from a URL.
  const factory ImagePart.fromUrl(Uri url, {required String mimeType}) =
      _ImagePartFromUrl;
}

// Private implementation classes for ImagePart factories
final class _ImagePartFromBytes extends ImagePart {
  const _ImagePartFromBytes(Uint8List bytes, {required super.mimeType})
    : super._(bytes: bytes);
}

final class _ImagePartFromBase64 extends ImagePart {
  const _ImagePartFromBase64(String base64, {required super.mimeType})
    : super._(base64: base64);
}

final class _ImagePartFromUrl extends ImagePart {
  const _ImagePartFromUrl(Uri url, {required super.mimeType})
    : super._(url: url);
}
