import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/game_state.dart';

/// Refreshes a timed effect's display without controlling its game deadline.
class TimedEffectBuilder extends StatefulWidget {
  const TimedEffectBuilder(
      {super.key,
      required this.gameState,
      required this.remaining,
      required this.builder});

  final GameState gameState;
  final Duration Function() remaining;
  final Widget Function(BuildContext, Duration) builder;

  @override
  State<TimedEffectBuilder> createState() => _TimedEffectBuilderState();
}

class _TimedEffectBuilderState extends State<TimedEffectBuilder> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _syncRefresh();
  }

  @override
  void didUpdateWidget(TimedEffectBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRefresh();
  }

  void _syncRefresh() {
    if (widget.gameState.status != GameStateStatus.playing) {
      _refresh?.cancel();
      _refresh = null;
    } else {
      _refresh ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.remaining());
}
