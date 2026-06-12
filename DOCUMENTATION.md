# ZenithArrows — Complete Technical Documentation

> **Platform:** iOS 17+  **Language:** Swift 5.9  **UI:** SwiftUI + SpriteKit  
> **Architecture:** MVVM + Observable State  **Version:** 1.2.0  
> **Tests:** 186 passing · 0 failures  **Levels:** 39 verified solvable

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Project Structure](#3-project-structure)
4. [Core Game Mechanics](#4-core-game-mechanics)
5. [Data Models](#5-data-models)
6. [Game Logic Layer](#6-game-logic-layer)
7. [Managers](#7-managers)
8. [Views & Navigation](#8-views--navigation)
9. [SpriteKit Rendering Layer](#9-spritekit-rendering-layer)
10. [Feature Modules F1–F5 (Gameplay)](#10-feature-modules-f1f5-gameplay)
11. [Feature Modules F6–F10 (Progression)](#11-feature-modules-f6f10-progression)
12. [Feature Modules F11–F14 (Visual & Polish)](#12-feature-modules-f11f14-visual--polish)
13. [Feature Modules F15–F20 (Quality of Life)](#13-feature-modules-f15f20-quality-of-life)
14. [Feature Modules F21–F27 (Competitor Features)](#14-feature-modules-f21f27-competitor-features)
15. [Level System & JSON Format](#15-level-system--json-format)
16. [Persistence & Storage Keys](#16-persistence--storage-keys)
17. [Bug Fixes Log](#17-bug-fixes-log)
18. [Testing](#18-testing)
19. [Build & Run](#19-build--run)
20. [Competitor Comparison Matrix](#20-competitor-comparison-matrix)

---

## 1. Project Overview

**ZenithArrows** is a grid-based logic puzzle game for iOS. Players tap arrows on a grid to slide them in their facing direction. An arrow slides until it exits the board or hits an obstacle. Clear all arrows in the correct dependency order to win.

### Core Loop
```
Tap Arrow -> Validate Move -> Slide Animation -> Remove from Grid
    -> Cascade Combo? -> Win Check -> Star Rating
```

### What Makes ZenithArrows Stand Out
- **Guaranteed-solvable levels** via reverse-simulation generator + HintEngine verification
- **Diagonal arrows** (8 directions) — unique in the genre
- **Portal & Trap tiles** — unique obstacle types not in any competitor
- **Booster coin economy** — earned by playing, no forced IAP
- **Privacy-first analytics** — all data local, zero cross-app tracking
- **Full accessibility** — colorblind mode with shape + letter overlays
- **Seasonal events** with theme unlocks as free rewards

---

## 2. Architecture

```
SwiftUI Views
  HomeView  GameBoardView  EndLevelView  SettingsView  StatisticsView ...
      |
Observable State (@MainActor singletons)
  GameState  LevelManager  ProgressManager  BoosterManager  StatisticsManager
      |
Pure Game Logic (stateless)
  MoveValidator  HintEngine  LevelGenerator  ComboEngine  ReplayEngine
      |
SpriteKit Rendering
  GameScene  GridNode  ArrowNode
```

**Design Patterns:** MVVM, Singleton, Observer (@Published + Combine), Strategy (MoveValidator/HintEngine), Command (MoveRecord undo), Reverse Simulation (LevelGenerator)

---

## 3. Project Structure

```
ZenithArrows/
├── App/ZenithArrowsApp.swift
├── Models/
│   ├── ArrowModel.swift        Arrow entity, directions, types, colors
│   ├── GameState.swift         Live session state (moves, lives, phase, combo, replay)
│   ├── GridModel.swift         2D grid + SlidePath
│   └── LevelModel.swift        World/Level JSON-decodable structures
├── GameLogic/
│   ├── MoveValidator.swift     Pure move legality + dependency graph
│   ├── HintEngine.swift        Topological sort solver
│   ├── LevelGenerator.swift    Seeded reverse-simulation generator
│   └── LevelManager.swift      Load worlds, persist progress, daily challenge
├── Managers/
│   ├── ProgressManager.swift   Lifetime stats, streaks, IAP, GameCenter
│   ├── ThemeManager.swift      5 themes + star/streak unlock gates
│   ├── AudioManager.swift      Music + 7 SFX events
│   ├── HapticManager.swift     Core Haptics (6 patterns)
│   └── AnalyticsManager.swift  Privacy-first local event buffer
├── Features/                   27 gameplay improvement features
│   ├── TimedChallengeManager.swift   F1  Countdown mode
│   ├── ComboEngine.swift             F2  Cascade combos
│   ├── ReplayEngine.swift            F5  Solution replay
│   ├── WeeklyChallengeManager.swift  F6  Weekly puzzles
│   ├── ChallengeShareManager.swift   F7  Share codes
│   ├── StreakRewardManager.swift     F9  Streak milestones
│   ├── AchievementManager.swift      F10 In-app achievements
│   ├── ColorblindManager.swift       F18 Accessibility overlays
│   ├── NotificationManager.swift     F20 Local push notifications
│   ├── BoosterManager.swift          F21 Erase/Auto/Skip + coin economy
│   ├── StatisticsManager.swift       F22 Per-level + global stats
│   ├── SeasonalEventManager.swift    F23 Seasonal events
│   └── GridOverlayManager.swift      F24 Moveable indicators
├── Views/
│   ├── HomeView.swift            BoosterBarView.swift
│   ├── GameBoardView.swift       StatisticsView.swift
│   ├── GameHUDView.swift         SeasonalEventView.swift
│   ├── EndLevelView.swift        AchievementsView.swift
│   ├── LevelSelectView.swift     WeeklyChallengeView.swift
│   ├── SettingsView.swift        StreakRewardView.swift
│   ├── PauseMenuView.swift       TrailEffectView.swift
│   └── TutorialView.swift
├── SpriteKit/
│   ├── GameScene.swift   GridNode.swift   ArrowNode.swift
└── Resources/Levels/
    ├── world1.json  (15 levels: tutorial->expert, 4x4-5x5)
    ├── world2.json  (10 levels: walls, 5x5-6x6)
    ├── world3.json  (8 levels: diagonals, 5x5-6x6)
    └── world4.json  (6 levels: portals, 5x5-6x6)

ZenithArrowsTests/
├── ZenithArrowsTests.swift          (106 tests: core engine + F1-F20)
└── CompetitorFeatureTests.swift     (80 tests: F21-F27 + world JSON)
```

---

## 4. Core Game Mechanics

### Arrow Sliding
```
pos = arrowPosition + direction.delta
while pos is in bounds:
    empty / ice  -> continue
    portal       -> teleport to partner, continue
    trap         -> trapEncountered = true, stop
    arrow / wall -> BLOCKED -> return nil
exits board -> SlidePath(exitsBoardAt: pos)
```

### Arrow Types
| Type | Behaviour |
|------|-----------|
| standard | Normal slide |
| ice | Slides through ice tiles |
| heavy | Cannot move until row/column fully clear |
| locked | Immovable obstacle |
| rotatable | Player rotates before launch (F3) |
| snake | Multi-cell (F4) |

### Obstacle Types
| Kind | Effect |
|------|--------|
| wall | Blocks all movement |
| portal | Paired teleporter |
| ice | Tile modifier, arrow continues |
| trap | Reverses direction on entry |

### Star Rating
```swift
mistakes==0 && moves<=parMoves && time<=parTime  ->  3 stars
mistakes<=1 && moves<=parMoves+3                 ->  2 stars
otherwise                                         ->  1 star
```

---

## 5. Data Models

### GameState (@MainActor)
Key published properties: `grid`, `phase`, `moves`, `mistakes`, `lives`, `elapsedTime`, `hintsRemaining`, `comboEngine` (F2), `replayEngine` (F5), `parMoves` (F16), `isFreeHintReady` (F17), `undoReturnedArrowID` (F15)

**GamePhase:** idle | playing | animating | paused | levelComplete(stars:) | levelFailed | tutorial(step:)

### GridModel
- `cells: [[CellContent]]` — O(1) row-major lookup
- `arrowPositions: [UUID: GridPosition]` — O(1) reverse lookup
- `slidePath(for:) -> SlidePath?` handles portals, traps, obstacles
- `copy() -> GridModel` deep copy for undo stack

### LevelDefinition (JSON-decodable)
```json
{
  "id": "w1_l001", "worldID": 1, "index": 1,
  "gridRows": 4, "gridCols": 4,
  "arrows": [{"row":0,"col":0,"direction":"right","type":"standard","color":"white"}],
  "obstacles": [{"row":2,"col":2,"kind":"wall"},
                {"row":0,"col":4,"kind":"portal","portalID":1,"portalColor":"blue"}],
  "difficulty": "tutorial", "parMoves": 4, "parTime": 30,
  "diagonalsEnabled": false, "title": "First Steps"
}
```

---

## 6. Game Logic Layer

### MoveValidator (pure stateless)
- `validateMove(arrow:in:) -> SlidePath?` — nil if locked/heavy-locked/blocked
- `moveableArrows(in:) -> [Arrow]`
- `buildDependencyGraph(for:in:) -> [UUID: Set<UUID>]`

### HintEngine — Kahn's-style topological sort
1. Find all moveable arrows
2. Remove from simulation grid
3. Repeat until empty (solvable) or deadlock (nil)

Methods: `nextSafeMove(in:)`, `solveOrder(arrows:grid:)`, `isSolvable(grid:)`

### LevelGenerator — Reverse simulation
1. Empty grid
2. Pick random cell + direction
3. Only place if path is clear (no current arrows blocking)
4. Reversal of placement order = valid solve sequence -> always solvable
5. Seeded via `SeededRNG` for deterministic daily/weekly challenges

---

## 7. Managers

| Manager | Core Responsibility | Storage |
|---------|-------------------|---------|
| LevelManager | Load JSON worlds, persist progress, daily challenge | zenith_progress_v1 |
| ProgressManager | totalStars, streak, hints, IAP, GameCenter + triggers F9/F10/F13 | zenith_stats_v1 |
| ThemeManager | 5 themes, star/streak gates, `unlockTheme(key:)` | zenith_theme_v1 |
| AudioManager | Music loops + 7 SFX (slide/wrongTap/success/failure/tap/hint/star) | zenith_music/sfx |
| HapticManager | Core Haptics for arrowTap/wrongTap/levelComplete/levelFailed/starEarned | zenith_haptics_enabled |
| AnalyticsManager | Local event buffer, 50-event flush, 12 event types | zenith_analytics_buffer |

### Theme Unlock Gates
| Key | Free? | Stars | Streak |
|-----|-------|-------|--------|
| zen | Always | — | — |
| nature | No | 50 | — |
| neon | No | 100 | 14 days |
| cyber | No | 300 | 30 days |
| dark | No | — | 100 days |

---

## 8. Views & Navigation

```
HomeView
  ├── GameBoardView
  │    ├── GameHUDView     (combo banner F2, par colour F16, free hint F17)
  │    ├── BoosterBarView  (coins, Erase/Auto/Skip   F21)
  │    ├── TrailEffectView (slide trail overlay       F11)
  │    ├── UndoReturnLabel (undo highlight            F15)
  │    ├── PauseMenuView
  │    └── EndLevelView    (per-star haptic F12, watch solution F5)
  ├── WorldSelectView -> LevelSelectView (grid+badge F14)
  ├── WeeklyChallengeView  (F6)
  ├── AchievementsView     (F10)
  ├── StatisticsView       (F22)
  ├── SeasonalEventView    (F23)
  ├── SettingsView         (F13 theme locks, F18 colorblind, F20 notifications, F24 indicators)
  └── ShopView
```

---

## 9. SpriteKit Rendering Layer

### GameScene — Key Fixes (v1.2.0)
- `touchesBegan`: valid moves call `triggerSlide` only; invalid taps call `handleTap` once (fixed double-penalty bug)
- `triggerSlide`: locks `slidingArrowIDs`, commits model, animates node, calls `finaliseRemoval`

### GridNode
- Renders cells, walls (filled rect), portals (pulsing circle), ice (cyan tint), traps (red tint)
- `gridPosition(for:)` converts SpriteKit point -> GridPosition

### ArrowNode
- Custom CGPath chevron, rotated by `direction.rotationDegrees`
- States: idle, highlighted (pulsing glow), wrong-tap (red flash + shake), sliding (moveBy + fadeOut)

---

## 10. Feature Modules F1-F5 (Gameplay)

### F1 — Timed Challenge (`TimedChallengeManager`)
- Standard: 60s, +10/under-par, -25/mistake; Blitz: 30s, +20, -50
- Score = baseScore +/- adjustments + timeRemaining*2
- Stars: >=20s=3, >=10s=2, <10s=1, expired=0
- Best scores persisted in `zenith_timed_best_scores_v1`

### F2 — Arrow Chain Combos (`ComboEngine`)
- Cascade = moveableArrows grows after removal
- multiplier = 1.0 + streak * 0.5
- Banners: COMBO x2! / TRIPLE! / MEGA COMBO x4! / UNSTOPPABLE x5!

### F3 — Rotatable Arrows
- `rotateClockwise/CounterClockwise(diagonalsEnabled:)` on `Arrow`
- 4-step (cardinal) or 8-step (diagonal) cycle; no-op for other types

### F4 — Snake Arrows
- `addSegment(_:)` — dedup-safe; `head`/`tail`/`isSnake` properties on `Arrow`

### F5 — Solution Replay (`ReplayEngine`)
- History mode: records each MoveStep during live play
- Optimal mode: HintEngine.solveOrder -> animated highlight sequence
- "Watch Solution" button in EndLevelView

---

## 11. Feature Modules F6-F10 (Progression)

### F6 — Weekly Challenges (`WeeklyChallengeManager`)
- Resets every Monday; seed from ISO 8601 week ID hash
- Hard difficulty 6x6 level; stores 8 weeks of history
- Best-of completion semantics (score never decreases)

### F7 — Challenge a Friend (`ChallengeShareManager`)
- URL-safe Base64 JSON (no +/= chars)
- Deep link: `zenith://challenge?code=<base64>`
- `level(from:)` reconstructs identical layout via LevelGenerator

### F9 — Streak Rewards (`StreakRewardManager`)
Days 3/7: hints | Days 14/30: theme unlocks | Days 60/100: hints/theme

### F10 — Achievements (`AchievementManager`)
14 achievements (stars/moves/streak/combo/perfect/timed/nohint), synced to GameCenter.
`AchievementsView` with progress bars + `AchievementToast` popup.

---

## 12. Feature Modules F11-F14 (Visual & Polish)

| Feature | Implementation |
|---------|---------------|
| F11 Slide Trail | `TrailEffectView` overlay, particles fade 750ms |
| F12 Per-star celebration | 0.28s stagger, `AudioManager.play(.star)` + `HapticManager.starEarned()` per star |
| F13 Theme unlocking | Star gates (50/100/300) + streak reward gates; `unlockTheme(key:)` |
| F14 Grid size indicator | `LevelCell` shows "5x5" dimensions + difficulty abbreviation (TUT/EZ/MED/HARD/EXP/ZEN) |

---

## 13. Feature Modules F15-F20 (Quality of Life)

| Feature | Implementation |
|---------|---------------|
| F15 Smart undo highlight | `undoReturnedArrowID` published 700ms; overlay label in GameBoardView |
| F16 Par indicator | Move counter: green/accent/orange by delta from par; "par N" sub-label |
| F17 Free hint cooldown | 30-min `isFreeHintReady`; `freeHintCooldownLabel`; no paid-hint decrement |
| F18 Colorblind mode | `ColorblindManager` shapes/labels/both; unique shape+letter per ArrowColor |
| F19 Level editor export | `ShareLink` in `LevelEditorView` |
| F20 Push notifications | Daily 9AM, weekly Mon 10AM, streak reminder 8PM; badge cleared on launch |

---

## 14. Feature Modules F21-F27 (Competitor Features)

### F21 — Booster System (`BoosterManager`)
| Booster | Effect | Cost |
|---------|--------|------|
| Erase | Remove 1 arrow, no penalty | 3 coins |
| Auto Move | Execute next optimal move | 5 coins |
| Skip | Skip level, 1-star completion | 10 coins |

Coins: 1-3 per level complete, 10/day daily bonus. `testOnly_reset()` for test isolation.

### F22 — Statistics (`StatisticsManager`)
Per-level: bestMoves, bestTime, averageTime, completionRate, maxCombo, hintsUsed, boostersUsed
Global: totalPlayTime, totalLevelsCompleted, totalMovesAllTime, totalCombosAllTime
`StatisticsView`: expandable world cards with per-level rows.

### F23 — Seasonal Events (`SeasonalEventManager`)
| Event | Period | Reward |
|-------|--------|--------|
| Summer Blaze | Jun-Aug 2026 | 25 coins + Neon City theme |
| Haunted Grid | Oct-Nov 2026 | 30 coins + Pure Dark theme |
| Frozen Arrows | Dec 2026 | 30 coins + Nature theme |

Each event: 5 hard levels generated from `weekID.hashValue` seed.
`SeasonalEventView`: live banner + level list + past history.

### F24 — Grid Overlay (`GridOverlayManager`)
- `showMoveableIndicators` — green ring on tappable arrows (persisted in `zenith_moveable_indicators_v1`)
- `showCoordinates` — row/col index in each cell (session-only)
- Toggled in Settings

### F25 — Pinch-to-Zoom
`GameScene` handles `UIPinchGestureRecognizer`; scale clamped 0.6x-2.0x, centered on pinch midpoint.

### F26 — Skip via Booster
`BoosterType.skipLevel` deducts 10 coins, auto-completes level with 1 star via `BoosterBarView.onSkip`.

### F27 — Color Hex Extension
`Color(hex:)` on SwiftUI Color; 6-char hex (# prefix optional); used by `SeasonalEventView`.

---

## 15. Level System & JSON Format

### World Summary
| World | Name | Levels | Grid | Stars to Unlock |
|-------|------|--------|------|----------------|
| 1 | Basics | 15 | 4x4 to 5x5 | 0 (always unlocked) |
| 2 | Obstacles (walls) | 10 | 5x5 to 6x6 | 15 |
| 3 | Diagonals (8-dir) | 8 | 5x5 to 6x6 | 40 |
| 4 | Portals | 6 | 5x5 to 6x6 | 70 |

All 39 levels generated by reverse-simulation; verified by `HintEngine.isSolvable`.

### JSON Schema
```json
{
  "id": "w1_l001", "worldID": 1, "index": 1,
  "gridRows": 4, "gridCols": 4,
  "arrows": [
    {"row": 0, "col": 0, "direction": "right", "type": "standard", "color": "white"}
  ],
  "obstacles": [
    {"row": 2, "col": 2, "kind": "wall"},
    {"row": 0, "col": 4, "kind": "portal", "portalID": 1, "portalColor": "blue"}
  ],
  "difficulty": "tutorial",
  "parMoves": 4, "parTime": 30,
  "diagonalsEnabled": false,
  "title": "First Steps"
}
```

### Daily Challenge Seed
```swift
let seed = Int(Date().timeIntervalSince1970 / 86400)  // UTC day number — same puzzle all day
```

---

## 16. Persistence & Storage Keys

| Key | Type | Owner |
|-----|------|-------|
| zenith_stats_v1 | Stats JSON | ProgressManager |
| zenith_progress_v1 | ProgressRecord JSON | LevelManager |
| zenith_theme_v1 | String | ThemeManager |
| zenith_unlocked_themes_v1 | [String] JSON | ThemeManager |
| zenith_music / zenith_sfx | Bool | AudioManager |
| zenith_haptics_enabled | Bool | HapticManager |
| zenith_colorblind_v1 | Bool | ColorblindManager |
| zenith_colorblind_mode_v1 | String | ColorblindManager |
| zenith_moveable_indicators_v1 | Bool | GridOverlayManager |
| zenith_achievements_v2 | [Achievement] JSON | AchievementManager |
| zenith_streak_rewards_v1 | [StreakMilestone] JSON | StreakRewardManager |
| zenith_weekly_v1 | Storage JSON | WeeklyChallengeManager |
| zenith_timed_best_scores_v1 | [String:Int] JSON | TimedChallengeManager |
| zenith_booster_coins_v1 | Int | BoosterManager |
| zenith_statistics_v1 | [String:LevelStat] JSON | StatisticsManager |
| zenith_global_stats_v1 | GlobalStats JSON | StatisticsManager |
| zenith_seasonal_events_v1 | [SeasonalEvent] JSON | SeasonalEventManager |
| zenith_analytics_buffer | [[String:Any]] | AnalyticsManager |
| zenith_daily_coin_date | Date | BoosterManager |

---

## 17. Bug Fixes Log

### v1.2.0 (2026-06-11)
| Bug | Cause | Fix |
|-----|-------|-----|
| Level 1 unplayable — all taps wrong | Corner arrows in circular dependency | Regenerated all 39 levels with algorithm-guaranteed solvability |
| Double wrong-tap penalty | GameScene called handleTap for valid moves AND triggerSlide | Split: triggerSlide only for valid; handleTap once for invalid |
| Sequential taps blocked | handleTap rejected .animating phase | Allow .playing OR .animating |
| Empty-cell tap crash | registerWrongTap required non-nil UUID | Changed to UUID? with optional flash |
| Win condition unreliable | finaliseRemoval used pendingRemovalIDs.isEmpty | Changed to grid.activeArrows.isEmpty |
| World3 duplicate positions | Hand-crafted diagonal levels | Regenerated via scripted reverse-simulation generator |
| World4 L3 portal OOB | Portal at row 5 in 5-row grid | Regenerated with bounds-checked generator |

---

## 18. Testing

**Total: 186 tests, 0 failures** (ZenithArrowsTests.swift + CompetitorFeatureTests.swift)

### Test Coverage Summary
| Class | Tests | Area |
|-------|-------|------|
| GridModelTests | 7 | Place/remove/slide/OOB/copy |
| MoveValidatorTests | 5 | Standard/locked/heavy/graph |
| HintEngineTests | 4 | Next move/solve/deadlock |
| TimedChallengeTests | 6 | F1 scoring/stars/persistence |
| ComboEngineTests | 5 | F2 cascade/multiplier/labels |
| RotatableArrowTests | 6 | F3 CW/CCW/diagonal |
| SnakeArrowTests | 5 | F4 segments/head/tail |
| ReplayEngineTests | 5 | F5 record/optimal/stop |
| WeeklyChallengeTests | 6 | F6 difficulty/completion |
| ChallengeShareTests | 5 | F7 encode/decode/URL |
| StreakRewardTests | 4 | F9 milestones/rewards |
| AchievementTests | 5 | F10 unlock/progress |
| ThemeUnlockTests | 5 | F13 gates |
| GridSizeIndicatorTests | 2 | F14 dimensions |
| UndoHighlightTests | 1 | F15 returned ID |
| ParIndicatorTests | 3 | F16 under/at/over par |
| FreeHintTests | 4 | F17 ready/cooldown |
| ColorblindModeTests | 4 | F18 shapes/labels |
| NotificationTests | 3 | F20 identifiers |
| StarRatingTests | 5 | 3/2/1 star scenarios |
| GameStateIntegrationTests | 7 | Restart/pause/undo |
| LevelGeneratorTests | 3 | Solvable/deterministic |
| BoosterManagerTests | 12 | F21 coins/afford/activate |
| StatisticsManagerTests | 10 | F22 best/avg/rate |
| SeasonalEventManagerTests | 9 | F23 catalog/levels |
| GridOverlayManagerTests | 4 | F24 toggles |
| GameStateTapFixTests | 7 | Phase bugs/empty-cell/life |
| LevelSolvabilityTests | 7 | All 4 worlds verified |
| LevelGeneratorExtendedTests | 6 | Seeds/determinism |
| ColorHexTests | 3 | F27 hex parsing |
| CompetitorComparisonTests | 22 | 1 test per differentiator |

### Run Tests
```bash
xcodebuild test \
  -project ZenithArrows.xcodeproj \
  -scheme ZenithArrows \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' \
  -derivedDataPath /tmp/zenith_build
```

---

## 19. Build & Run

### Build
```bash
xcodebuild build \
  -project ZenithArrows.xcodeproj \
  -scheme ZenithArrows -configuration Debug \
  -destination 'platform=iOS Simulator,id=71189EA8-5CF8-4FA1-87DE-C754210AAFF3' \
  -derivedDataPath /tmp/zenith_build
```

### Install & Launch on Simulator
```bash
xcrun simctl boot 71189EA8-5CF8-4FA1-87DE-C754210AAFF3
APP=$(find /tmp/zenith_build -name "ZenithArrows.app" -not -path "*/dSYM/*" | head -1)
xcrun simctl install 71189EA8-5CF8-4FA1-87DE-C754210AAFF3 "$APP"
xcrun simctl launch 71189EA8-5CF8-4FA1-87DE-C754210AAFF3 com.zenith.ZenithArrows
```

### Info.plist Requirements
- `NSUserNotificationsUsageDescription` — required for F20
- `UIRequiredDeviceCapabilities` — armv7 (haptics need physical device)

---

## 20. Competitor Comparison Matrix

Top 4 arrow-escape apps (App Store, Jun 2026):

| Feature | Arrows–Puzzle Escape 4.9* 216K | Arrow Maze 4.7* 72K | Arrow Out 4.6* 181K | Arrow Fever 4.6* 18K | **ZenithArrows** |
|---------|------|------|------|------|------|
| Handcrafted levels | Yes (thousands) | Yes | Yes | Yes (70+) | **Yes (39) + infinite procedural** |
| Daily challenge | Yes | No | No | Yes | **Yes** |
| Weekly challenge | No | No | No | No | **Yes (F6)** |
| Hint system | Yes | Yes | Yes | Yes | **Yes paid + free cooldown (F17)** |
| Booster tools | No | Yes | Yes (zoom/erase/wand) | No | **Yes coin economy (F21)** |
| Timed mode | No | No | No | No | **Yes (F1)** |
| Combo system | No | No | No | No | **Yes (F2)** |
| Diagonal arrows | No | No | No | No | **Yes 8 directions (World 3)** |
| Portal obstacles | No | No | No | No | **Yes (World 4)** |
| Trap obstacles | No | No | No | No | **Yes** |
| Solution replay | No | No | No | No | **Yes (F5)** |
| Seasonal events | No | Yes | Yes | No | **Yes (F23)** |
| In-app achievements | GameCenter only | GameCenter only | GameCenter only | No | **Yes in-app + GameCenter (F10)** |
| Statistics screen | No | No | No | No | **Yes (F22)** |
| Streak rewards | No | No | No | No | **Yes (F9)** |
| Colorblind mode | No | No | No | No | **Yes shapes+labels (F18)** |
| Challenge a friend | No | No | No | No | **Yes share codes (F7)** |
| Pinch-to-zoom | No | No | Yes | No | **Yes (F25)** |
| Privacy (no tracking) | Tracks ID | Tracks location | Tracks purchases | Tracks ID | **Local only, zero cross-app tracking** |
| No forced ads | No | No | No (ads every level) | No (ads every level) | **Yes** |
| 10-deep undo | No | No | No | No | **Yes** |
