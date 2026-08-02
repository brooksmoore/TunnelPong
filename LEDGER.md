# Tunnel Pong — Ledger

Append-only history. Never rewrite old entries; only add new dated sections.
Audience: Brooks + any AI (Claude, Grok, Composer) picking up the project.

---

## 2026-07-23 — Inheritance snapshot (pre-Grok)

**Source:** Brand-new Claude-generated iOS game. Brooks asked Grok to audit/debug thoroughly, then patch bugs and add tests + `.gitignore`.

### What it was

| Item | State |
|------|--------|
| Type | 2.5D tunnel Pong (SpriteKit), finger paddle vs AI |
| Stack | Pure SpriteKit, zero assets, zero packages |
| Size | 7 Swift files, ~1k lines, ~72 KB |
| Target | iPhone only, portrait, iOS 17+ |
| Bundle ID | `com.brooksmoore.tunnelpong` |
| Entry | `AppDelegate` → `GameViewController` → `GameScene` |
| Layout | All tunables in `Config.swift`; perspective in `Projection.swift`; everything else in one `GameScene` |
| Docs | Solid `README.md` (run steps + difficulty dials) |
| Tests | None |
| `.gitignore` | None |
| App icon / Assets | None |
| Privacy manifest | None |
| Signing team | Not set (user picks in Xcode) |

### File tree then

```
TunnelPong/
├── README.md
├── TunnelPong.xcodeproj/
└── TunnelPong/
    ├── AppDelegate.swift
    ├── GameViewController.swift
    ├── Config.swift
    ├── Projection.swift      # perspective divide only
    ├── GameScene.swift       # state machine, physics, AI, HUD, touch
    ├── Nodes.swift
    └── Haptics.swift
```

### Architecture (unchanged intent)

- World space: `z = 0` player plane, `z = zFar` (900) opponent plane.
- One perspective formula: `scale = focal / (focal + z)`.
- Paddle hits by **z-plane crossing** (not screen-pixel overlap) — correct design.
- Explicit phases: `title → playing → paused | levelTransition → gameOver`.
- AI: reaction delay + aim error that shrinks per level.
- Score/high score via `UserDefaults` key `"highScore"`.
- Rules: 3 player lives whole run; opponent 3 lives/level; ball +12%/level, AI +16%/level, error ×0.80/level.

### Audit findings (bugs present at inheritance)

1. **High-score tie bug** — matching the old high score showed “NEW HIGH SCORE”.
2. **Shake residual** — interrupting the court shake mid-action could leave the tunnel permanently offset.
3. **HUD ignored safe areas** — hard-coded Y positions; risk under notch / Dynamic Island / home indicator.
4. **Game over left paddles visible** — title hid them; game over did not.
5. **Opponent point used wall-bounce haptic** — wrong feedback for scoring.
6. **`ringCount == 1` would divide by zero** — safe at default 13, fragile if Config tweaked.
7. **Projection at `z ≤ -focal`** — divide-by-zero / non-finite scale if ball ever went that deep.
8. **No unit tests** despite Projection being labeled testable.
9. **No `.gitignore`.**
10. **Could not full `xcodebuild` on Grok’s Mac** — Xcode reported iOS 26.1 platform not fully installed; Swift typecheck of all sources still passed.

### Quality scorecard at inheritance (Grok audit)

| Area | Score |
|------|-------|
| Architecture / clarity | 9/10 |
| Physics correctness | 8.5/10 |
| AI design | 8/10 |
| Polish / UX | 6/10 |
| Ship readiness | 4/10 |
| Test coverage | 1/10 |
| Overall v1 prototype | ~7.5/10 |

**Verdict then:** Coherent mini-game, not a messy AI dump. Strong Config-first design. Main gaps were polish bugs + zero tests + shipping packing, not a broken core loop.

### Deliberately out of scope (v1, still true)

Sound, multiplayer, networking, ads, IAP, analytics, accounts.

