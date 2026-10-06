class CampaignConfig {
  static const defaultBotImageAsset = 'assets/bot/card_bot.png';

  const CampaignConfig({
    required this.brandName,
    required this.backImageUrl,
    required this.stages,
    this.botImageAsset = defaultBotImageAsset,
  });

  final String brandName;
  final String backImageUrl;
  final List<CampaignStage> stages;
  final String botImageAsset;
}

class CampaignStage {
  const CampaignStage({
    required this.boardSize,
    required this.maxTime,
    required this.productImageUrl,
    required this.reward,
  });

  final int boardSize;
  final int maxTime;
  final String productImageUrl;
  final CampaignReward reward;
}

class CampaignReward {
  const CampaignReward({
    required this.title,
    required this.description,
    required this.code,
  });

  final String title;
  final String description;
  final String code;
}

const defaultCampaignConfig = CampaignConfig(
  brandName: 'Neon Flip',
  backImageUrl:
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400',
  stages: [
    CampaignStage(
      boardSize: 4,
      maxTime: 30,
      productImageUrl:
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600',
      reward: CampaignReward(
        title: 'FREE DRINK',
        description: 'Redeem one signature drink at the popup counter.',
        code: 'POP-2026-DRINK',
      ),
    ),
    CampaignStage(
      boardSize: 5,
      maxTime: 30,
      productImageUrl:
          'https://images.unsplash.com/photo-1541643600914-78b084683601?w=800',
      reward: CampaignReward(
        title: '10% OFF',
        description: 'Use instantly on selected popup store goods.',
        code: 'POP-2026-GOODS',
      ),
    ),
    CampaignStage(
      boardSize: 6,
      maxTime: 45,
      productImageUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800',
      reward: CampaignReward(
        title: 'FREE GIFT',
        description: 'Claim one limited mini product while supplies last.',
        code: 'POP-2026-GIFT',
      ),
    ),
  ],
);
