import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'campaign_config.dart';

enum TileOwner { player, bot, none }

enum TileType { normal, bomb, line, freeze }

enum GameStateStatus { ready, playing, paused, finishing, ended }

enum GameEndReason { timeExpired, boardCovered }

enum GameOutcome { playerWin, botWin, draw }

class BoardTile {
  BoardTile({
    required this.row,
    required this.col,
    required this.owner,
    this.type = TileType.normal,
  });

  final int row;
  final int col;
  TileOwner owner;
  TileType type;
}

class GameState extends ChangeNotifier {
  static const double _specialTileSpawnRate = 0.12;
  static const Duration _rapidTapWindow = Duration(milliseconds: 350);
  static const int _rapidTapLimit = 3;
  static const Duration _rapidTapPenaltyDuration = Duration(seconds: 1);
  static const Duration _resultDelay = Duration(milliseconds: 1400);

  GameState({
    this.campaign = defaultCampaignConfig,
  }) {
    initializeGame();
  }

  final CampaignConfig campaign;
  final Random _random = Random();

  int _currentStage = 1;
  int _unlockedStage = 1;
  List<List<BoardTile>> _board = [];
  int _timeLeft = 30;
  GameStateStatus _status = GameStateStatus.ready;
  Timer? _timer;
  Timer? _resultTimer;

  bool _isPlayerFrozen = false;
  bool _isBotFrozen = false;
  bool _isRapidTapPenaltyActive = false;
  Timer? _playerFreezeTimer;
  Timer? _botFreezeTimer;
  DateTime? _lastPlayerTapAt;
  int _rapidTapCount = 0;
  bool _isStartCountdownRequested = false;
  GameOutcome? _outcome;
  GameEndReason? _endReason;

  int get currentStage => _currentStage;
  int get unlockedStage => _unlockedStage;
  int get maxStage => campaign.stages.length;
  List<List<BoardTile>> get board => _board;
  int get timeLeft => _timeLeft;
  GameStateStatus get status => _status;
  bool get isPlayerFrozen => _isPlayerFrozen;
  bool get isBotFrozen => _isBotFrozen;
  bool get isRapidTapPenaltyActive => _isRapidTapPenaltyActive;
  bool get isStartCountdownRequested => _isStartCountdownRequested;
  GameOutcome? get outcome => _outcome;
  String get gameResult {
    final label = switch (_outcome) {
      GameOutcome.playerWin => 'PLAYER WINS!',
      GameOutcome.botWin => 'BOT WINS!',
      GameOutcome.draw => 'DRAW!',
      null => '',
    };
    return _endReason == GameEndReason.boardCovered
        ? '$label\n(ALL COVERED!)'
        : label;
  }

  GameEndReason? get endReason => _endReason;
  String get brandLogoImage => campaign.backImageUrl;
  int get boardSize => _stageConfig.boardSize;
  int get maxTime => _stageConfig.maxTime;
  int get totalTiles => boardSize * boardSize;
  String get currentProductImage => _stageConfig.productImageUrl;
  CampaignReward get currentReward => _stageConfig.reward;

  CampaignStage get _stageConfig => campaign.stages[_currentStage - 1];

  int get playerScore => _countTiles(TileOwner.player);
  int get botScore => _countTiles(TileOwner.bot);

  bool selectStage(int stage) {
    if (stage < 1 || stage > maxStage || stage > _unlockedStage) {
      return false;
    }

    _currentStage = stage;
    initializeGame();
    return true;
  }

  void initializeGame() {
    _status = GameStateStatus.ready;
    _timeLeft = maxTime;
    _outcome = null;
    _endReason = null;
    _isPlayerFrozen = false;
    _isBotFrozen = false;
    _isRapidTapPenaltyActive = false;
    _lastPlayerTapAt = null;
    _rapidTapCount = 0;
    _isStartCountdownRequested = false;
    _timer?.cancel();
    _resultTimer?.cancel();
    _playerFreezeTimer?.cancel();
    _botFreezeTimer?.cancel();

    _board = List.generate(boardSize, (row) {
      return List.generate(boardSize, (col) {
        final owner = (row + col).isEven ? TileOwner.player : TileOwner.bot;
        return BoardTile(row: row, col: col, owner: owner);
      });
    });

    notifyListeners();
  }

  void startGame() {
    if (_status == GameStateStatus.ready || _status == GameStateStatus.ended) {
      initializeGame();
    } else if (_status != GameStateStatus.paused) {
      return;
    }

    _status = GameStateStatus.playing;
    _startCountdown();
    notifyListeners();
  }

  void requestStartCountdown() {
    if (_status != GameStateStatus.ready) return;

    _isStartCountdownRequested = true;
    notifyListeners();
  }

  void consumeStartCountdownRequest() {
    _isStartCountdownRequested = false;
  }

  void pauseGame() {
    if (_status != GameStateStatus.playing) return;

    _status = GameStateStatus.paused;
    _timer?.cancel();
    notifyListeners();
  }