---

## 2026-07-23 — Post-Grok: bugs patched + tests + ledger

**Actor:** Grok (xAI), after Brooks approved “proceed with 1 and 2” (patch bugs + XCTest + `.gitignore`).

### What changed (code)

| Fix | Where / how |
|-----|-------------|
| High-score tie | `GameScene.endRun` — capture `isNewHigh = score > highScore && score > 0` **before** save overwrites |
| Shake residual | `playShake()` — remove old action, set `worldNode.position = .zero`, then run shake |
| Safe-area HUD | `GameViewController` sets `scene.safeInsets` after layout; `buildHUD` pads from insets |
| Game-over paddles | Hide player + opponent paddles in `endRun` |
| Opponent point haptic | `Haptics.pointScored()` success notification; `opponentMiss` uses it |
| Ring safety | `CourtMath.ringT` / `ringIndex` — no divide-by-zero when `ringCount == 1` |
| Projection clamp | `Projector.scale` clamps `z` so `focal + z` stays ≥ 1 |
| Pure math extraction | `CourtMath` in `Projection.swift`: `reflect`, `renormVelocity`, `moveToward`, ring helpers; `GameScene` calls these |
| Unit tests | New target `TunnelPongTests` + `CourtMathTests.swift` (~17 tests) |
| Scheme | `TunnelPong.xcscheme` runs tests on ⌘U |
| `.gitignore` | Xcode/DerivedData/DS_Store/secrets patterns |
| README | Tree + “Tests” section (⌘U) |

### File tree now

```
TunnelPong/
├── LEDGER.md                     ← this file
├── README.md
├── .gitignore
├── TunnelPong.xcodeproj/         # app + TunnelPongTests targets
├── TunnelPong/
│   ├── AppDelegate.swift         # unchanged intent
│   ├── GameViewController.swift  # passes safeInsets into scene
│   ├── Config.swift              # still the only place to tune feel
│   ├── Projection.swift          # Projector + CourtMath (unit-tested)
│   ├── GameScene.swift           # bugs fixed; uses CourtMath
│   ├── Nodes.swift
│   └── Haptics.swift             # + pointScored()
└── TunnelPongTests/
    └── CourtMathTests.swift
```

### Verification done (Grok’s machine)

- App sources **Swift typecheck: OK** against iOS Simulator SDK.
- Offline math smoke on `Projector` / `CourtMath` (incl. high-score tie logic): **PASS**.
- `xcodebuild -list` shows targets: **TunnelPong**, **TunnelPongTests**.
- Full device/simulator **build/run/⌘U not completed** here (iOS platform components missing on that Mac). Brooks still needs a local Xcode run.

### What did **not** change

- Game rules, scoring formulas, difficulty curves, ball/AI feel dials in `Config.swift`.
- No sound, multiplayer, ads, IAP.
- No app icon / `Assets.xcassets`.
- No `PrivacyInfo.xcprivacy` (needed later for App Store).
- No `DEVELOPMENT_TEAM` in project (Brooks picks Team in Xcode).
- `GameScene` remains the single gameplay god-object (~760 lines) — fine for v1.

### How to run / test (for next AI or Brooks)

1. Open `TunnelPong.xcodeproj` in Xcode 15+ (or current).
2. Signing & Capabilities → Automatic + your Team.
3. Device: Developer Mode + trust cert (see README). **⌘R** to play.
4. **⌘U** for unit tests (`CourtMathTests`).
5. Feel wrong? Edit **only** `Config.swift` — start with `aiErrorBase`, `ballBaseSpeed`, `aiBaseSpeed`.

### Suggested next work (not done)

1. Playtest on a real iPhone; retune Config if needed.
2. App icon asset catalog.
3. `PrivacyInfo.xcprivacy` before any store submission.
4. Optional: extra life every N levels (`extraLifeEveryNLevels` is wired, currently `0` = off).
5. Optional later: split `GameScene` if modes/powerups are added.

