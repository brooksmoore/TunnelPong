# CyberPong — MEMORY

Durable context for future AI sessions (Claude / Grok / Composer).  
Ephemeral ship state → `STATUS.md`. Dated history → `LEDGER.md` (append-only).

---

## What this is

**CyberPong** (repo folder still `TunnelPong`): solo 2.5D SpriteKit tunnel Pong, retrowave / modern GBC look, **endless high-score chase**. Pure code, **zero image/audio asset files**, zero packages.

**Core design rule (Brooks): there is no "win".** Score is the game. Levels count forever; `Config.maxLevel` (10) is a *difficulty ceiling*, not an ending.

**Lives are spare lives.** 3 hearts = 4 misses; empty heart row = last life (no LAST LIFE label). Clear level → +1 spare, cap 3.

- Bundle ID: `com.brooksmoore.tunnelpong`
- Platforms: iOS 17+ iPhone (portrait); Mac Catalyst for desktop debug
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

---

## Locked gameplay models

### AI (Brooks 2026-08-02)
- **Pure tracking only.** Intercept far plane when outbound; track ball XY when inbound.
- **No** aim error, reaction delay, idle recenter, or ease-in curve.
- **Only dial:** linear `aiSpeedL1` → `aiSpeedL10` (~96 → 490, ×2 from 48→245).
- `aiLateralFrac*` = safety ceiling only (not a skill dial).

### Physics
- Z-crossing paddle hits (not screen overlap).
- English on off-center hits; serve drag spin; corner boost.
- Spin turned up vs early builds so placement/drag read clearly.

### Serve / reset
- User serves first each round/level; after score you serve; after miss opponent auto-serves.
- Serve ball fixed court center until paddle covers + strike.
- Every `scheduleServe`: opponent snaps to (0,0); AI frozen while `!ballLive`.

### Feedback
- **No full-screen flash** on points/levels (removed — felt harsh).
- Point = heart disappears immediately + SFX/haptics; optional short freeze before next serve.
- Wall hit = ring colour flash (depth cue).
- Paddle hit = shell + fill brighten.
- Audio: player paddle high tick / opponent low tok.

---

## Theme (current)

**Refs:** Desktop `c3.png` (sky), `r1.jpg` (title energy).

- **Sky:** black top third → dark purples → thin muted pink base; Bayer dither; **full-frame** deterministic 1px stars; crescent moon. No mountains.
- **No** vanishing glow, dust motes, or live twinkle stars (caused floating pink blink).
- **Tunnel:** transparent walls; single neon-pink strokes; 2pt; continuous corner rails **to far plane**; far ring **drawn** (corner radius capped so it stays a rect, not a disc).
- **Actors:** player cyan · opponent magenta · ball orange pixel disc.
- **Type:** HUD plain pixel; titles **chrome 3-band** bright pink → mid magenta → dark purple + soft purple rim.
- **LCD** row overlay + light vignette.

---

## Chrome / safe area

- Hearts in Dynamic Island *ear* band when topSafe ≥ 44.
- LV + score fully under safe top (never on the notch).
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

## For Claude picking up

1. Read **STATUS.md** first (truth + open gate).
2. Tune **only Config.swift** for feel (AI speed, english, audio volumes).
3. AI must stay pure linear tracking — do not reintroduce aim error / reaction delay.
4. Do not start Multipeer until gate is green.
5. Open v1: app icon; freeze Config after multi-session play; second-person cold test.
