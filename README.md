# 🎮 FLIP FLAP (광고판 뒤집기 대결 게임)

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-10%2F10%20Passed-brightgreen?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

**팝업스토어 및 브랜드 이벤트 웨이팅 고객을 위한 실시간 1:1 광고 Reveal 타일 뒤집기 배틀 게임**

</div>

---
## 노션
https://app.notion.com/p/396ddebb56ca8009a682e38ed7e4ddfb?source=copy_link

## 📌 1. 프로젝트 개요 (Overview)

**FLIP FLAP**은 팝업스토어, 플래그십 스토어, 브랜드 행사장에서 대기 중인 고객들의 지루함을 해소하고, 자연스럽게 브랜드 제품을 홍보하기 위해 기획된 **마케팅 연계형 캐주얼 게임**입니다.

** 본작업은 바이브 코딩으로 진행하고 있습니다. **

- **타겟 유저**: 팝업스토어 및 현장 이벤트 웨이팅 고객
- **핵심 가치**: 
  - 1:1 대결을 통해 고객 몰입도 극대화
  - 플레이어가 타일을 뒤집을 때마다 프로모션 제품 이미지가 파편 형태로 점진 노출(Reveal)
  - 스테이지 승리 시 현장에서 즉시 사용 가능한 할인/증정 쿠폰(바코드) 발급
- **기술 스택**: Flutter, Dart, Provider (State Management)
- **앱 아이콘**: 3D 글래스모피즘(Glassmorphism) 기반 1:1 배틀 & 플립 심볼 (`assets/icon/app_icon.jpg`)

---

## 🎲 2. 핵심 게임 메커니즘 (Core Mechanics)

### ① 1:1 실시간 타일 뒤집기 대결
- 게임 시작 시 격자 보드가 플레이어(Player)와 봇(Bot)의 색상으로 교차 배치(Checkerboard)됩니다.
- **이미지 파편화 노출 (Cropped Image Reveal)**:
  - 플레이어가 타일을 뒤집으면 `FractionalOffset` 좌표 크롭을 통해 해당 위치의 **고화질 상품 광고 이미지 조각**이 나타납니다.
  - 봇이 타일을 뒤집으면 브랜드 로고 가림막으로 덮여 상품 이미지가 다시 숨겨집니다.

### ② 3단계 스테이지 & 난이도 시스템
| 스테이지 | 격자 크기 | 제한 시간 | Bot AI 난이도 | 클리어 보상 쿠폰 |
| :--- | :---: | :---: | :--- | :--- |
| **Stage 1** | **4 x 4** (16타일) | 30초 | Easy (여유로운 반응 속도) | 🥤 **FREE DRINK** (`POP-2026-DRINK`) |
| **Stage 2** | **6 x 6** (36타일) | 30초 | Medium (보통 반응 속도) | 🏷️ **10% OFF** (`POP-2026-GOODS`) |
| **Stage 3** | **8 x 8** (64타일) | 45초 | Hard (빠른 반응 + 특수 타일 우선 타겟) | 🎁 **FREE GIFT** (`POP-2026-GIFT`) |

> *※ 이전 스테이지를 클리어해야 다음 스테이지가 순차적으로 해금됩니다.*

### ③ 특수 아이템 타일
게임 중 일정 확률로 특수 효과를 가진 아이템 타일이 스폰됩니다.

| 아이콘 | 아이템명 | 코드 심볼 | 효과 설명 |
| :---: | :--- | :--- | :--- |
| 💣 | **Bomb (폭탄)** | `Icons.brightness_7` | 타일 발동 시 해당 위치 중심 **3x3 (주변 8방향 + 자신) 영역 전체**를 즉시 내 소유로 뒤집음 |
| ⚡ | **Line (라인)** | `Icons.add_road` | 타일 발동 시 해당 타일이 속한 **가로 행(Row) 및 세로 열(Column) 전체**를 즉시 내 소유로 뒤집음 |
| ❄️ | **Freeze (프리즈)** | `Icons.ac_unit` | 타일 발동 시 **상대방(Bot 또는 Player)의 조작을 2초간 동결(마비)**시킴 |

### ④ 승리 및 판정 규칙
- **올 커버 승리 (Instant Win)**: 제한 시간 내에 보드의 모든 타일을 자신의 색상/이미지로 채우면 즉시 승리
- **타임 오버 판정**: 제한 시간 종료 시 더 많은 타일을 점유한 쪽이 승리

---

## 🛠 3. 프로젝트 구조 (Architecture)

```
lib/
├── domain/
│   ├── campaign_config.dart   # 브랜드/스테이지/이미지/쿠폰 설정 데이터 모델
│   ├── game_state.dart        # 보드 상태, 타일 조작, 타이머, 승패 판정 핵심 로직 (Provider)
│   └── bot_ai.dart            # 난이도별 Bot AI 행동 패턴 및 타겟팅 알고리즘
├── presentation/
│   └── game_screen.dart       # 3D 타일 Flip 렌더링, 네온 스타일 UI, 점수 게이지
└── main.dart                  # 앱 진입점 및 승리 시 바코드 쿠폰 오버레이 다이얼로그
test/
└── game_logic_test.dart       # 비즈니스 로직 및 규칙 10종 유닛 테스트
assets/
└── icon/
    └── app_icon.jpg           # 앱 메인 아이콘
```

---

## 🎨 4. 브랜드 캠페인 커스텀 가이드 (Campaign Customization)

새로운 팝업스토어나 브랜드 이벤트에 맞게 이미지를 변경하려면 [`lib/domain/campaign_config.dart`](lib/domain/campaign_config.dart) 파일의 `defaultCampaignConfig`만 수정하면 됩니다. (게임 로직 수정 불필요)

```dart
const defaultCampaignConfig = CampaignConfig(
  brandName: '팝업 브랜드명',
  backImageUrl: '브랜드 로고 또는 가림막 이미지 URL',
  stages: [
    CampaignStage(
      boardSize: 4,
      maxTime: 30,
      productImageUrl: '1단계 상품 이미지 URL',
      reward: CampaignReward(
        title: 'FREE DRINK',
        description: '팝업스토어 현장 음료 교환권',
        code: 'POP-2026-DRINK',
      ),
    ),
    // Stage 2, Stage 3 ...
  ],
);
```

---

## 🧪 5. 테스트 및 검증 (Testing)

핵심 도메인 및 게임 로직은 10개의 단위 테스트로 전수 검증되어 있습니다.

```powershell
flutter test
```

### 테스트 케이스 항목
1. `GameState initialization starts at stage 1 with a 4x4 checkerboard`
2. `GameState initialization blocks locked stages`
3. `Tile flipping fails while the game is not playing`
4. `Tile flipping succeeds while the game is playing`
5. `Special tiles bomb flips the surrounding 3x3 area`
6. `Special tiles line flips its full row and column`
7. `Special tiles freeze disables the opponent temporarily`
8. `Win condition and stages winning stage 1 unlocks stage 2`
9. `Campaign images returns the configured image for the selected stage`
10. `Campaign images can swap campaign assets without changing game logic`

---

### 사전 요구 사항
- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 3.0.0)

---