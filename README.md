# ZenithArrows — iOS Puzzle Game

A premium, minimalist logic puzzle game for iOS built with **Swift + SwiftUI + SpriteKit**.

## Project Structure

```
ZenithArrows/
├── App/
│   └── ZenithArrowsApp.swift          # @main entry point + AppDelegate
├── Models/
│   ├── ArrowModel.swift               # Arrow, ArrowDirection, GridPosition
│   ├── GridModel.swift                # Live grid, cell contents, path checking
│   ├── LevelModel.swift               # LevelDefinition, World, obstacle placement
│   └── GameState.swift                # Observable session state, undo, timer
├── GameLogic/
│   ├── MoveValidator.swift            # Validates moves, builds dependency graph
│   ├── HintEngine.swift               # Topological sort → next safe move
│   ├── LevelManager.swift             # Loads worlds/levels, persists progress
│   └── LevelGenerator.swift          # Procedural solvable level generation
├── SpriteKit/
│   ├── GameScene.swift                # Main SKScene, bridges model ↔ renderer
│   ├── ArrowNode.swift                # Arrow sprite, slide animation, particles
│   └── GridNode.swift                 # Grid background, highlights, obstacles
├── Views/
│   ├── HomeView.swift                 # Root navigation: Play, Daily, Chapters
│   ├── LevelSelectView.swift          # World map + level grid
│   ├── GameBoardView.swift            # SpriteKit wrapper + HUD
│   ├── GameHUDView.swift              # Pause, Undo, Hint, timer, lives
│   ├── EndLevelView.swift             # Stars, stats, share, next level
│   ├── PauseMenuView.swift            # Resume, Restart, Quit
│   ├── SettingsView.swift             # Audio, Theme, IAP, About
│   ├── TutorialView.swift             # Guided first-5-levels overlay
│   └── LevelEditorView.swift          # In-app level designer + JSON export
├── Managers/
│   ├── ThemeManager.swift             # 5 visual themes (Zen, Neon, Cyber, Nature, Dark)
│   ├── HapticManager.swift            # Core Haptics integration
│   ├── AudioManager.swift             # AVFoundation music + SFX
│   ├── ProgressManager.swift          # Stats, streaks, Game Center
│   └── AnalyticsManager.swift         # Privacy-first local event buffering
└── Resources/
    └── Levels/
        ├── world1.json               # World 1: Basics (10 levels, 4×4–5×5)
        ├── world2.json               # World 2: Obstacles (5 levels, 5×5–6×6)
        ├── world3.json               # World 3: Complexity (2 levels, 7×7–8×8)
        └── world4.json               # World 4: Zenith (2 levels, 9×9–10×10)
```

---

## Setting Up the Xcode Project

### 1. Create the Xcode project

1. Open **Xcode → File → New → Project**
2. Choose **App** (iOS)
3. Product Name: `ZenithArrows`
4. Interface: **SwiftUI**
5. Language: **Swift**
6. Uncheck "Include Tests" (add later)
7. Set the location to this folder

### 2. Add source files

Drag all folders (`App/`, `Models/`, `GameLogic/`, `SpriteKit/`, `Views/`, `Managers/`) into the Xcode project navigator. Make sure **"Copy items if needed"** is checked.

### 3. Add level JSON files

Drag `Resources/Levels/*.json` into Xcode and ensure they are added to the **Target** (tick the checkbox).

### 4. Add SpriteKit Particle file (optional but recommended)

- File → New → File → SpriteKit Particle File
- Name: `ArrowTrail`
- Configure to taste; `ArrowNode.swift` uses it automatically.

### 5. Frameworks

Add these in **Target → General → Frameworks, Libraries**:
- `SpriteKit.framework` ✅
- `GameKit.framework` ✅
- `CoreHaptics.framework` ✅
- `AVFoundation.framework` ✅

### 6. Capabilities

In **Target → Signing & Capabilities**:
- **Game Center** — for leaderboards
- **In-App Purchase** — for Shop
- **iCloud + CloudKit** — optional for cross-device sync

### 7. Info.plist keys

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use analytics to improve difficulty balancing. No data is sold.</string>
```

---

## Core Algorithm: Solvability via Reverse Simulation

```
LevelGenerator:
  1. Start with empty grid
  2. For each arrow to place:
     a. Pick a random empty cell
     b. Find a direction whose path to the edge is completely clear
     c. Place the arrow
  3. The placement order is the reverse solution order → always solvable

HintEngine (topological sort):
  1. Find all arrows with no blockers (moveable NOW)
  2. Remove one from the simulated grid
  3. Repeat until empty or deadlock detected
  4. Return the ordered sequence → first element is the hint
```

---

## Game Mechanics Quick Reference

| Feature | Implementation |
|---|---|
| Arrow slide validation | `MoveValidator.validateMove()` → `GridModel.slidePath()` |
| Undo (10 moves) | `GameState.undo()` restores grid snapshot from `undoStack` |
| Hint system | `HintEngine.nextSafeMove()` → highlights arrow in `GameState` |
| Procedural levels | `LevelGenerator.generate(seed:rows:cols:arrowCount:)` |
| Daily challenge | Seeded by `floor(today / 86400)` → deterministic per day |
| Theming | `ThemeManager.current` injected into `GameScene` + SwiftUI views |
| Haptics | `HapticManager` wraps `CHHapticEngine` with UIKit fallback |
| Progress | `UserDefaults` + `LevelManager.saveProgress()` |
| Leaderboard | `GKScore` reported in `ProgressManager.recordLevelComplete()` |

---

## Adding More Levels

1. Open the relevant `worldN.json` in `Resources/Levels/`
2. Add a new object to the `"levels"` array following the existing schema
3. Validate solvability using the in-app **Level Editor** (tap "Validate")
4. Export JSON and paste it into the world file

---

## Monetization (Freemium Model)

| Product | Description | Suggested Price |
|---|---|---|
| `com.zenith.removeads` | Remove all ads | $1.99 |
| `com.zenith.fullunlock` | All 1000+ levels | $3.99 |
| `com.zenith.hints10` | 10 hint pack | $0.99 |
| `com.zenith.hints50` | 50 hint pack (best value) | $2.99 |

Implement StoreKit 2 (`Product.purchase()`) in `ShopView.swift`.

---

## Localization

Add `.lproj` folders for: `en`, `es`, `fr`, `de`, `ja`, `zh-Hans`, `ko`, `pt-BR`.
All user-facing strings in views should use `NSLocalizedString`.

---

## Performance Notes

- `GameScene` uses `scaleMode = .resizeFill` and targets 120 FPS (`preferredFramesPerSecond: 120`)
- `GridModel` uses a flat 2D array for O(1) cell access
- Arrow nodes use `SKEffectNode` for glow — disable on older devices by checking `ProcessInfo.processInfo.thermalState`
- Undo stack is capped at 10 to limit memory usage

---

## App Store Checklist

- [ ] App icon (1024×1024 + all required sizes via asset catalog)
- [ ] Screenshots for iPhone 6.7" and iPad 12.9"
- [ ] Privacy Nutrition Labels (no user tracking by default)
- [ ] Age rating: 4+
- [ ] Game Center enabled
- [ ] TestFlight beta before release
