import 'dart:math';

import 'package:card_game/domain/bot_ai.dart';
import 'package:card_game/domain/game_state.dart';
import 'package:card_game/domain/campaign_config.dart';
import 'package:card_game/presentation/bot_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final difficulty in BotDifficulty.values) {
    testWidgets('BOT-02 $difficulty includes travel in every turn interval',
        (tester) async {
      final game = await _playing(tester);
      final bot = BotAI(
        gameState: game,
        difficulty: difficulty,
        random: _FixedRandom(),
      )..start();
      addTearDown(bot.dispose);
      final interval = switch (difficulty) {
        BotDifficulty.easy => const Duration(milliseconds: 1200),
        BotDifficulty.medium => const Duration(milliseconds: 800),
        BotDifficulty.hard => const Duration(milliseconds: 400),
      };
      final started = tester.binding.clock.now();
      for (var turn = 1; turn <= 5; turn++) {
        final target = bot.target!;
        // Keep multiple flippable tiles without ending the test game.
        for (final tile in game.board.expand((row) => row)) {
          tile.type = TileType.normal;
          tile.owner =
              (tile.row + tile.col).isEven ? TileOwner.player : TileOwner.bot;
        }
        target.owner = TileOwner.player;
        final score = game.botScore;
        final origin = bot.position;
        expect(bot.actionRemaining + BotAI.movementDuration, interval);
        await tester.pump(bot.actionRemaining);
        expect(bot.isMoving, isTrue);
        expect(bot.position, origin);
        expect(game.botScore, score);
        await tester.pump(const Duration(milliseconds: 100));
        expect(bot.target, same(target));
        expect(bot.movementProgress, 0.5);
        expect(bot.position,
            Point((origin.x + target.col) / 2, (origin.y + target.row) / 2));
        expect(game.botScore, score);
        await tester.pump(const Duration(milliseconds: 99));
        expect(game.botScore, score);
        await tester.pump(const Duration(milliseconds: 1));
        expect(bot.arrivalCount, turn);
        expect(
            bot.position, Point(target.col.toDouble(), target.row.toDouble()));
        expect(target.owner, TileOwner.bot);
        expect(game.botScore, score + 1);
        expect(tester.binding.clock.now().difference(started), interval * turn);
      }
      bot.stop();
      game.initializeGame();
    });
  }

  testWidgets('BOT-02 difficulty upper bounds keep their original intervals',
      (tester) async {
    final game = await _playing(tester);
    for (final difficulty in BotDifficulty.values) {
      final bot = BotAI(
        gameState: game,
        difficulty: difficulty,
        random: _FixedRandom(value: 0.999999),
      )..start();
      final maximum = switch (difficulty) {
        BotDifficulty.easy => const Duration(milliseconds: 1800),
        BotDifficulty.medium => const Duration(milliseconds: 1200),
        BotDifficulty.hard => const Duration(milliseconds: 800),
      };
      expect(bot.actionRemaining + BotAI.movementDuration, maximum);
      bot.dispose();
    }
    game.initializeGame();
  });

  for (final type in [TileType.bomb, TileType.line, TileType.freeze]) {
    testWidgets('BOT-02 arrival uses the latest $type on its retained target',
        (tester) async {
      final game = await _playing(tester);
      final bot = BotAI(
          gameState: game,
          difficulty: BotDifficulty.easy,
          random: _FixedRandom())
        ..start();
      addTearDown(bot.dispose);
      final target = bot.target!;
      await tester.pump(bot.actionRemaining);
      await tester.pump(const Duration(milliseconds: 100));
      target.type = type;
      expect(bot.target, same(target));
      expect(target.owner, TileOwner.player);
      await tester.pump(const Duration(milliseconds: 100));
      expect(target.owner, TileOwner.bot);
      if (type == TileType.freeze) {
        expect(game.isPlayerFrozen, isTrue);
      } else {
        for (final tile in game.board.expand((row) => row)) {
          final affected = type == TileType.line
              ? tile.row == target.row || tile.col == target.col
              : (tile.row - target.row).abs() <= 1 &&
                  (tile.col - target.col).abs() <= 1;
          if (affected) expect(tile.owner, TileOwner.bot);
        }
      }
      bot.stop();
      game.initializeGame();
    });
  }

  testWidgets(
      'BOT-02 an item can claim the target without an extra arrival flip',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.easy, random: _FixedRandom())
      ..start();
    addTearDown(bot.dispose);
    final target = bot.target!;
    await tester.pump(bot.actionRemaining);
    await tester.pump(const Duration(milliseconds: 100));
    game.board[0][1].type = TileType.bomb;
    game.flipTile(0, 1, TileOwner.bot);
    for (final tile in game.board.expand((row) => row)) {
      tile.type = TileType.normal;
    }
    expect(target.owner, TileOwner.bot);
    final score = game.botScore;
    var notifications = 0;
    game.addListener(() => notifications++);
    await tester.pump(const Duration(milliseconds: 100));
    expect(bot.arrivalCount, 1);
    expect(bot.position, Point(target.col.toDouble(), target.row.toDouble()));
    expect(game.botScore, score);
    expect(notifications, 0);
    expect(bot.isMoving, isFalse);
    expect(bot.actionRemaining, const Duration(milliseconds: 1000));
    bot.stop();
    game.initializeGame();
  });

  testWidgets('BOT-02 player reclaim during travel is handled only at arrival',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.easy, random: _FixedRandom())
      ..start();
    addTearDown(bot.dispose);
    final target = bot.target!;
    await tester.pump(bot.actionRemaining);
    await tester.pump(const Duration(milliseconds: 100));
    game.flipTile(target.row, target.col, TileOwner.bot);
    target.type = TileType.normal;
    game.flipTile(target.row, target.col, TileOwner.player);
    target.type = TileType.normal;
    final score = game.botScore;
    await tester.pump(const Duration(milliseconds: 99));
    expect(target.owner, TileOwner.player);
    expect(bot.target, same(target));
    await tester.pump(const Duration(milliseconds: 1));
    expect(target.owner, TileOwner.bot);
    expect(game.botScore, score + 1);
    bot.stop();
    game.initializeGame();
  });

  testWidgets(
      'BOT-02 same-position item still arrives once on the original beat',
      (tester) async {
    final game = await _playing(tester);
    game.board[0][1].type = TileType.freeze;
    final bot = BotAI(
        gameState: game,
        difficulty: BotDifficulty.easy,
        random: _FixedRandom(index: 1))
      ..start();
    addTearDown(bot.dispose);
    final position = bot.position;
    expect(bot.target, same(game.board[0][1]));
    await tester.pump(bot.actionRemaining);
    await tester.pump(const Duration(milliseconds: 199));
    expect(bot.position, position);
    expect(bot.arrivalCount, 0);
    expect(game.isPlayerFrozen, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(bot.position, position);
    expect(bot.arrivalCount, 1);
    expect(game.isPlayerFrozen, isTrue);
    bot.stop();
    game.initializeGame();
  });

  testWidgets(
      'BOT-02 movement pause preserves position and the arrival remainder',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.easy, random: _FixedRandom())
      ..start();
    addTearDown(bot.dispose);
    final target = bot.target!;
    await tester.pump(bot.actionRemaining);
    await tester.pump(const Duration(milliseconds: 75));
    game.pauseGame();
    bot.pause();
    final position = bot.position;
    expect(bot.actionRemaining, const Duration(milliseconds: 125));
    await tester.pump(const Duration(seconds: 10));
    expect(bot.position, position);
    expect(bot.target, same(target));
    game.startGame();
    bot.start();
    await tester.pump(const Duration(milliseconds: 124));
    expect(target.owner, TileOwner.player);
    await tester.pump(const Duration(milliseconds: 1));
    expect(target.owner, TileOwner.bot);
    bot.stop();
    game.initializeGame();
  });

  testWidgets('BOT-02 same-position arrival has a small landing pulse',
      (tester) async {
    final game = await _playing(tester);
    game.board[0][1].type = TileType.freeze;
    final bot = BotAI(
        gameState: game,
        difficulty: BotDifficulty.easy,
        random: _FixedRandom(index: 1))
      ..start();
    await tester.pumpWidget(MaterialApp(
      home: Center(
          child: SizedBox.square(
        dimension: 240,
        child: BotCharacter(
          imageAsset: CampaignConfig.defaultBotImageAsset,
          boardSize: game.boardSize,
          row: 0,
          col: 1,
          tileSpacing: 5,
          botAI: bot,
        ),
      )),
    ));
    final image = find.byType(Image);
    final initial = tester.getRect(image);
    await tester.pump(bot.actionRemaining);
    await tester.pump(BotAI.movementDuration);
    expect(tester.getRect(image), initial);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getRect(image).width, closeTo(initial.width * 0.92, 0.001));
    expect(tester.getRect(image).center, initial.center);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getRect(image).width, closeTo(initial.width, 0.001));
    await tester.pumpWidget(const SizedBox.shrink());
    bot.dispose();
    game.initializeGame();
    expect(tester.takeException(), isNull);
  });

  for (final moving in [false, true]) {
    testWidgets('BOT-03 repeated freeze and background preserve moving=$moving',
        (tester) async {
      final game = await _playing(tester);
      final bot = BotAI(
          gameState: game,
          difficulty: BotDifficulty.easy,
          random: _FixedRandom())
        ..start();
      addTearDown(bot.dispose);
      if (moving) await tester.pump(bot.actionRemaining);
      await tester.pump(const Duration(milliseconds: 75));
      final target = bot.target;
      final remaining = bot.actionRemaining;
      final position = bot.position;
      void freeze() {
        game.board[3][3].type = TileType.freeze;
        expect(game.flipTile(3, 3, TileOwner.player), isTrue);
        for (final tile in game.board.expand((row) => row)) {
          tile.type = TileType.normal;
        }
      }

      freeze();
      expect(bot.isRunning, isFalse);
      expect(bot.position, position);
      await tester.pump(const Duration(milliseconds: 500));
      freeze();
      expect(game.botFreezeRemaining, GameState.freezeDuration);
      expect(bot.actionRemaining, remaining);
      game.setAppActive(false);
      game.setAppActive(false);
      await tester.pump(const Duration(seconds: 10));
      game.setAppActive(true);
      await tester.pump(const Duration(seconds: 10));
      expect(game.status, GameStateStatus.paused);
      expect(game.botFreezeRemaining, GameState.freezeDuration);
      expect(bot.position, position);
      expect(bot.target, same(target));
      game.startGame();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(bot.isRunning, isFalse);
      expect(bot.actionRemaining, remaining);
      await tester.pump(const Duration(milliseconds: 1));
      expect(bot.isRunning, isTrue);
      expect(bot.position, position);
      if (!moving) {
        await tester.pump(remaining);
        expect(bot.isMoving, isTrue);
      }
      await tester.pump(moving ? remaining : BotAI.movementDuration);
      expect(bot.arrivalCount, 1);
      expect(target!.owner, TileOwner.bot);
      bot.stop();
      game.initializeGame();
    });

    testWidgets('BOT-03 repeated manual pauses preserve moving=$moving',
        (tester) async {
      final game = await _playing(tester);
      final bot = BotAI(
          gameState: game,
          difficulty: BotDifficulty.easy,
          random: _FixedRandom())
        ..start();
      addTearDown(bot.dispose);
      if (moving) await tester.pump(bot.actionRemaining);
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 2; i++) {
        game.pauseGame();
        final position = bot.position;
        final remaining = bot.actionRemaining;
        await tester.pump(const Duration(seconds: 10));
        expect(bot.position, position);
        expect(bot.actionRemaining, remaining);
        game.startGame();
        expect(bot.isRunning, isTrue);
        await tester.pump(const Duration(milliseconds: 10));
      }
      final target = bot.target!;
      await tester.pump(bot.actionRemaining);
      if (!moving) await tester.pump(BotAI.movementDuration);
      expect(target.owner, TileOwner.bot);
      bot.stop();
      game.initializeGame();
    });
  }

  for (final penalty in [false, true]) {
    testWidgets(
        'BOT-03 player-only stop leaves the bot moving, penalty=$penalty',
        (tester) async {
      final game = await _playing(tester);
      final bot = BotAI(
          gameState: game,
          difficulty: BotDifficulty.easy,
          random: _FixedRandom())
        ..start();
      addTearDown(bot.dispose);
      await tester.pump(bot.actionRemaining);
      await tester.pump(const Duration(milliseconds: 75));
      final target = bot.target!;
      if (penalty) {
        for (var i = 0; i < 3; i++) {
          game.flipTile(0, 2, TileOwner.player);
        }
      } else {
        game.board[3][2].type = TileType.freeze;
        game.flipTile(3, 2, TileOwner.bot);
      }
      expect(game.isPlayerFrozen, isTrue);
      expect(game.isBotFrozen, isFalse);
      expect(bot.isRunning, isTrue);
      expect(bot.actionRemaining, const Duration(milliseconds: 125));
      await tester.pump(const Duration(milliseconds: 125));
      expect(target.owner, TileOwner.bot);
      expect(game.isPlayerFrozen, isTrue);
      bot.stop();
      game.initializeGame();
    });
  }

  testWidgets(
      'BOT-03 starting frozen queues a full turn and resumes automatically',
      (tester) async {
    final game = await _playing(tester);
    game.board[3][3].type = TileType.freeze;
    game.flipTile(3, 3, TileOwner.player);
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.easy, random: _FixedRandom())
      ..start();
    addTearDown(bot.dispose);
    expect(bot.isRunning, isFalse);
    expect(bot.actionRemaining, const Duration(milliseconds: 1000));
    await tester.pump(GameState.freezeDuration);
    expect(bot.isRunning, isTrue);
    expect(bot.actionRemaining, const Duration(milliseconds: 1000));
    bot.stop();
    game.initializeGame();
  });

  testWidgets(
      'BOT-03 pausing in the arrival notification keeps the settled position',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(
        gameState: game,
        difficulty: BotDifficulty.easy,
        random: _FixedRandom(index: 2))
      ..start();
    addTearDown(bot.dispose);
    final target = bot.target!;
    var paused = false;
    game.addListener(() {
      if (!paused && bot.arrivalCount == 1) {
        paused = true;
        game.pauseGame();
      }
    });
    await tester.pump(bot.actionRemaining);
    await tester.pump(BotAI.movementDuration);
    expect(paused, isTrue);
    expect(bot.position, Point(target.col.toDouble(), target.row.toDouble()));
    final settled = bot.position;
    await tester.pump(const Duration(seconds: 10));
    game.startGame();
    expect(bot.position, settled);
    expect(bot.arrivalCount, 1);
    expect(bot.actionRemaining, const Duration(milliseconds: 1000));
    bot.stop();
    game.initializeGame();
  });

  testWidgets('BOT-03 timeout wins when arrival shares its deadline',
      (tester) async {
    final game = await _playing(tester);
    await tester.pump(const Duration(milliseconds: 29600));
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.hard, random: _FixedRandom())
      ..start();
    addTearDown(bot.dispose);
    final target = bot.target!;
    await tester.pump(bot.actionRemaining);
    await tester.pump(BotAI.movementDuration);
    expect(game.status, GameStateStatus.finishing);
    expect(game.timeLeft, 0);
    expect(bot.arrivalCount, 0);
    expect(target.owner, TileOwner.player);
    game.initializeGame();
  });

  testWidgets('BOT-03 reset in a landing listener cannot schedule an old turn',
      (tester) async {
    final game = await _playing(tester);
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.easy, random: _FixedRandom())
      ..start();
    addTearDown(bot.dispose);
    var reset = false;
    bot.addListener(() {
      if (!reset && bot.arrivalCount == 1) {
        reset = true;
        game.initializeGame();
        game.startGame();
      }
    });
    await tester.pump(bot.actionRemaining);
    await tester.pump(BotAI.movementDuration);
    await tester.pump(const Duration(seconds: 3));
    expect(reset, isTrue);
    expect(bot.isRunning, isFalse);
    expect(game.botScore, 8);
    expect(bot.actionRemaining, Duration.zero);
    game.initializeGame();
  });

  testWidgets('BOT-03 stage changes discard the previous target and arrival',
      (tester) async {
    final game = await _playing(tester);
    for (final stage in [1, 2]) {
      final bot = BotAI(
          gameState: game,
          difficulty: BotDifficulty.easy,
          random: _FixedRandom())
        ..start();
      await tester.pump(bot.actionRemaining);
      await tester.pump(const Duration(milliseconds: 100));
      game.board[0][1].owner = TileOwner.player;
      game.endGame();
      expect(bot.isRunning, isFalse);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(game.selectStage(stage + 1), isTrue);
      game.startGame();
      await tester.pump(const Duration(seconds: 3));
      expect(game.botScore, game.totalTiles ~/ 2);
      expect(bot.arrivalCount, 0);
      expect(bot.target, isNull);
      bot.dispose();
    }
    game.initializeGame();
  });

  testWidgets(
      'BOT-03 disposing the game prevents a pending arrival from notifying',
      (tester) async {
    final game = GameState()..startGame();
    await tester.pump(const Duration(seconds: 3));
    final bot = BotAI(
        gameState: game, difficulty: BotDifficulty.easy, random: _FixedRandom())
      ..start();
    await tester.pump(bot.actionRemaining);
    await tester.pump(const Duration(milliseconds: 100));
    var notifications = 0;
    game.addListener(() => notifications++);
    game.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(notifications, 0);
    expect(bot.isRunning, isFalse);
    bot.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final cancel in ['stop', 'reset', 'finish', 'dispose']) {
    testWidgets('BOT-02 $cancel during travel prevents a late flip',
        (tester) async {
      final game = await _playing(tester);
      final bot = BotAI(
          gameState: game,
          difficulty: BotDifficulty.easy,
          random: _FixedRandom())
        ..start();
      final target = bot.target!;
      await tester.pump(bot.actionRemaining);
      await tester.pump(const Duration(milliseconds: 100));
      switch (cancel) {
        case 'stop':
          bot.stop();
        case 'reset':
          game.initializeGame();
          game.startGame();
        case 'finish':
          game.endGame();
        case 'dispose':
          bot.dispose();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(target.owner, TileOwner.player);
      if (cancel != 'dispose') bot.dispose();
      game.initializeGame();
    });
  }
}

Future<GameState> _playing(WidgetTester tester) async {
  final game = GameState()..startGame();
  addTearDown(game.dispose);
  await tester.pump(const Duration(seconds: 3));
  return game;
}

class _FixedRandom implements Random {
  _FixedRandom({this.value = 0, this.index = 0});
  final double value;
  final int index;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => index % max;
  @override
  bool nextBool() => false;
}
