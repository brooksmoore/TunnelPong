# CyberPong — MEMORY

Durable context for future AI sessions (Claude / Grok / Composer).  
Ephemeral ship state → `STATUS.md`. Dated history → `LEDGER.md` (append-only).

---

## What this is

**CyberPong** (repo folder still `TunnelPong`): solo 2.5D SpriteKit tunnel Pong, retrowave theme, 10-level campaign. Pure code, zero assets, zero packages.

- Bundle ID: `com.brooksmoore.tunnelpong`
- Platforms: iOS 17+ iPhone (portrait); Mac Catalyst for desktop debug
- v1 **feature-wrapped** 2026-08-01 — **do not start v2** until STATUS gate is green

---

## Architecture (v1)

| File | Role |
|------|------|
| `Config.swift` | **Only place to tune.** Difficulty is L1/L10 linear pairs + layout insets |
| `Projection.swift` | Perspective + CourtMath; `PeerMirror` inert (v2 prep) |
| `GameScene.swift` | State machine, physics, AI, serve, HUD, chrome layout |
| `Nodes.swift` | Procedural rings / paddles / shaded ball / labels |
| `GameViewController.swift` | SKView, safe insets, Mac hover paddle |
| `AppDelegate.swift` | Window; Mac phone-shaped frame |
| `bin/play-mac.sh` | Build+launch Catalyst (derived data off Desktop) |

**Physics:** z-crossing paddle hits (not screen overlap). English on off-center hits. AI leashed so XY speed ≤ fraction of ball max lateral (L10 ≈ 0.94, never 1.0).

**Player:** full paddle snap always (no skill ramp).  
**AI + ball speed + english + reaction:** ramp L1→L10 only.

---

## Serve / AI point reset (locked feel)

- User serves first each round (incl. L1 and each new level).
- After user scores → user serves; after miss → opponent auto-serves.
- Serve ball **fixed court center** until paddle covers it + strike (Mac click / iOS swipe).
- **Every `scheduleServe`:** opponent paddle snaps to **(0,0)**; AI frozen at center while `!ballLive`.

---

## Chrome / safe area

- HUD and title use `safeInsets` + `hudTopPad` / `hudBottomPad`.
- Mac Catalyst: min top inset `macTitlebarInset` (40) so titlebar doesn’t clip HUD/wordmark.
- `applyChromeLayout()` on present + layout changes. Court stays screen-centered; chrome moves into safe band.
- iOS: notch / home indicator via real safe area (async re-layout after insets settle).

---

## Theme (from Desktop c1/c2/c3)

- Black majority
- Player cyan · opponent magenta · ball sunset orange · tunnel violet wire
- Fonts: Avenir Next Condensed / DemiBold
- Title: **CYBER** / **PONG**
- Paddle hit: brief alpha flash

---

## v2 (do not implement yet)

Gate in STATUS: multi-session device play, Config freeze, cold second-person.  
Docs: `docs/ROADMAP.md`, `docs/V2_DESIGN.md`. Code: `PeerMirror` only.

---

## How to run

```bash
# Mac desktop
/Users/brooksmoore/Desktop/TunnelPong/bin/play-mac.sh

# iPhone
open TunnelPong.xcodeproj  # Xcode 26.1 → device BCM 16 Pro Max → signing team → ⌘R
# Trust developer: Settings → General → VPN & Device Management
```

---

## For Claude review — focus areas

1. Serve / AI center reset correctness  
2. Safe-area / Mac titlebar chrome layout  
3. Difficulty L1–L10 table and AI lateral leash  
4. Whether v1 wrap is honest (no half-done multiplayer)  
5. Any residual HUD/title clip on Catalyst or notched iPhone  
