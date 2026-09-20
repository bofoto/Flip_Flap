import 'package:card_game/domain/bot_ai.dart';
import 'package:card_game/domain/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('countdown locks input and repeated starts do not restart it',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    final session = game.sessionId;
    final score = game.playerScore;
    expect(game.selectStage(1), isFalse);
    expect(game.flipTile(0, 1, TileOwner.player), isFalse);
    expect(game.flipTile(0, 0, TileOwner.bot), isFalse);
    game.endGame();
    game.pauseGame();
    await tester.pump(const Duration(seconds: 1));
    expect(game.startCountdown, 2);
    game.startGame();
    expect(game.sessionId, session);
    await tester.pump(const Duration(seconds: 1));
    expect(game.startCountdown, 1);
    expect(game.timeLeft, game.maxTime);
    await tester.pump(const Duration(seconds: 1));
    expect(game.status, GameStateStatus.playing);
    expect(game.startCountdown, isNull);
    expect(game.playerScore, score);
    expect(game.selectStage(1), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(game.timeLeft, game.maxTime - 1);
    game.initializeGame();
  });

  testWidgets('reset cancels old countdown across a stage change',
      (tester) async {
    final game = await _playing(tester);
    game.board[0][1].owner = TileOwner.player;
    game.endGame();
    await tester.pump(const Duration(milliseconds: 1400));
    game.initializeGame();
    game.startGame();
    await tester.pump(const Duration(seconds: 2));
    game.initializeGame();
    expect(game.selectStage(2), isTrue);
    game.startGame();
    await tester.pump(const Duration(seconds: 1));
    expect(game.currentStage, 2);
    expect(game.status, GameStateStatus.starting);
    expect(game.startCountdown, 2);
    expect(game.timeLeft, game.maxTime);
    await tester.pump(const Duration(seconds: 2));
    expect(game.status, GameStateStatus.playing);
    expect(game.timeLeft, game.maxTime);
    game.initializeGame();
  });

  testWidgets('pause resumes immediately and reset discards old game ticks',
      (tester) async {
    final game = await _playing(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    game.pauseGame();
    expect(game.flipTile(0, 1, TileOwner.player), isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(game.timeLeft, game.maxTime - 1);
    game.startGame();
    expect(game.status, GameStateStatus.playing);
    expect(game.startCountdown, isNull);
    game.initializeGame();
    game.startGame();
    await tester.pump(const Duration(seconds: 3));
    expect(game.timeLeft, game.maxTime);
    await tester.pump(const Duration(seconds: 1));
    expect(game.timeLeft, game.maxTime - 1);
    game.pauseGame();
    expect(game.selectStage(1), isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(game.status, GameStateStatus.ready);
    expect(game.timeLeft, game.maxTime);
  });

  testWidgets('duplicate finish preserves outcome and original result deadline',
      (tester) async {
    final game = await _playing(tester);
    for (final tile in game.board.expand((row) => row)) {
      tile.owner = TileOwner.player;
    }
    game.board[0][0].owner = TileOwner.bot;
    game.flipTile(0, 0, TileOwner.player);
    expect(game.endReason, GameEndReason.boardCovered);
    expect(game.selectStage(2), isFalse);
    expect(game.flipTile(0, 0, TileOwner.bot), isFalse);
    await tester.pump(const Duration(milliseconds: 1000));
    game.endGame();
    game.startGame();
    game.pauseGame();
    expect(game.status, GameStateStatus.finishing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.status, GameStateStatus.ended);
    expect(game.outcome, GameOutcome.playerWin);
    expect(game.endReason, GameEndReason.boardCovered);
    game.endGame();
    expect(game.status, GameStateStatus.ended);
    expect(game.selectStage(2), isTrue);
  });

  testWidgets('reset from a finish listener cannot leave a result timer behind',
      (tester) async {
    final game = await _playing(tester);
    game.addListener(() {
      if (game.status == GameStateStatus.finishing) game.initializeGame();
    });
    game.endGame();
    game.startGame();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(game.status, GameStateStatus.starting);
    expect(game.outcome, isNull);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(game.status, GameStateStatus.playing);
    game.initializeGame();
  });

  testWidgets('reset cancels freeze and penalty callbacks from the old board',
      (tester) async {
    final game = await _playing(tester);
    game.board[0][1].type = TileType.freeze;
    game.flipTile(0, 1, TileOwner.player);
    game.board[0][0].type = TileType.freeze;
    game.flipTile(0, 0, TileOwner.player);
    game.flipTile(0, 3, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isTrue);
    expect(game.isBotFrozen, isTrue);
    game.initializeGame();
    var notifications = 0;
    game.addListener(() => notifications++);
    await tester.pump(const Duration(seconds: 3));
    expect(notifications, 0);
    expect(game.isPlayerFrozen, isFalse);
    expect(game.isBotFrozen, isFalse);
    expect(game.isRapidTapPenaltyActive, isFalse);
  });

  testWidgets('old bot turn cannot touch a new session', (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(gameState: game, difficulty: BotDifficulty.easy)..start();
    addTearDown(bot.stop);
    await tester.pump(const Duration(seconds: 1));
    game.initializeGame();
    game.startGame();
    await tester.pump(const Duration(seconds: 3));
    expect(game.botScore, game.totalTiles ~/ 2);
    expect(bot.isRunning, isFalse);
    bot.start();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(game.botScore, greaterThan(game.totalTiles ~/ 2));
    bot.stop();
    game.initializeGame();
  });

  testWidgets('stopping bot during its action prevents another scheduled turn',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(gameState: game, difficulty: BotDifficulty.easy)..start();
    addTearDown(bot.stop);
    game.addListener(() {
      if (game.botScore > game.totalTiles ~/ 2) bot.stop();
    });
    await tester.pump(const Duration(milliseconds: 1900));
    final score = game.botScore;
    expect(bot.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(game.botScore, score);
    game.initializeGame();
  });

  testWidgets('dispose cancels starting, running and finishing timers',
      (tester) async {
    for (final status in [
      GameStateStatus.starting,
      GameStateStatus.playing,
      GameStateStatus.finishing,
    ]) {
      final game = GameState()..startGame();
      if (status != GameStateStatus.starting) {
        await tester.pump(const Duration(seconds: 3));
      }
      if (status == GameStateStatus.finishing) game.endGame();
      game.dispose();
      await tester.pump(const Duration(seconds: 40));
      expect(tester.takeException(), isNull);
    }
  });
}

Future<GameState> _playing(WidgetTester tester) async {
  final game = GameState()..startGame();
  addTearDown(game.dispose);
  await tester.pump(const Duration(seconds: 3));
  return game;
}
