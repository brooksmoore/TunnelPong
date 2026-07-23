# Tunnel Pong — Roadmap (v1 → v2 → v3)

Living plan. Implementation details for v2 live in [`V2_DESIGN.md`](V2_DESIGN.md).
Current ship state lives in [`../STATUS.md`](../STATUS.md). History in [`../LEDGER.md`](../LEDGER.md).

---

## v1 — Solo vs AI (current)

**Goal:** One phone, one loop, one feel. Tunnel is readable without explanation.

**Shipped:** SpriteKit 2.5D tunnel Pong, AI levels, high score, haptics, unit-tested math.
**Not shipped:** sound, multiplayer, accounts, ads, IAP.

**Exit criteria for “v1 locked”** (same as the v2 gate below).

---

## Gate before starting v2

**Do not begin v2 implementation until all of these are true.**

| # | Criterion | Why it matters |
|---|-----------|----------------|
| 1 | v1 is on a **physical iPhone** and Brooks has played **several sessions** | Simulator feel ≠ device feel (touch offset, haptics, 60/120 Hz) |
| 2 | Difficulty curve tuned so **losing feels like your fault** | Unlocked Config thrash will poison multiplayer “fairness” debugging |
| 3 | **`Config` has stopped changing every session** | v2 changes loop + coordinates + fairness at once; need a stable baseline |
| 4 | **Someone else** has played and understood the tunnel **without explanation** | Proves the core illusion works for humans, not just the author |

**Reason for the gate:** v2 changes the game loop, the coordinate system, and the fairness model all at once. Doing that on top of unresolved v1 means you cannot tell whether a bad feel is networking or tuning. **Lock the feel first.**

Gate status is tracked in `STATUS.md`.

---

## v2 — Local 1v1 (same room)

Two iPhones, same Wi‑Fi or Bluetooth. **No accounts, no internet, no server.**

### Decision 1 — Transport: MultipeerConnectivity

| | MultipeerConnectivity | GameKit real-time |
|---|---|---|
| Accounts | None | Game Center sign-in |
| Offline | Yes (Bluetooth + peer Wi‑Fi) | No |
| Discovery UI | Built-in browser or custom | Apple matchmaker |
| Path to internet | None (local only) | Same API family |
| Local latency | ~5–30 ms | n/a for pure local |

**Choice: MultipeerConnectivity.** Friend across a table must not require sign-in. Cost: v2 transport is **throwaway** when v3 arrives. Accept that (a few hundred lines). Building v2 on GameKit to “save work later” forces Game Center for a couch game.

### Decision 2 — Authority: split (recommended)

Who decides where the ball is?

| Option | Summary | Verdict |
|--------|---------|---------|
| **A Host authoritative** | Host simulates all; client renders | Client feels lag on own saves — wrong for reflex Pong |
| **B Split authority** | Ball owner = device the ball is flying toward; local hit = zero latency; handoff on contact with full state | **Chosen** |
| **C Lockstep** | Both sim, inputs only, fixed-point | Wrong tool at this scale — skip |

**Split rules:**

1. While the ball travels toward you, **you own it**. Your device judges paddle contact locally.
2. On contact (or miss past your plane), broadcast full ball state: position, velocity, timestamp; **ownership transfers**.
3. Between contacts trajectory is deterministic (constant speed + wall reflections) → non-owner **extrapolates** from last packet.
4. **Tiebreak:** each device is authoritative over whether the ball got past **its own** paddle. If you think you saved it, you saved it. Peer accepts and corrects. Only rule that keeps both players honest; at local latency disagreements are rare/invisible.

### Decision 3 — Coordinate mirroring

Each player sees **themselves at `z = 0`** and opponent at `z = zFar`. Devices hold mirrored views of one world.

One transform at every network boundary (implemented as `PeerMirror` — apply **on send only**; receivers stay in local frame):

```
z'  = zFar - z
x'  = -x          // verify in first two-device playtest
vz' = -vz
vx' = -vx
y, vy unchanged
```

Apply on send **or** receive — **pick one, never both**. Mirroring bugs look fine on each device alone and inverted across devices; miserable to debug.

**Code today:** `PeerMirror` in `Projection.swift` + unit tests (invertibility). Not wired into gameplay until v2.

### Decision 4 — Game loop is a different mode

v1 is AI levels. 1v1 is not a reskin:

| v1 | v2 1v1 |
|----|--------|
| Unequal paddle sizes (difficulty dial) | **Equal** paddle sizes |
| Level progression | **No levels** — ball speed ramps **per rally**, resets each point |
| Lives | **First to N points**, best-of-M games |
| Serve toward player | **Alternate serve** + brief countdown |

Shared: rendering, projection, wall/paddle physics helpers.  
Separate: rules, scoring UI, connection states.

### Decision 5 — Connection lifecycle (finish line)

- Host / join with visible device list
- Clock offset exchange at handshake (comparable timestamps)
- Pause on packet-loss beyond threshold → “reconnecting” → grace → forfeit
- App backgrounding either side (phone call mid-rally)
- Graceful teardown (dropped session must not wedge the app)

### v2 scope boundary

Local only. No internet, no matchmaking, no accounts, no leaderboards, no spectating, **max two players**.

### Practical warning

Need **two physical devices**. Rebuild both constantly. Sim↔device over Wi‑Fi only (not Bluetooth); sim timing ≠ device. Budget **calendar time >> code size**. This is where solo projects stall.

---

## v3 — Internet play

### What actually changes

Latency ~20 ms → **50–150 ms** with jitter/loss. v2’s “extrapolation between handoffs is invisible” breaks. Need interpolation + smoothed correction; tune snap aggressiveness. Split authority still works; disagreement rate rises; **tiebreak becomes visible**.

### Transport

**GameKit real-time matchmaking** (default). Free matchmaking, relay, NAT traversal. Costs: Game Center required, dated API, limited visibility when broken.

Own backend relay: more control, you own uptime/cost/DDoS for a free Pong game — **not worth it** unless proven demand.

### v3 additions

- Matchmaking: random + invite friend
- Rematch without re-queue
- Disconnect / forfeit (rage-quit vs subway)
- Leaderboards / achievements (GameKit)
- Region / latency awareness (3000‑mile matches feel bad no matter the netcode)

### Honest assessment

v3 is likely **more work than v1+v2 combined** and delivers the least of “play my friend” — **v2 already does that**. Internet play needs a player base or the queue is empty (worse than no button).

### Prefer before full v3 (unless audience pulls you)

1. **Ghost / time attack** — record runs, race async (no netcode, no empty queue)
2. **GameKit leaderboards on solo** — ~a day of work, social without 1v1 netcode
3. **Invite-only internet** — friends only; skip random matchmaking

**Policy:** let demand pull v3; do not build full v3 on spec.

---

## Recommended sequence

```
v1 lock (gate) → v2 local Multipeer 1v1 → (optional) solo leaderboards / ghost
                                         → v3 only if people ask for online
```
