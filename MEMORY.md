# CyberPong — MEMORY

Durable context for future AI sessions (Claude / Grok / Composer).  
Ephemeral ship state → `STATUS.md`. Dated history → `LEDGER.md` (append-only).

---

## What this is

**CyberPong** (repo folder still `TunnelPong`): solo 2.5D SpriteKit tunnel Pong, retrowave / modern GBC look, **endless high-score chase**. Pure code, **zero image/audio asset files** (except generated app icon), zero packages.

**Core design rule (Brooks): there is no "win".** Score is the game. Levels count forever; `Config.maxLevel` (10) is a *difficulty ceiling*, not an ending.

**Lives are spare lives.** 3 hearts = 4 misses; empty heart row = last life. Clear level → +1 spare, cap 3.

- Bundle ID: `com.brooksmoore.tunnelpong`
- Platforms: iOS 17+ iPhone/iPad (portrait + landscape); Mac Catalyst free resize
- v1 feature-wrapped — **do not start v2** until STATUS gate is green

---

## Architecture (v1)

| File | Role |
|------|------|
| `Config.swift` | **Only place to tune** — difficulty pairs, palette, audio levels, layout |
| `Projection.swift` | Perspective + CourtMath; `PeerMirror` inert (v2 prep + tests) |
| `GameScene.swift` | State machine, physics, AI, serve, HUD, chrome |
| `Nodes.swift` | Procedural sky / tunnel / paddles / ball |
| `PixelFont.swift` | 5×7 procedural type; chrome titles (3-band pink→purple) |
| `Audio.swift` | Procedural retrowave SFX + ambient pad (AVAudioEngine) |
| `Haptics.swift` | Impact / notification generators |
| `GameViewController.swift` | SKView, safe insets, Mac hover paddle |
| `AppDelegate.swift` | Window; Mac phone-shaped frame |
| `bin/play-mac.sh` | Build+launch Catalyst (derived data off Desktop) |
| `bin/make-icon.swift` | Regenerates 1024 app icon into Assets |

---

## Locked gameplay models

### AI (Brooks 2026-08-02 — corrected)

- **Pure live ball XY only.** Every frame: chase current `(bx, by)`.
- **Forbidden:** far-plane intercept (`tHit = (zFar - bz) / vz`), `CourtMath.reflect` wall-fold for aim, aim error, reaction delay, idle dodge.
- **Only dial:** linear `aiSpeedL1` → `aiSpeedL10` (~96 → 490).
- `aiLateralFrac*` = safety ceiling only (caps raw speed vs ball lateral budget).

Why: intercept prediction pre-positions the paddle at the arrival point and reads as psychic. Tracking live XY means cuts and wall bounces beat a lagging opponent; speed ramp is the only skill curve.

### Physics
- Z-crossing paddle hits (not screen overlap).
- English on off-center hits; serve drag spin; corner boost.
- Spin turned up so placement/drag read clearly.

### Serve / reset
- User serves first each round/level; after score you serve; after miss opponent auto-serves.
- Serve ball fixed court center until paddle covers + strike.
- iOS: mid-drag swipe when cumulative travel > `serveSwipeMin` (14pt path length).
- Lift/click also serves if paddle overlaps (spin from net gesture when present).
- Every `scheduleServe`: opponent snaps to (0,0); AI frozen while `!ballLive`.

### Controls
- **iOS:** elastic relative trackpad (`touchGain` 2.3) with wall re-anchor.
- **Mac:** absolute hover-follow; click for serve/UI.

### Feedback
- No full-screen flash on points/levels.
- Point = heart disappears immediately + SFX/haptics.
- Wall hit = ring colour flash; paddle hit = shell + fill brighten.
- Audio: player high tick / opponent low tok; ambient attach-once.

---

## Theme (current)

**Refs:** Desktop `c3.png` (sky), `r1.jpg` (title energy).

- **Sky:** black top → dark purples → thin muted pink base; Bayer dither; full-frame 1px stars; crescent moon. No mountains.
- **No** vanishing glow, dust motes, or live twinkle stars.
- **Tunnel:** transparent walls; neon-pink strokes; continuous corner rails meeting **rounded** rings via 45° arc anchors; far ring drawn.
- **Actors:** player cyan · opponent magenta · ball orange pixel disc.
- **Type:** HUD plain pixel; titles chrome 3-band + purple rim.
- **LCD** row overlay + light vignette.

---

## Chrome / safe area

- Court fitted to **safe vertical band** (notch / Dynamic Island / home indicator).
- Hearts in Island *ear* band when topSafe ≥ 44.
- LV + score hang below top wall (`courtTopY - hudTopGap`).
- Mac: `macTitlebarInset` (40).
- `applyChromeLayout()` rebuilds tunnel geometry on resize.

---

## v2 (do not implement yet)

Gate in STATUS: multi-session device play, difficulty fair, Config freeze, cold second person.  
Docs: `docs/ROADMAP.md`, `docs/V2_DESIGN.md`. Code: `PeerMirror` only — **not wired**.

---

## How to run

```bash
/Users/brooksmoore/Desktop/TunnelPong/bin/play-mac.sh
open TunnelPong.xcodeproj   # device: BCM 16 Pro Max, signing team, ⌘R
```

---

## For any AI picking up

1. Read **STATUS.md** first.
2. Tune **only Config.swift** for feel.
3. AI must stay pure live-XY tracking — never reintroduce intercept prediction.
4. Do not start Multipeer until gate is green.
5. Open v1: freeze Config after multi-session play; second-person cold test.
