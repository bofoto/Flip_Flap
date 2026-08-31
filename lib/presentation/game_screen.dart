import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/bot_ai.dart';
import '../domain/game_state.dart';

Color faded(Color color, double opacity) {
  return color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  BotAI? _botAI;

  @override
  void dispose() {
    _botAI?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBot(gameState);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(gameState: gameState),
              const SizedBox(height: 20),
              _ScoreGauge(gameState: gameState),
              const SizedBox(height: 24),
              _TimerAndStatus(gameState: gameState),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Board(gameState: gameState),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ControlPanel(gameState: gameState),
            ],
          ),
        ),
      ),
    );
  }

  void _syncBot(GameState gameState) {
    if (gameState.status != GameStateStatus.playing) {
      _botAI?.stop();
      return;
    }

    final difficulty = switch (gameState.currentStage) {
      1 => BotDifficulty.easy,
      2 => BotDifficulty.medium,
      3 => BotDifficulty.hard,
      _ => BotDifficulty.easy,
    };

    if (_botAI == null || _botAI!.difficulty != difficulty) {
      _botAI?.stop();
      _botAI = BotAI(gameState: gameState, difficulty: difficulty);
    }

    _botAI!.start();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final isPlaying = gameState.status == GameStateStatus.playing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameState.campaign.brandName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Colors.cyanAccent, blurRadius: 10),
                    ],
                  ),
                ),
                Text(
                  'SPEED TILE BATTLE',
                  style: TextStyle(
                    color: faded(Colors.white, 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            StatusBadge(
              text: 'STAGE ${gameState.currentStage}',
              color: Colors.amberAccent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(gameState.maxStage, (index) {
            final stage = index + 1;
            final isUnlocked = stage <= gameState.unlockedStage;
            final isSelected = stage == gameState.currentStage;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 4,
                  right: index == gameState.maxStage - 1 ? 0 : 4,
                ),
                child: _StageButton(
                  stage: stage,
                  isSelected: isSelected,
                  isUnlocked: isUnlocked,
                  onTap: isPlaying || !isUnlocked
                      ? null
                      : () => gameState.selectStage(stage),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.stage,
    required this.isSelected,
    required this.isUnlocked,
    required this.onTap,
  });

  final int stage;
  final bool isSelected;
  final bool isUnlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = !isUnlocked
        ? Colors.grey
        : isSelected
            ? Colors.cyanAccent
            : Colors.white60;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: faded(Colors.cyanAccent, 0.2),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isUnlocked) ...[
              const Icon(Icons.lock, color: Colors.white24, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              'STAGE $stage',
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final playerScore = gameState.playerScore;
    final botScore = gameState.botScore;
    final totalTiles = gameState.totalTiles;
    final playerRatio = totalTiles > 0 ? playerScore / totalTiles : 0.5;
    final botRatio = totalTiles > 0 ? botScore / totalTiles : 0.5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ScoreLabel(
              text: 'PLAYER: $playerScore',
              color: Colors.cyanAccent,
              dotBeforeText: true,
            ),
            _ScoreLabel(
              text: 'BOT: $botScore',
              color: Colors.pinkAccent,
              dotBeforeText: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  flex: max(1, (playerRatio * 1000).round()),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyan, Colors.cyanAccent],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: max(1, (botRatio * 1000).round()),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pinkAccent, Colors.redAccent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  const _ScoreLabel({
    required this.text,
    required this.color,
    required this.dotBeforeText,
  });

  final String text;
  final Color color;
  final bool dotBeforeText;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 6)],
      ),
    );

    final label = Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );

    return Row(
      children: dotBeforeText
          ? [dot, const SizedBox(width: 8), label]
          : [label, const SizedBox(width: 8), dot],
    );
  }
}

