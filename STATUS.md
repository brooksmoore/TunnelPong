# Tunnel Pong — Status

Single source of “what’s true right now.” Update when ship state changes.
History goes in `LEDGER.md` (append-only). Plan detail in `docs/ROADMAP.md`.

**Last updated:** 2026-07-23 (Grok)

---

## Product

| Field | Value |
|-------|--------|
| Version intent | **v1** (solo vs AI) |
| Repo | https://github.com/brooksmoore/TunnelPong (**private**) |
| Platform | iOS 17+, iPhone, portrait, SpriteKit |
| Bundle ID | `com.brooksmoore.tunnelpong` |

---

## What works now

- Solo tunnel Pong vs AI (levels, lives, high score, haptics)
- Config-driven difficulty (`Config.swift`)
- Unit tests: `CourtMath` + `PeerMirror` (⌘U)
- Built and played on **iOS Simulator** (Xcode 26.1 / iPhone 17)
- Audit fixes from inheritance (high-score tie, shake, safe-area HUD, etc.)

---

## What does **not** work / not done

- **v2 local multiplayer** — not started (gated)
- **v3 internet play** — not started (and deprioritized vs v2 / lighter social)
- Physical **device** play not confirmed locked in this status (see gate)
- App icon, Privacy Manifest, App Store packing
- Sound

---

## v2 gate checklist

From `docs/ROADMAP.md`. **All four must be true before Multipeer / versus code.**

| # | Criterion | Status |
|---|-----------|--------|
| 1 | v1 on a **physical iPhone**, several real play sessions | **OPEN** — Simulator play only confirmed in sessions so far |
| 2 | Difficulty tuned so losses feel like player fault | **OPEN** — default Config; needs multi-session device feel |
| 3 | `Config` stable (not changing every session) | **OPEN** — no freeze declaration yet |
| 4 | A **second person** played and understood the tunnel with no explanation | **OPEN** — not recorded |

**Gate overall: CLOSED — do not start v2 implementation.**

When Brooks flips these to done, update this table and append a LEDGER entry, then follow `docs/V2_DESIGN.md`.

---

## Locked decisions (do not re-litigate casually)

| Topic | Decision |
|-------|----------|
| v2 transport | MultipeerConnectivity (throwaway vs GameKit later) |
| v2 authority | Split — owner = ball inbound device; local plane is local truth |
| v2 coordinates | Local frame always; `PeerMirror` **on send only** |
| v2 rules | Equal paddles; rally speed ramp; first-to-N / best-of-M; alternate serve |
| v3 default | GameKit if ever; prefer ghost/leaderboards/invite-only first |
| v3 policy | Demand-driven; not on-spec full matchmaking |

---

## Prep already in tree (safe under gate)

- `docs/ROADMAP.md` — full v1/v2/v3 scope + gate
- `docs/V2_DESIGN.md` — implementation blueprint
- `PeerMirror` pure math + tests — no gameplay wiring

---

## Next actions (Brooks / next AI)

1. Install v1 on a **real iPhone** and play several sessions; tune `Config` until stable.  
2. Hand phone to someone else; note if tunnel is clear without explanation.  
3. When gate table is all done → implement v2 per `docs/V2_DESIGN.md` PR sequence.  
4. Do **not** build GameKit / internet queue until v2 is real and demand exists.

---

## Quick commands

```bash
# Open project
open /Users/brooksmoore/Desktop/TunnelPong/TunnelPong.xcodeproj

# Prefer Xcode 26.1 Simulator only (not legacy /Applications/Xcode.app Simulator 13.1)
open /Applications/Xcode-26.1.app/Contents/Developer/Applications/Simulator.app

# Tests
# In Xcode: ⌘U
```
