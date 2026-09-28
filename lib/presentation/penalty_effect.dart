import 'package:flutter/material.dart';

import '../domain/game_state.dart';
import 'timed_effect_builder.dart';

const _penaltyInk = Color(0xFF781E26);
const _penaltyEdge = Color(0xFFEF6570);

class PenaltyStatus extends StatelessWidget {
  const PenaltyStatus({super.key, required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) => TimedEffectBuilder(
        gameState: gameState,
        remaining: () => gameState.rapidTapPenaltyRemaining,
        builder: (context, remaining) {
          final seconds = (remaining.inMicroseconds / 100000).ceil() / 10;
          final paused = gameState.status == GameStateStatus.paused;
          return Semantics(
            label: 'Rapid tapping penalty. Controls locked for one second.',
            value:
                '${seconds.toStringAsFixed(1)} seconds remaining${paused ? ', paused' : ''}',
            child: ExcludeSemantics(
              child: Container(
                width: 186,
                height: 30,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD9DD),
                    borderRadius: BorderRadius.circular(4)),
                child: Column(children: [
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(children: [
                      const Icon(Icons.pan_tool, size: 16, color: _penaltyInk),
                      const SizedBox(width: 4),
                      const Expanded(
                          child: Text('RAPID TAPS',
                              style: TextStyle(
                                  color: _penaltyInk,
                                  fontSize: 10,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w900))),
                      const SizedBox(width: 4),
                      SizedBox(
                          width: 40,
                          child: Text('${seconds.toStringAsFixed(1)}s',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  color: _penaltyInk,
                                  fontSize: 10,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ]))),
                    ]),
                  )),
                  LinearProgressIndicator(
                      value: _ratio(remaining),
                      minHeight: 3,
                      color: _penaltyInk,
                      backgroundColor: _penaltyInk.withAlpha(30)),
                ]),
              ),
            ),
          );
        },
      );
}

class PenaltyBoardOverlay extends StatelessWidget {
  const PenaltyBoardOverlay({super.key, required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) => TimedEffectBuilder(
        gameState: gameState,
        remaining: () => gameState.rapidTapPenaltyRemaining,
        builder: (context, remaining) => IgnorePointer(
          child: ExcludeSemantics(
              child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
                decoration: BoxDecoration(
                    border: Border.all(color: _penaltyEdge, width: 4))),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  key: const ValueKey('penalty_board_progress'),
                  value: _ratio(remaining),
                  minHeight: 6,
                  color: _penaltyEdge,
                  backgroundColor: const Color(0xFF53252B),
                )),
          ])),
        ),
      );
}

double _ratio(Duration remaining) => (remaining.inMicroseconds /
        GameState.rapidTapPenaltyDuration.inMicroseconds)
    .clamp(0.0, 1.0);
