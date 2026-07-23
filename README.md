# Tunnel Pong (iOS, v1)

2.5D tunnel Pong: look down a wireframe hallway, drag your paddle with a finger,
volley against an AI at the far end. Pure SpriteKit, zero assets, zero
dependencies. iOS 17+, iPhone only, portrait locked.

**Roadmap:** [docs/ROADMAP.md](docs/ROADMAP.md) · **v2 blueprint:** [docs/V2_DESIGN.md](docs/V2_DESIGN.md) · **Now:** [STATUS.md](STATUS.md) · **History:** [LEDGER.md](LEDGER.md)

> **v2 local multiplayer is gated.** Do not start Multipeer / 1v1 code until the
> checklist in `STATUS.md` is all green (device play, stable Config, second-person playtest).

## Structure

```
TunnelPong/
├── STATUS.md / LEDGER.md / README.md
├── docs/
│   ├── ROADMAP.md                 v1→v2→v3 scope, gate, decisions
│   └── V2_DESIGN.md               local 1v1 implementation blueprint
├── TunnelPong.xcodeproj
├── TunnelPong/
│   ├── AppDelegate.swift
│   ├── GameViewController.swift
│   ├── Config.swift               EVERY tunable number — tune here only
│   ├── Projection.swift           Projector + CourtMath + PeerMirror
│   ├── GameScene.swift            solo state machine, physics, AI, HUD
│   ├── Nodes.swift
│   └── Haptics.swift
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

1. **`aiErrorBase`** (46) — strongest dial; raise = easier opponent.
2. **`ballBaseSpeed`** (620) — lower toward 520 if too hard.
3. **`aiBaseSpeed`** (240) — lower if AI reaches corners too well.

Also: `paddleSmoothing`, `touchOffsetY`, `englishMultiplier`.

When Config stops changing every session, mark that on the v2 gate in `STATUS.md`.

## Rules (solo v1)

- You: 3 lives for the run. Opponent: 3 per level.
- Clear opponent lives → level up; ball +12%/level, AI +16%/level, error ×0.80/level.
- Score: 10 × level per hit, 100 × level per opponent life. High score in `UserDefaults`.

## Tests

Xcode → **⌘U**. Covers perspective, wall fold, velocity renorm, ring helpers, **PeerMirror** (v2 coordinate prep).

## Scope

| Version | Status |
|---------|--------|
| v1 solo | **Current** |
| v2 local 1v1 (Multipeer, split authority) | Gated — see STATUS |
| v3 internet (GameKit) | Deferred; prefer ghost/leaderboards unless demand |

Out of scope for v1: sound, multiplayer, networking, ads, IAP, analytics, accounts.