  bool flipTile(int row, int col, TileOwner owner) {
    if (_status != GameStateStatus.playing) return false;
    if (owner == TileOwner.player) {
      if (_isPlayerFrozen) return false;
      if (_registerPlayerTap()) return false;
    }
    if (owner == TileOwner.bot && _isBotFrozen) return false;

    final tile = _board[row][col];
    if (tile.owner == owner && tile.type == TileType.normal) return false;

    final originalType = tile.type;
    tile.owner = owner;
    tile.type = TileType.normal;

    switch (originalType) {
      case TileType.bomb:
        _applyBombEffect(row, col, owner);
        break;
      case TileType.line:
        _applyLineEffect(row, col, owner);
        break;
      case TileType.freeze:
        _applyFreezeEffect(owner);
        break;
      case TileType.normal:
        break;
    }

    if (_random.nextDouble() < _specialTileSpawnRate) {
      _spawnSpecialTile();
    }

    notifyListeners();
    _checkBoardCoveredWin();
    return true;
  }

  void endGame() {
    if (playerScore > botScore) {
      _finishGame(
        winner: TileOwner.player,
        reason: GameEndReason.timeExpired,
      );
    } else if (botScore > playerScore) {
      _finishGame(winner: TileOwner.bot, reason: GameEndReason.timeExpired);
    } else {
      _finishGame(reason: GameEndReason.timeExpired);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft <= 1) {
        _timeLeft = 0;
        endGame();
        return;
      }

      _timeLeft--;
      notifyListeners();
      _checkBoardCoveredWin();
    });
  }

  int _countTiles(TileOwner owner) {
    return _board
        .expand((row) => row)
        .where((tile) => tile.owner == owner)
        .length;
  }

  void _applyBombEffect(int row, int col, TileOwner owner) {
    for (int r = row - 1; r <= row + 1; r++) {
      for (int c = col - 1; c <= col + 1; c++) {
        if (_isInBounds(r, c)) {
          _board[r][c].owner = owner;
        }
      }
    }
  }

  void _applyLineEffect(int row, int col, TileOwner owner) {
    for (int i = 0; i < boardSize; i++) {
      _board[row][i].owner = owner;
      _board[i][col].owner = owner;
    }
  }

  void _applyFreezeEffect(TileOwner attacker) {
    if (attacker == TileOwner.player) {
      _isBotFrozen = true;
      _botFreezeTimer?.cancel();
      _botFreezeTimer = Timer(const Duration(seconds: 2), () {
        _isBotFrozen = false;
        notifyListeners();
      });
      return;
    }

    _isPlayerFrozen = true;
    _isRapidTapPenaltyActive = false;
    _playerFreezeTimer?.cancel();
    _playerFreezeTimer = Timer(const Duration(seconds: 2), () {
      _isPlayerFrozen = false;
      notifyListeners();
    });
  }

  bool _registerPlayerTap() {
    final now = DateTime.now();
    final previousTap = _lastPlayerTapAt;
    _lastPlayerTapAt = now;

    if (previousTap == null || now.difference(previousTap) > _rapidTapWindow) {
      _rapidTapCount = 1;
      return false;
    }

    _rapidTapCount++;
    if (_rapidTapCount < _rapidTapLimit) return false;

    _rapidTapCount = 0;
    _isPlayerFrozen = true;
    _isRapidTapPenaltyActive = true;
    _playerFreezeTimer?.cancel();
    _playerFreezeTimer = Timer(_rapidTapPenaltyDuration, () {
      _isPlayerFrozen = false;
      _isRapidTapPenaltyActive = false;
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void _spawnSpecialTile() {
    final availableTiles = _board
        .expand((row) => row)
        .where((tile) => tile.type == TileType.normal)
        .toList();

    if (availableTiles.isEmpty) return;

    const itemTypes = [TileType.bomb, TileType.line, TileType.freeze];
    final targetTile = availableTiles[_random.nextInt(availableTiles.length)];
    targetTile.type = itemTypes[_random.nextInt(itemTypes.length)];
  }

  void _checkBoardCoveredWin() {
    if (playerScore == totalTiles) {
      _finishGame(winner: TileOwner.player, reason: GameEndReason.boardCovered);
    } else if (botScore == totalTiles) {
      _finishGame(winner: TileOwner.bot, reason: GameEndReason.boardCovered);
    }
  }

  void _finishGame({
    TileOwner? winner,
    required GameEndReason reason,
  }) {
    _timer?.cancel();
    _resultTimer?.cancel();
    _status = GameStateStatus.finishing;
    _endReason = reason;

    if (winner == TileOwner.player) {
      _outcome = GameOutcome.playerWin;
      _unlockNextStage();
    } else if (winner == TileOwner.bot) {
      _outcome = GameOutcome.botWin;
    } else {
      _outcome = GameOutcome.draw;
    }

    notifyListeners();
    _resultTimer = Timer(_resultDelay, () {
      _status = GameStateStatus.ended;
      notifyListeners();
    });
  }

  void _unlockNextStage() {
    if (_currentStage == _unlockedStage && _unlockedStage < maxStage) {
      _unlockedStage++;
    }
  }

  bool _isInBounds(int row, int col) {
    return row >= 0 && row < boardSize && col >= 0 && col < boardSize;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resultTimer?.cancel();
    _playerFreezeTimer?.cancel();
    _botFreezeTimer?.cancel();
    super.dispose();
  }
}
