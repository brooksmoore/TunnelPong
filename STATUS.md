# CyberPong — Status

**Last updated:** 2026-08-02 (Grok) — polish + Claude catch-up docs.

> **"WRAPPED" means feature-complete, not gate-satisfied.** The v2 gate below is
> still CLOSED. Open v1 work: app icon, multi-session device play, Config freeze.

---

## Product

| Field | Value |
|-------|--------|
| Name | **CyberPong** |
| Version | **v1 solo — WRAPPED** (feature-complete for solo endless chase) |
| Repo | https://github.com/brooksmoore/TunnelPong (private) |
| Bundle | `com.brooksmoore.tunnelpong` |
| Platforms | iOS 17+ iPhone · Mac Catalyst desktop |
| Format | **Endless high-score chase — no win state.** L1→L10 then hold |
| Lives | Spare lives: 3 hearts = 4 misses; +1 per level clear, cap 3 |
| Look | Night gradient sky + stars + moon · neon-pink tunnel wire · chrome titles · pixel actors |
| Audio | Procedural retrowave (`Audio.swift`) — ambient pad + SFX, zero asset files |

---

## Running truth

| Surface | State |
|---------|--------|
| Mac Catalyst | `bin/play-mac.sh` |
| Physical iPhone | Proven earlier (BCM 16 Pro Max) |
| Simulator | Works; prefer device/Catalyst for feel |

---

## What Grok shipped since Claude’s theme stack (read this)

### Rules / feel
- Endless + spare lives (Claude) kept.
- **AI = pure tracking only** — no aim error, no reaction delay, no idle dodge.
- Difficulty: **linear** `aiSpeedL1→L10` (~48→245). Safety ceiling `aiLateralFrac*` only.
- Spin/english turned up; `minVzFraction` 0.48 so lateral spin reads.
- **No full-screen flash** on points or level-ups (haptics + SFX only).
- Hearts update immediately on score/miss; no POINT/MISS text.

### Visual
- c3-inspired night sky (black/purple dominate; thin pink low) + **consistent** 1px stars full frame + moon.
- **No** vanishing glow, dust, or live twinkle nodes (those were the “pink blink”).
- Tunnel: transparent walls, **2pt** neon-pink rings + 4 continuous corner rails, far ring **present** so rails meet a frame (capped corner radius so it doesn’t read as a disc).
- Title chrome: **3-band** bright pink → magenta → dark purple + soft purple rim (r1 energy, easier palette).
- Player cyan paddle/hearts; opponent magenta; wall-hit ring colour flash kept.

### Audio (`Audio.swift`)
- Soft ambient pad on title/play.
- Player paddle = high **tick**; opponent = low **tok**.
- Wall, point, miss, level-up, serve, UI tap.
- Volume: `Config.audioMaster` / `audioSFX` / `audioAmbient`.

### Still open for v1
App icon · Config freeze after play · cold second-person · multi-session device play.

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
