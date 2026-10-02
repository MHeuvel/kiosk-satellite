import 'logging.dart';

/// Result of executing a [Command].
class CommandResult {
  const CommandResult.ok([this.data]) : ok = true, error = null;
  const CommandResult.fail(this.error) : ok = false, data = null;

  final bool ok;
  final Object? data;
  final String? error;

  Map<String, Object?> toJson() => {
    'ok': ok,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
  };
}

typedef CommandHandler =
    Future<CommandResult> Function(Map<String, Object?> params);

/// A named, remotely-invocable capability.
class Command {
  const Command({
    required this.name,
    required this.description,
    required this.handler,
    this.params = const {},
    this.quiet = false,
    this.secretParams = const {},
  });

  final String name;
  final String description;

  /// Skips the per-execution info log. For side-effect-free status reads
  /// executed on a cadence (pollers, event fan-out): logging each one turns
  /// the app log into a metronome — a download had getUpdateStatus logged
  /// several times a second, which read as something being wrong (#272).
  final bool quiet;

  /// Params whose values never reach the log: API keys, passwords and
  /// anything carrying them. The log is what users paste into public
  /// issues, and an OpenAI key logged this way was revoked by OpenAI
  /// within minutes of being posted (#804).
  final Set<String> secretParams;

  /// Human-readable parameter descriptions, keyed by param name
  /// (e.g. {'level': 'Brightness 0..1'}). Documentation, not validation.
  final Map<String, String> params;
  final CommandHandler handler;
}

/// The single administration surface.
///
/// Every user-facing capability is registered here once; the JS API bridge,
/// the remote REST/WS API and the ESPHome entities are thin protocol
/// adapters over this registry.
class CommandRegistry {
  CommandRegistry(this._log) : _commands = {}, source = null;

  CommandRegistry._as(this._log, this._commands, this.source);

  final Logger _log;
  final Map<String, Command> _commands;

  /// Who a command executed through this handle is logged as coming from:
  /// the manager it runs in, the device UI, or null for the root registry.
  final String? source;

  /// The same registry (one command table, shared) seen through a handle
  /// that logs every execute with `[source]` at its end. Every manager holds one
  /// under its own name, so the log says whether a command came from the
  /// remote admin page, an ESPHome entity, the page's JS API or the
  /// device's own UI, which is the whole question when a setting keeps
  /// flipping and nobody on the device touched it.
  CommandRegistry as(String source) =>
      CommandRegistry._as(_log, _commands, source);

  void register(Command command) {
    assert(
      !_commands.containsKey(command.name),
      'duplicate command ${command.name}',
    );
    _commands[command.name] = command;
  }

  List<Command> get all => _commands.values.toList(growable: false);

  Future<CommandResult> execute(
    String name,
    Map<String, Object?> params,
  ) async {
    final command = _commands[name];
    if (command == null) return CommandResult.fail('unknown command: $name');
    try {
      if (!command.quiet) {
        _log.info(
          'command',
          '$name${params.isEmpty ? '' : ' ${_redact(command, params)}'}'
              '${source == null ? '' : ' [$source]'}',
        );
      }
      return await command.handler(params);
    } catch (e) {
      _log.error('command', '$name failed: $e');
      return CommandResult.fail('$e');
    }
  }

  static Map<String, Object?> _redact(
    Command command,
    Map<String, Object?> params,
  ) {
    if (command.secretParams.isEmpty) return params;
    return {
      for (final e in params.entries)
        e.key: command.secretParams.contains(e.key) && e.value != null
            ? '<redacted>'
            : e.value,
    };
  }
}
