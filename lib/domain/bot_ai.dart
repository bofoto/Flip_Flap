import 'dart:math';

import 'package:flutter/foundation.dart';

import 'game_state.dart';
import 'pausable_timer.dart';

enum BotDifficulty { easy, medium, hard }

class BotAI extends ChangeNotifier {
  static const movementDuration = Duration(milliseconds: 200);

  BotAI({
    required this.gameState,
    required this.difficulty,
    Random? random,
  }) : _random = random ?? Random();

  final GameState gameState;
  final BotDifficulty difficulty;
  final Random _random;

  final _loopTimer = PausableTimer();
  int? _session;
  bool _isRunning = false;
  int _runId = 0;
  Point<double> _position = const Point(1, 0);
  BoardTile? _target;
  bool _isMoving = false;
  int _arrivalCount = 0;

  bool get isRunning => _isRunning;
  bool get isMoving => _isMoving;
  BoardTile? get target => _target;
  int get arrivalCount => _arrivalCount;
  int? get sessionId => _session;
  Duration get actionRemaining => _loopTimer.remaining;
  double get movementProgress => _isMoving
      ? (1 - actionRemaining.inMicroseconds / movementDuration.inMicroseconds)
          .clamp(0.0, 1.0)
      : 0;
  Point<double> get position {
    final target = _target;
    if (!_isMoving || target == null) return _position;
    final progress = movementProgress;
    return Point(
      _position.x + (target.col - _position.x) * progress,
      _position.y + (target.row - _position.y) * progress,
    );
  }

  void start() {
    if (_isRunning || gameState.status != GameStateStatus.playing) {
      return;
    }

    if (_session == gameState.sessionId) {
      if (gameState.isBotFrozen) return;
      _isRunning = true;
      if (_loopTimer.isPending) {
        _loopTimer.resume();
        notifyListeners();
      } else if (_isMoving) {
        _schedule(Duration.zero, _arrive);
        notifyListeners();
      } else {
        // A game listener may pause exactly when an arrival finishes.
        _scheduleNextAction();
      }
      return;
    }
    _loopTimer.cancel();
    _session = gameState.sessionId;
    gameState.addListener(_syncGameState);
    _runId++;
    final initialTile = gameState.board.expand((row) => row).firstWhere(
          (tile) => tile.owner == TileOwner.bot,
          orElse: () => gameState.board[0][0],
        );
    _position = Point(initialTile.col.toDouble(), initialTile.row.toDouble());
    _isMoving = false;
    _arrivalCount = 0;
    _isRunning = true;
    _scheduleNextAction();
    if (gameState.isBotFrozen) pause();
  }

  void _syncGameState() {
    if (_session != gameState.sessionId ||
        (gameState.status != GameStateStatus.playing &&
            gameState.status != GameStateStatus.paused)) {
      stop();
    } else if (gameState.status == GameStateStatus.paused ||
        gameState.isBotFrozen) {
      pause();
    } else {
      start();
    }
  }

  void stop() {
    gameState.removeListener(_syncGameState);
    _position = position;
    _runId++;
    _isRunning = false;
    _isMoving = false;
    _target = null;
    _loopTimer.cancel();
    _session = null;
    notifyListeners();
  }

  void pause() {
    if (!_isRunning) return;
    _isRunning = false;
    _loopTimer.pause();
    notifyListeners();
  }

  void _scheduleNextAction() {
    if (!_isRunning || gameState.status != GameStateStatus.playing) {
      _isRunning = false;
      return;
    }

    _target = _selectTarget();
    if (_target == null) {
      stop();
      return;
    }
    // Travel is part of the existing turn interval, not an extra delay.
    _schedule(_nextDelay - movementDuration, _beginMovement);
    notifyListeners();
  }

  void _schedule(Duration delay, VoidCallback action) {
    final run = _runId;
    final session = _session;
    _loopTimer.start(delay, () {
      if (!_isRunning || run != _runId) return;
      if (session != gameState.sessionId ||
          gameState.status != GameStateStatus.playing) {
        stop();
        return;
      }
      if (gameState.isBotFrozen) {
        pause();
        return;
      }
      action();
    });
  }

  void _beginMovement() {
    _isMoving = true;
    _schedule(movementDuration, _arrive);
    notifyListeners();
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

  void _arrive() {
    final run = _runId;
    final target = _target!;
    _position = Point(target.col.toDouble(), target.row.toDouble());
    _isMoving = false;
    _arrivalCount++;
    // Re-read ownership and item type at arrival, including an invalid flip.
    // Publish the landing after the flip, so listeners cannot interrupt it
    // between consuming the arrival timer and applying the game rule.
    gameState.flipTile(target.row, target.col, TileOwner.bot);
    if (_isRunning && run == _runId) _scheduleNextAction();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
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
