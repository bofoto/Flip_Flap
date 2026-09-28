import 'package:card_game/domain/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final interval in [0, 349000, 350000, 350001, 351000]) {
    testWidgets('three distinct captures at ${interval}us intervals',
        (tester) async {
      final game = await _playing(tester);
      final gap = Duration(microseconds: interval);
      expect(_normalFlip(game, 0, 1), isTrue);
      await tester.pump(gap);
      expect(_normalFlip(game, 0, 3), isTrue);
      expect(game.isRapidTapPenaltyActive, isFalse);
      await tester.pump(gap);
      final penalized = interval <= 350000;
      expect(_normalFlip(game, 1, 0), !penalized);
      expect(game.isRapidTapPenaltyActive, penalized);
      expect(game.isPlayerFrozen, penalized);
      expect(
          game.board[1][0].owner, penalized ? TileOwner.bot : TileOwner.player);
      expect(game.playerScore, penalized ? 10 : 11);
      game.initializeGame();
    });
  }

  testWidgets('repeated own normal tile taps count despite doing nothing',
      (tester) async {
    final game = await _playing(tester);
    for (var tap = 1; tap <= 3; tap++) {
      expect(game.flipTile(0, 0, TileOwner.player), isFalse);
      expect(game.isRapidTapPenaltyActive, tap == 3);
      expect(game.playerScore, 8);
    }
    game.initializeGame();
  });

  testWidgets('own tile taps and successful captures share one counter',
      (tester) async {
    final game = await _playing(tester);
    expect(game.flipTile(0, 0, TileOwner.player), isFalse);
    expect(_normalFlip(game, 0, 1), isTrue);
    expect(_normalFlip(game, 0, 3), isFalse);
    expect(game.isRapidTapPenaltyActive, isTrue);
    expect(game.playerScore, 9);
    game.initializeGame();
  });

  testWidgets('a gap over 350ms starts a new chain rather than a penalty',
      (tester) async {
    final game = await _playing(tester);
    game.flipTile(0, 0, TileOwner.player);
    await tester.pump(const Duration(milliseconds: 100));
    game.flipTile(0, 0, TileOwner.player);
    await tester.pump(const Duration(milliseconds: 351));
    game.flipTile(0, 0, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isFalse);
    await tester.pump(const Duration(milliseconds: 350));
    game.flipTile(0, 0, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isFalse);
    await tester.pump(const Duration(milliseconds: 350));
    game.flipTile(0, 0, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isTrue);
    game.initializeGame();
  });

  testWidgets('invalid coordinates and no owner do not count as taps',
      (tester) async {
    final game = await _playing(tester);
    game.flipTile(0, 0, TileOwner.player);
    for (final (row, col, owner) in [
      (-1, 0, TileOwner.player),
      (0, -1, TileOwner.player),
      (game.boardSize, 0, TileOwner.player),
      (0, game.boardSize, TileOwner.player),
      (0, 1, TileOwner.none),
    ]) {
      expect(game.flipTile(row, col, owner), isFalse);
    }
    game.flipTile(0, 0, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isFalse);
    game.flipTile(0, 0, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isTrue);
    game.initializeGame();
  });

  testWidgets('bot actions neither trigger nor clear the player tap chain',
      (tester) async {
    final game = await _playing(tester);
    game.flipTile(0, 0, TileOwner.player);
    game.flipTile(0, 0, TileOwner.player);
    for (final (row, col) in [(0, 0), (0, 2), (1, 1)]) {
      expect(_normalFlip(game, row, col, TileOwner.bot), isTrue);
    }
    expect(game.isPlayerFrozen, isFalse);
    expect(game.isBotFrozen, isFalse);
    expect(_normalFlip(game, 0, 3), isFalse);
    expect(game.isRapidTapPenaltyActive, isTrue);
    expect(_normalFlip(game, 2, 0, TileOwner.bot), isTrue);
    game.initializeGame();
  });

  testWidgets('penalized third tap does not consume a special tile',
      (tester) async {
    final game = await _playing(tester);
    game.flipTile(0, 0, TileOwner.player);
    game.flipTile(0, 0, TileOwner.player);
    game.board[0][1].type = TileType.freeze;
    expect(game.flipTile(0, 1, TileOwner.player), isFalse);
    expect(game.board[0][1].owner, TileOwner.bot);
    expect(game.board[0][1].type, TileType.freeze);
    expect(game.isBotFrozen, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(game.flipTile(0, 1, TileOwner.player), isTrue);
    expect(game.isBotFrozen, isTrue);
    game.initializeGame();
  });

  testWidgets('extra frozen taps do not extend the exact one second penalty',
      (tester) async {
    final game = await _playing(tester);
    _triggerPenalty(game);
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.flipTile(0, 1, TileOwner.player), isFalse);
    }
    await tester.pump(const Duration(milliseconds: 99));
    expect(game.rapidTapPenaltyRemaining, const Duration(milliseconds: 1));
    expect(game.isPlayerFrozen, isTrue);
    expect(game.isRapidTapPenaltyActive, isTrue);
    expect(game.playerScore, 8);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.isPlayerFrozen, isFalse);
    expect(game.isRapidTapPenaltyActive, isFalse);
    expect(game.timeLeft, game.maxTime - 1);
    expect(game.rapidTapPenaltyRemaining, Duration.zero);
    expect(_normalFlip(game, 0, 1), isTrue);
    expect(_normalFlip(game, 0, 3), isTrue);
    expect(_normalFlip(game, 1, 0), isFalse);
    expect(game.isRapidTapPenaltyActive, isTrue);
    game.initializeGame();
  });

  testWidgets('bot freeze replaces penalty with a fresh two second freeze',
      (tester) async {
    final game = await _playing(tester);
    _triggerPenalty(game);
    await tester.pump(const Duration(milliseconds: 400));
    game.board[0][0].type = TileType.freeze;
    expect(game.flipTile(0, 0, TileOwner.bot), isTrue);
    expect(game.isRapidTapPenaltyActive, isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.rapidTapPenaltyRemaining, Duration.zero);
    expect(game.isPlayerFrozen, isTrue);
    for (var i = 0; i < 3; i++) {
      expect(game.flipTile(0, 1, TileOwner.player), isFalse);
    }
    expect(game.isRapidTapPenaltyActive, isFalse);
    await tester.pump(const Duration(milliseconds: 1399));
    expect(game.isPlayerFrozen, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(game.isPlayerFrozen, isFalse);
    expect(_normalFlip(game, 0, 1), isTrue);
    expect(_normalFlip(game, 0, 3), isTrue);
    expect(game.isRapidTapPenaltyActive, isFalse);
    game.initializeGame();
  });

  for (final background in [false, true]) {
    testWidgets('pause clears a two-tap chain (background: $background)',
        (tester) async {
      final game = await _playing(tester);
      game.flipTile(0, 0, TileOwner.player);
      game.flipTile(0, 0, TileOwner.player);
      if (background) {
        game.setAppActive(false);
      } else {
        game.pauseGame();
      }
      for (var i = 0; i < 3; i++) {
        expect(game.flipTile(0, 1, TileOwner.player), isFalse);
      }
      if (background) game.setAppActive(true);
      game.startGame();
      // No time elapses: only clearing history can prevent a third-tap penalty.
      expect(_normalFlip(game, 0, 1), isTrue);
      expect(_normalFlip(game, 0, 3), isTrue);
      expect(_normalFlip(game, 1, 0), isFalse);
      expect(game.isRapidTapPenaltyActive, isTrue);
      game.initializeGame();
    });
  }

  for (final reason in GameEndReason.values) {
    testWidgets('ending by $reason clears an active penalty and its callback',
        (tester) async {
      final game = await _playing(tester);
      if (reason == GameEndReason.timeExpired) {
        await tester.pump(Duration(milliseconds: game.maxTime * 1000 - 200));
      }
      _triggerPenalty(game);
      if (reason == GameEndReason.timeExpired) {
        await tester.pump(const Duration(milliseconds: 200));
      } else {
        for (final tile in game.board.expand((row) => row)) {
          tile.owner = TileOwner.bot;
          tile.type = TileType.normal;
        }
        game.board[0][0].owner = TileOwner.player;
        expect(game.flipTile(0, 0, TileOwner.bot), isTrue);
      }
      expect(game.status, GameStateStatus.finishing);
      expect(game.endReason, reason);
      expect(game.isPlayerFrozen, isFalse);
      expect(game.isRapidTapPenaltyActive, isFalse);
      var notifications = 0;
      expect(game.rapidTapPenaltyRemaining, Duration.zero);
      game.addListener(() => notifications++);
      await tester.pump(const Duration(milliseconds: 1399));
      expect(notifications, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(game.status, GameStateStatus.ended);
      expect(notifications, 1);
      game.initializeGame();
    });
  }

  testWidgets('dispose cancels simultaneous bot freeze and player penalty',
      (tester) async {
    final game = GameState()..startGame();
    await tester.pump(const Duration(seconds: 3));
    game.board[0][1].type = TileType.freeze;
    game.flipTile(0, 1, TileOwner.player);
    game.flipTile(0, 0, TileOwner.player);
    game.flipTile(0, 0, TileOwner.player);
    expect(game.isBotFrozen, isTrue);
    expect(game.isRapidTapPenaltyActive, isTrue);
    var notifications = 0;
    game.addListener(() => notifications++);
    game.dispose();
    await tester.pump(const Duration(seconds: 40));
    expect(notifications, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<GameState> _playing(WidgetTester tester) async {
  final game = GameState()..startGame();
  addTearDown(game.dispose);
  await tester.pump(const Duration(seconds: 3));
  return game;
}

bool _normalFlip(GameState game, int row, int col,
    [TileOwner owner = TileOwner.player]) {
  // Isolate tap rules from random item spawns on previous successful flips.
  game.board[row][col].type = TileType.normal;
  return game.flipTile(row, col, owner);
}

void _triggerPenalty(GameState game) {
  for (var i = 0; i < 3; i++) {
    game.flipTile(0, 0, TileOwner.player);
  }
  expect(game.isRapidTapPenaltyActive, isTrue);
  expect(game.rapidTapPenaltyRemaining, GameState.rapidTapPenaltyDuration);
}
