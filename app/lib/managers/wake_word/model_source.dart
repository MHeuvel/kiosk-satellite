import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Wake word models are addressed by URL: http(s) for a model Home Assistant
/// serves (its custom wake words, or the Voice Satellite integration on the
/// dashboard runtime), `asset:///<path>` for the ones bundled with the app
/// and `file://` for the custom models added to the kiosk.
bool isBundledModel(String url) => url.startsWith('asset:');

bool isLocalModel(String url) => url.startsWith('file:');

/// A model already on the device, which the stores' download caches skip.
bool isStoredModel(String url) => isBundledModel(url) || isLocalModel(url);

/// The URL of a bundled model file, e.g. `assets/wake_words/vswakeword/x.json`.
String bundledModelUrl(String assetPath) => 'asset:///$assetPath';

String _assetPath(String url) {
  final q = url.indexOf('?');
  final bare = q >= 0 ? url.substring(0, q) : url;
  return Uri.parse(bare).path.replaceFirst(RegExp('^/+'), '');
}

/// The file's bytes, from the bundle, the kiosk's own storage or over HTTP.
/// Files already on the device skip the stores' disk caches.
Future<Uint8List> readModelBytes(
  String url, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  if (isBundledModel(url)) {
    final data = await rootBundle.load(_assetPath(url));
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
  if (isLocalModel(url)) {
    final q = url.indexOf('?');
    return File.fromUri(
      Uri.parse(q >= 0 ? url.substring(0, q) : url),
    ).readAsBytes();
  }
  final resp = await http.get(Uri.parse(url)).timeout(timeout);
  if (resp.statusCode != 200) {
    throw StateError('HTTP ${resp.statusCode}: $url');
  }
  return resp.bodyBytes;
}

Future<String> readModelText(
  String url, {
  Duration timeout = const Duration(seconds: 30),
}) async => utf8.decode(await readModelBytes(url, timeout: timeout));