class _TimerAndStatus extends StatelessWidget {
  const _TimerAndStatus({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final isLowTime = gameState.timeLeft <= 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.timer,
              color: isLowTime ? Colors.redAccent : Colors.cyanAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isLowTime ? Colors.redAccent : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: isLowTime
                    ? [const Shadow(color: Colors.redAccent, blurRadius: 10)]
                    : null,
              ),
              child: Text('${gameState.timeLeft}s'),
            ),
          ],
        ),
        Row(
          children: [
            if (gameState.isPlayerFrozen)
              const StatusBadge(text: 'YOU FROZEN!', color: Colors.blueAccent),
            if (gameState.isPlayerFrozen && gameState.isBotFrozen)
              const SizedBox(width: 8),
            if (gameState.isBotFrozen)
              const StatusBadge(
                  text: 'BOT FROZEN!', color: Colors.orangeAccent),
          ],
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: faded(color, 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(color: faded(color, 0.3), blurRadius: 6)],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final size = gameState.boardSize;

    return GridView.builder(
      key: ValueKey('board_grid_${gameState.currentStage}'),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: size,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: size * size,
      itemBuilder: (context, index) {
        final row = index ~/ size;
        final col = index % size;
        final tile = gameState.board[row][col];

        return FlipTileWidget(
          key: ValueKey('tile_${row}_$col'),
          tile: tile,
          boardSize: size,
          productImageUrl: gameState.currentProductImage,
          backImageUrl: gameState.brandLogoImage,
          onTap: () => gameState.flipTile(row, col, TileOwner.player),
        );
      },
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    if (gameState.status == GameStateStatus.ready ||
        gameState.status == GameStateStatus.ended) {
      return NeonButton(
        text: 'START GAME',
        color: Colors.cyanAccent,
        onPressed: gameState.startGame,
      );
    }

    return Row(
      children: [
        Expanded(
          child: NeonButton(
            text: gameState.status == GameStateStatus.playing
                ? 'PAUSE'
                : 'RESUME',
            color: Colors.orangeAccent,
            onPressed: gameState.status == GameStateStatus.playing
                ? gameState.pauseGame
                : gameState.startGame,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: NeonButton(
            text: 'RESET',
            color: Colors.redAccent,
            onPressed: gameState.initializeGame,
          ),
        ),
      ],
    );
  }
}

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
  });

  final String text;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color, width: 2),
        elevation: 6,
        shadowColor: faded(color, 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class FlipTileWidget extends StatelessWidget {
  const FlipTileWidget({
    super.key,
    required this.tile,
    required this.boardSize,
    required this.productImageUrl,
    required this.backImageUrl,
    required this.onTap,
  });

  final BoardTile tile;
  final int boardSize;
  final String productImageUrl;
  final String backImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlayerTile = tile.owner == TileOwner.player;
    final itemIcon = _itemIcon;

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isPlayerTile ? 0 : pi),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (context, angle, child) {
          final isFront = angle < pi / 2;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isFront
                ? _TileFace(
                    borderColor: Colors.cyan,
                    shadowColor: Colors.cyanAccent,
                    icon: itemIcon,
                    child: _ProductImagePiece(
                      tile: tile,
                      boardSize: boardSize,
                      imageUrl: productImageUrl,
                    ),
                  )
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _TileFace(
                      borderColor: Colors.pink,
                      shadowColor: Colors.pinkAccent,
                      icon: itemIcon,
                      child: _BackImage(imageUrl: backImageUrl),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget? get _itemIcon {
    return switch (tile.type) {
      TileType.bomb =>
        const Icon(Icons.brightness_7, color: Colors.white, size: 24),
      TileType.line =>
        const Icon(Icons.add_road, color: Colors.white, size: 24),
      TileType.freeze =>
        const Icon(Icons.ac_unit, color: Colors.white, size: 24),
      TileType.normal => null,
    };
  }
}

class _TileFace extends StatelessWidget {
  const _TileFace({
    required this.borderColor,
    required this.shadowColor,
    required this.child,
    this.icon,
  });

  final Color borderColor;
  final Color shadowColor;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: faded(shadowColor, 0.35),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (icon != null) Center(child: icon),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: faded(borderColor, 0.8), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackImage extends StatelessWidget {
  const _BackImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        faded(Colors.black, 0.4),
        BlendMode.darken,
      ),
      child: Image.network(imageUrl, fit: BoxFit.cover),
    );
  }
}

class _ProductImagePiece extends StatelessWidget {
  const _ProductImagePiece({
    required this.tile,
    required this.boardSize,
    required this.imageUrl,
  });

  final BoardTile tile;
  final int boardSize;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth;
        final tileHeight = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -tile.col * tileWidth,
              top: -tile.row * tileHeight,
              width: tileWidth * boardSize,
              height: tileHeight * boardSize,
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ],
        );
      },
    );
  }
}
