import 'dart:async';

import 'package:clock/clock.dart';

/// A one-shot timer that preserves the unfinished delay while paused.
class PausableTimer {
  Timer? _timer;
  DateTime? _deadline;
  Duration? _remaining;
  void Function()? _callback;

  bool get isPending => _remaining != null;

  Duration get remaining {
    if (_remaining == null) return Duration.zero;
    if (_deadline == null) return _remaining!;
    final left = _deadline!.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  void start(Duration duration, void Function() callback) {
    cancel();
    _remaining = duration;
    _callback = callback;
    resume();
  }

  void pause() {
    if (_timer == null) return;
    final left = _deadline!.difference(clock.now());
    _remaining = left.isNegative ? Duration.zero : left;
    _timer!.cancel();
    _timer = null;
    _deadline = null;
  }

  void resume() {
    if (_timer != null || _remaining == null) return;
    _deadline = clock.now().add(_remaining!);
    _timer = Timer(_remaining!, () {
      final callback = _callback!;
      cancel();
      callback();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _remaining = null;
    _callback = null;
  }
}