### Handoff note for Claude

- Prefer reading this ledger + `README.md` + `Config.swift` before large refactors.
- Do **not** rewrite ledger history; append a new dated section when you change state.
- Core physics approach (z-plane paddle hits, `CourtMath` pure functions) is intentional — don’t replace with SpriteKit physics without a strong reason.
- Keep tunables in `Config.swift` so Brooks can verify by structure, not by reading diffs.
- Money/fleet rules in global Claude.md do **not** apply here; this is a local iOS game, not a trading bot.

---
## 2026-07-23 — GitHub private repo (v1 push)

**Actor:** Grok, at Brooks’s request (“commit and push v1 … as a private project”).

| Item | Value |
|------|--------|
| Remote | `https://github.com/brooksmoore/TunnelPong` |
| Visibility | **PRIVATE** |
| Branch | `main` |
| Commit | `5343398` — *Initial v1: tunnel Pong iOS game with audit fixes and tests.* |
| Files in commit | 13 (app, tests, README, LEDGER, .gitignore, Xcode project/scheme) |
| Not committed | `.DS_Store` (gitignored) |

Working tree was clean after push. Clone with: `gh repo clone brooksmoore/TunnelPong` (auth required; private).

---
## 2026-07-23 — v2/v3 scope locked; gate enforced; PeerMirror prep

**Actor:** Grok, at Brooks’s request to proceed comprehensively on the v2/v3 scope document.

### Intelligent handling of the gate

The scope’s first rule is: **do not begin v2 until the gate is green.** Brooks has played v1 on **Simulator** and said it “looks good,” but the gate still requires:

1. Physical iPhone, several sessions  
2. Difficulty “losing is my fault”  
3. Config frozen across sessions  
4. A second person understands the tunnel unprompted  

**Therefore: no MultipeerConnectivity, no versus game loop, no GameKit.** v2 code starts only when `STATUS.md` gate table is all done.

### What was delivered (docs + safe prep)

| Artifact | Purpose |
|----------|---------|
| `docs/ROADMAP.md` | Full v1→v2→v3 plan, gate, five v2 decisions, v3 honesty + cheaper alternatives |
| `docs/V2_DESIGN.md` | Implementation blueprint: modules, messages, ownership, lifecycle, PR order |
| `STATUS.md` | Live gate checklist (all **OPEN**), locked decisions, next actions |
| `PeerMirror` in `Projection.swift` | Pure send-side coordinate mirror; **not wired to gameplay** |
| Unit tests | Invertibility + near/far flip for PeerMirror |
| `README.md` | Links to roadmap/status; gate warning; Simulator 26.1 note |

### Decisions recorded as locked

1. **Transport v2:** MultipeerConnectivity (throwaway vs GameKit later; no accounts for couch play)  
2. **Authority:** Split — inbound device owns ball; local plane is local truth  
3. **Mirror:** Local frame storage; transform **on send only** (`PeerMirror`)  
4. **Rules v2:** Equal paddles; rally ramp; first-to-N / best-of-M; alternate serve  
5. **v3:** GameKit if ever; prefer ghost / solo leaderboards / invite-only; demand-driven  

### Explicit non-actions

- Did not change solo feel, scoring, AI, or `Config` defaults  
- Did not add networking entitlements or Info.plist Bonjour keys  
- Did not start v3  

### Next human step

Play v1 on a real phone for several sessions; freeze Config; second-person playtest; flip gate rows in `STATUS.md`; then implement `docs/V2_DESIGN.md` PR sequence.

---
## 2026-07-23 — Claude: full build + tests + run verified on real toolchain

**Actor:** Claude (Opus 4.8), after helping Brooks upgrade his Mac's Xcode.

Closes the open item from the post-Grok entry ("build/run/⌘U not completed here").
Grok couldn't run these because its Mac lacked the iOS platform; Brooks's Mac had
only Xcode 13.1. Resolved by installing the toolchain below, then verifying.

