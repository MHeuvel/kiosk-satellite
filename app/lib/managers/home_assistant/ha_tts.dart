import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Home Assistant's text to speech as plain audio bytes: `tts_get_url` with
/// an engine entity, then the file it points at. [engine] empty takes the
/// first `tts.` entity Home Assistant has, the Announcements rule. Null
/// when Home Assistant is not set up, not reachable or has no engine; a
/// caller treats speech as a bonus and carries on without it.
Future<Uint8List?> haSpeak({
  required String base,
  required String token,
  required String engine,
  required String message,
  http.Client Function() client = http.Client.new,
  Duration timeout = const Duration(seconds: 15),
}) async {
  base = base.trim().replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty || token.isEmpty || message.trim().isEmpty) return null;
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  final c = client();
  try {
    var entity = engine.trim();
    if (entity.isEmpty) {
      final states = await c
          .get(Uri.parse('$base/api/states'), headers: headers)
          .timeout(timeout);
      if (states.statusCode != 200) return null;
      final list = jsonDecode(states.body);
      if (list is! List) return null;
      entity =
          [
            for (final e in list)
              if (e is Map && '${e['entity_id']}'.startsWith('tts.'))
                '${e['entity_id']}',
          ].firstOrNull ??
          '';
      if (entity.isEmpty) return null;
    }
    final res = await c
        .post(
          Uri.parse('$base/api/tts_get_url'),
          headers: headers,
          body: jsonEncode({'engine_id': entity, 'message': message}),
        )
        .timeout(timeout);
    if (res.statusCode != 200) return null;
    final url = (jsonDecode(res.body) as Map?)?['url'];
    if (url is! String || url.isEmpty) return null;
    final audio = await c
        .get(Uri.parse(url), headers: url.startsWith(base) ? headers : const {})
        .timeout(timeout);
    if (audio.statusCode != 200 || audio.bodyBytes.isEmpty) return null;
    return audio.bodyBytes;
  } catch (_) {
    return null;
  } finally {
    c.close();
  }
}
