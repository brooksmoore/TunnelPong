# CyberPong — Status

**Last updated:** 2026-08-04 (Claude) — v1.5 audited, test harness rewired to real source, installed on device.

> **v1.5 mechanics ship.** Curveball-style continuous curve, degrading score bonuses,
> pure-logic CLI tests green. v2 multiplayer gate still CLOSED.

### Recent movement
- **v1.5 "Make It Actually Curve"** (2026-08-04): continuous curve from paddle velocity, renorm-after-curve, self-degrading bonuses + popups, AI wall clamp, face-grid / no-op knobs deleted. CLI: `./bin/test_v1_5.sh` (21 pass, linked against real source). Mac Catalyst + iOS device builds clean.

---

## Product

| Field | Value |
|-------|--------|
| Name | **CyberPong** |
| Version | **v1.5** (curve + scoring teeth; endless solo chase) |
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
