import 'package:card_game/domain/bot_ai.dart';
import 'package:card_game/domain/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'pausing preserves the fractional game tick across repeated pauses',
      (tester) async {
    final game = await _playing(tester);
    await tester.pump(const Duration(milliseconds: 750));
    game.pauseGame();
    await tester.pump(const Duration(seconds: 60));
    expect(game.timeLeft, game.maxTime);
    game.startGame();
    await tester.pump(const Duration(milliseconds: 249));
    expect(game.timeLeft, game.maxTime);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.timeLeft, game.maxTime - 1);
    await tester.pump(const Duration(milliseconds: 500));
    game.pauseGame();
    await tester.pump(const Duration(seconds: 60));
    game.pauseGame();
    game.startGame();
    await tester.pump(const Duration(milliseconds: 499));
    expect(game.timeLeft, game.maxTime - 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.timeLeft, game.maxTime - 2);
    game.initializeGame();
  });

  for (final attacker in [TileOwner.player, TileOwner.bot]) {
    testWidgets('freeze by $attacker keeps its remaining duration while paused',
        (tester) async {
      final game = await _playing(tester);
      game.board[0][0].type = TileType.freeze;
      expect(game.flipTile(0, 0, attacker), isTrue);
      bool frozen() =>
          attacker == TileOwner.player ? game.isBotFrozen : game.isPlayerFrozen;
      await tester.pump(const Duration(milliseconds: 750));
      game.pauseGame();
      await tester.pump(const Duration(seconds: 30));
      expect(frozen(), isTrue);
      game.startGame();
      await tester.pump(const Duration(milliseconds: 1249));
      expect(frozen(), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(frozen(), isFalse);
      game.initializeGame();
    });
  }

  testWidgets('background keeps penalty paused until explicit resume',
      (tester) async {
    final game = await _playing(tester);
    for (var i = 0; i < 3; i++) {
      game.flipTile(0, 0, TileOwner.player);
    }
    expect(game.isRapidTapPenaltyActive, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    game.setAppActive(false);
    game.setAppActive(false);
    game.startGame();
    await tester.pump(const Duration(seconds: 30));
    expect(game.status, GameStateStatus.paused);
    expect(game.isRapidTapPenaltyActive, isTrue);
    game.setAppActive(true);
    await tester.pump(const Duration(seconds: 30));
    expect(game.status, GameStateStatus.paused);
    expect(game.isRapidTapPenaltyActive, isTrue);
    game.startGame();
    await tester.pump(const Duration(milliseconds: 599));
    expect(game.isPlayerFrozen, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.isPlayerFrozen, isFalse);
    expect(game.isRapidTapPenaltyActive, isFalse);
    game.initializeGame();
  });

  testWidgets('leaving during countdown cancels it and blocks hidden starts',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(seconds: 1));
    game.setAppActive(false);
    expect(game.status, GameStateStatus.ready);
    expect(game.startCountdown, isNull);
    game.startGame();
    expect(game.selectStage(1), isFalse);
    await tester.pump(const Duration(seconds: 10));
    game.setAppActive(true);
    expect(game.status, GameStateStatus.ready);
    game.startGame();
    expect(game.startCountdown, 3);
    await tester.pump(const Duration(seconds: 3));
    expect(game.timeLeft, game.maxTime);
    game.initializeGame();
  });

  testWidgets('reset discards paused effect and fractional tick',
      (tester) async {
    final game = await _playing(tester);
    game.board[0][0].type = TileType.freeze;
    game.flipTile(0, 0, TileOwner.bot);
    await tester.pump(const Duration(milliseconds: 900));
    game.pauseGame();
    game.initializeGame();
    game.startGame();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 999));
    expect(game.timeLeft, game.maxTime);
    expect(game.isPlayerFrozen, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.timeLeft, game.maxTime - 1);
    game.initializeGame();
  });

  testWidgets('bot resumes its remaining turn delay instead of a fresh delay',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(gameState: game, difficulty: BotDifficulty.easy)..start();
    addTearDown(bot.stop);
    await tester.pump(const Duration(milliseconds: 1100));
    game.pauseGame();
    bot.pause();
    await tester.pump(const Duration(seconds: 30));
    bot.pause();
    expect(game.botScore, 8);
    game.startGame();
    bot.start();
    await tester.pump(const Duration(milliseconds: 99));
    expect(game.botScore, 8);
    await tester.pump(const Duration(milliseconds: 602));
    expect(game.botScore, greaterThan(8));
    bot.stop();
    game.initializeGame();
  });

  testWidgets('last second expires only after its resumed remainder',
      (tester) async {
    final game = await _playing(tester);
    await tester.pump(Duration(milliseconds: game.maxTime * 1000 - 300));
    game.pauseGame();
    await tester.pump(const Duration(seconds: 30));
    expect(game.timeLeft, 1);
    game.startGame();
    await tester.pump(const Duration(milliseconds: 299));
    expect(game.status, GameStateStatus.playing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.timeLeft, 0);
    expect(game.status, GameStateStatus.finishing);
    game.initializeGame();
  });
}

Future<GameState> _playing(WidgetTester tester) async {
  final game = GameState()..startGame();
  addTearDown(game.dispose);
  await tester.pump(const Duration(seconds: 3));
  return game;
}
