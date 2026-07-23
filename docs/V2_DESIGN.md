# v2 Design — Local 1v1 (implementation blueprint)

**Status:** Design locked; **code not started** until the [v2 gate](ROADMAP.md#gate-before-starting-v2) is green in `STATUS.md`.

This doc is what an implementer (Claude / Grok / human) should follow when the gate opens. Do not freestyle transport or authority.

---

## 1. Product shape

- **Mode select** on title: Solo (v1 loop) | Versus (local)
- Versus is a **separate rules path**, shared render/physics helpers
- Two iPhones, MultipeerConnectivity, no accounts

---

## 2. Modules (proposed file layout)

Keep `GameScene` from becoming a second god-object for networking.

```
TunnelPong/
  Config.swift                 # + VersusConfig section (points to win, rally ramp, equal paddles)
  Projection.swift             # Projector, CourtMath, PeerMirror (exists)
  Modes/
    SoloRules.swift            # extract from GameScene when convenient
    VersusRules.swift          # score, serve alternate, rally speed
  Net/
    PeerSession.swift          # MultipeerConnectivity session, browse/advertise
    PeerProtocol.swift         # message enums + Codable payloads
    PeerClock.swift            # RTT / offset estimate at handshake
    BallOwnership.swift        # who owns ball, handoff, extrapolation
  GameScene.swift              # present modes; or VersusScene.swift if cleaner
```

First PR after gate can be thinner: `PeerSession` + protocol + versus scene skeleton with equal paddles offline “hot seat” optional — but **prefer two-device from day one** for netcode.

---

## 3. PeerMirror convention (locked)

**Each device stores world state in local frame:** self paddle at `z = 0`, opponent at `z = zFar`.

**Apply `PeerMirror` on SEND only.** Receiver already works in local frame.

```swift
// PeerMirror (Projection.swift) — already unit-tested
// position: (x,y,z) → (-x, y, zFar - z)
// velocity: (vx,vy,vz) → (-vx, vy, -vz)
```

**Playtest check (first real session):** confirm `x` sign. If both players feel left/right inverted relative to the physical room, flip the x/vx convention once, update tests, document here.

Applying mirror on send **and** receive double-flips — never do that.

---

## 4. Authority & messages

### Ownership

| Condition | Owner |
|-----------|--------|
| Ball `vz` toward local player (inbound in local frame) | **Local** device |
| After local paddle hit | Peer becomes owner (after broadcast) |
| After local miss (past near plane) | Local awards point to peer; broadcast point + reset |

“Toward local player” in local frame: `vz < 0` (same as v1 inbound).

### Tiebreak (fairness)

- **Local device is sole judge of local paddle hit and local miss.**
- Peer never overrules “I saved it” / “it got past me” for the peer’s own plane.
- On conflict (rare at local RTT): accept owner’s packet; snap ball state.

### Message types (minimal)

| Message | Payload | When |
|---------|---------|------|
| `hello` | protocolVersion, displayName, role | handshake |
| `clockSync` | t0, t1, … | handshake / periodic |
| `paddle` | x, y, t | ~20–30 Hz while touching / always low rate |
| `ballHandoff` | x,y,z, vx,vy,vz, t, seq | paddle contact or serve launch |
| `point` | scorer, scores, nextServer, t | point scored |
| `pause` / `resume` | reason | user or net |
| `goodbye` | reason | teardown |

Use monotonic `seq` on ball handoffs; ignore stale seq.

### Extrapolation (non-owner)

Between handoffs:

```
dt = now_local - packet.t_adjusted_for_clock_offset
position += velocity * dt
// fold wall bounces with CourtMath.reflect (same as AI intercept)
```

Do **not** re-simulate peer paddle hits on non-owner.

---

## 5. Versus rules (not v1 levels)

| Rule | Value (starting point; tune in VersusConfig) |
|------|-----------------------------------------------|
| Paddle half size | Same for both = player paddle size from v1 (`playerPaddleHalfW/H`) |
| Points to win game | 11 (win by 2 optional later) |
| Best of | 3 games (first to 2) |
| Rally speed | base + N * increment per hit; reset on point |
| Serve | Alternate; `serveDelay` countdown; no ace during UI stare |
| English | Keep v1 english on local hit |

No AI. No levels. No high-score lives.

---

## 6. Connection lifecycle

```
Title → Versus lobby
  Host: advertise service type e.g. "tunnelpong-v2"
  Join: browse peers → connect
Handshake → clock sync → ready
  Both confirm "Ready" or auto after sync
Playing
  ↔ paddle + ballHandoff + point
Packet loss high / peer silent > T1
  → Reconnecting (game frozen, ball parked)
Silent > T2
  → Forfeit, return lobby
Background (willResignActive)
  → send pause; local pause
Teardown
  → goodbye; invalidate session; clear owners
```

Suggested timers (tune on device): T1 = 0.5–1.0 s freeze, T2 = 10–15 s forfeit.

Info.plist (when implementing): local network usage description; Bonjour service `_tunnelpong-v2._tcp` (and Multipeer names as required by current iOS).

---

## 7. Testing strategy

| Layer | How |
|-------|-----|
| PeerMirror / CourtMath | Unit tests (already started) |
| Protocol encode/decode | Unit tests on Codable round-trip |
| Ownership handoff | Two-device scripted scenarios |
| Feel | Two phones, same room, 20-point play sessions |

**Do not trust Simulator-only multiplayer** for ship decisions. Sim↔device is Wi‑Fi only; timing differs.

---

## 8. Explicit non-goals (v2)

- Internet, Game Center, accounts  
- >2 players, spectating  
- Ranked ladder, leaderboards  
- Voice chat  
- Replacing Multipeer with custom UDP (unless MC fails hard in practice)

---

## 9. First implementation PR sequence (when gate opens)

1. `VersusConfig` + mode select UI (Solo still default).  
2. `PeerSession` host/join + hello/goodbye.  
3. Paddle-only sync (no ball) to validate mirror + latency feel.  
4. `ballHandoff` + ownership + local hit.  
5. Scoring, serve alternate, reconnect/forfeit.  
6. Polish: haptics parity, mid-game background, teardown.

Ship when two non-author humans can finish a best-of-3 without wedging.
