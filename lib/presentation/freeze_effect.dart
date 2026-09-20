import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/game_state.dart';

class FreezeStatus extends StatefulWidget {
  const FreezeStatus(
      {super.key, required this.gameState, required this.target});

  final GameState gameState;
  final TileOwner target;

  @override
  State<FreezeStatus> createState() => _FreezeStatusState();
}

class _FreezeStatusState extends State<FreezeStatus> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _syncRefresh();
  }

  @override
  void didUpdateWidget(FreezeStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRefresh();
  }

  void _syncRefresh() {
    if (widget.gameState.status != GameStateStatus.playing) {
      _refresh?.cancel();
      _refresh = null;
    } else {
      // Refresh only this display; the domain timer alone releases the freeze.
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
  Widget build(BuildContext context) {
    final player = widget.target == TileOwner.player;
    final remaining = player
        ? widget.gameState.playerFreezeRemaining
        : widget.gameState.botFreezeRemaining;
    final seconds = (remaining.inMicroseconds / 100000).ceil() / 10;
    final ratio =
        (remaining.inMicroseconds / GameState.freezeDuration.inMicroseconds)
            .clamp(0.0, 1.0);
    final ink = player ? const Color(0xFF123C50) : const Color(0xFF4B350C);
    final paused = widget.gameState.status == GameStateStatus.paused;

    return Semantics(
      label: player ? 'You are frozen. Controls locked.' : 'Bot is frozen.',
      value:
          '${seconds.toStringAsFixed(1)} seconds remaining${paused ? ', paused' : ''}',
      child: ExcludeSemantics(
        child: Container(
          width: 186,
          height: 30,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: player ? const Color(0xFFCAF0FA) : const Color(0xFFFFE5AB),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Icon(Icons.ac_unit, size: 16, color: ink),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(player ? 'YOU FROZEN!' : 'BOT FROZEN!',
                            style: TextStyle(
                                color: ink,
                                fontSize: 10,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 40,
                        child: Text('${seconds.toStringAsFixed(1)}s',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                color: ink,
                                fontSize: 10,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                      ),
                    ],
                  ),
                ),
              ),
              LinearProgressIndicator(
                  value: ratio,
                  minHeight: 3,
                  color: ink,
                  backgroundColor: ink.withAlpha(30)),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerFrostOverlay extends StatelessWidget {
  const PlayerFrostOverlay({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: ExcludeSemantics(
            child: CustomPaint(painter: _FrostBorderPainter())),
      );
}

class _FrostBorderPainter extends CustomPainter {
  const _FrostBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final depth = math.min(12.0, size.shortestSide * 0.055);
    final ice = Paint()..color = const Color(0xB3C7F3FF);
    final highlight = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..strokeWidth = 1.5;
    final origins = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height)
    ];
    // Four narrow, faceted strips leave the product image's center untouched.
    for (var edge = 0; edge < 4; edge++) {
      final length = edge.isEven ? size.width : size.height;
      canvas.save();
      canvas.translate(origins[edge].dx, origins[edge].dy);
      canvas.rotate(edge * math.pi / 2);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(length, 0);
      for (var step = 16; step >= 0; step--) {
        final facetDepth = step.isEven ? depth : depth * 0.35;
        path.lineTo(length * step / 16, facetDepth);
      }
      path.close();
      canvas.drawPath(path, ice);
      canvas.drawLine(Offset(0, 1), Offset(length, 1), highlight);
      for (var step = 1; step < 8; step++) {
        final x = length * step / 8;
        canvas.drawLine(
            Offset(x, 1), Offset(x - depth / 2, depth * 0.7), highlight);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FrostBorderPainter oldDelegate) => false;
}
