# Tunnel Pong (iOS, v1)

2.5D tunnel Pong: look down a wireframe hallway, drag your paddle with a finger,
volley against an AI at the far end. Pure SpriteKit, zero assets, zero
dependencies. iOS 17+, iPhone only, portrait locked.

## Structure

```
TunnelPong/
├── TunnelPong.xcodeproj          ← open this in Xcode
├── TunnelPong/
│   ├── AppDelegate.swift          app entry
│   ├── GameViewController.swift   SKView host (portrait, 120fps-capable)
│   ├── Config.swift               EVERY tunable number — tune here only
│   ├── Projection.swift           perspective divide + CourtMath (unit-tested)
│   ├── GameScene.swift            state machine, physics, AI, HUD, touch
│   ├── Nodes.swift                procedural visual builders
│   └── Haptics.swift              pre-warmed feedback generators
└── TunnelPongTests/
    └── CourtMathTests.swift       pure math tests (⌘U in Xcode)
```

## Run on your iPhone

1. Open `TunnelPong.xcodeproj` in Xcode (15 or newer).
2. Click the `TunnelPong` target → **Signing & Capabilities** → check
   **Automatically manage signing** and pick your **Team** (your free Apple ID
   works: Xcode → Settings → Accounts → add Apple ID).
3. Plug in your iPhone. On the phone: Settings → Privacy & Security →
   **Developer Mode** → on (iOS 16+ requires this; the phone reboots).
4. Pick your iPhone in the device dropdown at the top of Xcode, press **⌘R**.
5. First run only: on the phone, Settings → General → **VPN & Device
   Management** → trust your developer certificate, then launch again.

## If the difficulty feels wrong, tune these first (in `Config.swift`)

1. **`aiErrorBase`** (46) — the opponent's aim slop at level 1.
   Too hard → raise it (opponent misses more). Too easy → lower it.
   This is the strongest single dial.
2. **`ballBaseSpeed`** (620) — level-1 ball speed.
   Too hard → lower toward 520. Too easy → raise toward 720.
3. **`aiBaseSpeed`** (240) — how fast the opponent's paddle travels at level 1.
   Too hard → lower it (it can't reach corner shots). Too easy → raise it.

Feel dials: `paddleSmoothing` (higher = snappier finger tracking),
`touchOffsetY` (how far the paddle rides above your thumb),
`englishMultiplier` (how much off-center hits bend the return).

## Rules

- You: 3 lives for the whole run. Opponent: 3 per level.
- Clear the opponent's 3 lives to level up; each level the ball is +12% faster,
  the opponent +16% faster and 20% more accurate (formulas in `Config.swift`).
- Score: 10 × level per paddle hit, 100 × level per opponent life.
  High score persists via `UserDefaults`.

## Tests

In Xcode: open the project, pick any iPhone simulator/device, press **⌘U**.
`CourtMathTests` covers perspective scale, wall-fold `reflect`, velocity renorm
(min z-share), ring helpers, and move-toward.

Out of scope for v1 (deliberately): sound, multiplayer, networking, ads, IAP,
analytics, accounts.
