import 'package:card_game/domain/campaign_config.dart';
import 'package:card_game/domain/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState initialization', () {
    test('starts at stage 1 with a 4x4 checkerboard', () {
      final gameState = GameState();

      expect(gameState.currentStage, 1);
      expect(gameState.unlockedStage, 1);
      expect(gameState.boardSize, 4);
      expect(gameState.board.length, 4);
      expect(gameState.status, GameStateStatus.ready);
      expect(gameState.board[0][0].owner, TileOwner.player);
      expect(gameState.board[0][1].owner, TileOwner.bot);
    });

    test('blocks locked stages', () {
      final gameState = GameState();

      expect(gameState.selectStage(2), isFalse);
      expect(gameState.currentStage, 1);
    });
  });

  group('Tile flipping', () {
    test('fails while the game is not playing', () {
      final gameState = GameState();

      expect(gameState.flipTile(0, 1, TileOwner.player), isFalse);
    });

    test('succeeds while the game is playing', () {
      final gameState = GameState()..startGame();

      expect(gameState.board[0][1].owner, TileOwner.bot);
      expect(gameState.flipTile(0, 1, TileOwner.player), isTrue);
      expect(gameState.board[0][1].owner, TileOwner.player);
    });
  });

  group('Special tiles', () {
    test('bomb flips the surrounding 3x3 area', () {
      final gameState = GameState()..startGame();
      _forceStageClear(gameState);

      expect(gameState.unlockedStage, 2);
      gameState
        ..selectStage(2)
        ..startGame();
      gameState.board[2][2].type = TileType.bomb;
      gameState.flipTile(2, 2, TileOwner.player);

      for (int row = 1; row <= 3; row++) {
        for (int col = 1; col <= 3; col++) {
          expect(gameState.board[row][col].owner, TileOwner.player);
        }
      }
    });

    test('line flips its full row and column', () {
      final gameState = GameState()..startGame();

      gameState.board[2][2].type = TileType.line;
      gameState.flipTile(2, 2, TileOwner.player);

      for (int i = 0; i < 4; i++) {
        expect(gameState.board[2][i].owner, TileOwner.player);
        expect(gameState.board[i][2].owner, TileOwner.player);
      }
    });

    test('freeze disables the opponent temporarily', () {
      final gameState = GameState()..startGame();

      gameState.board[1][1].type = TileType.freeze;
      gameState.flipTile(1, 1, TileOwner.player);

      expect(gameState.isBotFrozen, isTrue);
      expect(gameState.isPlayerFrozen, isFalse);
    });
  });

  group('Win condition and stages', () {
    test('winning stage 1 unlocks stage 2', () {
      final gameState = GameState()..startGame();

      _forceStageClear(gameState);

      expect(gameState.status, GameStateStatus.ended);
      expect(gameState.gameResult, contains('PLAYER WINS!'));
      expect(gameState.unlockedStage, 2);
    });
  });

  group('Campaign images', () {
    test('returns the configured image for the selected stage', () {
      final gameState = GameState();

      expect(
        gameState.currentProductImage,
        contains('photo-1523275335684-37898b6baf30'),
      );
      expect(
        gameState.brandLogoImage,
        contains('photo-1618005182384-a83a8bd57fbe'),
      );

      gameState.startGame();
      _forceStageClear(gameState);
      gameState.selectStage(2);

      expect(
        gameState.currentProductImage,
        contains('photo-1541643600914-78b084683601'),
      );
      expect(gameState.currentReward.code, 'POP-2026-GOODS');
    });

    test('can swap campaign assets without changing game logic', () {
      const campaign = CampaignConfig(
        brandName: 'Client Popup',
        backImageUrl: 'https://cdn.example.com/client/back.jpg',
        stages: [
          CampaignStage(
            boardSize: 3,
            maxTime: 15,
            productImageUrl: 'https://cdn.example.com/client/product-a.jpg',
            reward: CampaignReward(
              title: 'CLIENT GIFT',
              description: 'Client-specific reward copy.',
              code: 'CLIENT-001',
            ),
          ),
        ],
      );

      final gameState = GameState(campaign: campaign);

      expect(gameState.maxStage, 1);
      expect(gameState.boardSize, 3);
      expect(gameState.maxTime, 15);
      expect(
          gameState.currentProductImage, campaign.stages.first.productImageUrl);
      expect(gameState.brandLogoImage, campaign.backImageUrl);
      expect(gameState.currentReward.code, 'CLIENT-001');
    });
  });
}

void _forceStageClear(GameState gameState) {
  for (final row in gameState.board) {
    for (final tile in row) {
      tile.owner = TileOwner.player;
    }
  }

  gameState.board[0][0].owner = TileOwner.bot;
  gameState.flipTile(0, 0, TileOwner.player);
}
