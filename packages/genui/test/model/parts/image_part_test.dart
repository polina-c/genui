// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genai_primitives/genai_primitives.dart';
import 'package:genui/src/model/parts/image.dart';

void main() {
  group('ImagePart', () {
    test('fromBytes creates correct instance with equality', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final part = ImagePart.fromBytes(bytes, mimeType: 'image/png');

      expect(part.bytes, bytes);
      expect(part.mimeType, 'image/png');
      expect(part.base64, isNull);
      expect(part.url, isNull);

      final samePart = ImagePart.fromBytes(bytes, mimeType: 'image/png');
      expect(part, equals(samePart));
      expect(part.hashCode, equals(samePart.hashCode));

      final differentBytes = Uint8List.fromList([1, 2, 4]);
      final differentPart = ImagePart.fromBytes(
        differentBytes,
        mimeType: 'image/png',
      );
      expect(part, isNot(equals(differentPart)));
    });

    test('fromBase64 creates correct instance with equality', () {
      const base64 = 'AQID';
      final part = ImagePart.fromBase64(base64, mimeType: 'image/jpeg');

      expect(part.base64, base64);
      expect(part.mimeType, 'image/jpeg');
      expect(part.bytes, isNull);
      expect(part.url, isNull);

      final samePart = ImagePart.fromBase64(base64, mimeType: 'image/jpeg');
      expect(part, equals(samePart));
      expect(part.hashCode, equals(samePart.hashCode));

      final differentPart = ImagePart.fromBase64(
        'different',
        mimeType: 'image/jpeg',
      );
      expect(part, isNot(equals(differentPart)));
    });

    test('fromUrl creates correct instance with equality', () {
      final url = Uri.parse('https://example.com/image.png');
      final part = ImagePart.fromUrl(url, mimeType: 'image/png');

      expect(part.url, url);
      expect(part.mimeType, 'image/png');
      expect(part.bytes, isNull);
      expect(part.base64, isNull);

      final samePart = ImagePart.fromUrl(url, mimeType: 'image/png');
      expect(part, equals(samePart));
      expect(part.hashCode, equals(samePart.hashCode));

      final differentUrl = Uri.parse('https://example.com/other.png');
      final differentPart = ImagePart.fromUrl(
        differentUrl,
        mimeType: 'image/png',
      );
      expect(part, isNot(equals(differentPart)));
    });

    test('toJson and fromJson for bytes', () {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final part = ImagePart.fromBytes(bytes, mimeType: 'image/png');
      final json = part.toJson();

      expect(json, {'type': 'Image', 'mimeType': 'image/png', 'bytes': bytes});

      final reconstructed = ImagePart.fromJson(json);
      expect(reconstructed, equals(part));
    });

    test('toJson and fromJson for base64', () {
      const base64 = 'SGVsbG8=';
      final part = ImagePart.fromBase64(base64, mimeType: 'image/webp');
      final json = part.toJson();

      expect(json, {
        'type': 'Image',
        'mimeType': 'image/webp',
        'base64': base64,
      });

      final reconstructed = ImagePart.fromJson(json);
      expect(reconstructed, equals(part));
    });

    test('toJson and fromJson for url', () {
      final url = Uri.parse('https://example.com/pic.jpg');
      final part = ImagePart.fromUrl(url, mimeType: 'image/jpeg');
      final json = part.toJson();

      expect(json, {
        'type': 'Image',
        'mimeType': 'image/jpeg',
        'url': 'https://example.com/pic.jpg',
      });

      final reconstructed = ImagePart.fromJson(json);
      expect(reconstructed, equals(part));
    });

    test('Part.fromJson polymorphism works via Part.fromJson', () {
      // NOTE: For Part.fromJson to work, the registry needs to know about ImagePart.
      // Since ImagePart is in genui, not genai_primitives, it won't be in the default registry.
      // We need to provide a custom registry.

      final url = Uri.parse('https://example.com/pic.jpg');
      final part = ImagePart.fromUrl(url, mimeType: 'image/jpeg');
      final json = part.toJson();

      final registry = {
        'Image': PartConverter(ImagePart.fromJson),
        ...defaultPartConverterRegistry,
      };

      final reconstructed = Part.fromJson(json, converterRegistry: registry);
      expect(reconstructed, isA<ImagePart>());
      expect(reconstructed, equals(part));
    });

    test('toString returns expected string', () {
      final part = ImagePart.fromUrl(
        Uri.parse('http://a.com'),
        mimeType: 'image/png',
      );
      expect(part.toString(), contains('ImagePart'));
      expect(part.toString(), contains('http://a.com'));
      expect(part.toString(), contains('image/png'));
    });
  });
}
