// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:genai_primitives/genai_primitives.dart';

/// An image part of a message.
///
/// Use the factory constructors to create an instance from different sources.
final class _Json {
  static const mimeType = 'mimeType';
  static const bytes = 'bytes';
  static const base64 = 'base64';
  static const url = 'url';
}

/// An image part of a message.
///
/// Use the factory constructors to create an instance from different sources.
final class ImagePart extends Part {
  static const String type = 'Image';

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

  /// Creates an image part from a JSON map.
  factory ImagePart.fromJson(Map<String, Object?> json) {
    if (json.containsKey(_Json.bytes)) {
      return ImagePart.fromBytes(
        Uint8List.fromList((json[_Json.bytes] as List).cast<int>()),
        mimeType: json[_Json.mimeType] as String,
      );
    } else if (json.containsKey(_Json.base64)) {
      return ImagePart.fromBase64(
        json[_Json.base64] as String,
        mimeType: json[_Json.mimeType] as String,
      );
    } else if (json.containsKey(_Json.url)) {
      // Check if url is just a string, as it might be serialized as a string
      final urlValue = json[_Json.url];
      final Uri uri;
      if (urlValue is String) {
        uri = Uri.parse(urlValue);
      } else {
        // Assume it might be an object that we need to handle or it's incorrectly typed,
        // but for now let's assume standard string serialization for URLs in JSON.
        // If it's something else, let it throw or handle as needed.
        // Based on genai_primitives it casts to String.
        uri = Uri.parse(urlValue as String);
      }

      return ImagePart.fromUrl(uri, mimeType: json[_Json.mimeType] as String);
    }
    throw FormatException('Invalid JSON for ImagePart: $json');
  }

  @override
  Map<String, Object?> toJson() => {
    Part.typeKey: type,
    _Json.mimeType: mimeType,
    if (bytes != null) _Json.bytes: bytes,
    if (base64 != null) _Json.base64: base64,
    if (url != null) _Json.url: url.toString(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    // We don't have deep equality here yet, using basic comparison matching genai_primitives roughly
    // BUT genai_primitives uses DeepCollectionEquality from collection.
    // I need to check if collection is available or if I should use it.
    // `genui` pubspec imports `genai_primitives` which exports `collection` (maybe?)
    // Actually `genui` likely depends on `collection` or `genai_primitives` does.
    // Let's implement manually for now to avoid extra imports if not present,
    // or assume we can use what's available.
    // Since `genai_primitives` is imported, let's see if we can use its utility or just standard dart logic.
    // For bytes comparison we need list equality.

    // Simpler approach: check if content matches.
    if (other is! ImagePart) return false;

    // For bytes, we need list equality.
    // Since we don't have `update` to add imports easily in this single step without checking,
    // I will use a simple list comparison helper if needed or assume standard usage.
    // But wait, `Part` might not be providing equality utils.
    // Let's rely on `genai_primitives` being available.
    // `genui` imports `genai_primitives`.

    return other.mimeType == mimeType &&
        other.base64 == base64 &&
        other.url == url &&
        _bytesEqual(other.bytes, bytes);
  }

  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    mimeType,
    base64,
    url,
    // Simple hash for bytes to avoid dragging in complex util if not needed
    bytes == null ? null : Object.hashAll(bytes!),
  );

  @override
  String toString() =>
      'ImagePart(mimeType: $mimeType, '
      'bytes: ${bytes?.length}, base64: ${base64?.length}, url: $url)';
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
