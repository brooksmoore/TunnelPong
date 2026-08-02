# CyberPong (iOS, v1 — wrapped)

2.5D retrowave tunnel Pong: look down a neon wireframe hallway, drag your paddle,
volley against an AI at the far end. Pure SpriteKit, zero assets, zero
dependencies. iOS 17+, iPhone (+ Mac Catalyst desktop play), portrait locked.

**v1 is feature-complete for solo play.** Pause before v2 multiplayer until the
STATUS gate is green (device feel, Config freeze, cold second-person test).

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

Campaign is **10 levels**, linear L1→L10. Each ramping variable has an `*L1` and `*L10` pair — edit those endpoints, not ad-hoc multipliers.

1. **`aiErrorL1` / `aiErrorL10`** — aim noise (higher = easier).
2. **`ballSpeedL1` / `ballSpeedL10`** — ball speed.
3. **`aiLateralFracL1` / `aiLateralFracL10`** — AI XY as a fraction of ball lateral max (L10 ≈ 0.94, never 1.0).

Player paddle does **not** ramp. When dials stop moving every session, mark that on the v2 gate in `STATUS.md`.

## Rules (solo v1)

- You: 3 lives for the run. Opponent: 3 per level. **10 levels** total; clear L10 → win.
- Difficulty is linear from L1 (calibrated easy) to L10 (near-max AI + physics).
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
