import 'dart:ui' as ui;

import 'package:card_game/domain/game_state.dart';
import 'package:card_game/presentation/penalty_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('penalty edges and progress paint without covering the center',
      (tester) async {
    final game = GameState()..startGame();
    addTearDown(game.dispose);
    await tester.pump(const Duration(seconds: 3));
    for (var tap = 0; tap < 3; tap++) {
      game.flipTile(0, 0, TileOwner.player);
    }
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child: SizedBox(
              width: 200,
              height: 200,
              child: RepaintBoundary(
                  key: const ValueKey('penalty_pixels'),
                  child: PenaltyBoardOverlay(gameState: game)))),
    ));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('penalty_pixels')));
    var fullProgressRed = 0;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      for (final (x, y) in [(100, 1), (198, 100), (100, 198), (1, 100)]) {
        expect(bytes.getUint8((y * 200 + x) * 4 + 3), greaterThan(0));
      }
      for (var y = 20; y < 180; y += 10) {
        for (var x = 20; x < 180; x += 10) {
          expect(bytes.getUint8((y * 200 + x) * 4 + 3), 0);
        }
      }
      fullProgressRed = bytes.getUint8((197 * 200 + 150) * 4);
      image.dispose();
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('penalty_board_progress')))
            .value,
        0.5);
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(bytes.getUint8((197 * 200 + 150) * 4), lessThan(fullProgressRed));
      image.dispose();
    });
    game.initializeGame();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
