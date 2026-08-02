# CyberPong — Status

**Last updated:** 2026-08-02 (Grok) — Landscape + free-aspect court resize.

> **"WRAPPED" means feature-complete, not gate-satisfied.** The v2 gate below is
> still CLOSED. Open v1 work: multi-session device play, Config freeze, cold second person.

---

## Product

| Field | Value |
|-------|--------|
| Name | **CyberPong** |
| Version | **v1 solo — WRAPPED** (feature-complete for solo endless chase) |
| Repo | https://github.com/brooksmoore/TunnelPong (private) |
| Bundle | `com.brooksmoore.tunnelpong` |
| Platforms | iOS 17+ iPhone/iPad (portrait + landscape) · Mac Catalyst free resize |
| Format | **Endless high-score chase — no win state.** L1→L10 then hold |
| Lives | Spare lives: 3 hearts = 4 misses; +1 per level clear, cap 3 |
| Look | Night gradient sky + stars + moon · neon-pink tunnel wire · chrome titles · pixel actors |
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
Multi-session device play · Config freeze · cold second-person · (App Store only: PrivacyInfo).

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
open /Users/brooksmoore/Desktop/TunnelPong/TunnelPong.xcodeproj
```
