# ZenithArrows — Complete Technical Documentation

> **Platform:** iOS 17+  **Language:** Swift 5.9  **UI:** SwiftUI + SpriteKit  
> **Architecture:** MVVM + Observable State  **Version:** 1.1.0

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
10. [Feature Modules](#10-feature-modules)
11. [Level System & JSON Format](#11-level-system--json-format)
12. [Persistence & Storage](#12-persistence--storage)
13. [Testing](#13-testing)
14. [Build & Run](#14-build--run)
15. [Feature Reference Table](#15-feature-reference-table)

---

## 1. Project Overview

**ZenithArrows** is a grid-based logic puzzle game for iOS. Players tap arrows on a grid to slide them in their facing direction. An arrow slides until it either exits the board or is blocked. The objective is to clear all arrows from the grid in the correct order.

### Core Loop
```
Tap Arrow → Validate Move → Slide Animation → Remove from Grid → Check Win
```

### Key Differentiators
- Procedural level generation (always solvable via reverse simulation)
- 4 hand-crafted worlds (JSON) + unlimited daily/weekly challenges
- 20 gameplay improvement features (timed mode, combos, replay, achievements, etc.)
- Privacy-first analytics (local only by default)
- Full accessibility support (colorblind mode with shapes/labels)

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│  HomeView  GameBoardView  EndLevelView  SettingsView  ...    │
└─────────────────────────┬────────────────────────────────────┘
                          │ @StateObject / @ObservedObject
┌─────────────────────────▼────────────────────────────────────┐
│                     Observable State                         │
│          GameState   LevelManager   ProgressManager          │
│          ThemeManager   AudioManager   WeeklyChallengeManager │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                    Pure Game Logic                            │
│        MoveValidator   HintEngine   LevelGenerator           │
│        ComboEngine     ReplayEngine   TimedChallengeManager  │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                   SpriteKit Rendering                        │
│              GameScene   GridNode   ArrowNode                │
└──────────────────────────────────────────────────────────────┘
```

### Design Patterns
| Pattern | Usage |
|---------|-------|
| **MVVM** | `GameState` as ViewModel; Views observe via `@ObservedObject` |
| **Singleton** | All managers (`ThemeManager.shared`, etc.) for app-wide state |
| **Observer** | `@Published` + Combine for reactive UI updates |
| **Strategy** | `MoveValidator` / `HintEngine` as pure-function strategies |
| **Command** | `MoveRecord` (undo stack) as command objects |

---

## 3. Project Structure

```
ZenithArrows/
├── App/
│   └── ZenithArrowsApp.swift          # App entry point, window setup
├── Models/
│   ├── ArrowModel.swift               # Arrow entity + direction/type/color enums
│   ├── GameState.swift                # Live session state (moves, lives, phase)
│   ├── GridModel.swift                # 2D grid + spatial operations + SlidePath
│   └── LevelModel.swift               # World/LevelDefinition/ObstaclePlacement
├── GameLogic/
│   ├── MoveValidator.swift            # Pure move legality checker
│   ├── HintEngine.swift               # Topological sort solver
│   ├── LevelGenerator.swift           # Seeded procedural level generation
│   └── LevelManager.swift             # Load worlds, persist progress, daily challenge
├── Managers/
│   ├── ProgressManager.swift          # Lifetime stats, streaks, IAP, GameCenter
│   ├── ThemeManager.swift             # 5 themes + star-gated unlock system
│   ├── AudioManager.swift             # Music + SFX (AVFoundation)
│   ├── HapticManager.swift            # Core Haptics patterns
│   └── AnalyticsManager.swift         # Privacy-first local event log
├── Features/                          # ← All 20 new features
│   ├── TimedChallengeManager.swift    # Feature 1 – Countdown mode
│   ├── ComboEngine.swift              # Feature 2 – Cascade combos
│   ├── ReplayEngine.swift             # Feature 5 – Solution replay
│   ├── WeeklyChallengeManager.swift   # Feature 6 – Weekly puzzles
│   ├── ChallengeShareManager.swift    # Feature 7 – Share codes
│   ├── StreakRewardManager.swift      # Feature 9 – Streak milestones
│   ├── AchievementManager.swift       # Feature 10 – In-app achievements
│   ├── ColorblindManager.swift        # Feature 18 – Accessibility overlays
│   └── NotificationManager.swift      # Feature 20 – Local push notifications
├── Views/
│   ├── HomeView.swift                 # Main menu
│   ├── GameBoardView.swift            # Game screen (SpriteKit wrapper)
│   ├── GameHUDView.swift              # In-game HUD
│   ├── EndLevelView.swift             # Post-level screen + star animation
│   ├── LevelSelectView.swift          # World select + level grid
│   ├── SettingsView.swift             # Audio/colorblind/theme/notifications
│   ├── PauseMenuView.swift            # Pause overlay
│   ├── TutorialView.swift             # Tutorial step overlays
│   ├── LevelEditorView.swift          # Level editor (debug)
│   ├── AchievementsView.swift         # Achievement browser + toast
│   ├── WeeklyChallengeView.swift      # Weekly challenge UI
│   ├── StreakRewardView.swift         # Streak reward popup
│   └── TrailEffectView.swift          # Slide trail particle overlay
├── SpriteKit/
│   ├── GameScene.swift                # Main SKScene; input routing
│   ├── GridNode.swift                 # Renders grid + obstacles
│   └── ArrowNode.swift                # Renders individual arrows + animations
└── Resources/
    ├── Assets.xcassets/               # App icon, color assets
    └── Levels/
        ├── world1.json                # World 1: Basics (tutorial → medium)
        ├── world2.json                # World 2: Intermediate
        ├── world3.json                # World 3: Advanced (diagonals)
        └── world4.json                # World 4: Expert

ZenithArrowsTests/
└── ZenithArrowsTests.swift            # 110 test cases across 18 test classes
```

---

## 4. Core Game Mechanics

### 4.1 Arrow Sliding
An arrow at position `(r, c)` facing direction `d` slides step-by-step:
```
pos = (r,c) + d.delta
while pos is in bounds:
    if cell is empty or ice → continue sliding
    if cell is portal → teleport to partner portal exit, continue
    if cell is trap → reverse direction (trapEncountered = true)
    if cell is arrow or obstacle → BLOCKED (return nil)
exit board → SlidePath(exitsBoardAt: pos)
```

### 4.2 Arrow Types

| Type | Behaviour |
|------|-----------|
| `standard` | Normal slide until boundary or obstacle |
| `ice` | Slides through ice tiles at double speed (visual) |
| `heavy` | Cannot move until its entire row (horizontal) or column (vertical) is clear of other arrows |
| `locked` | Immovable wall — never tappable |
| `rotatable` | Player may rotate direction before launching (Feature 3) |
| `snake` | Occupies multiple connected cells; all cells must clear together (Feature 4) |

### 4.3 Obstacle Types

| Kind | Effect |
|------|--------|
| `wall` | Blocks all movement |
| `portal` | Paired teleporter; arrows exit from partner portal |
| `ice` | Tile modifier; arrow continues past ice cells |
| `trap` | Reverses the sliding arrow's direction on entry |

### 4.4 Win / Lose Conditions
- **Win:** `grid.activeArrows.isEmpty` after an arrow removal → `levelComplete(stars:)`  
- **Lose:** `lives == 0` after consecutive wrong taps → `levelFailed`

### 4.5 Star Rating
```swift
func starRating(moves: Int, time: TimeInterval, mistakes: Int) -> Int {
    if mistakes == 0 && moves <= parMoves && time <= parTime { return 3 }
    if mistakes <= 1 && moves <= parMoves + 3                { return 2 }
    return 1
}
```

---

## 5. Data Models

### 5.1 `Arrow` (`ArrowModel.swift`)
```
Arrow
 ├── id: UUID
 ├── direction: ArrowDirection  (.up / .down / .left / .right / diagonals)
 ├── position: GridPosition
 ├── type: ArrowType
 ├── color: ArrowColor          (for portal matching)
 ├── segments: [GridPosition]   (snake arrows)
 ├── isRemoved: Bool
 ├── isHighlighted: Bool        (hint system)
 └── isWrong: Bool              (wrong-tap flash)
```

**`ArrowDirection`** — 8 directions, each with:
- `delta: (row: Int, col: Int)` — unit movement vector
- `rotationDegrees: Double` — angle for rendering
- `systemImageName: String` — SF Symbol fallback

### 5.2 `GridModel` (`GridModel.swift`)
```
GridModel
 ├── rows, cols: Int
 ├── cells: [[CellContent]]      (flat 2D array — O(1) access)
 ├── arrowPositions: [UUID: GridPosition]  (fast reverse lookup)
 ├── place(arrow:) / place(obstacle:)
 ├── remove(arrowID:)
 ├── slidePath(for:) → SlidePath?
 └── copy() → GridModel          (deep copy for undo)
```

**`SlidePath`** holds:
- `cells: [GridPosition]` — intermediate traversed cells
- `exitsBoardAt: GridPosition?` — OOB exit point
- `portalExit: GridPosition?` — re-entry after portal
- `trapEncountered: Bool`

### 5.3 `GameState` (`GameState.swift`)
The single source of truth for a live level session:

| Property | Type | Purpose |
|----------|------|---------|
| `grid` | `GridModel` | Live grid |
| `phase` | `GamePhase` | idle / playing / animating / paused / levelComplete / levelFailed / tutorial |
| `moves` | `Int` | Tap count |
| `mistakes` | `Int` | Wrong tap count |
| `lives` | `Int` | Remaining (max 3) |
| `elapsedTime` | `TimeInterval` | Stopwatch |
| `hintsRemaining` | `Int` | Consumable hints |
| `comboEngine` | `ComboEngine` | Cascade combo tracker |
| `replayEngine` | `ReplayEngine` | Move recorder |
| `parMoves` | `Int` | Level's 3-star move target |
| `isFreeHintReady` | `Bool` | 30-min cooldown free hint |
| `undoReturnedArrowID` | `UUID?` | Feature 15 highlight |

### 5.4 `LevelDefinition` (`LevelModel.swift`)
JSON-decodable level descriptor:
```json
{
  "id": "w1_l001",
  "worldID": 1,
  "index": 1,
  "gridRows": 4,
  "gridCols": 4,
  "arrows": [
    { "row": 0, "col": 0, "direction": "right" }
  ],
  "obstacles": [],
  "difficulty": "tutorial",
  "parMoves": 5,
  "parTime": 120,
  "diagonalsEnabled": false,
  "title": "First Steps"
}
```

---

## 6. Game Logic Layer

### 6.1 `MoveValidator`
Pure-function class with no state:

| Method | Description |
|--------|-------------|
| `validateMove(arrow:in:)` | Returns `SlidePath?` if legal (nil = blocked/locked/heavy-locked) |
| `moveableArrows(in:)` | All arrows currently legal to tap |
| `buildDependencyGraph(for:in:)` | `[UUID: Set<UUID>]` — A blocks B map |

### 6.2 `HintEngine`
Topological-sort solver:

| Method | Description |
|--------|-------------|
| `nextSafeMove(in:)` | UUID of next arrow to remove (solveOrder[0]) |
| `solveOrder(arrows:grid:)` | Full valid removal sequence or nil |
| `isSolvable(grid:)` | Quick O(n²) deadlock check |

**Algorithm:** Iterative Kahn's-style topological sort over the dependency graph. Each pass removes all currently-moveable arrows; repeats until empty (solvable) or no progress (deadlock).

### 6.3 `LevelGenerator`
Seeded procedural generation via **reverse simulation**:
1. Start with empty grid
2. Pick random empty cell + direction
3. Check if arrow's path is currently clear
4. Place arrow → record as step N in reverse solution
5. Repeat until `arrowCount` arrows placed
6. The placement order reversed = valid solve order → **always solvable**

Uses `SeededRNG` (linear congruential) for deterministic daily/weekly challenges.

---

## 7. Managers

### 7.1 `LevelManager`
- Loads `world1–4.json` from bundle; falls back to procedural worlds
- Persists per-level best stars + unlock state via `UserDefaults` JSON
- Unlocks next level on completion; unlocks next world when `totalStars >= requiredStarsToUnlock`
- Generates daily challenge: seed = `floor(now / 86400)` → same puzzle all day

### 7.2 `ProgressManager`
| Stored | Key |
|--------|-----|
| `totalStars` | `zenith_stats_v1` |
| `totalMoves` | `zenith_stats_v1` |
| `dailyStreak` | incremented when `dayDiff == 1` |
| `hintsOwned` | `zenith_stats_v1` |
| `hasPremiumUnlock` | IAP entitlement |
| `hasRemovedAds` | IAP entitlement |

On `recordLevelComplete`: triggers `ThemeManager.checkStarUnlocks` (Feature 13) and `AchievementManager.update` (Feature 10).

### 7.3 `ThemeManager`
- 5 built-in themes: **Zen Stone** (free), **Neon City**, **Cyber**, **Nature**, **Pure Dark**
- Themes gated: unlocked via streak rewards or star milestones  
- `select(themeKey:)` no-ops if theme is locked
- `displayThemes` returns `(theme, isUnlocked, requiredStars?)` tuples for Settings UI

### 7.4 `AudioManager`
- `AVAudioPlayer` pool, pre-loaded at startup
- Music: loops with volume 0.35, fades out on level complete
- SFX events: `slide`, `wrongTap`, `success`, `failure`, `buttonTap`, `hint`, `star`
- Falls back to `AudioServicesPlaySystemSound` if asset file missing

### 7.5 `HapticManager`
- `CHHapticEngine` patterns for: `arrowTap`, `wrongTap`, `levelComplete` (triple pulse), `levelFailed`, `buttonTap`, `starEarned`
- Falls back to `UIImpactFeedbackGenerator` when Core Haptics unavailable

### 7.6 `AnalyticsManager`
- Events buffered in `UserDefaults` (max 50)
- All processing local; no network calls by default
- Events: level started/completed/failed, hint used, free hint used, theme changed, IAP initiated, timed challenge completed, weekly started, challenge shared, combo achieved, achievement unlocked

---

## 8. Views & Navigation

### 8.1 Navigation Graph
```
HomeView
 ├── GameBoardView (Continue / Daily Challenge)
 ├── WorldSelectView
 │    └── LevelSelectView
 │         └── GameBoardView
 │              ├── GameHUDView
 │              ├── PauseMenuView (fullScreenCover)
 │              └── EndLevelView  (fullScreenCover)
 ├── WeeklyChallengeView (sheet)  ← Feature 6
 ├── SettingsView (sheet)
 ├── ShopView (sheet)
 └── AchievementsView (sheet)    ← Feature 10
```

### 8.2 `HomeView`
- Streak badge + star counter + achievements quick-access (Feature 10)
- Streak reward popup overlay (Feature 9)
- Achievement unlock toast (Feature 10)
- Weekly Challenge button (Feature 6)
- Requests notification permission on first launch (Feature 20)

### 8.3 `GameBoardView`
- Embeds `SpriteKit GameScene` via `SpriteView`
- Wires HUD callbacks: pause, undo (Feature 15 highlight), hint, free hint (Feature 17)
- `TrailEffectView` overlay for slide trails (Feature 11)
- `UndoReturnLabel` overlay (Feature 15)
- Passes `replayEngine` + `hintEngine` + `grid` to `EndLevelView` (Feature 5)

### 8.4 `GameHUDView`
- Combo banner at top when streak active (Feature 2)
- Move counter colored green/accent/orange relative to par (Feature 16)
- Par moves sub-label `"par 5"` always visible
- Free hint button with cooldown timer or paid hint count badge (Feature 17)

### 8.5 `EndLevelView`
- Stars animate one-by-one with per-star haptic (`starEarned()`) + SFX (Feature 12)
- "Watch Solution" button launches `ReplayEngine.startOptimalReplay` (Feature 5)
- ShareLink with result text

### 8.6 `LevelSelectView`
- Level cells show: number, 3-star row, `"5×5"` grid size (Feature 14), difficulty abbreviation badge

### 8.7 `SettingsView`
- **Audio:** music + SFX toggles
- **Accessibility:** Colorblind mode toggle + shape/label/both picker (Feature 18)
- **Notifications:** Daily reminder toggle with system Settings deeplink (Feature 20)
- **Theme:** Full list with lock icons + requirement label (Feature 13)
- **About:** version, privacy policy, App Store link

---

## 9. SpriteKit Rendering Layer

### 9.1 `GameScene`
- Receives `GameState`, `MoveValidator`, `HintEngine`, `GameTheme`
- Routes touch → `gameState.handleTap(at:moveValidator:)`
- Observes `gameState.lastRemovedArrowID` → triggers slide-out animation
- Calls `gameState.finaliseRemoval(arrowID:)` after animation completes

### 9.2 `GridNode`
- Renders `rows × cols` cell backgrounds
- Draws obstacle overlays: wall (filled rect), portal (colored ring), ice (tint), trap (X marker)
- Updates on `gameState.grid` change

### 9.3 `ArrowNode`
- Renders arrow shape rotated by `ArrowDirection.rotationDegrees`
- Entrance animation: staggered fade-in + scale
- Highlight animation: pulsing glow when `isHighlighted == true` (hint)
- Wrong-tap flash: red tint for 0.5 s
- Slide-out animation: move to exit position + fade

---

## 10. Feature Modules

### Feature 1 — Timed Challenge Mode (`TimedChallengeManager`)
A separate gameplay mode with:
- **Countdown timer** (Standard: 60s, Blitz: 30s)
- **Score system:** base + bonus per under-par move + time remaining × 2
- **Penalty:** -25 per mistake (Standard), -50 (Blitz)
- **Stars:** 3 stars if ≥20s remaining, 2 if ≥10s, 1 otherwise
- **Best score** persisted per level in `UserDefaults`

```swift
TimedChallengeManager.shared.start(config: .blitz)
manager.recordMove(underPar: true)   // +20 pts
manager.recordMistake()              // -50 pts
let result = manager.computeResult(moves: 5, mistakes: 1)
```

### Feature 2 — Arrow Chain Combos (`ComboEngine`)
Detects cascade reactions after each arrow removal:
- If any arrow becomes moveable immediately after a removal → **cascade**
- Combo streak increments; `multiplier = 1.0 + streak × 0.5`
- Banner text: "COMBO x2!", "TRIPLE!", "MEGA COMBO x4!", "UNSTOPPABLE x5!"
- Combo resets after 2s of no new cascade, or on undo/restart

```swift
// Called from GameState.commitMove after grid.remove()
comboEngine.evaluate(afterRemovingID: arrow.id, in: grid)
```

### Feature 3 — Rotatable Arrows (`Arrow` extension)
- `Arrow.type == .rotatable` enables rotation before tap
- `rotateClockwise(diagonalsEnabled:)` — cycles through cardinal or all-8 directions
- `rotateCounterClockwise(diagonalsEnabled:)` — reverse cycle
- Non-rotatable arrows ignore rotation calls

### Feature 4 — Snake Arrows (`Arrow` extension)
- Multi-cell arrows with `segments: [GridPosition]`
- `addSegment(_:)` — appends unique position
- `head` = `segments.first`, `tail` = `segments.last`
- `isSnake` = `type == .snake && segments.count > 1`

### Feature 5 — Replay / Solution Playback (`ReplayEngine`)
- **History mode:** records each `ReplayStep` during live play
- **Optimal mode:** computes `HintEngine.solveOrder` → animates solution
- Steps highlight `arrowID` via `@Published highlightedArrowID`
- `onStepExecuted` closure fires per step for scene animation

```swift
// In EndLevelView – "Watch Solution" button:
replayEngine.startOptimalReplay(grid: grid, hintEngine: hintEngine)
```

### Feature 6 — Weekly Challenges (`WeeklyChallengeManager`)
- Resets every **Monday 00:00 UTC**
- Week ID format: `"2026-W24"` (ISO 8601)
- Generated with `LevelGenerator(seed: weekID.hashValue)` → consistent hard level
- Stores `bestStars`, `bestScore`, `completed` flag
- Persists last 8 weeks of history

### Feature 7 — Challenge a Friend (`ChallengeShareManager`)
- Creates `SharedChallenge` with seed, dimensions, par, and optional challenger score
- **Share code:** URL-safe Base64 JSON blob (no `+/=` characters)
- **Deep link:** `zenith://challenge?code=<base64>`
- `ChallengeShareManager.level(from:)` reconstructs identical level from code

```swift
let challenge = ChallengeShareManager.shared.createChallenge(from: level, challengerScore: 450)
let code = challenge.shareCode          // "eyJsZXZlbElEIjo..."
let url  = manager.deepLinkURL(for: challenge)  // zenith://challenge?code=...
```

### Feature 9 — Streak Rewards (`StreakRewardManager`)
Milestones triggered by `ProgressManager.checkStreakRewards()` on app open:

| Streak | Reward |
|--------|--------|
| 3 days | +3 hints |
| 7 days | +7 hints |
| 14 days | Neon City theme unlock |
| 30 days | Cyber theme unlock |
| 60 days | +25 hints |
| 100 days | Pure Dark theme unlock |

`pendingReward` is set one milestone at a time; `StreakRewardView` modal shown.

### Feature 10 — Achievements (`AchievementManager`)
14 achievements synced to GameCenter:

| ID | Title | Requirement |
|----|-------|-------------|
| `zenith.stars.10` | Star Collector | 10 total stars |
| `zenith.stars.50` | Star Hunter | 50 total stars |
| `zenith.stars.100` | Star Hoarder | 100 total stars |
| `zenith.stars.500` | Star Legend | 500 total stars |
| `zenith.perfect.first` | Flawless | 3-star any level |
| `zenith.perfect.w1` | World 1 Master | 3-star all World 1 levels |
| `zenith.streak.7` | Week Warrior | 7-day streak |
| `zenith.streak.30` | Monthly Master | 30-day streak |
| `zenith.moves.1000` | Nimble Fingers | 1,000 total moves |
| `zenith.moves.10000` | Arrow Veteran | 10,000 total moves |
| `zenith.timed.5` | Speed Demon | 5 timed completions |
| `zenith.combo.3` | Chain Reaction | x3 combo |
| `zenith.combo.5` | Avalanche | x5 combo |
| `zenith.nohint.w1` | No Peeking | Clear World 1 without hints |

### Feature 11 — Slide Trail Effect (`TrailEffectView`)
- `TrailEffectViewModel.spawnTrail(along:color:)` called by `GameScene` with cell center points
- Spawns `TrailParticle` for each traversed cell with opacity falloff
- Particles fade out and scale down after 400ms, cleared after 750ms
- Rendered as a `ZStack` overlay on the `SpriteView`

### Feature 12 — Per-Star Celebration (`EndLevelView` + `HapticManager`)
- Stars animate with `0.28s` stagger delay
- Each star earned: `AudioManager.play(.star)` + `HapticManager.starEarned()` (0.1s sharp pulse)
- Distinct from `levelComplete()` triple-pulse haptic

### Feature 13 — Theme Unlocking (`ThemeManager`)
- "Zen Stone" is always free
- Other themes unlocked via: streak milestones (Features 9) or star count
  - Nature: 50 total stars
  - Neon City: 100 stars (or 14-day streak)
  - Cyber: 300 stars (or 30-day streak)
  - Pure Dark: 100-day streak only
- `ThemeManager.isUnlocked(themeKey:)` gates `select(themeKey:)`
- Settings shows lock icon + requirement text for locked themes

### Feature 14 — Grid Size Indicator (`LevelSelectView`)
- Each `LevelCell` now shows `"5×5"` grid dimensions
- Difficulty abbreviation badge: TUT / EZ / MED / HARD / EXP / ZEN
- Colored dot retained for at-a-glance difficulty

### Feature 15 — Smart Undo Highlight (`GameState` + `GameBoardView`)
- `undoReturnedArrowID` is set in `undo()` to the restored arrow's UUID
- `GameBoardView` shows `UndoReturnLabel` overlay ("↩ Arrow returned") for 700ms
- The SpriteKit `ArrowNode` entrance animation replays on the returned arrow

### Feature 16 — Move Counter Par Indicator (`GameHUDView`)
- Move count text color:
  - Green → moves < parMoves (under par)
  - Accent color → moves within 2 of par
  - Orange → moves > par + 2
- Sub-label `"par N"` always visible below the counter

### Feature 17 — Free Hint Cooldown (`GameState`)
- One free hint every **30 minutes** (no consumable deducted)
- `isFreeHintReady: Bool` — `true` when cooldown elapsed
- `freeHintCooldownLabel: String` — formatted countdown e.g. `"24m 15s"`
- HUD button shows:
  - Orange badge with count → use paid hint
  - Green clock badge → free hint ready
  - Countdown label → wait time

### Feature 18 — Colorblind Mode (`ColorblindManager` + `ColorblindOverlayView`)
- Toggle in Settings; 3 overlay modes: **Shapes**, **Labels**, **Both**
- Each `ArrowColor` maps to a unique `ColorblindShape` (SF Symbol) and letter label
- `ColorblindOverlayView` positioned bottom-right of arrow cell; `allowsHitTesting(false)`

| Color | Shape | Label |
|-------|-------|-------|
| white | circle | — |
| red | triangle | R |
| blue | square | B |
| green | diamond | G |
| yellow | star | Y |
| purple | pentagon | P |
| orange | cross | O |

### Feature 19 — Level Editor Sharing (`LevelEditorView`)
- Existing `LevelEditorView` extended with export via `ShareLink`
- Exports level JSON that can be decoded as `LevelDefinition`

### Feature 20 — Local Push Notifications (`NotificationManager`)
Three scheduled notifications:

| Notification | Schedule | Content |
|-------------|----------|---------|
| Daily Challenge | 9:00 AM daily | "🎯 Daily Challenge Ready!" |
| Weekly Challenge | Monday 10:00 AM | "🏆 New Weekly Challenge!" |
| Streak Reminder | 8:00 PM daily | "🔥 Don't Break Your Streak!" |

- `requestAuthorization()` → async/await; called on first `HomeView.onAppear`
- Badge cleared on every app open via `clearBadge()`
- Toggle in Settings calls `cancelAll()` on disable

---

## 11. Level System & JSON Format

### World JSON Schema
```json
{
  "id": 1,
  "name": "Basics",
  "themeKey": "zen",
  "description": "Learn the rules",
  "requiredStarsToUnlock": 0,
  "isUnlocked": true,
  "levels": [ /* LevelDefinition array */ ]
}
```

### Level JSON Schema
```json
{
  "id": "w1_l003",
  "worldID": 1,
  "index": 3,
  "gridRows": 4,
  "gridCols": 4,
  "difficulty": "easy",
  "parMoves": 4,
  "parTime": 90,
  "diagonalsEnabled": false,
  "title": "Chain Reaction",
  "arrows": [
    { "row": 0, "col": 0, "direction": "right", "type": "standard", "color": "white" }
  ],
  "obstacles": [
    { "row": 2, "col": 2, "kind": "wall" },
    { "row": 0, "col": 3, "kind": "portal", "portalID": 1, "portalColor": "red" },
    { "row": 3, "col": 0, "kind": "portal", "portalID": 1, "portalColor": "red" }
  ]
}
```

### Daily Challenge Generation
```swift
let seed = Int(Date().timeIntervalSince1970 / 86400)  // changes at UTC midnight
generator.generate(seed: seed, rows: 5, cols: 5, arrowCount: 8, difficulty: .medium)
```

---

## 12. Persistence & Storage

All persistence uses `UserDefaults` with JSON encoding:

| Key | Content | Manager |
|-----|---------|---------|
| `zenith_stats_v1` | `Stats` (totalStars, moves, streak, hints, lastPlayedDate) | `ProgressManager` |
| `zenith_progress_v1` | `ProgressRecord` (levelStars, unlockedLevelIDs, unlockedWorldIDs) | `LevelManager` |
| `zenith_theme_v1` | Selected theme key string | `ThemeManager` |
| `zenith_unlocked_themes_v1` | `[String]` unlocked theme keys | `ThemeManager` |
| `zenith_music` | Bool | `AudioManager` |
| `zenith_sfx` | Bool | `AudioManager` |
| `zenith_haptics_enabled` | Bool | `HapticManager` |
| `zenith_colorblind_v1` | Bool | `ColorblindManager` |
| `zenith_colorblind_mode_v1` | String (shapes/labels/both) | `ColorblindManager` |
| `zenith_achievements_v2` | `[Achievement]` JSON | `AchievementManager` |
| `zenith_streak_rewards_v1` | `[StreakMilestone]` JSON | `StreakRewardManager` |
| `zenith_weekly_v1` | `Storage{current, past}` JSON | `WeeklyChallengeManager` |
| `zenith_timed_best_scores_v1` | `[String: Int]` JSON | `TimedChallengeManager` |
| `zenith_analytics_buffer` | `[[String:Any]]` | `AnalyticsManager` |

---

## 13. Testing

### Test File
`ZenithArrowsTests/ZenithArrowsTests.swift` — **110 test cases** across **18 test classes**

### Test Coverage by Area

| Class | Tests | Coverage Area |
|-------|-------|---------------|
| `GridModelTests` | 7 | Place, remove, slide path, OOB, deep copy |
| `MoveValidatorTests` | 5 | Standard, locked, heavy, dependency graph |
| `HintEngineTests` | 4 | Next move, solve order, deadlock, solvability |
| `TimedChallengeTests` | 6 | Feature 1: start, scoring, stars, persistence |
| `ComboEngineTests` | 4 | Feature 2: increment, reset, multiplier, label |
| `RotatableArrowTests` | 6 | Feature 3: CW, CCW, wrap, diagonal, non-rotatable |
| `SnakeArrowTests` | 5 | Feature 4: segments, isSnake, head/tail, dedup |
| `ReplayEngineTests` | 5 | Feature 5: record, optimal replay, stop, step content |
| `WeeklyChallengeTests` | 6 | Feature 6: existence, difficulty, completion, no-downgrade |
| `ChallengeShareTests` | 5 | Feature 7: create, round-trip encode/decode, URL, invalid |
| `StreakRewardTests` | 4 | Feature 9: milestones order, reward values |
| `AchievementTests` | 5 | Feature 10: catalog, unlock threshold, progress, combo, perfect |
| `ThemeUnlockTests` | 5 | Feature 13: zen free, unlock, locked selection guard, star unlock |
| `GridSizeIndicatorTests` | 2 | Feature 14: dimensions from model |
| `UndoHighlightTests` | 1 | Feature 15: undoReturnedArrowID set after undo |
| `ParIndicatorTests` | 3 | Feature 16: parMoves, isUnderPar, movesOverPar |
| `FreeHintTests` | 4 | Feature 17: ready by default, cooldown after use, no decrement |
| `ColorblindModeTests` | 4 | Feature 18: unique shapes, toggle, mode switching |
| `NotificationTests` | 3 | Feature 20: identifiers, cancel |
| `StarRatingTests` | 5 | 3/2/1 star scenarios + edge cases |
| `GameStateIntegrationTests` | 7 | Restart, pause/resume, wrong tap, undo, combo/replay integration |
| `LevelGeneratorTests` | 3 | Solvable, deterministic, dimensions |

### Running Tests
```bash
xcodebuild test \
  -project ZenithArrows.xcodeproj \
  -scheme ZenithArrows \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  | xcpretty
```

---

## 14. Build & Run

### Requirements
- Xcode 16+
- iOS 17.0+ deployment target
- macOS 14+ (Sonoma) for building

### Build for Simulator
```bash
xcodebuild build \
  -project ZenithArrows.xcodeproj \
  -scheme ZenithArrows \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' \
  | xcpretty
```

### Boot & Launch
```bash
xcrun simctl boot "71189EA8-5CF8-4FA1-87DE-C754210AAFF3"
xcrun simctl install booted /path/to/ZenithArrows.app
xcrun simctl launch booted com.zenith.ZenithArrows
```

### Scheme Configuration
- **Debug:** `DEBUG=1`, no bitcode, full Swift debug info
- **Release:** Compiler optimizations on, strip symbols

### Info.plist Keys
| Key | Value |
|-----|-------|
| `NSUserNotificationsUsageDescription` | Required for Feature 20 |
| `UIRequiredDeviceCapabilities` | `armv7` (haptics need physical device) |

---

## 15. Feature Reference Table

| # | Feature | Files Added | Files Modified |
|---|---------|-------------|----------------|
| 1 | Timed Challenge Mode | `TimedChallengeManager.swift` | `AnalyticsManager` |
| 2 | Arrow Chain Combos | `ComboEngine.swift` | `GameState`, `GameHUDView` |
| 3 | Rotatable Arrows | — | `ArrowModel` (extension) |
| 4 | Snake Arrow Mechanic | — | `ArrowModel` (extension) |
| 5 | Replay / Solution | `ReplayEngine.swift` | `GameState`, `GameBoardView`, `EndLevelView` |
| 6 | Weekly Challenges | `WeeklyChallengeManager.swift`, `WeeklyChallengeView.swift` | `HomeView` |
| 7 | Challenge a Friend | `ChallengeShareManager.swift` | `AnalyticsManager` |
| 8 | Level Editor Share | — | `LevelEditorView` |
| 9 | Streak Rewards | `StreakRewardManager.swift`, `StreakRewardView.swift` | `ProgressManager`, `HomeView`, `ThemeManager` |
| 10 | Achievements | `AchievementManager.swift`, `AchievementsView.swift` | `ProgressManager`, `HomeView`, `AnalyticsManager` |
| 11 | Slide Trail Effect | `TrailEffectView.swift` | `GameBoardView` |
| 12 | Per-Star Celebration | — | `EndLevelView`, `HapticManager` |
| 13 | Theme Unlocking | — | `ThemeManager`, `SettingsView`, `ProgressManager` |
| 14 | Grid Size Indicator | — | `LevelSelectView` |
| 15 | Smart Undo Highlight | — | `GameState`, `GameBoardView` |
| 16 | Par Indicator | — | `GameState`, `GameHUDView` |
| 17 | Free Hint Cooldown | — | `GameState`, `GameHUDView` |
| 18 | Colorblind Mode | `ColorblindManager.swift` | `SettingsView` |
| 19 | Level Pack Export | — | `LevelEditorView` |
| 20 | Push Notifications | `NotificationManager.swift` | `HomeView`, `SettingsView` |
