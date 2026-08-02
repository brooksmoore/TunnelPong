# CyberPong — Status

**Last updated:** 2026-08-01 (Claude) — audit of Grok's wrap; endless-mode + spare-life rules, Mac resize fix, dead-code purge.

> **"WRAPPED" means feature-complete, not gate-satisfied.** The v2 gate below is
> still CLOSED. Open v1 work: app icon, theme pass, feel tweaks.

---

## Product

| Field | Value |
|-------|--------|
| Name | **CyberPong** |
| Version | **v1 solo — WRAPPED** (feature-complete for solo campaign) |
| Repo | https://github.com/brooksmoore/TunnelPong (private) |
| Bundle | `com.brooksmoore.tunnelpong` |
| Platforms | iOS 17+ iPhone · Mac Catalyst desktop |
| Format | **Endless high-score chase — no win state.** Difficulty ramps L1→L10 then holds |
| Lives | Spare-life model: 3 hearts = 4 misses; +1 per level cleared, capped at 3 |

---

## Running truth

| Surface | State |
|---------|--------|
| Mac Catalyst | `bin/play-mac.sh` — hover paddle, click-to-serve |
| Physical iPhone | Proven earlier session (BCM 16 Pro Max, iOS 27, trust developer) |
| Simulator | Works; prefer device or Catalyst for feel |

---

## Latest fixes

**Grok (earlier):** opponent snaps to center every point (no crawl-back during your
serve); Mac titlebar treated as min 40pt top inset; iOS HUD respects real safe area.

**Claude (audit pass):**

1. **Endless mode** — removed the win state. Levels count up forever; difficulty
   clamps at L10. `LV n` replaces `LV n/10`.
2. **Spare-life model** — hearts are spares; 0 hearts shows `LAST LIFE` and the
   next miss ends the run. +1 spare per level cleared, capped at 3.
   *(Old rules needed a ~95% point-win rate over 30 points to finish — unwinnable.)*
3. **Mac window resize no longer desyncs the tunnel** — `applyChromeLayout()` now
   rebuilds ring paths and corner rails from the live court size; previously the
   ball's walls moved but the drawn wireframe didn't.
4. **Dead code purged** — `serveTouchedBall` (never read), `segmentHitsBall`,
   `isOnBall`, `playerMiss`/`opponentMiss` (never called), and the
   `paddleSmoothing` / `serveBallHitPad` knobs.
5. **AI leash documented honestly** — `aiLateralFrac*` never binds (verified at all
   10 levels); `aiSpeedL1/L10` is the real dial. Ceiling kept as a guardrail.

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
