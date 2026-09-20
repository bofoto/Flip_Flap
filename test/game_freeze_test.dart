import 'dart:ui' as ui;

import 'package:card_game/domain/game_state.dart';
import 'package:card_game/presentation/freeze_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final target in [TileOwner.player, TileOwner.bot]) {
    testWidgets('$target freeze remaining follows pause resume and expiry',
        (tester) async {
      final game = await _playing(tester);
      _freeze(game, target);
      expect(_remaining(game, target), const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_remaining(game, target), const Duration(milliseconds: 1500));
      game.pauseGame();
      await tester.pump(const Duration(seconds: 30));
      expect(_remaining(game, target), const Duration(milliseconds: 1500));
      game.startGame();
      await tester.pump(const Duration(milliseconds: 1499));
      expect(_remaining(game, target), const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(_remaining(game, target), Duration.zero);
      game.initializeGame();
    });

    testWidgets('$target repeated freeze starts a fresh two second duration',
        (tester) async {
      final game = await _playing(tester);
      _freeze(game, target);
      await tester.pump(const Duration(milliseconds: 750));
      _freeze(game, target);
      expect(_remaining(game, target), const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 1250));
      expect(_remaining(game, target), const Duration(milliseconds: 750));
      await tester.pump(const Duration(milliseconds: 750));
      expect(_remaining(game, target), Duration.zero);
      game.initializeGame();
    });
  }

  testWidgets('tap penalty is excluded from item freeze remaining',
      (tester) async {
    final game = await _playing(tester);
    for (var i = 0; i < 3; i++) {
      game.flipTile(0, 0, TileOwner.player);
    }
    expect(game.isPlayerFrozen, isTrue);
    expect(game.playerFreezeRemaining, Duration.zero);
    _freeze(game, TileOwner.player);
    expect(game.isRapidTapPenaltyActive, isFalse);
    expect(game.playerFreezeRemaining, GameState.freezeDuration);
    game.initializeGame();
  });

  for (final finish in [false, true]) {
    testWidgets('clearing freeze discards remaining time (finish: $finish)',
        (tester) async {
      final game = await _playing(tester);
      _freeze(game, TileOwner.player);
      await tester.pump(const Duration(milliseconds: 300));
      if (finish) {
        game.endGame();
      } else {
        game.initializeGame();
      }
      expect(game.playerFreezeRemaining, Duration.zero);
      expect(game.botFreezeRemaining, Duration.zero);
      game.initializeGame();
    });
  }

  testWidgets('frost paints all edges but leaves the center transparent',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child:
              SizedBox(width: 200, height: 200, child: PlayerFrostOverlay())),
    ));
    final painter =
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(200, 200));
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int alpha(int x, int y) => bytes.getUint8((y * 200 + x) * 4 + 3);
      for (final (x, y) in [(100, 1), (198, 100), (100, 198), (1, 100)]) {
        expect(alpha(x, y), greaterThan(0));
      }
      for (var y = 20; y < 180; y += 10) {
        for (var x = 20; x < 180; x += 10) {
          expect(alpha(x, y), 0);
        }
      }
      image.dispose();
      picture.dispose();
    });
  });
}

Future<GameState> _playing(WidgetTester tester) async {
  final game = GameState()..startGame();
  addTearDown(game.dispose);
  await tester.pump(const Duration(seconds: 3));
  return game;
}

void _freeze(GameState game, TileOwner target) {
  game.board[0][0].type = TileType.freeze;
  expect(
      game.flipTile(
          0, 0, target == TileOwner.player ? TileOwner.bot : TileOwner.player),
      isTrue);
}

Duration _remaining(GameState game, TileOwner target) =>
    target == TileOwner.player
        ? game.playerFreezeRemaining
        : game.botFreezeRemaining;
