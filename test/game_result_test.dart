import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:card_game/domain/game_state.dart';
import 'package:card_game/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = _ImageHttpOverrides();
    addTearDown(() => HttpOverrides.global = previous);
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
          game.board[0][1].owner = TileOwner.player;
          game.endGame();
          game.selectStage(game.currentStage + 1);
        }
        game.startGame();
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
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
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
