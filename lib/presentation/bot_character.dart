import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/bot_ai.dart';
import '../domain/campaign_config.dart';

/// Board coordinates share the grid's spacing; the layer never consumes taps.
class BotCharacter extends StatefulWidget {
  const BotCharacter({
    super.key,
    required this.imageAsset,
    required this.boardSize,
    required this.row,
    required this.col,
    required this.tileSpacing,
    this.botAI,
  });

  final String imageAsset;
  final int boardSize;
  final int row;
  final int col;
  final double tileSpacing;
  final BotAI? botAI;

  @override
  State<BotCharacter> createState() => _BotCharacterState();
}

class _BotCharacterState extends State<BotCharacter>
    with SingleTickerProviderStateMixin {
  late final Ticker _frames;

  @override
  void initState() {
    super.initState();
    _frames = createTicker((_) => setState(() {}));
    widget.botAI?.addListener(_refresh);
    _syncFrames();
  }

  @override
  void didUpdateWidget(BotCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.botAI != widget.botAI) {
      oldWidget.botAI?.removeListener(_refresh);
      widget.botAI?.addListener(_refresh);
    }
    _syncFrames();
  }

  void _syncFrames() {
    final bot = widget.botAI;
    if (bot != null && bot.isMoving && bot.isRunning) {
      if (!_frames.isActive) _frames.start();
    } else {
      _frames.stop();
    }
  }

  void _refresh() {
    _syncFrames();
    setState(() {});
  }

  @override
  void dispose() {
    widget.botAI?.removeListener(_refresh);
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bot = widget.botAI;
    final frozen = bot?.gameState.isBotFrozen ?? false;
    final position = bot?.position;
    final row = position?.y ?? widget.row.toDouble();
    final col = position?.x ?? widget.col.toDouble();
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, constraints) {
        final tileSide = (constraints.maxWidth -
                widget.tileSpacing * (widget.boardSize - 1)) /
            widget.boardSize;
        final characterSide = tileSide * 0.45;
        final inset = (tileSide - characterSide) / 2;
        return Stack(children: [
          Positioned(
            left: col * (tileSide + widget.tileSpacing) + inset,
            top: row * (tileSide + widget.tileSpacing) + inset,
            width: characterSide,
            height: characterSide,
            child: TweenAnimationBuilder<double>(
              key: ValueKey((bot?.sessionId, bot?.arrivalCount)),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 120),
              builder: (context, progress, child) => Transform.scale(
                scale: bot != null && bot.arrivalCount > 0 && bot.isRunning
                    ? 1 - 0.48 * (1 - (2 * progress - 1).abs())
                    : 1,
                child: child,
              ),
              child: Semantics(
                label: 'Bot card character',
                value: frozen ? 'Frozen' : null,
                image: true,
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(
                    widget.imageAsset,
                    key: ValueKey(widget.imageAsset),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      CampaignConfig.defaultBotImageAsset,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.sentiment_satisfied_alt,
                          color: Color(0xFFFFD580)),
                    ),
                  ),
                  if (frozen) ...[
                    DecoratedBox(
                      key: const ValueKey('bot_character_freeze'),
                      decoration: BoxDecoration(
                        color: const Color(0x226ACDE5),
                        border: Border.all(color: const Color(0xFFB7E9F5)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.ac_unit,
                          key: const ValueKey('bot_character_freeze_icon'),
                          size: characterSide * 0.42,
                          color: const Color(0xFFB7E9F5)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
