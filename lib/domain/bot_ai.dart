import 'dart:async';
import 'dart:math';

import 'game_state.dart';

enum BotDifficulty { easy, medium, hard }

class BotAI {
  BotAI({
    required this.gameState,
    required this.difficulty,
  });

  final GameState gameState;
  final BotDifficulty difficulty;
  final Random _random = Random();

  Timer? _loopTimer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _scheduleNextAction();
  }

  void stop() {
    _isRunning = false;
    _loopTimer?.cancel();
  }

  void _scheduleNextAction() {
    if (!_isRunning || gameState.status != GameStateStatus.playing) {
      _isRunning = false;
      return;
    }

    _loopTimer = Timer(_nextDelay, () {
      _performAction();
      _scheduleNextAction();
    });
  }

  Duration get _nextDelay {
    final (minSeconds, rangeSeconds) = switch (difficulty) {
      BotDifficulty.easy => (1.2, 0.6),
      BotDifficulty.medium => (0.8, 0.4),
      BotDifficulty.hard => (0.4, 0.4),
    };

    final seconds = minSeconds + _random.nextDouble() * rangeSeconds;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  void _performAction() {
    if (gameState.status != GameStateStatus.playing || gameState.isBotFrozen) {
      return;
    }

    final target = _selectTarget();
    if (target != null) {
      gameState.flipTile(target.row, target.col, TileOwner.bot);
    }
  }

  BoardTile? _selectTarget() {
    final allTiles = gameState.board.expand((row) => row).toList();
    final specialTiles = allTiles
        .where((tile) => tile.type != TileType.normal)
        .where((tile) => tile.owner != TileOwner.bot)
        .toList();
    final playerTiles =
        allTiles.where((tile) => tile.owner == TileOwner.player).toList();
    final flippableTiles = allTiles
        .where((tile) =>
            tile.owner != TileOwner.bot || tile.type != TileType.normal)
        .toList();

    return switch (difficulty) {
      BotDifficulty.hard => _pickHardTarget(
          specialTiles: specialTiles,
          playerTiles: playerTiles,
          fallbackTiles: allTiles,
        ),
      BotDifficulty.medium => _pickMediumTarget(
          specialTiles: specialTiles,
          playerTiles: playerTiles,
          fallbackTiles: flippableTiles,
        ),
      BotDifficulty.easy => _pickEasyTarget(
          specialTiles: specialTiles,
          fallbackTiles: flippableTiles,
        ),
    };
  }

  BoardTile? _pickHardTarget({
    required List<BoardTile> specialTiles,
    required List<BoardTile> playerTiles,
    required List<BoardTile> fallbackTiles,
  }) {
    if (specialTiles.isNotEmpty) return _pick(specialTiles);
    if (playerTiles.isNotEmpty && _random.nextDouble() < 0.8) {
      return _pick(playerTiles);
    }
    return _pick(fallbackTiles);
  }

  BoardTile? _pickMediumTarget({
    required List<BoardTile> specialTiles,
    required List<BoardTile> playerTiles,
    required List<BoardTile> fallbackTiles,
  }) {
    if (specialTiles.isNotEmpty && _random.nextDouble() < 0.5) {
      return _pick(specialTiles);
    }
    if (playerTiles.isNotEmpty && _random.nextDouble() < 0.5) {
      return _pick(playerTiles);
    }
    return _pick(fallbackTiles);
  }

  BoardTile? _pickEasyTarget({
    required List<BoardTile> specialTiles,
    required List<BoardTile> fallbackTiles,
  }) {
    if (specialTiles.isNotEmpty && _random.nextDouble() < 0.3) {
      return _pick(specialTiles);
    }
    return _pick(fallbackTiles);
  }

  BoardTile? _pick(List<BoardTile> tiles) {
    if (tiles.isEmpty) return null;
    return tiles[_random.nextInt(tiles.length)];
  }
}
