import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'campaign_config.dart';
import 'pausable_timer.dart';

enum TileOwner { player, bot, none }

enum TileType { normal, bomb, line, freeze }

enum GameStateStatus { ready, starting, playing, paused, finishing, ended }

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
  static const freezeDuration = Duration(seconds: 2);
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
  final _timer = PausableTimer();
  Timer? _resultTimer;
  Timer? _startTimer;
  int? _startCountdown;
  int _sessionId = 0;

  bool _isPlayerFrozen = false;
  bool _isBotFrozen = false;
  bool _isRapidTapPenaltyActive = false;
  final _playerFreezeTimer = PausableTimer();
  final _botFreezeTimer = PausableTimer();
  bool _isAppActive = true;
  DateTime? _lastPlayerTapAt;
  int _rapidTapCount = 0;
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
  Duration get playerFreezeRemaining =>
      _isPlayerFrozen && !_isRapidTapPenaltyActive
          ? _playerFreezeTimer.remaining
          : Duration.zero;
  Duration get botFreezeRemaining =>
      _isBotFrozen ? _botFreezeTimer.remaining : Duration.zero;
  int? get startCountdown => _startCountdown;
  int get sessionId => _sessionId;
  bool get canSelectStage =>
      _isAppActive &&
      (_status == GameStateStatus.ready ||
          _status == GameStateStatus.paused ||
          _status == GameStateStatus.ended);
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
    if (!canSelectStage ||
        stage < 1 ||
        stage > maxStage ||
        stage > _unlockedStage) {
      return false;
    }

    _currentStage = stage;
    initializeGame();
    return true;
  }

  void initializeGame() {
    _sessionId++;
    _startTimer?.cancel();
    _startCountdown = null;
    _status = GameStateStatus.ready;
    _timeLeft = maxTime;
    _outcome = null;
    _endReason = null;
    _isPlayerFrozen = false;
    _isBotFrozen = false;
    _isRapidTapPenaltyActive = false;
    _lastPlayerTapAt = null;
    _rapidTapCount = 0;
    _timer.cancel();
    _resultTimer?.cancel();
    _playerFreezeTimer.cancel();
    _botFreezeTimer.cancel();

    _board = List.generate(boardSize, (row) {
      return List.generate(boardSize, (col) {
        final owner = (row + col).isEven ? TileOwner.player : TileOwner.bot;
        return BoardTile(row: row, col: col, owner: owner);
      });
    });

    notifyListeners();
  }

  void startGame() {
    if (!_isAppActive) return;
    if (_status == GameStateStatus.paused) {
      _beginPlaying();
      return;
    }
    if (_status != GameStateStatus.ready && _status != GameStateStatus.ended) {
      return;
    }

    initializeGame();
    _status = GameStateStatus.starting;
    _startCountdown = 3;
    final session = _sessionId;
    _startTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (session != _sessionId || _status != GameStateStatus.starting) {
        timer.cancel();
        return;
      }
      if (_startCountdown == 1) {
        timer.cancel();
        _startCountdown = null;
        _beginPlaying();
      } else {
        _startCountdown = _startCountdown! - 1;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _beginPlaying() {
    _status = GameStateStatus.playing;
    if (_timer.isPending) {
      _timer.resume();
    } else {
      _startGameTimer();
    }
    _playerFreezeTimer.resume();
    _botFreezeTimer.resume();
    notifyListeners();
  }

  void pauseGame() {
    if (_status != GameStateStatus.playing) return;

    _status = GameStateStatus.paused;
    _timer.pause();
    _playerFreezeTimer.pause();
    _botFreezeTimer.pause();
    _lastPlayerTapAt = null;
    _rapidTapCount = 0;
    notifyListeners();
  }

  void setAppActive(bool active) {
    if (_isAppActive == active) return;
    _isAppActive = active;
    if (!active && _status == GameStateStatus.starting) {
      initializeGame();
    } else if (!active && _status == GameStateStatus.playing) {
      pauseGame();
    } else {
      notifyListeners();
    }
  }

  bool flipTile(int row, int col, TileOwner owner) {
    if (_status != GameStateStatus.playing) return false;
    if (!_isInBounds(row, col) || owner == TileOwner.none) return false;
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

    _checkBoardCoveredWin();
    if (_status == GameStateStatus.playing) notifyListeners();
    return true;
  }

  void endGame() {
    if (_status != GameStateStatus.playing) return;
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

  void _startGameTimer() {
    final session = _sessionId;
    _timer.start(const Duration(seconds: 1), () {
      if (session != _sessionId || _status != GameStateStatus.playing) {
        return;
      }
      if (_timeLeft <= 1) {
        _timeLeft = 0;
        endGame();
        return;
      }

      _timeLeft--;
      _checkBoardCoveredWin();
      if (session == _sessionId && _status == GameStateStatus.playing) {
        _startGameTimer();
        notifyListeners();
      }
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
      _botFreezeTimer.start(freezeDuration, () {
        _isBotFrozen = false;
        notifyListeners();
      });
      return;
    }

    _isPlayerFrozen = true;
    _isRapidTapPenaltyActive = false;
    _playerFreezeTimer.start(freezeDuration, () {
      _isPlayerFrozen = false;
      notifyListeners();
    });
  }

  bool _registerPlayerTap() {
    final now = clock.now();
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
    _playerFreezeTimer.start(_rapidTapPenaltyDuration, () {
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
    if (_status != GameStateStatus.playing) return;
    _timer.cancel();
    _resultTimer?.cancel();
    _playerFreezeTimer.cancel();
    _botFreezeTimer.cancel();
    _isPlayerFrozen = false;
    _isBotFrozen = false;
    _isRapidTapPenaltyActive = false;
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

    final session = _sessionId;
    _resultTimer = Timer(_resultDelay, () {
      if (session != _sessionId || _status != GameStateStatus.finishing) return;
      _status = GameStateStatus.ended;
      notifyListeners();
    });
    notifyListeners();
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
    _sessionId++;
    _startTimer?.cancel();
    _timer.cancel();
    _resultTimer?.cancel();
    _playerFreezeTimer.cancel();
    _botFreezeTimer.cancel();
    super.dispose();
  }
}
