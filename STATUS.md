# CyberPong — Status

**Last updated:** 2026-08-01 (Grok) — opponent center reset + chrome/safe-area fix; ready for Claude review.

---

## Product

| Field | Value |
|-------|--------|
| Name | **CyberPong** |
| Version | **v1 solo — WRAPPED** (feature-complete for solo campaign) |
| Repo | https://github.com/brooksmoore/TunnelPong (private) |
| Bundle | `com.brooksmoore.tunnelpong` |
| Platforms | iOS 17+ iPhone · Mac Catalyst desktop |
| Campaign | 10 levels linear; clear L10 = YOU WIN |

---

## Running truth

| Surface | State |
|---------|--------|
| Mac Catalyst | `bin/play-mac.sh` — hover paddle, click-to-serve |
| Physical iPhone | Proven earlier session (BCM 16 Pro Max, iOS 27, trust developer) |
| Simulator | Works; prefer device or Catalyst for feel |

---

## Latest fixes (this session tail)

1. **Opponent starts each point at center** — `scheduleServe` snaps `ox,oy = 0`; AI holds center while ball not live (no crawl-back during user serve).  
2. **Mac top clip** — titlebar treated as min top inset (40pt); taller default window; HUD/title laid out under chrome via `applyChromeLayout()`.  
3. **iOS notch** — HUD uses real safe-area top/bottom + pad; re-layout after insets settle.

---

## v2 gate (CLOSED)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Multi-session physical play | IN PROGRESS (install done) |
| 2 | Difficulty feels fair | IN PROGRESS (L1 good) |
| 3 | Config frozen | OPEN |
| 4 | Cold second person | OPEN |

**Do not implement Multipeer / PeerMirror wiring.**

---

## Docs for next model

| File | Use |
|------|-----|
| `MEMORY.md` | Durable architecture + conventions |
| `STATUS.md` | This file — current truth |
| `LEDGER.md` | Append-only history |
| `README.md` | Run / tune guide |
| `docs/ROADMAP.md` | v1→v2→v3 scope (gated) |
| `docs/V2_DESIGN.md` | v2 blueprint only |

---

## Commands

```bash
/Users/brooksmoore/Desktop/TunnelPong/bin/play-mac.sh
open /Users/brooksmoore/Desktop/TunnelPong/TunnelPong.xcodeproj
```
