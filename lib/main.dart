import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'domain/campaign_config.dart';
import 'domain/game_state.dart';
import 'presentation/game_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameState(),
      child: const NeonFlipApp(),
    ),
  );
}

class NeonFlipApp extends StatelessWidget {
  const NeonFlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final campaign = context.read<GameState>().campaign;

    return MaterialApp(
      title: campaign.brandName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.pinkAccent,
          surface: Color(0xFF1E293B),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'monospace'),
          bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'monospace'),
        ),
      ),
      home: const GameOverlayWrapper(),
    );
  }
}

class GameOverlayWrapper extends StatelessWidget {
  const GameOverlayWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Stack(
      children: [
        const GameScreen(),
        if (gameState.status == GameStateStatus.ended)
          _ResultOverlay(gameState: gameState),
      ],
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final isPlayerWinner = gameState.gameResult.contains('PLAYER');
    final accent = isPlayerWinner ? Colors.cyanAccent : Colors.pinkAccent;
    final hasNextStage =
        isPlayerWinner && gameState.currentStage < gameState.maxStage;
    final hasFinalReward =
        isPlayerWinner && gameState.currentStage == gameState.maxStage;

    return Positioned.fill(
      child: Container(
        color: faded(Colors.black, 0.88),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 340,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: faded(accent, 0.3),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ResultHero(gameState: gameState),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      children: [
                        Text(
                          isPlayerWinner ? 'STAGE CLEAR!' : 'STAGE FAILED',
                          style: TextStyle(
                            color: accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Final Score: Player ${gameState.playerScore} vs Bot ${gameState.botScore}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (hasFinalReward) ...[
                          _Coupon(reward: gameState.currentReward),
                          const SizedBox(height: 24),
                        ] else if (!isPlayerWinner) ...[
                          const Icon(
                            Icons.sentiment_very_dissatisfied,
                            size: 48,
                            color: Colors.pinkAccent,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Try again to reveal the product\nand unlock the reward.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (hasNextStage) ...[
                          _PrimaryResultButton(
                            text: 'NEXT CHALLENGE',
                            onPressed: () {
                              gameState.selectStage(gameState.currentStage + 1);
                              gameState.requestStartCountdown();
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        _SecondaryResultButton(
                          text: hasNextStage ? 'RETRY STAGE' : 'PLAY AGAIN',
                          onPressed: gameState.initializeGame,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(gameState.currentProductImage, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  faded(Colors.black, 0.3),
                  const Color(0xFF1E293B),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatusBadge(
                text: 'STAGE ${gameState.currentStage} REVEALED',
                color: Colors.amberAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Coupon extends StatelessWidget {
  const _Coupon({required this.reward});

  final CampaignReward reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: faded(Colors.amberAccent, 0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REWARD PASS',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'IN STORE',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reward.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reward.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          const SizedBox(height: 16),
          _Barcode(seed: reward.code),
          const SizedBox(height: 6),
          Text(
            reward.code,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(40, (index) {
          final charCode = seed.codeUnitAt(index % seed.length);
          final isDark =
              (charCode + index) % 3 == 0 || (charCode * (index + 1)) % 7 == 0;

          return Expanded(
            flex: isDark ? 2 : 1,
            child: ColoredBox(color: isDark ? Colors.black : Colors.white),
          );
        }),
      ),
    );
  }
}

class _PrimaryResultButton extends StatelessWidget {
  const _PrimaryResultButton({
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyanAccent,
        foregroundColor: const Color(0xFF0F172A),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SecondaryResultButton extends StatelessWidget {
  const _SecondaryResultButton({
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white30, width: 1.5),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
