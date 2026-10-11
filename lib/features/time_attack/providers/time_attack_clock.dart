abstract interface class TimeAttackMonotonicClock {
  int get elapsedMilliseconds;

  bool get isRunning;

  void start();

  void stop();

  void reset();
}

class StopwatchTimeAttackClock implements TimeAttackMonotonicClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();

  @override
  void reset() => _stopwatch.reset();
}
