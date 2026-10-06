import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:card_game/domain/bot_ai.dart';
import 'package:card_game/domain/campaign_config.dart';
import 'package:card_game/domain/game_state.dart';
import 'package:card_game/main.dart';
import 'package:card_game/presentation/bot_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const directory = String.fromEnvironment('PREVIEW_FONT_DIRECTORY');
    if (directory.isEmpty) return;
    final textFont = ByteData.sublistView(
        await File('$directory/roboto-regular.ttf').readAsBytes());
    for (final family in ['Ahem', 'monospace', 'Roboto']) {
      await (FontLoader(family)..addFont(Future.value(textFont))).load();
    }
    final icons = ByteData.sublistView(
        await File('$directory/materialicons-regular.otf').readAsBytes());
    await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  });

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = _ImageHttpOverrides();
    addTearDown(() => HttpOverrides.global = previous);
  });

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final moving in [false, true]) {
      testWidgets(
          'BOT-03 frozen character and manual resume moving=$moving $viewport',
          (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = GameState();
        addTearDown(game.dispose);
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: game,
          child: const RepaintBoundary(
              key: ValueKey('freeze_preview'), child: NeonFlipApp()),
        ));
        game.startGame();
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        final character = find.byType(BotCharacter);
        final bot = tester.widget<BotCharacter>(character).botAI!;
        if (moving) await tester.pump(bot.actionRemaining);
        await tester.pump(const Duration(milliseconds: 75));
        final image =
            find.descendant(of: character, matching: find.byType(Image));
        final bounds = tester.getRect(image);
        final remaining = bot.actionRemaining;
        final target = bot.target!;
        game.board[0][2].type = TileType.freeze;
        game.flipTile(0, 2, TileOwner.player);
        for (final tile in game.board.expand((row) => row)) {
          tile.type = TileType.normal;
        }
        await tester.pump();
        final ice = find.byKey(const ValueKey('bot_character_freeze'));
        final snowflake =
            find.byKey(const ValueKey('bot_character_freeze_icon'));
        expect(ice, findsOneWidget);
        expect(snowflake, findsOneWidget);
        expect(tester.getRect(image), bounds);
        expect(tester.getRect(ice), bounds);
        expect(
            tester
                .widget<Semantics>(find
                    .descendant(of: character, matching: find.byType(Semantics))
                    .first)
                .properties
                .value,
            'Frozen');
        if (const bool.fromEnvironment('CAPTURE_BOT_FREEZE_PREVIEW')) {
          await _captureFreezePreview(tester, viewport,
              name: 'bot_freeze_${moving ? "moving" : "waiting"}');
        }
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump(const Duration(seconds: 5));
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('PAUSED'), findsOneWidget);
        expect(game.botFreezeRemaining, GameState.freezeDuration);
        expect(bot.actionRemaining, remaining);
        expect(tester.getRect(image), bounds);
        expect(bot.target, same(target));
        await tester.tap(find.text('RESUME'));
        await tester.pump(GameState.freezeDuration);
        expect(ice, findsNothing);
        expect(bot.isRunning, isTrue);
        expect(bot.actionRemaining, remaining);
        expect(tester.getRect(image), bounds);
        await tester.pump(remaining);
        if (!moving) await tester.pump(BotAI.movementDuration);
        expect(target.owner, TileOwner.bot);
        expect(bot.arrivalCount, 1);
        game.initializeGame();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('BOT-01 character stays inside all board corners',
      (tester) async {
    for (final size in [4, 5, 6]) {
      for (final row in [0, size - 1]) {
        for (final col in [0, size - 1]) {
          await tester.pumpWidget(MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: 240,
                child: BotCharacter(
                  imageAsset: CampaignConfig.defaultBotImageAsset,
                  boardSize: size,
                  row: row,
                  col: col,
                  tileSpacing: 5,
                ),
              ),
            ),
          ));
          final boardBounds = tester.getRect(find.byType(BotCharacter));
          final imageBounds = tester.getRect(find.byType(Image));
          expect(boardBounds.contains(imageBounds.topLeft), isTrue);
          expect(boardBounds.contains(imageBounds.bottomRight), isTrue);
        }
      }
    }
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final stage in [1, 2, 3]) {
      testWidgets('BOT-01 placement and touch at stage $stage $viewport',
          (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = GameState();
        addTearDown(game.dispose);
        while (game.currentStage < stage) {
          game.startGame();
          await tester.pump(const Duration(seconds: 3));
          game.board[0][1].owner = TileOwner.player;
          game.endGame();
          await tester.pump(const Duration(milliseconds: 1400));
          game.selectStage(game.currentStage + 1);
        }
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: game,
          child: const RepaintBoundary(
              key: ValueKey('freeze_preview'), child: NeonFlipApp()),
        ));
        final character = find.byType(BotCharacter);
        expect(character, findsNothing);
        game.startGame();
        await tester.pump();
        expect(character, findsNothing);
        await tester.pump(const Duration(seconds: 3));
        expect(character, findsOneWidget);
        final initialScore = game.botScore;
        expect(initialScore, game.boardSize * game.boardSize ~/ 2);
        final botImage =
            find.descendant(of: character, matching: find.byType(Image));
        final bounds = tester.getRect(botImage);
        final tile = find.byKey(const ValueKey('tile_0_1'));
        final tileBounds = tester.getRect(tile);
        final boardBounds =
            tester.getRect(find.byKey(ValueKey('board_grid_$stage')));
        expect(bounds.center.dx, closeTo(tileBounds.center.dx, 0.001));
        expect(bounds.center.dy, closeTo(tileBounds.center.dy, 0.001));
        expect(bounds.width, closeTo(tileBounds.width * 0.45, 0.001));
        expect(boardBounds.contains(bounds.topLeft), isTrue);
        expect(boardBounds.contains(bounds.bottomRight), isTrue);
        expect(bounds.top,
            greaterThan(tester.getRect(find.text('${game.maxTime}s')).bottom));
        if (const bool.fromEnvironment('CAPTURE_BOT_PREVIEW')) {
          await _captureFreezePreview(tester, viewport,
              name: 'bot_stage_$stage');
        }
        // Tap the actual character center, not an uncovered corner of the tile.
        await tester.tapAt(bounds.center);
        expect(game.board[0][1].owner, TileOwner.player);
        expect(game.botScore, initialScore - 1);
        await tester.pump(const Duration(milliseconds: 350));
        final currentBounds = tester.getRect(botImage);
        expect(boardBounds.contains(currentBounds.topLeft), isTrue);
        expect(boardBounds.contains(currentBounds.bottomRight), isTrue);
        game.pauseGame();
        await tester.pump();
        expect(character, findsOneWidget);
        expect(tester.getRect(botImage), currentBounds);
        game.initializeGame();
        await tester.pump();
        expect(character, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final asset in [
    CampaignConfig.defaultBotImageAsset,
    'assets/bot/card_bot_mint.png',
    'assets/bot/missing.png',
  ]) {
    testWidgets('BOT-01 theme image and fallback: $asset', (tester) async {
      final game = GameState(
        campaign: CampaignConfig(
          brandName: defaultCampaignConfig.brandName,
          backImageUrl: defaultCampaignConfig.backImageUrl,
          stages: defaultCampaignConfig.stages,
          botImageAsset: asset,
        ),
      )..startGame();
      addTearDown(game.dispose);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: game,
        child: const RepaintBoundary(
            key: ValueKey('freeze_preview'), child: NeonFlipApp()),
      ));
      final character = find.byType(BotCharacter);
      final context = tester.element(character);
      await tester.runAsync(() async {
        await precacheImage(
            const AssetImage(CampaignConfig.defaultBotImageAsset), context);
        await precacheImage(AssetImage(asset), context,
            onError: (error, stackTrace) {});
      });
      await tester.pump();
      final images = tester.widgetList<Image>(
          find.descendant(of: character, matching: find.byType(Image)));
      expect((images.first.image as AssetImage).assetName, asset);
      final displayed = images.last.image as AssetImage;
      expect(
          displayed.assetName,
          asset.endsWith('missing.png')
              ? CampaignConfig.defaultBotImageAsset
              : asset);
      expect(
          tester
              .renderObject<RenderImage>(find
                  .descendant(of: character, matching: find.byType(RawImage))
                  .last)
              .image,
          isNotNull);
      expect(game.botScore, 8);
      expect(game.timeLeft, 30);
      expect(game.campaign.stages, same(defaultCampaignConfig.stages));
      if (const bool.fromEnvironment('CAPTURE_BOT_PREVIEW') &&
          asset.endsWith('mint.png')) {
        await _captureFreezePreview(tester, const Size(800, 600),
            name: 'bot_mint');
      }
      await tester.tapAt(tester
          .getRect(find
              .descendant(of: character, matching: find.byType(RawImage))
              .last)
          .center);
      expect(game.board[0][1].owner, TileOwner.player);
      game.endGame();
      await tester.pump();
      expect(character, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1400));
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final stage in [1, 2, 3]) {
      testWidgets(
          'BOT-02 rendered movement and touch at stage $stage $viewport',
          (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = GameState();
        addTearDown(game.dispose);
        while (game.currentStage < stage) {
          game.startGame();
          await tester.pump(const Duration(seconds: 3));
          game.board[0][1].owner = TileOwner.player;
          game.endGame();
          await tester.pump(const Duration(milliseconds: 1400));
          game.selectStage(game.currentStage + 1);
        }
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: game,
          child: const RepaintBoundary(
              key: ValueKey('freeze_preview'), child: NeonFlipApp()),
        ));
        game.startGame();
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        if (stage == 3) {
          // Hard can choose an owned card; give this geometry test one priority
          // target so it always checks a journey across the board.
          game.board.last.last.type = TileType.freeze;
        }
        await tester.pump(const Duration(seconds: 1));
        final character = find.byType(BotCharacter);
        final bot = tester.widget<BotCharacter>(character).botAI!;
        final image =
            find.descendant(of: character, matching: find.byType(Image));
        final origin = tester.getRect(image).center;
        final target = bot.target!;
        final destination = tester
            .getRect(find.byKey(ValueKey('tile_${target.row}_${target.col}')))
            .center;
        final score = game.botScore;
        await tester.pump(bot.actionRemaining);
        expect(tester.getRect(image).center, origin);
        if (const bool.fromEnvironment('CAPTURE_BOT_MOVEMENT_PREVIEW')) {
          await _captureFreezePreview(tester, viewport,
              name: 'bot_move_stage_${stage}_start');
        }
        var gameNotifications = 0;
        game.addListener(() => gameNotifications++);
        final time = game.timeLeft;
        await tester.pump(const Duration(milliseconds: 50));
        expect(
            (tester.getRect(image).center -
                    Offset.lerp(origin, destination, 0.25)!)
                .distance,
            lessThan(0.001));
        await tester.pump(const Duration(milliseconds: 50));
        final middle = tester.getRect(image);
        expect(
            (middle.center - Offset.lerp(origin, destination, 0.5)!).distance,
            lessThan(0.001));
        expect(middle.center, isNot(origin));
        expect(game.botScore, score);
        // Frames refresh only the character; game notifications are timer ticks.
        expect(gameNotifications, time - game.timeLeft);
        if (const bool.fromEnvironment('CAPTURE_BOT_MOVEMENT_PREVIEW')) {
          await _captureFreezePreview(tester, viewport,
              name: 'bot_move_stage_${stage}_middle');
        }
        await tester.pump(const Duration(milliseconds: 99));
        // A moving character must still pass a tap to the card beneath it.
        for (final tile in game.board.expand((row) => row)) {
          tile.type = TileType.normal;
        }
        game.flipTile(target.row, target.col, TileOwner.bot);
        target.type = TileType.normal;
        await tester.pump();
        await tester.tapAt(tester.getRect(image).center);
        expect(target.owner, TileOwner.player);
        await tester.pump(const Duration(milliseconds: 1));
        expect((tester.getRect(image).center - destination).distance,
            lessThan(0.001));
        expect(target.owner, TileOwner.bot);
        expect(game.botScore, score + 1);
        final board = tester.getRect(find.byKey(ValueKey('board_grid_$stage')));
        expect(board.contains(middle.topLeft), isTrue);
        expect(board.contains(middle.bottomRight), isTrue);
        if (const bool.fromEnvironment('CAPTURE_BOT_MOVEMENT_PREVIEW')) {
          await _captureFreezePreview(tester, viewport,
              name: 'bot_move_stage_${stage}_arrival');
        }
        game.initializeGame();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600)
  ]) {
    for (final target in [TileOwner.player, TileOwner.bot]) {
      testWidgets('$target freeze presentation and pause at $viewport',
          (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = GameState()..startGame();
        addTearDown(game.dispose);
        await tester.pump(const Duration(seconds: 3));
        game.board[0][0].type = TileType.freeze;
        game.flipTile(0, 0,
            target == TileOwner.player ? TileOwner.bot : TileOwner.player);
        for (final tile in game.board.expand((row) => row)) {
          tile.type = TileType.normal;
        }
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: game,
          child: const RepaintBoundary(
              key: ValueKey('freeze_preview'), child: NeonFlipApp()),
        ));
        final player = target == TileOwner.player;
        final status = find.byKey(
            ValueKey(player ? 'player_freeze_status' : 'bot_freeze_status'));
        final frost = find.byKey(const ValueKey('player_frost_overlay'));
        expect(status, findsOneWidget);
        expect(frost, player ? findsOneWidget : findsNothing);
        expect(
            find.text(player ? 'YOU FROZEN!' : 'BOT FROZEN!'), findsOneWidget);
        expect(find.text('2.0s'), findsOneWidget);
        expect(tester.getSize(find.text('2.0s')).height, lessThanOrEqualTo(16));
        expect(
            tester
                .getSize(find.text(player ? 'YOU FROZEN!' : 'BOT FROZEN!'))
                .height,
            lessThanOrEqualTo(16));
        final board = find.byKey(const ValueKey('board_grid_1'));
        final boardBounds = tester.getRect(board);
        if (player) expect(tester.getRect(frost), boardBounds);
        expect(tester.getRect(status).bottom, lessThan(boardBounds.top));
        final bar = find.descendant(
            of: status, matching: find.byType(LinearProgressIndicator));
        expect(tester.widget<LinearProgressIndicator>(bar).value, 1);
        if (player && const bool.fromEnvironment('CAPTURE_FREEZE_PREVIEW')) {
          await _captureFreezePreview(tester, viewport);
        }
        final score = game.playerScore;
        await tester.tap(find.byKey(const ValueKey('tile_0_1')),
            warnIfMissed: !player);
        expect(game.playerScore, player ? score : score + 1);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('1.5s'), findsOneWidget);
        expect(tester.widget<LinearProgressIndicator>(bar).value, 0.75);
        game.setAppActive(false);
        await tester.pump(const Duration(seconds: 10));
        game.setAppActive(true);
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('1.5s'), findsOneWidget);
        expect(find.text('PAUSED'), findsOneWidget);
        expect(tester.getRect(board), boardBounds);
        await tester.tap(find.text('RESUME'));
        await tester.pump(const Duration(milliseconds: 1499));
        expect(status, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(status, findsNothing);
        expect(frost, findsNothing);
        game.initializeGame();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600)
  ]) {
    for (final stage in [1, 3]) {
      testWidgets(
          'stage $stage penalty progress pause and retrigger at $viewport',
          (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = GameState();
        addTearDown(game.dispose);
        while (game.currentStage < stage) {
          game.startGame();
          await tester.pump(const Duration(seconds: 3));
          game.board[0][1].owner = TileOwner.player;
          game.endGame();
          await tester.pump(const Duration(milliseconds: 1400));
          game.selectStage(game.currentStage + 1);
        }
        game.startGame();
        await tester.pump(const Duration(seconds: 3));
        if (stage == 3) {
          game.board[0][0].type = TileType.freeze;
          game.flipTile(0, 0, TileOwner.player);
          game.board[0][0].type = TileType.normal;
          game.pauseGame();
          game.startGame();
        }
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: game,
          child: const RepaintBoundary(
              key: ValueKey('freeze_preview'), child: NeonFlipApp()),
        ));
        final board = find.byKey(ValueKey('board_grid_$stage'));
        final initialBounds = tester.getRect(board);
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(find.byKey(const ValueKey('tile_0_0')));
          await tester.pump();
        }
        final status = find.byKey(const ValueKey('player_penalty_status'));
        final overlay = find.byKey(const ValueKey('penalty_board_overlay'));
        final bounds = tester.getRect(board);
        if (stage == 1) expect(bounds, initialBounds);
        expect(tester.getRect(overlay), bounds);
        expect(tester.getRect(status).bottom, lessThan(bounds.top));
        expect(
            find.byKey(const ValueKey('player_frost_overlay')), findsNothing);
        expect(find.byIcon(Icons.pan_tool), findsOneWidget);
        if (stage == 3) expect(find.text('BOT FROZEN!'), findsOneWidget);
        _expectPenalty(tester, '1.0s', 1);
        if (const bool.fromEnvironment('CAPTURE_PENALTY_PREVIEW')) {
          await _captureFreezePreview(tester, viewport,
              name: 'penalty_stage$stage');
        }
        await tester.pump(const Duration(milliseconds: 300));
        _expectPenalty(tester, '0.7s', 0.7);
        final score = game.playerScore;
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(find.byKey(const ValueKey('tile_0_1')),
              warnIfMissed: false);
          await tester.pump();
        }
        expect(game.playerScore, score);
        _expectPenalty(tester, '0.7s', 0.7);
        await tester.pump(const Duration(milliseconds: 100));
        game.setAppActive(false);
        await tester.pump(const Duration(seconds: 10));
        game.setAppActive(true);
        await tester.pump(const Duration(seconds: 10));
        _expectPenalty(tester, '0.6s', 0.6);
        expect(tester.getRect(board), bounds);
        await tester.tap(find.text('RESUME'));
        await tester.pump(const Duration(milliseconds: 599));
        expect(overlay, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(overlay, findsNothing);
        expect(status, findsNothing);
        await tester.tap(find.byKey(const ValueKey('tile_0_1')));
        expect(game.playerScore, score + 1);
        game.board[0][0].type = TileType.normal;
        for (var tap = 0; tap < 2; tap++) {
          await tester.tap(find.byKey(const ValueKey('tile_0_0')));
          await tester.pump();
        }
        _expectPenalty(tester, '1.0s', 1);
        game.initializeGame();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final transition in ['reset', 'finish', 'freeze', 'unmount']) {
    testWidgets('penalty presentation clears on $transition', (tester) async {
      final game = GameState()..startGame();
      addTearDown(game.dispose);
      await tester.pump(const Duration(seconds: 3));
      for (var tap = 0; tap < 3; tap++) {
        game.flipTile(0, 0, TileOwner.player);
      }
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: game,
        child: const NeonFlipApp(),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      _expectPenalty(tester, '0.8s', 0.8);
      switch (transition) {
        case 'reset':
          game.initializeGame();
        case 'finish':
          game.endGame();
        case 'freeze':
          game.board[0][0].type = TileType.freeze;
          game.flipTile(0, 0, TileOwner.bot);
        case 'unmount':
          await tester.pumpWidget(const SizedBox.shrink());
          game.initializeGame();
      }
      await tester.pump();
      expect(game.rapidTapPenaltyRemaining, Duration.zero);
      expect(find.byKey(const ValueKey('penalty_board_overlay')), findsNothing);
      expect(find.text('RAPID TAPS'), findsNothing);
      if (transition == 'freeze') {
        expect(
            find.byKey(const ValueKey('player_frost_overlay')), findsOneWidget);
        expect(find.text('YOU FROZEN!'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 800));
        expect(game.isPlayerFrozen, isTrue);
        expect(find.text('1.2s'), findsOneWidget);
      }
      game.initializeGame();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bot freeze refreshes the visible deadline and can unmount early',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(seconds: 3));
    game.board[0][0].type = TileType.freeze;
    game.flipTile(0, 0, TileOwner.player);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    await tester.pump(const Duration(milliseconds: 750));
    game.board[0][0].type = TileType.freeze;
    game.flipTile(0, 0, TileOwner.player);
    await tester.pump();
    expect(find.text('2.0s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1250));
    expect(find.text('0.8s'), findsOneWidget);
    expect(find.text('BOT FROZEN!'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_frost_overlay')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    game.initializeGame();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('penalty has no frost and bot freeze replaces its presentation',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 3; i++) {
      game.flipTile(0, 0, TileOwner.player);
    }
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    expect(find.text('RAPID TAPS'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_frost_overlay')), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    game.board[0][0].type = TileType.freeze;
    game.flipTile(0, 0, TileOwner.bot);
    await tester.pump();
    expect(find.text('RAPID TAPS'), findsNothing);
    expect(find.text('YOU FROZEN!'), findsOneWidget);
    expect(find.text('2.0s'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_frost_overlay')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1.4s'), findsOneWidget);
    game.initializeGame();
    await tester.pump();
    expect(find.byKey(const ValueKey('player_frost_overlay')), findsNothing);
    expect(find.text('YOU FROZEN!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('finish removes frost without waiting for the freeze deadline',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(seconds: 3));
    game.board[0][0].type = TileType.freeze;
    game.flipTile(0, 0, TileOwner.bot);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    game.endGame();
    await tester.pump();
    expect(find.byKey(const ValueKey('player_frost_overlay')), findsNothing);
    expect(find.text('YOU FROZEN!'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(game.status, GameStateStatus.ended);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600)
  ]) {
    testWidgets('full journey with retries at $viewport', (tester) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = GameState();
      addTearDown(game.dispose);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: game,
        child: const NeonFlipApp(),
      ));
      await tester.tap(find.text('STAGE 3'));
      expect(game.currentStage, 1);
      await tester.tap(find.text('START GAME'));

      for (var stage = 1; stage <= 3; stage++) {
        expect(game.currentStage, stage);
        await _checkNewPlay(tester, game);

        // Set the score only; result transitions and buttons use real app code.
        for (final tile in game.board.expand((row) => row)) {
          tile.owner = TileOwner.bot;
          tile.type = TileType.normal;
        }
        game.endGame();
        await _showResult(tester, game);
        expect(find.text('STAGE FAILED'), findsOneWidget);
        expect(find.text('NEXT CHALLENGE'), findsNothing);
        expect(find.text('REWARD PASS'), findsNothing);
        expect(game.unlockedStage, stage);
        await _retryThroughButtons(tester, game, 'PLAY AGAIN');
        expect(game.currentStage, stage);
        await _checkNewPlay(tester, game);

        // A fully owned odd-sized board cannot end with equal scores.
        if (stage != 2) {
          game.endGame();
          await _showResult(tester, game);
          expect(find.text('DRAW!'), findsOneWidget);
          expect(find.text('REWARD PASS'), findsNothing);
          await _retryThroughButtons(tester, game, 'PLAY AGAIN');
          await _checkNewPlay(tester, game);
        }

        await _clearThroughLastCard(tester, game);
        expect(find.text('STAGE CLEAR!'), findsOneWidget);
        expect(game.unlockedStage, stage == 3 ? 3 : stage + 1);
        expect(find.text('REWARD PASS'),
            stage == 3 ? findsOneWidget : findsNothing);
        final retryLabel = stage == 3 ? 'PLAY AGAIN' : 'RETRY STAGE';
        await _retryThroughButtons(tester, game, retryLabel);
        expect(game.currentStage, stage);
        expect(game.unlockedStage, stage == 3 ? 3 : stage + 1);
        await _checkNewPlay(tester, game);
        await _clearThroughLastCard(tester, game);
        if (stage < 3) {
          await tester.ensureVisible(find.text('NEXT CHALLENGE'));
          await tester.tap(find.text('NEXT CHALLENGE'));
        } else {
          expect(find.text('NEXT CHALLENGE'), findsNothing);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final stage in [1, 2, 3]) {
    testWidgets('stage $stage time bar follows countdown pause and reset',
        (tester) async {
      final game = GameState();
      addTearDown(game.dispose);
      while (game.currentStage < stage) {
        game.startGame();
        await tester.pump(const Duration(seconds: 3));
        game.board[0][1].owner = TileOwner.player;
        game.endGame();
        await tester.pump(const Duration(milliseconds: 1400));
        game.selectStage(game.currentStage + 1);
      }
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: game,
        child: const NeonFlipApp(),
      ));
      _expectTimeBar(tester, game.maxTime, game.maxTime);
      await tester.tap(find.text('START GAME'));
      await _checkNewPlay(tester, game);
      // Hold bot actions while exercising the timer with the real screen.
      game.board[0][0].type = TileType.freeze;
      game.flipTile(0, 0, TileOwner.player);
      await tester.pump();
      final board = find.byKey(ValueKey('board_grid_$stage'));
      final boardBounds = tester.getRect(board);
      await tester.pump(const Duration(milliseconds: 999));
      _expectTimeBar(tester, game.maxTime, game.maxTime);
      await tester.pump(const Duration(milliseconds: 1));
      _expectTimeBar(tester, game.maxTime - 1, game.maxTime);
      expect(tester.getRect(board), boardBounds);
      await tester.pump(const Duration(milliseconds: 400));
      if (stage == 2) {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      } else {
        await tester.tap(find.text('PAUSE'));
      }
      await tester.pump(const Duration(seconds: 5));
      _expectTimeBar(tester, game.maxTime - 1, game.maxTime);
      expect(_timeBar(tester).color, Colors.white54);
      if (stage == 2) {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(seconds: 5));
        _expectTimeBar(tester, game.maxTime - 1, game.maxTime);
        expect(game.status, GameStateStatus.paused);
      }
      await tester.tap(find.text('RESUME'));
      await tester.pump(const Duration(milliseconds: 599));
      _expectTimeBar(tester, game.maxTime - 1, game.maxTime);
      await tester.pump(const Duration(milliseconds: 1));
      _expectTimeBar(tester, game.maxTime - 2, game.maxTime);
      await tester.tap(find.text('RESET'));
      await tester.pump();
      _expectTimeBar(tester, game.maxTime, game.maxTime);
      expect(_timeBar(tester).color, Colors.amberAccent);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('time bar warns at five seconds and freezes while paused',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(Duration(seconds: 3 + game.maxTime - 6));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    _expectTimeBar(tester, 6, game.maxTime);
    expect(_timeBar(tester).color, Colors.amberAccent);
    await tester.pump(const Duration(seconds: 1));
    _expectTimeBar(tester, 5, game.maxTime);
    expect(_timeBar(tester).color, Colors.redAccent);
    await tester.tap(find.text('PAUSE'));
    await tester.pump(const Duration(seconds: 10));
    _expectTimeBar(tester, 5, game.maxTime);
    expect(_timeBar(tester).color, Colors.white54);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(_timeBar(tester).color, Colors.redAccent);
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('time bar reaches zero at timeout and stays empty in results',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(Duration(seconds: 3 + game.maxTime - 1));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    _expectTimeBar(tester, 1, game.maxTime);
    await tester.pump(const Duration(milliseconds: 999));
    _expectTimeBar(tester, 1, game.maxTime);
    await tester.pump(const Duration(milliseconds: 1));
    _expectTimeBar(tester, 0, game.maxTime);
    expect(game.status, GameStateStatus.finishing);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(game.status, GameStateStatus.ended);
    _expectTimeBar(tester, 0, game.maxTime);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('early board victory preserves the remaining bar until retry',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(milliseconds: 7250));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    _expectTimeBar(tester, game.maxTime - 4, game.maxTime);
    await _clearThroughLastCard(tester, game);
    _expectTimeBar(tester, game.maxTime - 4, game.maxTime);
    await _retryThroughButtons(tester, game, 'RETRY STAGE');
    await _checkNewPlay(tester, game);
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600)
  ]) {
    testWidgets('time bar fits with simultaneous statuses at $viewport',
        (tester) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = GameState()..startGame();
      addTearDown(game.dispose);
      await tester.pump(const Duration(seconds: 3));
      game.board[0][1].type = TileType.freeze;
      game.flipTile(0, 1, TileOwner.player);
      game.board[0][0].type = TileType.normal;
      game.flipTile(0, 0, TileOwner.player);
      game.flipTile(0, 0, TileOwner.player);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: game,
        child: const NeonFlipApp(),
      ));
      _expectTimeBar(tester, game.maxTime, game.maxTime);
      final bar =
          tester.getRect(find.byKey(const ValueKey('remaining_time_bar')));
      final penalty = tester.getRect(find.text('RAPID TAPS'));
      final frozen = tester.getRect(find.text('BOT FROZEN!'));
      final digits = tester.getRect(find.text('${game.maxTime}s'));
      final board = tester.getRect(find.byKey(const ValueKey('board_grid_1')));
      expect(bar.height, 6);
      expect(bar.width, viewport.width - 24);
      expect(bar.top, greaterThanOrEqualTo(penalty.bottom));
      expect(bar.top, greaterThanOrEqualTo(frozen.bottom));
      expect(board.top, greaterThan(bar.bottom));
      expect(penalty.overlaps(digits), isFalse);
      expect(frozen.overlaps(digits), isFalse);
      expect(penalty.overlaps(frozen), isFalse);
      await tester.pump(const Duration(seconds: 1));
      _expectTimeBar(tester, game.maxTime - 1, game.maxTime);
      expect(find.text('RAPID TAPS'), findsNothing);
      game.initializeGame();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('penalty badge and board lock follow the one second penalty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = GameState();
    addTearDown(game.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    await tester.tap(find.text('START GAME'));
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('tile_0_0')));
      await tester.pump();
    }
    expect(game.isRapidTapPenaltyActive, isTrue);
    expect(find.text('RAPID TAPS'), findsOneWidget);
    expect(find.text('YOU FROZEN!'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tile_0_1')),
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 999));
    expect(game.playerScore, 8);
    expect(find.text('RAPID TAPS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('RAPID TAPS'), findsNothing);
    expect(game.isPlayerFrozen, isFalse);
    await tester.tap(find.byKey(const ValueKey('tile_0_1')));
    expect(game.board[0][1].owner, TileOwner.player);
    expect(game.playerScore, 9);
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause resume and reset buttons preserve or reset the same game',
      (tester) async {
    final game = GameState();
    addTearDown(game.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    await tester.tap(find.text('START GAME'));
    await _checkNewPlay(tester, game);
    await tester.tap(find.byKey(const ValueKey('tile_0_1')));
    await tester.pump(const Duration(milliseconds: 600));
    final score = game.playerScore;
    final session = game.sessionId;
    await tester.tap(find.text('PAUSE'));
    await tester.pump(const Duration(seconds: 5));
    expect(game.playerScore, score);
    expect(game.timeLeft, game.maxTime);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(game.status, GameStateStatus.playing);
    expect(game.startCountdown, isNull);
    expect(game.sessionId, session);
    expect(game.playerScore, score);
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.timeLeft, game.maxTime - 1);
    await tester.tap(find.text('RESET'));
    await tester.pump();
    expect(game.status, GameStateStatus.ready);
    await tester.tap(find.text('START GAME'));
    await _checkNewPlay(tester, game);
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'lifecycle pauses board and bot until the resume button is tapped',
      (tester) async {
    final game = GameState();
    addTearDown(game.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    await tester.tap(find.text('START GAME'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 1100));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 20));
    expect(game.timeLeft, game.maxTime - 1);
    expect(game.playerScore, 8);
    expect(find.text('PAUSED'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 20));
    expect(game.status, GameStateStatus.paused);
    expect(game.playerScore, 8);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('PAUSED'), findsNothing);
    await tester.pump(const Duration(milliseconds: 701));
    expect(game.botScore, greaterThan(8));
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifecycle cancels the visible countdown without auto restart',
      (tester) async {
    final game = GameState();
    addTearDown(game.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    await tester.tap(find.text('START GAME'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('GET READY'), findsNothing);
    expect(find.text('START GAME'), findsOneWidget);
    expect(game.status, GameStateStatus.ready);
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('background during finish preserves the result on return',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(seconds: 3));
    game.endGame();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.status, GameStateStatus.ended);
    expect(game.outcome, GameOutcome.draw);
    expect(find.text('DRAW!'), findsOneWidget);
    expect(find.text('RESUME'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('all next-stage buttons countdown and lock stage selection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = GameState();
    addTearDown(game.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    await tester.tap(find.text('START GAME'));
    for (var stage = 1; stage <= 3; stage++) {
      await tester.pump();
      expect(game.currentStage, stage);
      expect(find.text('3'), findsOneWidget);
      final start = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'GET READY'));
      expect(start.onPressed, isNull);
      await tester.tap(find.text('STAGE 1').last);
      expect(game.currentStage, stage);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      expect(game.playerScore, (game.totalTiles / 2).ceil());
      await tester.pump(const Duration(seconds: 1));
      expect(game.status, GameStateStatus.playing);
      expect(game.timeLeft, game.maxTime);
      game.board[0][1].owner = TileOwner.player;
      game.endGame();
      await tester.pump();
      await tester.tap(find.text('STAGE 1').last);
      expect(game.status, GameStateStatus.finishing);
      expect(game.currentStage, stage);
      expect(find.text('RESET'), findsNothing);
      final score = game.playerScore;
      await tester.pump(const Duration(milliseconds: 1400));
      expect(game.playerScore, score);
      await tester.pump(const Duration(milliseconds: 500));
      if (stage < 3) await tester.tap(find.text('NEXT CHALLENGE'));
    }
    expect(find.text('REWARD PASS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('same-frame reset cancels bot and paused board rejects touches',
      (tester) async {
    final game = GameState();
    addTearDown(game.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const NeonFlipApp(),
    ));
    game.startGame();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    game.pauseGame();
    await tester.pump();
    final score = game.playerScore;
    await tester.tap(find.byKey(const ValueKey('tile_0_1')),
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.playerScore, score);
    game.startGame();
    game.initializeGame();
    game.startGame();
    await tester.pump(const Duration(seconds: 3));
    expect(game.playerScore, game.totalTiles ~/ 2);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(game.playerScore, game.totalTiles ~/ 2);
    expect(tester.takeException(), isNull);
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final stage in [1, 3]) {
    for (final outcome in GameOutcome.values) {
      testWidgets('stage $stage timeout shows $outcome through both screens',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = GameState();
        addTearDown(game.dispose);

        while (game.currentStage < stage) {
          game.startGame();
          await tester.pump(const Duration(seconds: 3));
          game.board[0][1].owner = TileOwner.player;
          game.endGame();
          await tester.pump(const Duration(milliseconds: 1400));
          game.selectStage(game.currentStage + 1);
        }
        game.startGame();
        await tester.pump(const Duration(seconds: 3));
        if (outcome == GameOutcome.playerWin) {
          game.board[0][1].owner = TileOwner.player;
        } else if (outcome == GameOutcome.botWin) {
          game.board[0][0].owner = TileOwner.bot;
        }

        // Advance the actual game timer without a mounted bot changing scores.
        await tester.pump(Duration(seconds: game.maxTime));
        expect(game.timeLeft, 0);
        expect(game.outcome, outcome);
        expect(game.status, GameStateStatus.finishing);
        expect(game.endReason, GameEndReason.timeExpired);
        expect(game.unlockedStage,
            stage == 1 && outcome == GameOutcome.playerWin ? 2 : stage);

        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: game,
          child: const NeonFlipApp(),
        ));
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('TIME UP'), findsOneWidget);
        expect(
          find.text(switch (outcome) {
            GameOutcome.playerWin => 'YOU WIN',
            GameOutcome.botWin => 'BOT WINS',
            GameOutcome.draw => 'DRAW!',
          }),
          findsOneWidget,
        );
        expect(find.text('REWARD PASS'), findsNothing);

        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 500));
        expect(game.status, GameStateStatus.ended);
        expect(find.text('TIME UP'), findsNothing);
        expect(
          find.text(switch (outcome) {
            GameOutcome.playerWin => 'STAGE CLEAR!',
            GameOutcome.botWin => 'STAGE FAILED',
            GameOutcome.draw => 'DRAW!',
          }),
          findsOneWidget,
        );
        expect(
            find.text('NEXT CHALLENGE'),
            stage == 1 && outcome == GameOutcome.playerWin
                ? findsOneWidget
                : findsNothing);
        expect(
            find.text('REWARD PASS'),
            stage == 3 && outcome == GameOutcome.playerWin
                ? findsOneWidget
                : findsNothing);
        if (outcome == GameOutcome.draw) {
          expect(find.text('BOT WINS'), findsNothing);
          expect(find.text('STAGE FAILED'), findsNothing);
          expect(find.byIcon(Icons.sentiment_very_dissatisfied), findsNothing);
          expect(find.byIcon(Icons.balance), findsOneWidget);
          expect(find.text('STAGE $stage RESULT'), findsOneWidget);
          await tester.tap(find.text('PLAY AGAIN'));
          await tester.pump();
          expect(game.status, GameStateStatus.ready);
          expect(game.outcome, isNull);
          expect(game.gameResult, isEmpty);
          expect(find.text('DRAW!'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final owner in [TileOwner.player, TileOwner.bot]) {
    testWidgets('board coverage preserves $owner win presentation',
        (tester) async {
      final game = GameState()..startGame();
      addTearDown(game.dispose);
      await tester.pump(const Duration(seconds: 3));
      for (final tile in game.board.expand((row) => row)) {
        tile.owner = owner;
      }
      game.board[0][0].owner = TileOwner.none;
      game.flipTile(0, 0, owner);
      expect(game.endReason, GameEndReason.boardCovered);
      expect(
          game.outcome,
          owner == TileOwner.player
              ? GameOutcome.playerWin
              : GameOutcome.botWin);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: game,
        child: const NeonFlipApp(),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      expect(
          find.text(
              owner == TileOwner.player ? 'BOARD COMPLETE!' : 'BOARD TAKEN!'),
          findsOneWidget);
      expect(find.text('TIME UP'), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(
          find.text(
              owner == TileOwner.player ? 'STAGE CLEAR!' : 'STAGE FAILED'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _checkNewPlay(WidgetTester tester, GameState game) async {
  for (final count in [3, 2, 1]) {
    await tester.pump();
    expect(game.status, GameStateStatus.starting);
    expect(find.text('$count'), findsOneWidget);
    expect(game.timeLeft, game.maxTime);
    _expectTimeBar(tester, game.maxTime, game.maxTime);
    await tester.pump(const Duration(seconds: 1));
  }
  expect(game.status, GameStateStatus.playing);
  expect(game.outcome, isNull);
  expect(game.endReason, isNull);
  expect(game.isPlayerFrozen, isFalse);
  expect(game.isBotFrozen, isFalse);
  expect(game.isRapidTapPenaltyActive, isFalse);
  expect(game.timeLeft, game.maxTime);
  for (final tile in game.board.expand((row) => row)) {
    expect(tile.owner,
        (tile.row + tile.col).isEven ? TileOwner.player : TileOwner.bot);
    expect(tile.type, TileType.normal);
  }
  expect(tester.takeException(), isNull);
}

void _expectPenalty(WidgetTester tester, String seconds, double ratio) {
  final status = find.byKey(const ValueKey('player_penalty_status'));
  expect(find.text('RAPID TAPS'), findsOneWidget);
  expect(find.descendant(of: status, matching: find.text(seconds)),
      findsOneWidget);
  final statusProgress = tester.widget<LinearProgressIndicator>(find.descendant(
      of: status, matching: find.byType(LinearProgressIndicator)));
  final boardProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('penalty_board_progress')));
  expect(statusProgress.value, closeTo(ratio, 0.000001));
  expect(boardProgress.value, closeTo(ratio, 0.000001));
}

Future<void> _captureFreezePreview(WidgetTester tester, Size viewport,
    {String name = 'freeze'}) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byKey(const ValueKey('tile_0_0')));
    final game = context.read<GameState>();
    await precacheImage(NetworkImage(game.currentProductImage), context);
    await precacheImage(NetworkImage(game.brandLogoImage), context);
    await precacheImage(
        const AssetImage(CampaignConfig.defaultBotImageAsset), context);
    await precacheImage(AssetImage(game.campaign.botImageAsset), context,
        onError: (error, stackTrace) {});
  });
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('freeze_preview')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File(
        '${Directory.systemTemp.path}/flip_flap_${name}_${viewport.width.toInt()}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
    debugPrint('Effect preview: ${file.path}');
  });
}

LinearProgressIndicator _timeBar(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('remaining_time_bar')));

void _expectTimeBar(WidgetTester tester, int remaining, int total) {
  final bar = _timeBar(tester);
  expect(bar.value, closeTo(remaining / total, 0.000001));
  expect(bar.semanticsLabel, 'Remaining time: $remaining of $total seconds');
  expect(bar.semanticsValue, isNull);
  expect(find.text('${remaining}s'), findsOneWidget);
}

Future<void> _showResult(WidgetTester tester, GameState game) async {
  await tester.pump(const Duration(milliseconds: 1399));
  expect(game.status, GameStateStatus.finishing);
  expect(find.text('PLAY AGAIN'), findsNothing);
  await tester.pump(const Duration(milliseconds: 1));
  expect(game.status, GameStateStatus.ended);
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

Future<void> _retryThroughButtons(
    WidgetTester tester, GameState game, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
  expect(game.status, GameStateStatus.ready);
  expect(game.outcome, isNull);
  expect(find.text('REWARD PASS'), findsNothing);
  expect(find.text('STAGE CLEAR!'), findsNothing);
  await tester.tap(find.text('START GAME'));
}

Future<void> _clearThroughLastCard(WidgetTester tester, GameState game) async {
  for (final tile in game.board.expand((row) => row)) {
    tile.owner = TileOwner.player;
    tile.type = TileType.normal;
  }
  game.board[0][1].owner = TileOwner.bot;
  await tester.tap(find.byKey(const ValueKey('tile_0_1')));
  expect(game.endReason, GameEndReason.boardCovered);
  await _showResult(tester, game);
}

// Serve a local pixel for image requests so result tests never need the network.
class _ImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _ImageClient();
}

class _ImageClient extends Fake implements HttpClient {
  @override
  set autoUncompress(bool value) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageRequest();
}

class _ImageRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAANSURBVBhXY7h8+fJ/AAhvA3nL6ibXAAAAAElFTkSuQmCC',
  );

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _pixel.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_pixel).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
