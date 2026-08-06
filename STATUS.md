# CyberPong — Status

**Last updated:** 2026-08-04 (Claude) — v1.9 surface type sized to one wall segment, 33 assertions green, installed on device.

> **v1.6 mechanics ship.** Centre-start rallies, Curveball-style continuous curve, degrading score bonuses,
> pure-logic CLI tests green. v2 multiplayer gate still CLOSED.

### Recent movement
- **v1.9 "One Segment"** (2026-08-04): surface type depth is now derived from a ring index rather than a raw number, so LVL/score end exactly on the second ring and fill one wall segment. Vertical span down to 52%. Depth dot approved by Brooks. 33 assertions green.
- **v1.8 "Surface Type"** (2026-08-04): depth tracker simplified to a small dot in the wall-impact colour; LVL and score projected onto the ceiling and floor planes via `PixelLabel.SurfaceProjection` (equidistance falls out of the geometry); pause moved bottom-right at 0.85. **Appearance not verified — no Screen Recording permission.**
- **v1.7 "Depth Readout"** (2026-08-04): four dashes ride the corner rails at the ball's z, in the ball's colour, giving the missing z-axis cue. x/y walls still stay dark until individually struck (deliberate). Pause moved to bottom-right at 0.85 alpha. 33 assertions green. **Visual result not verified — no Screen Recording permission; Brooks to judge on device.**
- **v1.6 "Centre Start"** (2026-08-04): every point now launches from dead centre of the tunnel toward whoever won the previous point. Swipe-to-serve removed entirely — your opening move is a return. Rally rules extracted to `CourtMath` so they're testable; 29 assertions green, sign-flip failure proven.
- **v1.5 "Make It Actually Curve"** (2026-08-04): continuous curve from paddle velocity, renorm-after-curve, self-degrading bonuses + popups, AI wall clamp, face-grid / no-op knobs deleted. CLI: `./bin/test_v1_5.sh` (21 pass, linked against real source). Mac Catalyst + iOS device builds clean.

---

## Product

| Field | Value |
|-------|--------|
| Name | **CyberPong** |
| Version | **v1.9** (surface HUD type; depth dot; centre start; curve + scoring; endless solo chase) |
| Repo | https://github.com/brooksmoore/TunnelPong (public) |
| Bundle | `com.brooksmoore.tunnelpong` |
| Platforms | iOS 17+ iPhone/iPad (portrait + landscape) · Mac Catalyst free resize |
| Format | **Endless high-score chase — no win state.** L1→L10 then hold |
| Lives | Spare lives: 3 hearts = 4 misses; +1 per level clear, cap 3 |
| Look | Night gradient sky + stars (+ crescent moon — KEEP, confirmed 2026-08-04) · neon-pink tunnel wire · chrome titles · pixel actors |
| Curve | Continuous banana arc (`curveX/Y` + dt exponential decay); paddle-velocity sourced |
| Audio | Procedural retrowave (`Audio.swift`) — ambient pad + SFX, zero asset files |
| Icon | Procedural `bin/make-icon.swift` → Assets.xcassets |

---

## Running truth

| Surface | State |
|---------|--------|
| Mac Catalyst | `bin/play-mac.sh` |
| Physical iPhone | Proven (BCM 16 Pro Max) |
| Simulator | Available (iOS 26.1); prefer device/Catalyst for feel |

---

## AI model (locked 2026-08-02)

- **Pure live ball XY tracking only.** Chase `bx, by` every frame.
- **No** far-plane intercept prediction, **no** wall-bounce fold, **no** aim error, **no** reaction delay.
- Difficulty dial: **linear** `aiSpeedL1 → aiSpeedL10` only.
- `aiLateralFrac*` = safety ceiling only (not a skill dial).

---

## What shipped recently

### Feel / correctness
- AI intercept prediction removed (was psychic pre-positioning).
- Serve swipe threshold = **cumulative** travel (`serveSwipeMin` 14pt), not per-frame.
- Elastic thumb trackpad (iOS) + swipe-to-serve; Mac hover absolute.
- Court fitted to safe band (Dynamic Island + landscape side insets).
- **Orientation:** portrait + landscape; tunnel rebuilds on rotate/resize; physics units unchanged.
- Corner rails meet rounded rings at 45° arc anchors.

### Polish / efficiency
- App icon wired.
- SFX: cached buffers + 12-node player pool.
- Ambient: attach once; stop/play only.
- Trail alphas hoisted out of frame loop.

### Still open for v1 (human gate)
Multi-session device play · Config freeze · cold second-person. (PrivacyInfo + StoreKit shipped.)

---

## v2 gate (CLOSED)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Multi-session physical play | IN PROGRESS |
| 2 | Difficulty feels fair | IN PROGRESS |
| 3 | Config frozen | OPEN |
| 4 | Cold second person | OPEN |

**Do not implement Multipeer / PeerMirror wiring.**

---

## Commands

```bash
/Users/brooksmoore/Desktop/TunnelPong/bin/play-mac.sh
/Users/brooksmoore/Desktop/TunnelPong/bin/test_v1_5.sh
open /Users/brooksmoore/Desktop/TunnelPong/TunnelPong.xcodeproj
```
