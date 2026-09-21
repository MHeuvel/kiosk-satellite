/// The last quarter hour of CPU load, memory pressure and temperature, one
/// sample per tick, so the Overview's metric tiles are full the moment an
/// admin page connects instead of growing from empty while someone watches.
///
/// Oldest first. A value the platform declined is kept as null so the
/// columns stay aligned in time. Sixty samples fifteen seconds apart is
/// fifteen minutes and a few hundred doubles.
class StatsHistory {
  StatsHistory({
    this.capacity = 60,
    this.interval = const Duration(seconds: 15),
  });

  final int capacity;
  final Duration interval;

  final _cpu = <double?>[];
  final _memory = <double?>[];
  final _temp = <double?>[];
  DateTime? _at;

  int get length => _cpu.length;
  DateTime? get lastSampleAt => _at;

  /// Records one sample. [memory] is the used share of RAM in percent.
  void add({double? cpu, double? memory, double? temp, DateTime? at}) {
    _cpu.add(cpu);
    _memory.add(memory);
    _temp.add(temp);
    _at = at ?? DateTime.now();
    while (_cpu.length > capacity) {
      _cpu.removeAt(0);
      _memory.removeAt(0);
      _temp.removeAt(0);
    }
  }

  /// Whether any sample carried a value for any metric: a host that
  /// declines every read has nothing worth a tile.
  bool get hasData =>
      _cpu.any((v) => v != null) ||
      _memory.any((v) => v != null) ||
      _temp.any((v) => v != null);

  Map<String, Object?> toJson() => {
    'intervalSeconds': interval.inSeconds,
    'capacity': capacity,
    'at': _at?.millisecondsSinceEpoch,
    'cpu': List<double?>.unmodifiable(_cpu),
    'memory': List<double?>.unmodifiable(_memory),
    'temp': List<double?>.unmodifiable(_temp),
  };
}
