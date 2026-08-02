# Tunnel Pong — Status

Single source of “what’s true right now.” Update when ship state changes.
History goes in `LEDGER.md` (append-only). Plan detail in `docs/ROADMAP.md`.

**Last updated:** 2026-08-01 (Grok) — Sonnet external audit absorbed; Mac Catalyst desktop play added; **v2 still gated**.

---

## Product

| Field | Value |
|-------|--------|
| Version intent | **v1** (solo vs AI) |
| Repo | https://github.com/brooksmoore/TunnelPong (**private**) |
| Platform | iOS 17+, iPhone, portrait, SpriteKit |
| Desktop debug | Mac Catalyst (same codebase; mouse hover = paddle) |
| Bundle ID | `com.brooksmoore.tunnelpong` |

---

## What works now

- Solo tunnel Pong vs AI (levels, lives, high score, haptics)
- Config-driven difficulty (`Config.swift`) — single source of truth
- Unit tests: `CourtMath` + inert `PeerMirror` (⌘U)
- iOS Simulator (Xcode 26.1)
- **Mac Catalyst** native window via `bin/play-mac.sh` (no Simulator; hover-follow paddle; **not** a substitute for gate #1)

---

## What does **not** work / not done

- **Physical iPhone play** — still unconfirmed (gate #1 OPEN). Cable install blocked if phone OS is ahead of this Mac’s Xcode; TestFlight not started (no codesign identity on this machine as of 2026-08-01)
- **v2 local multiplayer** — not started; **do not start**
- **v3 internet** — not started
- App icon, Privacy Manifest, App Store packing, sound

---

## v2 gate checklist

From `docs/ROADMAP.md`. **All four must be true before Multipeer / versus code.**

| # | Criterion | Status |
|---|-----------|--------|
| 1 | v1 on a **physical iPhone**, several real play sessions | **OPEN** — Simulator + Mac Catalyst only |
| 2 | Difficulty tuned so losses feel like player fault | **OPEN** — default Config; needs real-thumb sessions |
| 3 | `Config` stable (not changing every session) | **OPEN** — no freeze declaration |
| 4 | A **second person** played and understood the tunnel with no explanation | **OPEN** — not recorded |

**Gate overall: CLOSED — do not start v2 implementation. Do not expand PeerMirror / V2 docs until green.**

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

## Prep already in tree (safe under gate — **leave inert**)

- `docs/ROADMAP.md`, `docs/V2_DESIGN.md` — blueprint only
- `PeerMirror` pure math + tests — **no gameplay wiring; no more v2 prep until gate green**
- External audit (Sonnet, 2026-08-01): v1 game quality solid; process/scaffolding overshot relative to unproven device feel. Grok agrees. Discipline: play phone → freeze Config → cold second-person → only then v2.

---

## Next actions (Brooks / next AI) — order is load-bearing

1. **Get v1 on a real iPhone** (primary). Prefer TestFlight signed build if cable debug fails on OS mismatch. Requires Apple Developer team + signing on a machine that can archive. AltStore is fallback.
2. **Play a lot** on device — real thumb, haptics, ProMotion. Tune `Config.swift` only.
3. **Freeze Config**, then cold handoff to one other person (gate #4).
4. **Stop writing v2** (code, PeerMirror expansion, more design docs) until the gate table is all green.
5. GameScene ~758 lines is fine for solo v1; only split when versus actually starts.

Mac Catalyst is for **cheap desktop iteration** (Config feel, bugs). It does **not** close gate #1–4.

---

## Quick commands

```bash
# Open project
open /Users/brooksmoore/Desktop/TunnelPong/TunnelPong.xcodeproj

# Desktop play (Mac Catalyst — no Simulator)
/Users/brooksmoore/Desktop/TunnelPong/bin/play-mac.sh

# Prefer Xcode 26.1 Simulator only (not legacy Xcode.app Simulator)
open /Applications/Xcode-26.1.app/Contents/Developer/Applications/Simulator.app

# Tests
# In Xcode: ⌘U
```