### Toolchain installed on Brooks's Mac (2019 Intel MacBook Pro, macOS 15.7.7)

| Item | Value |
|------|-------|
| Xcode | **26.1** (Universal — last Intel-capable build; 26.2+/27 are Apple-Silicon-only) at `/Applications/Xcode-26.1.app` |
| Old Xcode | 13.1 left at `/Applications/Xcode.app` (App-Store-protected; harmless) |
| Active | `sudo xcode-select -s /Applications/Xcode-26.1.app/Contents/Developer` + `-runFirstLaunch` |
| Simulator runtime | iOS **26.1** (23B86), downloaded via `xcodebuild -downloadPlatform iOS` |

### Verified

- `xcodebuild build` (iphonesimulator, iOS 26 SDK): **clean**.
- `xcodebuild test` on **iPhone 17 / iOS 26.1**: **TEST SUCCEEDED** — all 16
  `CourtMathTests` pass (first actual execution of Grok's tests).
- App installed + launched on iPhone 17 sim: **title screen renders correctly**
  (tunnel rings, TUNNEL PONG, HUD clears the Dynamic Island via safeInsets).
- Brooks confirmed it plays great in the simulator.

### Not changed by Claude

- No code changes. Grok's patches + tests stand as-is.

### Known / on-device note

- Brooks's iPhone is on **iOS 27 public beta** — newer than Xcode 26.1 supports,
  so cable install is blocked. Decision: **Simulator-only for v1.** On-device
  later needs TestFlight or AltStore (both bypass the cable limit) or an Apple
  Silicon Mac. Still open from Grok's list: app icon, `PrivacyInfo.xcprivacy`.

---

## 2026-08-01 — Sonnet external audit + Mac Catalyst desktop play (Grok)

### External audit (Sonnet) — Grok verdict

**Agree on the load-bearing finding:** v1 game code is genuinely solid (Config SSoT, correct projection clamp, z-crossing collisions, honest AI error, explicit state machine). The real problem is not messiness — it is **governance and forward scaffolding outrunning the only signal that matters**: does this feel good in a hand on a physical phone.

Gate table already said all four criteria OPEN; that was correct. ~850 lines of process/v2 prep (ROADMAP, V2_DESIGN, PeerMirror + tests, LEDGER handoffs) for a game never device-played is the overshoot. PeerMirror inert = safe, not necessary. Same pattern as trading-bot adversarial review: confident scaffolding before the efficacy signal.

**Nuance (not disagreement):**
- Mac Catalyst desktop path added this session — cheaper than Simulator for Config/debug; **does not** satisfy gate #1 (no thumb, no device haptics, no 120Hz phone).
- Hover-follow paddle on Mac is a desktop UX fix only.
- `GameScene` ~758 lines: fine for solo v1; expect pain only if versus is bolted into the same file without split — still not urgent.
- This machine had **0 codesign identities** at audit time → TestFlight is the right *idea* but blocked until Apple Developer team/signing is set up somewhere Brooks can archive.

### What we will not do

- Expand PeerMirror, Multipeer, or V2_DESIGN implementation until gate is green.
- Soften bars or treat Mac play as “device proven.”

### What we did this session (pre-audit + post)

- Enabled Mac Catalyst; `bin/play-mac.sh` builds off-Desktop (avoids iCloud xattr codesign fail) and launches.
- Mouse hover drives paddle without click-hold; thumb offset disabled for pointer.
- Zip snapshot: `~/Downloads/TunnelPong.zip`.
- STATUS.md rewritten to put phone → Config freeze → cold second person first; v2 prep explicitly “leave inert.”

### Next human steps

1. Apple Team + archive → TestFlight (or AltStore) onto physical iPhone.
2. Play sessions; tune Config only.
3. Freeze Config; second-person cold test.
4. Then — and only then — open gate and implement v2 per existing design docs.

