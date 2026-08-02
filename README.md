# CyberPong (iOS, v1 — wrapped)

2.5D retrowave tunnel Pong: look down a neon wireframe hallway, drag your paddle,
volley against an AI at the far end. **Endless high-score chase** — no ending,
just how deep you get. Pure SpriteKit, zero assets, zero dependencies. iOS 17+,
iPhone (+ Mac Catalyst desktop play), portrait locked.

**v1 is feature-complete for solo play.** Pause before v2 multiplayer until the
STATUS gate is green (device feel, Config freeze, cold second-person test).

**Roadmap:** [docs/ROADMAP.md](docs/ROADMAP.md) · **v2 blueprint:** [docs/V2_DESIGN.md](docs/V2_DESIGN.md) · **Now:** [STATUS.md](STATUS.md) · **History:** [LEDGER.md](LEDGER.md)

> **v2 local multiplayer is gated.** Do not start Multipeer / 1v1 code until the
> checklist in `STATUS.md` is all green (device play, stable Config, second-person playtest).

## Structure

```
TunnelPong/
├── STATUS.md / LEDGER.md / MEMORY.md / README.md
├── docs/
│   ├── ROADMAP.md                 v1→v2→v3 scope, gate, decisions
│   └── V2_DESIGN.md               local 1v1 implementation blueprint
├── bin/play-mac.sh                Mac Catalyst build + launch
├── bin/make-icon.swift            regenerate app icon
├── TunnelPong.xcodeproj
├── TunnelPong/
│   ├── AppDelegate.swift
│   ├── GameViewController.swift
│   ├── Config.swift               EVERY tunable number — tune here only
│   ├── Projection.swift           Projector + CourtMath + PeerMirror
│   ├── GameScene.swift            solo state machine, physics, AI, HUD
│   ├── Nodes.swift
│   ├── PixelFont.swift            procedural 5×7 type
│   ├── Audio.swift                procedural SFX + ambient (zero audio files)
│   ├── Haptics.swift
│   └── Assets.xcassets            app icon only
└── TunnelPongTests/
    └── CourtMathTests.swift       math + PeerMirror tests (⌘U)
```

## Run on your iPhone

1. Open `TunnelPong.xcodeproj` in **Xcode 26.1** (or current), not a leftover old Xcode if you have both.
2. Target → **Signing & Capabilities** → Automatically manage signing → your **Team**.
3. Plug in iPhone → Developer Mode on → pick device → **⌘R**.
4. First run: Settings → General → **VPN & Device Management** → trust cert.

### Simulator note (Mac)

Prefer:

```bash
open /Applications/Xcode-26.1.app/Contents/Developer/Applications/Simulator.app
```

A legacy `/Applications/Xcode.app` Simulator (v13.x) can crash on modern macOS
(“Simulator quit unexpectedly”). Boot **one** iPhone device only.

## If the difficulty feels wrong, tune these first (`Config.swift`)

Difficulty ramps linearly L1→L10 and then **holds at L10 forever**. Each ramping
variable has an `*L1` and `*L10` pair — edit those endpoints, not ad-hoc multipliers.

1. **`aiSpeedL1` / `aiSpeedL10`** — how fast the AI can chase the ball's
   **current** XY. **Only** AI skill dial (live tracking — no intercept
   prediction, no aim error, no reaction delay).
2. **`ballSpeedL1` / `ballSpeedL10`** — ball speed.
3. **`englishL1` / `englishL10`** — off-center spin bite (your skill expression).

`aiLateralFracL1/L10` is **not** a tuning dial — safety ceiling only so the AI
can never become a perfect wall if you crank `aiSpeedL10`.

Player paddle does **not** ramp. When dials stop moving every session, mark that on the v2 gate in `STATUS.md`.

## Rules (solo v1)

**Endless high-score chase — there is no "win".** Levels count up forever; the
difficulty curve maxes out at L10 and stays there. The run ends when you run out
of lives, and the high score is the game.

- **Lives are *spare* lives.** The HUD hearts are what you have left over. Start
  with 3. At **0 hearts the HUD reads `LAST LIFE`** — the next miss ends the run.
  So 3 hearts = 4 misses.
- **Clearing a level returns one spare, capped at 3.** You can't bank lives you
  never lost, so a clean level grants nothing and the pressure never fully lifts.
- Opponent: 3 lives per level. Take all 3 → next level.
- Score: 10 × level per hit, 100 × level per opponent life. Since level is
  uncapped, deep runs are worth exponentially more. High score in `UserDefaults`.

## Tests

Xcode → **⌘U**. Covers perspective, wall fold, velocity renorm, ring helpers, **PeerMirror** (v2 coordinate prep).

## Scope

| Version | Status |
|---------|--------|
| v1 solo (endless score chase) | **Current** |
| v2 local 1v1 (Multipeer, split authority) | Gated — see STATUS |
| v3 internet (GameKit) | Deferred; prefer ghost/leaderboards unless demand |

Out of scope for v1: multiplayer, networking, ads, IAP, analytics, accounts.
(Audio is in: procedural, no asset files.)
