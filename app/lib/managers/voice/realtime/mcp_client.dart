import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One tool an MCP server offers.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;

  /// JSON Schema for the arguments.
  final Map<String, Object?> inputSchema;
}

/// What a tool call came back with: its text, and whether the server
/// flagged it as an error.
class McpResult {
  const McpResult(this.text, {this.error = false});
  final String text;
  final bool error;
}

class McpException implements Exception {
  McpException(this.message, {this.status});
  final String message;

  /// The HTTP status, when the server answered with one.
  final int? status;

  @override
  String toString() => message;
}

/// A minimal MCP client over Streamable HTTP: initialize, list tools, call
/// a tool. Enough for Home Assistant's MCP Server integration and any
/// server that speaks the same transport. A reply comes back either as
/// plain JSON or as a short server-sent event stream, and both are read.
class McpClient {
  McpClient({
    required this.url,
    this.token = '',
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.clientVersion = '',
    this.deviceId,
  }) : _client = client ?? http.Client();

  final Uri url;
  final String token;
  final Duration timeout;
  final String clientVersion;
  final http.Client _client;

  /// The Home Assistant device the calls act for. Home Assistant offers
  /// the timer tools only to a device that can run timers, and starts the
  /// timers on it. Null for any other server.
  final Future<String?> Function()? deviceId;

  static const protocolVersion = '2025-06-18';

  /// The request metadata key Home Assistant reads the device from.
  static const deviceMetaKey = 'io.home-assistant/device_id';

  String? _session;
  bool _initialized = false;
  int _nextId = 1;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    'MCP-Protocol-Version': protocolVersion,
    'Mcp-Session-Id': ?_session,
  };

  Future<void> _initialize() async {
    if (_initialized) return;
    await _request('initialize', {
      'protocolVersion': protocolVersion,
      'capabilities': const <String, Object?>{},
      // Servers built on the MCP SDKs refuse a client without a version.
      'clientInfo': {
        'name': 'Kiosk Satellite',
        'version': clientVersion.isEmpty ? '1.0' : clientVersion,
      },
    });
    _initialized = true;
    await _notify('notifications/initialized');
  }

  Future<Map<String, Object?>?> _meta() async {
    String? device;
    try {
      device = await deviceId?.call();
    } catch (_) {
      // Without a device the tools still work, only the timers are left out.
    }
    return device == null || device.isEmpty ? null : {deviceMetaKey: device};
  }

  /// Every tool the server offers, following its pages.
  Future<List<McpTool>> listTools() async {
    await _initialize();
    final meta = await _meta();
    final tools = <McpTool>[];
    String? cursor;
    for (var page = 0; page < 20; page++) {
      final result = await _request('tools/list', {
        'cursor': ?cursor,
        '_meta': ?meta,
      });
      final list = result['tools'];
      if (list is List) {
        for (final raw in list) {
          if (raw is! Map) continue;
          final name = '${raw['name'] ?? ''}';
          if (name.isEmpty) continue;
          final schema = raw['inputSchema'];
          tools.add(
            McpTool(
              name: name,
              description: '${raw['description'] ?? ''}',
              inputSchema: schema is Map
                  ? schema.cast<String, Object?>()
                  : const {'type': 'object', 'properties': {}},
            ),
          );
        }
      }
      final next = result['nextCursor'];
      if (next is! String || next.isEmpty) break;
      cursor = next;
    }
    return tools;
  }

  Future<McpResult> callTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    await _initialize();
    final meta = await _meta();
    final result = await _request('tools/call', {
      'name': name,
      'arguments': arguments,
      '_meta': ?meta,
    });
    final parts = <String>[];
    final content = result['content'];
    if (content is List) {
      for (final item in content) {
        if (item is Map && item['type'] == 'text') parts.add('${item['text']}');
      }
    }
    final structured = result['structuredContent'];
    if (parts.isEmpty && structured != null) parts.add(jsonEncode(structured));
    return McpResult(parts.join('\n'), error: result['isError'] == true);
  }

  Future<void> _notify(String method) async {
    final response = await _client
        .post(
          url,
          headers: _headers,
          body: jsonEncode({'jsonrpc': '2.0', 'method': method}),
        )
        .timeout(timeout);
    if (response.statusCode >= 400) {
      throw McpException(
        '$method refused (HTTP ${response.statusCode})',
        status: response.statusCode,
      );
    }
  }

  Future<Map<String, Object?>> _request(
    String method,
    Map<String, Object?> params,
  ) async {
    final id = _nextId++;
    final request = http.Request('POST', url)
      ..headers.addAll(_headers)
      ..body = jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      });
    final streamed = await _client.send(request).timeout(timeout);
    final session = streamed.headers['mcp-session-id'];
    if (session != null && session.isNotEmpty) _session = session;
    if (streamed.statusCode == 404 &&
        _session != null &&
        method != 'initialize') {
      // The server forgot the session: start a new one once.
      _session = null;
      _initialized = false;
      await streamed.stream.drain<void>();
      await _initialize();
      return _request(method, params);
    }
    if (streamed.statusCode >= 400) {
      final body = await streamed.stream.bytesToString().timeout(timeout);
      throw McpException(
        'HTTP ${streamed.statusCode}${body.isEmpty ? '' : ': ${_short(body)}'}',
        status: streamed.statusCode,
      );
    }
    final type = streamed.headers['content-type'] ?? '';
    final Map<String, Object?> message;
    if (type.contains('text/event-stream')) {
      message = await _fromEvents(streamed.stream, id);
    } else {
      final body = await streamed.stream.bytesToString().timeout(timeout);
      message = _decode(body);
    }
    final error = message['error'];
    if (error is Map) {
      throw McpException('${error['message'] ?? 'error'}');
    }
    final result = message['result'];
    return result is Map ? result.cast<String, Object?>() : const {};
  }

  /// The response to [id] from a server-sent event stream.
  Future<Map<String, Object?>> _fromEvents(
    Stream<List<int>> stream,
    int id,
  ) async {
    final data = StringBuffer();
    await for (final line
        in stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(timeout)) {
      if (line.startsWith('data:')) {
        data.write(line.substring(5).trimLeft());
        continue;
      }
      if (line.isNotEmpty || data.isEmpty) continue;
      // A blank line ends an event.
      final message = _decode(data.toString());
      data.clear();
      if (message['id'] == id) return message;
    }
    if (data.isNotEmpty) {
      final message = _decode(data.toString());
      if (message['id'] == id) return message;
    }
    throw McpException('no response');
  }

  Map<String, Object?> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {}
    throw McpException('unreadable response: ${_short(body)}');
  }

  static String _short(String text) =>
      text.length > 160 ? '${text.substring(0, 160)}...' : text;

  void close() => _client.close();
}
