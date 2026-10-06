# BOT-01 card character assets

- Default: `card_bot.png` — honey border and heart.
- Alternate theme: `card_bot_mint.png` — mint border and clover.
- Both are 1254 × 1254 RGBA PNGs with transparent backgrounds. Keep new skins square, centered, and with comparable transparent margins.
- Generated with the built-in imagegen tool on 2026-10-06. Original generated files were copied into this project; no API fallback or extra dependency was used.

Set `CampaignConfig.botImageAsset` to change appearance. Omitting it retains the default. An unavailable skin falls back to the default asset.

```dart
final mintCampaign = CampaignConfig(
  brandName: defaultCampaignConfig.brandName,
  backImageUrl: defaultCampaignConfig.backImageUrl,
  stages: defaultCampaignConfig.stages,
  botImageAsset: 'assets/bot/card_bot_mint.png',
);
final game = GameState(campaign: mintCampaign);
```

The common board layout controls character size and position, independent of the skin. The character starts on the first bot card after the countdown. BOT-02 connects the AI's target, 200ms straight-line movement, and arrival flip. The travel time is included in the existing difficulty interval; a small 120ms landing pulse adds no gameplay delay. Skin changes do not alter targeting, timing, or item rules.

BOT-03 pauses the same action timer during bot freeze or game pause. A small ice outline and snowflake identify a frozen bot; its position, target, and unfinished time are retained until resume. Ending, resetting, changing stages, or disposing cancels the old action.

Design direction: a friendly playing card with a clear face and dark outline, visible on the existing board. Palette: ivory `#FFF8E8`, cocoa `#522813`, honey `#F6C650`, blush `#F7AAA0`, mint `#A2DAB3`, teal `#146A68`. No added typography, glow, idle animation, or decorative UI. Character box: 45% of a card side, centered over the card. Existing game typography and controls are outside this component's scope.

## Generation prompts

Default (built-in generation, transparent background):

> Use case: stylized-concept. Asset type: small game character PNG with true transparent background for a Flutter card flipping game, BOT-01. Create ONE cute friendly upright playing-card character, centered on a square canvas with consistent 12% transparent margins on each side. Rounded pale ivory card body with a clear cocoa-brown outline, two dark dot eyes, a small cheerful curved smile, tiny soft pink cheeks, short mitten hands and tiny feet, a muted honey-yellow card border and a small single heart near the top. Simple flat illustration, crisp readable silhouette at 24 pixels, no glow, no neon, no gradients, no text, no watermark, no props, no cast shadow or background. Front view, full character visible. The character itself should occupy approximately 76% of canvas width/height. Save the finished PNG as a local generated image and include its saved file path in output metadata.

Mint (built-in edit of the default, transparent background):

> Use case: precise-object-edit. Asset type: alternate theme PNG for the same small Flutter card game character. Change ONLY the existing card character's honey yellow border to muted mint green, and its red heart symbol to a small dark teal four-leaf clover symbol. Keep the same cute face, brown outlines, pale ivory card body, pink cheeks, hands, feet, front-view pose, square canvas, exact character scale and placement and transparent margins. Preserve genuine transparent background. No text, no glow, no neon, no new objects. This is the same character wearing the mint theme. Save finished transparent PNG locally and return its saved file path.
