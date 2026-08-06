# Tunnel Pong — Ledger

Append-only history. Never rewrite old entries; only add new dated sections.
Audience: Brooks + any AI (Claude, Grok, Composer) picking up the project.

---

## 2026-08-04 — v2.0 "To The Glass" (Claude)

**Source:** Brooks, with a device screenshot of v1.9. Four notes.

### 1. Ball now travels to the screen
The player's paddle plane moved from `z = 0` (the first wall) to a **negative
depth in front of it**, so the z axis genuinely continues through the viewer.

Not hardcoded. `CourtMath.planeZFilling` derives the depth at which the court
projects to the full screen width, so the plane lands at the glass on any device,
orientation, or Mac window size, and the paddle can reach every visible point.
`playerPlaneScreenFill` (1.0) tunes it; `playerPlaneMinZ` (-140) is a hard floor.

**Why the floor matters:** the perspective divide blows up as z approaches
`-focal` (-280) and turns the tunnel inside out. The sabotage run proved this is
live — with the clamp removed, an extreme aspect ratio produced z = -279.4.

Physics is unchanged: walls and the ball stay in world units, so only the plane
of judgement and its projection moved. Near-plane crossing, hit response, miss
freeze, and paddle rendering all key off the new plane.

### 2. Motion blur raised
`trailLength` 5 → 8, head alpha 0.55 → 0.70, tail 0.12 → 0.16, tail scale
0.55 → 0.62.

### 3. Depth dot differentiates with distance
Size now lerps `depthDotNearScale` 1.45 → `depthDotFarScale` 0.50 **linearly in
depth**, rather than reading straight off the perspective divide. Linear keeps
the near/far difference a deliberate, tunable amount. Echoes the rails, which are
already thicker near the viewer and thinner heading away — Brooks's own reason.

### 4. Surface type centred in its wall segment
Brooks saw a gap at one wall and none at the other. Cause: the type was inset in
**z**, but perspective is non-linear, so equal depth padding produces unequal
screen gaps. `CourtMath.surfaceTypeSpan` now insets in *scale* space, which is
what the eye actually reads as centred. `hudSurfaceSegmentInset` = 0.14 of the
segment's on-screen height, both ends.

Also `hudLevelSize` 30 → 36: LVL read skinny next to the score, and in a bitmap
font the pixel size *is* the stroke weight, so matching heights matches weight.

### Tests
**39 assertions** (up from 33). New: the type stays inside its segment, the two
screen gaps are equal to within 0.002 and both non-zero; the plane lands where
the court fills the target width, is never pushed behind the first wall, is
clamped at the safety floor, and the rails still extend past it.

**Failure proven twice:** zeroing the inset turns the centring red; removing the
plane clamp turns two red including the inside-out case above.

### Not verified
Appearance unverified locally — still no Screen Recording permission. Brooks to
judge, especially whether the ball arriving at the glass feels right, since at
that depth the side walls sit near or beyond the frame edges by design.

---

## 2026-08-04 — v1.9 "One Segment" (Claude)

**Source:** Brooks, with a device screenshot of v1.8. Depth dot approved. Surface
type liked but too tall — should span "between the first and second wall".

### Change
`hudSurfaceZFar` is no longer a raw number. It is now derived from
`hudSurfaceEndRing` (= 1) through `CourtMath.ringT`, so the type ends **exactly
on the second ring** and fills one wall segment. Depth 300 → 112.5.

Measured effect: near-edge scale is unchanged at 0.966, far-edge rises 0.483 →
0.713, so the on-screen vertical span drops to **52%** of v1.8. Glyph sizes were
left alone — the sprawl was depth, not point size.

Expressing this as a ring index rather than a depth is the actual fix. It is why
the type reads as *part of* the floor and ceiling: it fills one wall segment by
construction, and it keeps doing so if `ringCount` or `zFar` ever change.

### Tests
Four assertions added (33 total): the type ends on or before the second ring,
starts before it ends, starts at or after the near wall, and spans no more than
~1.2 wall segments. **Failure proven:** setting `hudSurfaceEndRing = 3` turns two
red; reverting turns them green. That guard is the point — the sprawl this
release fixes is now impossible to reintroduce silently.

### Not verified
Appearance still unverified on this machine (no Screen Recording permission).
The 52% figure is computed from the projection, not observed. Brooks to judge.

---

## 2026-08-04 — v1.8 "Surface Type" (Claude)

**Source:** Brooks, with device screenshots. Depth dash read as clunky; pause and
HUD type notes.

### Depth tracker simplified
Replaced the long perspective dash with a **small square dot** per corner rail,
recoloured to `ringHitColor` — the same colour a wall flashes when struck — so
the two cues read as one family while staying separate channels. The dot still
scales with perspective (floored at `depthDotMinScale` so it survives the far
wall), which keeps the acceleration-as-timing-cue property without the bulk.

Removed `CourtMath.depthTickSpan` and its four assertions along with the dash;
they tested geometry that no longer exists. Suite back to 29.

### Pause button
Bottom-right corner, on the safe-area floor, alpha 0.4 → 0.85.

### HUD type on the tunnel surfaces
LVL and the score are now **projected onto the ceiling and floor planes** rather
than drawn flat over them. `PixelLabel.SurfaceProjection` maps every glyph pixel
through the same perspective divide the tunnel uses, emitting quads instead of
rects — so the type genuinely lies on the surface: near rows taller and wider,
each row at the screen height that surface actually has at that depth.

Both labels anchor to their own wall (`+halfH` / `-halfH`) over the same
zNear/zFar span, so **the equidistance Brooks asked for falls out of the geometry
rather than being tuned per device** — it holds across portrait, landscape, and
free Mac resize automatically. Sizes raised to `hudLevelSize` 30 / `hudScoreSize`
38 (these are near-edge sizes; perspective shrinks the far rows).

`hudTopGap` deleted — the level label no longer uses a flat offset.

### Not verified
**Appearance again untested.** Screen Recording permission is still missing on
this Mac, so `screencapture` returns the desktop wallpaper rather than the app.
Typecheck, dead-knob sweep, and the 29 logic assertions pass; how it *looks* is
Brooks's call. Likely knobs if the type reads badly: `hudSurfaceZFar` (recession
depth — the main legibility lever), `hudSurfaceWidthScale`, and the two sizes.

---

## 2026-08-04 — v1.7 "Depth Readout" (Claude)

**Source:** Brooks, after playing v1.6. Two asks: move the pause button, and add
a z-axis depth cue because it is hard to judge when the ball reaches your plane.

### Pause button
Moved from beside the score to the **bottom-right corner**, on the safe-area
floor rather than the court floor, and opacity raised 0.4 → `pauseButtonAlpha`
0.85. It is now clear of the tunnel mouth and under the thumb.

### Depth tracker
Four bright dashes ride the corner rails at the ball's current z — a halo stroke
plus a hard core stroke, in the **ball's own colour**, so the eye reads "that is
the ball's depth" rather than "that wall was struck".

Deliberate design constraint from Brooks, preserved: **the x/y walls still stay
dark until individually struck.** He called that a good design choice and it is —
it is what makes an impact read as an impact. Depth therefore gets its own
channel on the only geometry that runs along z, instead of being folded into the
wall-glow the original Curveball used.

The dash spans a fixed range in *world* z, so perspective turns it into the
timing cue by itself: short and creeping while the ball is far, long and racing
as it arrives. No extra easing needed — the projection does the work.

### Tests
`CourtMath.depthTickSpan` extracted so the clamping is reachable from the CLI
harness. **33 assertions** (up from 29): the span never collapses anywhere on the
court, never leaves the drawable rail, is clamped at the far wall, and correctly
straddles the player plane. **Failure proven:** removing the far clamp in the real
function turned two red; restoring turned them green.

### Not verified
**The visual result is untested.** `screencapture` on this machine lacks Screen
Recording permission and returns the desktop wallpaper instead of the app window
— the identical trap that produced Grok's bogus v1.5 moon screenshot. The
geometry math is asserted; how it *looks* is not. Brooks to judge on device.
Likely tuning knobs if it reads wrong: `depthTickHalfZ` (length),
`depthTickHaloAlpha` (glow strength), `depthTickWidth`.

---

## 2026-08-04 — v1.6 "Centre Start" (Claude)

**Source:** Brooks, after extended device play. Curve confirmed good on phone; no
retune needed.

### The change

Every point now begins with the ball parked **dead centre of the tunnel**
(`rallyStartZFraction = 0.5`), hanging for `serveDelay`, then launching toward
whoever gets the first touch. Swipe-to-serve is gone entirely — your opening
action is a *return*, not a serve.

**Direction rule:** the ball goes first toward whoever **won** the previous
point. Win it and you get the free opening touch; lose it and the opponent takes
the ball first and you receive whatever curve they put on it. A new level (and a
fresh run) counts as a win for the player, so it comes to you.

Note this is a genuine behaviour change on a loss: the old code had the opponent
serve *at* you after you conceded. Now they get the first touch instead.

### Record correction

Brooks recalled the original Curveball as starting each point with the ball
travelling to the player from the far side. Re-checked the decompiled source:
it does not. After a point the original goes to a "Serve" state with the ball
stationary at the player's own plane (`myPos.z = 0`, `mySpeed.z = 0`) and
`onClipEvent(mouseDown)` launches it — essentially what CyberPong already had.
The new behaviour is therefore **our design, not a port**. It is better than
both: it removes a dead stop from the start of every point and makes the opening
action a return, which is where the curve mechanic actually lives.

### Deleted (dead once serving is gone)

`awaitingPlayerServe`, the five `serveDrag*` gesture vars, `serveReadyShown`,
`serveHintLabel` (+ its layout and creation), `tryDragServe`, `tryClickServe`,
`launchPlayerServe`, `serveSpinVector`, `serveTravelMin`, `paddleOverlapsServeBall`,
`clearServeGesture`, and the serve branches in all three touch handlers.
Config: `serveSwipeMin`, `serveDragSpin`, `playerServeZ`, `serveZFraction`.
`serveCornerBoost` stays — `applyEnglish` still uses it for corner contact.

### Tests

Extracted the rally rules to `CourtMath.rallyStartZ`, `rallyLaunchVz`, and
`firstTouchGoesToPlayer` so they are reachable from the CLI harness instead of
being buried in the scene, and wired `GameScene` to call them. **29 assertions**
(up from 21), including that the centre is strictly between both planes, that a
negative magnitude cannot silently flip direction, and that the winner of the
last point gets the first touch.

**Failure proven:** inverting the sign in the real `rallyLaunchVz` turned three
assertions red; reverting turned them green. The sign convention (player plane
is z = 0, so toward the player is negative vz) is exactly the thing most likely
to get flipped by a future edit, which is why it is a named function rather than
a ternary in the scene.

Dead-knob sweep clean. Built signed and installed on BCM 16 Pro Max.

---

## 2026-08-04 — v1.5 "Make It Actually Curve" (Grok)

**Source:** `GROK_HANDOFF_v1_5.md` (Claude) after Curveball SWF decompile comparison.
**Results:** `~/Desktop/umbrella/inbox/GROK_TO_CLAUDE_cyberpong_v1_5_RESULTS.md`

### Shipped
- **Persistent curve** (`curveX`/`curveY`): integrate before position, exponential
  decay `pow(curveDecayPerSecond, dt)`, renorm speed + minVz (bend, don't accelerate).
- **Curve from paddle velocity** (player + AI), smoothed; serve drag writes curve not vx/vy.
- **Paddle lag** (`paddleFollowLerp`) so velocity signal exists on Mac/iOS.
- **Scoring teeth:** hit / curve / super-curve / accuracy / level-clear bank with
  degrade-to-zero + reset on life loss; PixelLabel popups.
- **AI wall clamp** (half paddle-width beyond flush) for wall-hug scoring lane.
- **englishStrength** demoted 0.88 → 0.45 (contact offset kept, curve dominant).
- **Deletions:** face-grid path + 5 grid Config knobs; `ballDrawScale`; collapsed
  serve swipe constants; `railLineWidth` → `railLineWidthDefault`; fixed hudTopGap comment.
- **E6 moon:** left in place; flagged with screenshot for Brooks.

### Tests (fail-able CLI, no simulator)
- `bin/test_v1_5.sh` — 21 PASS against real linked source (see Claude audit below)
- Failure proven by sabotaging real `applyCurveStep` (red), then reverting (green)
- Mac Catalyst **BUILD SUCCEEDED** + launch; iOS device generic **BUILD SUCCEEDED**

### Not done
- Feel-tune on device beyond Catalyst launch (recommended defaults documented in RESULTS).
- Strategy / App Store / multiplayer — out of scope.

### Claude audit of v1.5 (same day)

Implementation verified correct: curve integrates before position, wall bounce
flips the reflected axis only, `invert:` is true for the player hit and false for
the AI hit (matching the original's asymmetry), all new Config knobs are wired,
and every Part E deletion landed with zero remaining references.

Two defects found and fixed:

1. **The test harness did not test the shipping code.** `bin/test_v1_5.swift`
   contained a hand-copied *mirror* of `CourtMath` and `ScoreBonuses` and asserted
   against the copy, with hard-coded tuning literals rather than Config values —
   while its own header claimed it compiled `Projection.swift`. It would have
   stayed green through any regression in the real file. This is the fleet's
   named anti-pattern: a test that simulates a code path instead of driving it.
   Replaced with `bin/v1_5_tests/main.swift` + `bin/test_v1_5.sh`, which links
   the real `Config.swift` and `Projection.swift` and reads every threshold from
   Config, so test/app drift is impossible by construction. Deleted the mirrored
   harness and the separate "red-before" file (a second reimplementation, not a
   test of anything shipping).
   **Failure proven, not assumed:** sabotaging the real `applyCurveStep` to
   per-frame decay turned it red (2 failures); reverting turned it green.
   21 assertions pass, up from 17.
2. **Magic number outside Config.** The D1 AI wall inset `1.5` was duplicated in
   `clampOpponent` and `stepAI`. Extracted to `Config.aiWallInsetPaddles` — it
   directly controls how wide the high-level scoring lane is and belongs on the
   tuning surface.

Also re-derived the D2 table from live Config inside the test rather than from
copied literals, and promoted "ceiling never binds" from a printed table to an
actual assertion — so if a future retune makes it bind, the suite says so.

Built signed and installed on BCM 16 Pro Max. `PrivacyInfo.xcprivacy` present in
the bundle; `Products.storekit` correctly absent.

**Moon: RESOLVED — it stays.** Brooks confirmed 2026-08-04 that he likes it. The
earlier "no mountains or moon" instruction is superseded; mountains gone, moon
intended. **Do not remove it as a cleanup.** Recorded in `docs/ROADMAP.md` along
with his v2 idea: a dynamic 8-bit backdrop — passing clouds, or a small figure on
the moon who cheers when the player hits the ball.

For the record: Grok's `docs/v1_5/moon_flag.png` was **not valid evidence** — it
captured the desktop wallpaper (which has its own moon) behind the app menu bar,
the same screen-capture trap hit earlier in this project. Deleted rather than
committed (4.9 MB, public repo). Moon presence was confirmed by reading
`Nodes.swift` instead.

**Still open:** device feel-tuning of `curveFromPaddleVel` (0.55 shipped; try
0.60–0.65 if swipes read weak on ProMotion).

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

## 2026-08-01 — First physical iPhone run

Brooks installed and launched v1 on **BCM 16 Pro Max (iOS 27)** via Xcode cable + Apple Development signing (personal Apple ID). Initial miss was run destination set to Simulator; after switching destination to the device and trusting the developer profile in Settings → General → VPN & Device Management, app opened. Brooks: “super cool.”

Gate #1 → **IN PROGRESS** (need multiple sessions, not one launch). Still do not start v2.

## 2026-08-01 — CyberPong v1 wrap (retrowave + campaign)

**Rename / theme:** Product title **CyberPong**. Majority black + retrowave from desktop refs c1.jpg / c2.jpg / c3.png — electric cyan player, hot magenta opponent, sunset orange ball, violet tunnel wire. Condensed cyberpunk type (Avenir Next Condensed*). Title wordmark CYBER / PONG.

**Gameplay polish this pass:** Paddle strike flash (alpha → ~0.12 then recover). 10-level linear difficulty already in; wrap declares v1 solo complete for feature scope.

**Discipline:** STATUS marks v1 WRAPPED. v2 gate still CLOSED — no Multipeer / PeerMirror wiring until multi-session device play + Config freeze + cold second person.

**Play:** Mac `bin/play-mac.sh`; phone cable install proven earlier this session.

## 2026-08-01 — Opponent center reset + chrome layout (pre-Claude review)

### Gameplay
- **Every point / serve:** opponent paddle snaps to world center `(0,0)`; AI does not move while `!ballLive` (fixes crawl-back during user serve).
- User still serves first each round; ball still fixed center until paddle strike.

### Layout
- Mac: `macTitlebarInset` (40) + taller default window (400×920); HUD and title wordmark laid out under chrome via `applyChromeLayout()`.
- iOS: HUD respects safe-area top/bottom (notch / home indicator) with `hudTopPad` / `hudBottomPad`; async re-layout after insets settle.
- Court projection remains screen-centered; only chrome moves into the safe band.

### Docs for Claude review
- Added **MEMORY.md** (durable architecture).
- STATUS rewritten for review handoff.
- v1 remains WRAPPED; v2 gate still CLOSED.

### Review ask
Claude: verify serve/AI reset, Catalyst/iOS chrome, L1–L10 difficulty leash, and that nothing multiplayer was half-wired.

## 2026-08-01 — Claude audit of Grok's wrap + endless-mode rules

**Actor:** Claude (Opus 5). Grok's 852-line CyberPong wrap was committed as-is
first (`fc6193a`) so his work stayed attributable before any edits.

### Audit verdict

Implementation is sound. Gate discipline **held** — no multiplayer half-wired;
`PeerMirror` still inert, referenced only by tests. 20/20 tests passed on his
code as received. Findings were tuning-honesty and edge cases, not foundations.

### Findings

| # | Finding | Disposition |
|---|---------|-------------|
| 1 | 852 lines of the wrap uncommitted | Committed + pushed before edits |
| 2 | Campaign needed ~95% point-win rate over 30 points to finish (36.7% run completion at p=0.90, 12% at p=0.85) | Replaced with endless mode per Brooks |
| 3 | `aiLateralFrac*` never binds at any level — yet README dial #3, MEMORY, and Config all called it "the real leash" | Kept as safety ceiling; docs corrected to `aiSpeedL1/L10` |
| 4 | Mac window resize desynced tunnel from play area (`applyChromeLayout` recomputed halfW/halfH but never rebuilt ring paths; corner rails never referenced after creation) | Fixed |
| 5 | Dead code: `serveTouchedBall` written 3× never read; `segmentHitsBall`/`isOnBall` fed only that flag; `playerMiss`/`opponentMiss` never called; `paddleSmoothing`/`serveBallHitPad` unread | Removed |
| 6 | `TARGETED_DEVICE_FAMILY = "1,2"` vs iPhone-only docs | Noted, not changed (Catalyst needs it) |
| 7 | No app icon (placeholder grid on home screen) | Open — Brooks wants to design together |

### Design decision (Brooks, locked)

**There is no "win".** CyberPong is an endless high-score chase like every great
iOS arcade game. `Config.maxLevel = 10` is a *difficulty ceiling* — "as hard as
it gets without being impossible," where impossible = an opponent too fast to
get past. Levels count up forever; the curve holds at L10.

**Lives are spare lives.** 3 hearts = 4 misses; at 0 hearts the HUD reads
`LAST LIFE`. Clearing a level returns one spare, capped at 3 — no banking lives
you never lost, so the pressure never fully lifts.

### Code changes

- Endless: removed `winRun()`, `endRun(won:)` → `endRun()`, level uncapped,
  `LV n` replaces `LV n/10`.
- Lives: `playerLivesMax` + `lifeGainPerLevel` replace `extraLifeEveryNLevels`;
  run ends at `playerLives < 0`; `LAST LIFE` HUD state.
- `rebuildTunnelGeometry()` re-derives ring paths + corner rails on every
  layout change; pause dim now resizes too.
- Dead code purge (finding 5).

### Verified

Xcode 26.1 / iPhone 17 / iOS 26.1: build clean, **20/20 tests pass**.

### Still open for v1

App icon (needs real PNGs — the one place "zero assets" must bend), theme pass,
feel tweaks. v2 gate remains CLOSED.

---

## 2026-08-01 — Grok review of Claude theme stack + depth/texture pass

**Actor:** Grok (xAI). Brooks asked for a review of Claude's recent work and more
texture/depth in the design.

### Claude review (commits after Grok wrap)

| Commit | What | Verdict |
|--------|------|---------|
| `a62b6ca` | Endless score-chase, spare lives, Mac resize tunnel rebuild, dead-code purge | **Keep.** Honest AI docs (`aiSpeed` is the dial). Correct Mac resize bug. |
| `34b4368` | Retrowave sunset backdrop, hairline type, three-colour actors | Superseded — Brooks wanted black background only. |
| `fce510c` | Black + starfield, square tunnel, rounded paddles + impact glow, hearts | **Keep** as base look. |
| `523a5b1` | PixelFont 5×7, wall colour ramp, rolling ball, scanlines, serve hint fix | **Keep.** Strong 8-bit read without assets. |

**Bugs found:** Pause HUD used `❚❚`, which is not in `PixelFont` → blank control (fixed → `||`). `MEMORY.md` still described cyan/Avenir after theme moved on (docs lag).

**Quality:** Theme iteration was disciplined (zero assets, Config-driven). Gameplay rules from endless pass remain solid. GameScene continues to grow as the god-object (~1.3k lines) — fine for v1.

### Depth / texture pass (this session)

All procedural, still zero asset files:

1. Layered starfield + live twinkle stars  
2. Radial vignette (tube edges)  
3. Soft depth panels behind rings  
4. Perspective grid (floor / ceiling / side walls)  
5. Vanishing-point glow (slow breathe)  
6. Dust motes in the shaft  
7. Ball motion trail + floor contact shadow  
8. Paddle inner plate + crosshair ticks  
9. CRT grain layered with scanlines  
10. Stronger ball surface bands for roll readability  
11. Pause glyph fix  

**Verified:** Mac Catalyst `bin/play-mac.sh` → **BUILD SUCCEEDED**, app launched.

**Still open for v1:** App icon; play-feel after living with the denser look; v2 gate still CLOSED.

## 2026-08-01 — Modern GBC / c3.png style pass (Grok)

**Ask:** Much more 8-bit; Desktop `c3.png` as direct style reference; feel like a
modernly designed Game Boy Color game — retro but beautiful.

### Direction
- Limited, deliberate palette pulled from c3 (black zenith → indigo → violet →
  magenta → hot pink horizon; black peaks; pink ridges; white moon).
- Hard pixels and nearest-neighbour upscale, not soft neon/CRT blur.
- Depth via stepped colour, dither, parallax silhouettes, and grid — modern
  craft on 8-bit constraints (Celeste / modern GBC homebrew energy).

### Code
- `Config`: pixel grid (`pixel=3`, snap helpers), GBC palette, stepped
  `wallColor`, LCD overlay knobs, square paddles.
- `Nodes`: `worldBackdropTexture` (c3 landscape baked at logical res),
  Bayer dither sky, pixel moon/peaks/streaks, `pixelDiscTexture` ball,
  hard tunnel strokes, LCD overlay.
- `PixelLabel`: block size snaps to grid; optional 1-block title shadow.
- `GameScene`: pixel-snap positions, quantized scales, 16-step ball spin,
  stepped trail/shadow alpha, square dust, discrete vanishing pulse.

**Verified:** Mac Catalyst BUILD SUCCEEDED, launched.

## 2026-08-02 — Grok polish + Claude catch-up docs

**Actor:** Grok (xAI).

### Play / feel
- AI pure tracking, linear `aiSpeed` only (~48→245); ease-in removed earlier.
- Spin/english/serve drag raised; minVzFraction 0.48.
- Screen flashes removed from points and level-ups (haptics + audio remain).
- Far tunnel ring restored so corner rails meet a real frame; corner radius
  capped so far ring stays a rounded rect (not a pink disc).
- Title chrome: 3-band brighter pink → magenta → dark purple.

### Audio / type / sky (earlier same day)
- `Audio.swift` procedural retrowave; player tick / opponent tok.
- Chrome titles (r1-inspired); c3 sky without mountains; consistent stars;
  vanishing glow + dust + twinkle removed.

### Docs
- STATUS.md + MEMORY.md rewritten for Claude handoff.
- v2 gate still CLOSED.

**Verified:** Mac Catalyst builds during session.

## 2026-08-02 — Claude final v1 audit: app icon, audio/frame efficiency, device-ready

**Actor:** Claude (Opus 5). Grok's polish pass committed as-is first (`563a3b4`).

### Efficiency findings (both fixed)

1. **Audio allocated and attached a node per sound.** `playTone` synthesised a
   fresh PCM buffer sample-by-sample *and* called `engine.attach` +
   `engine.connect` on the running engine for every hit, detaching async after.
   In a rally that fires several times a second; attach/detach on a live
   AVAudioEngine is expensive and can glitch output.
   → Waveforms are now cached by (freq, dur, wave) and synthesised once;
   amplitude is baked at 1.0 with loudness applied via `player.volume`, so one
   buffer serves every volume. A fixed pool of 12 player nodes is attached once
   at `prepare()` and reused round-robin, preferring an idle node.
2. **Per-frame heap allocation in `renderWorld`.** The stepped trail-alpha array
   was built inline inside the ghost loop — ~300 allocations/second at 60fps,
   against the project's own "no allocations in the update loop" rule.
   → Hoisted to `GameScene.trailAlphaSteps`.

Noted, not changed: `trailHistory.insert(at: 0)` is O(n), but n = trailLength
(5) so the shift is negligible.

### App icon (was the last open v1 item)

Generated, not drawn: `bin/make-icon.swift` renders a 1024px icon into
`Assets.xcassets` — tunnel of concentric squares on the same wall ramp as
`Config.wallColor`, corner rails to the vanishing point, neon-orange ball with a
radial glow, deterministic stars. Ring count cut to 5 and the outer ring held
inside 0.40 so it survives iOS's corner mask and stays legible at home-screen
size. Re-run with `xcrun swift bin/make-icon.swift`.

Wired `Assets.xcassets` into the project + `ASSETCATALOG_COMPILER_APPICON_NAME`.
**Caught during wiring:** the new asset entries initially reused
`A10000000000000000000009` / `A20000000000000000000009`, already taken by
Grok's `Audio.swift` — duplicate pbxproj UUIDs. Re-keyed to `...000A`, verified
no duplicates remain.

### Verified

- **iOS device (Release, generic/platform=iOS): BUILD SUCCEEDED** — this is the
  configuration that matters for installing on hardware.
- **Mac Catalyst: BUILD SUCCEEDED.**
- A first device build failed on `AssetCatalogSimulatorAgent`; a clean derived
  data directory cleared it. Transient, not a project defect.
- **Unit tests were NOT re-run this pass** — Brooks asked for no simulators, and
  the test target can't run on Catalyst (its macOS deployment target, 26.1,
  exceeds this Mac's 15.7.7). The functions `CourtMathTests` covers were not
  touched by this pass.

### Notch / safe area (reviewed, unchanged)

Hearts sit in the Dynamic Island *ear* band when `topSafe >= 44`; level and
score sit fully below the safe top. Checked the corner-radius geometry: at the
hearts' height on a Pro Max the screen curve intrudes ~12pt, and `sidePad` is
18pt, so the hearts clear it. Pause button sits ~44pt off the bottom, above the
home-indicator gesture strip.

### Still open (deliberately)

`PrivacyInfo.xcprivacy` (App Store only, not needed for personal install);
deployment target is iOS 17, which excludes iPhone X/8 (they cap at iOS 16).

---

## 2026-08-02 — Claude: iOS corners, Island clearance, elastic thumb trackpad

**Actor:** Claude (Opus 5), at Brooks's request after playing on device.

### 1. Tunnel corners match the device

`ringCornerRadius` (a flat 9pt) replaced by `ringCornerFrac` = 0.125 of court
width — the same proportion iPhone uses for its own screen corner (~55pt on a
440pt display) — scaled by depth so distant rings round less. `ringCornerCap`
(0.32 of the ring's smaller half-dimension) stops far rings collapsing into
discs. Applied in `NodeFactory.ring`, `depthPanel`, and `rebuildTunnelGeometry`
so all three stay in agreement.

### 2. Top wall no longer crosses the Dynamic Island

The court was sized off the raw screen (`height/2 * 0.95`), putting the near
ring's top edge ~24pt from the top — straight through the Island.

Court geometry is now derived from the **safe vertical band**: top wall at
`height - safeTop - courtTopPad`, bottom at `safeBottom + courtBottomPad`, with
the vanishing point at the band's centre. The top wall clears the Island on any
device, and the fix generalises to every notch rather than hard-coding one.

Knock-on: LV/score previously sat at `height - safeTop - 6`, which would now
land *on* the wall line. They hang from the wall instead (`courtTopY -
hudTopGap`), inside the tunnel. Hearts stay in the Island ear band.

### 3. Elastic trackpad (iOS only)

Absolute touch-to-paddle mapping meant covering a 6.9" court required stretching
the thumb off the grip. The phone now treats the finger as a **relative
trackpad**: press anywhere to set an origin, and the paddle travels
`touchGain` (2.3) × further than the thumb. The whole court is reachable with a
short swipe from a natural grip, anywhere on the glass.

**Elastic re-anchor:** when the paddle is pinned against a wall, the origin
moves to the thumb's current position. Without it the thumb accumulates "debt"
past the edge and the paddle sits dead until you drag all the way back — the
standard relative-control failure.

Knock-on: steering *is* dragging now, so the old mid-drag serve would fire the
instant the paddle crossed the ball. Serve moved to **lift** (touchesEnded,
which already handled it); iOS hint reads "LIFT TO SERVE". Drag direction at
release still supplies serve spin. Mac is untouched — hover still maps absolute.

`Config.touchOffsetY` (the thumb-occlusion offset) is now dead and removed;
relative control has no occlusion problem, since the paddle isn't under the
finger.

### Verified

iOS device Debug **BUILD SUCCEEDED**, signed, and installed on BCM 16 Pro Max
via `devicectl`.

---

## 2026-08-02 — Claude: rail/corner join fix + swipe-to-serve restored

**Actor:** Claude (Opus 5), from Brooks's device screenshot.

### Corner rails floated off the ring corners

Rails were drawn to `(±halfW, ±halfH)` — the ring's *sharp* corner. Once the
rings took an iPhone-sized corner radius, that point stopped being on the drawn
path: the arc cuts across it, so the rails ran past the rings into empty space.
The bigger the radius, the worse the gap — invisible at the old 9pt, obvious at
~55pt.

New `railAnchor(sx:sy:z:)` returns the 45° point on the corner arc, inset from
the sharp corner by `r · (1 − 1/√2)` on each axis. Both rail endpoints use it,
so rails meet the rounded rings at every depth.

### Serve back to swipe

`LIFT TO SERVE` reverted — Brooks preferred sweeping the paddle across the ball.
Restored the mid-drag strike: while awaiting serve, if the paddle overlaps the
ball and the thumb has moved more than `Config.serveSwipeMin` (6pt) that frame,
it launches with the drag's spin. The same motion that steers now strikes, which
is what made the original feel good. `touchesEnded` still serves as a fallback
for a slow nudge onto the ball.

### Verified

Device build signed and installed on BCM 16 Pro Max.

---

## 2026-08-02 — Grok: 10/10 polish (pure-XY AI + audit cleanup)

**Actor:** Grok (xAI), after Brooks's audit of Claude's night work + report that
the opponent felt like it predicted where the ball would land.

### Root cause (AI felt psychic)

`stepAI` was **not** pure tracking. On outbound balls (`vz > 0`) it computed:

```
tHit = (zFar - bz) / vz
tx, ty = CourtMath.reflect(bx + vx*tHit, …)  // exact far-plane intercept
```

That is classic intercept aim with wall-bounce folding — the paddle pre-moves
to the arrival point, so speed only needs to cover remaining distance before
impact. Brooks's intended design: chase **live** `(bx, by)` and get faster.

### Fixes

| Item | Change |
|------|--------|
| AI | Always chase clamped current ball XY. No intercept, no `reflect` aim. |
| Serve swipe | Cumulative path length + net displacement; threshold 14pt (was per-frame 6). Spin from full gesture. |
| Ambient audio | Attach ambient player once; stop/play only (same class as SFX pool fix). |
| Docs | STATUS / MEMORY / README brought current (icon done, audio in-scope, AI lock). |

### Not changed

- Difficulty numbers (`aiSpeedL1/L10` etc.) — retune after play if pure tracking
  makes mid/late too easy.
- v2 gate still CLOSED.
- No multiplayer.

### Verified

Mac Catalyst rebuild + launch; unit tests on iPhone 17 sim (see session log).

---

## 2026-08-02 — Mac swipe-serve, more spin, stepped ring weights

**Actor:** Grok, at Brooks's request while playing on Catalyst.

| Change | Detail |
|--------|--------|
| Mac serve | Same as iOS: click-**drag** across ball (`serveSwipeMin` travel). Pure click no longer serves. Hint: `SWIPE TO SERVE`. During serve swipe, drag steers paddle; hover still aims when not clicked. |
| Spin | english 0.48→0.78, serveDrag 420→720, cornerBoost 0.72, minVz 0.42, ballSpinFactor 1.25 |
| Ring strokes | Near 3 rings **3pt**, mid 3 **2pt**, far 3 **1pt** (`Config.ringLineWidth(index:)`). Z rails stay **1pt**. |

Verified: `bin/play-mac.sh` rebuild.

---

## 2026-08-02 — Claude audit of Grok's tweaks pass

**Actor:** Claude (Opus 5). Grok's pass committed as-is first (`10e3a58`).

### Verdict

Grok's changes hold up. The AI is now genuinely pure tracking — `stepAI` chases
clamped live `(bx, by)` with no intercept solve and no `reflect` fold, which is
what Brooks asked for. Serve-swipe uses cumulative path length plus net
displacement (better than the per-frame delta it replaced). The ambient audio
fix is the right shape: attach once, stop/play thereafter.

Confirmed all six earlier Claude fixes survived the pass: `railAnchor`,
hoisted `trailAlphaSteps`, safe-band court geometry, audio tone cache, audio
player pool, elastic trackpad.

### Fixed: dead knobs in the tuning surface

`Config.swift` is contracted to be the one place anyone tunes, so an entry that
does nothing is a trap. Removed 18 that no code reads:

- **`englishL1` / `englishL10` / `serveDragL1` / `serveDragL10`** — the dangerous
  ones. Grok flattened english and serve-drag to full-strength-from-L1 and left
  these as aliases pointing at the flat value. Nothing reads them, so editing
  `englishL10` to change late-game spin would have silently done nothing. Same
  class of trap as the `aiLateralFrac` finding on 2026-08-01.
- `wallColor()` + `wallNear/Mid1/Mid2/Mid3/Far` — superseded by the single
  `wallNeonPink`; all five aliased to it and were unreferenced.
- `paddleGlowWidth`, `hudScoreGap`, `ringSkipFarPlane`, `panelAlphaNear/Far`,
  `gridLineWidthFar`, `groundColor`, `ridgeColor`, `streakColor`, `dustCount` —
  orphans from removed visual features.

`Config.blend` was checked and **kept**: still used by the ring hit flash.

### Noted, not changed

`CourtMath.reflect` is no longer called by app code — the new pure-tracking AI
was its only consumer. Left in place: it is pure, documented, covered by five
passing tests, and the AI model has changed twice this week. Flagging rather
than deleting so the choice is visible.

### Verified

- iOS device Debug **BUILD SUCCEEDED**, zero compiler warnings, signed and
  installed on BCM 16 Pro Max.
- No `print`/TODO/FIXME left in app code; no `try!` or `as!` force-casts.
- App icon + asset catalog intact.
- pbxproj checked properly: 47 distinct UUIDs, **every ID maps to exactly one
  entity** (no repeat of the Assets/Audio collision).
- Unit tests not re-run (no simulator by request; test target's macOS
  deployment target still exceeds this Mac's).

---

## 2026-08-02 — Landscape + any-aspect court (Grok)

**Request:** Rotate into landscape; tunnel/game resize to any device aspect;
mechanics same; playing field shape follows the screen.

### Changes
| Area | What |
|------|------|
| Orientations | Phone: portrait + both landscapes (`allButUpsideDown`). iPad: all. Info.plist keys updated. |
| Court metrics | `halfW`/`halfH` from usable safe band (left/right + top/bottom). Landscape tightens hearts gap + score band. Adaptive min court height for short landscape. |
| Resize safety | On layout: re-clamp player/AI/ball + touch target so mid-rally rotate stays legal. |
| Mac Catalyst | Free window aspect (min 360×320, max 2400×1800); still rebuilds tunnel via `applyChromeLayout`. |

### Unchanged (by design)
- Ball speed, paddle sizes, AI speed, english — fixed world units.
- Wider landscape → wider field; shorter height → shorter field. Rules identical.

### Verified
- Mac Catalyst `bin/play-mac.sh` → **BUILD SUCCEEDED**, launched.

---

## 2026-08-02 — Mac window resize actually unlocks (Grok)

**Bug:** Dragging the Mac window did nothing — stayed fixed vertical phone shell.

**Cause:** Catalyst sizeRestrictions were set once at launch when `windowScene` was often still nil (optional chaining no-op). Host AppKit window also needed resizable style + cleared aspect lock.

**Fix (`AppDelegate`):** Re-apply sizeRestrictions (360×300…4096×4096) on async/active/appear; unlock host NSWindow via KVC (`styleMask` resizable, `contentAspectRatio` zero, min/max size); walk `NSApplication.windows` as backup.

### Verified
- BUILD SUCCEEDED, relaunched. Human: drag edges to widen.

---

## 2026-08-02 — Crash on launch from resize KVC (Grok)

**Symptom:** TunnelPong quits immediately (SIGSEGV 139).

**Cause:** `AppDelegate.unlockHostWindow` used `value(forKey: "nsWindow")` / AppKit KVC.
Missing keys raise `NSException` → `EXC_BAD_ACCESS` on main thread (not Swift-catchable).

**Fix:** Removed all AppKit KVC unlock paths. Mac resize uses only
`UIWindowScene.sizeRestrictions` (safe). App stays up (verified pid after launch).

---

## 2026-08-02 — Claude: App Store groundwork (privacy manifest + StoreKit 2)

**Actor:** Claude (Opus 5). Brooks decided: **no ads in v1** — free app with a
single $0.99 non-consumable "Supporter" purchase. Keeps the zero-dependency
property, skips App Tracking Transparency, and keeps privacy labels near-empty.

### Added

| File | Purpose |
|------|---------|
| `TunnelPong/PrivacyInfo.xcprivacy` | Required for submission. Declares no tracking, no collected data, and the one required-reason API in use: `UserDefaults` (`CA92.1`) for the high score. |
| `TunnelPong/Store.swift` | StoreKit 2 wrapper — native, no third-party SDK. Product load, purchase, restore, entitlement refresh, and a `Transaction.updates` listener for Ask-to-Buy / cross-device / refund events. |
| `TunnelPong/Products.storekit` | Local StoreKit config so purchases can be tested **before** paying Apple $99. Referenced by the scheme; deliberately **not** in the Resources build phase. |

### Design notes

- Ownership truth is always `Transaction.currentEntitlements` (Apple-verified).
  The UserDefaults copy is only a launch/offline **cache** for rendering, never
  the grant itself.
- `AppStore.sync()` restore is wired to an explicit RESTORE control — App Review
  rejects non-consumables without one, and sync must be user-initiated.
- The store row hides itself when no product loads (offline, or before the
  product exists in App Store Connect) rather than showing a dead button.
- Title-screen taps: the store controls are claimed **before** the
  "tap anywhere to start" handler, or they'd be unreachable.

### Fixed along the way

- **Title layout was index-based** (`kids[0..3]`), so adding any node silently
  shifted everything after it. Replaced with named references.
- **`Products.storekit` was shipping inside the .app** after I first added it to
  Resources. Removed from the build phase; verified absent from the bundle and
  that `PrivacyInfo.xcprivacy` *is* present.

### Still between here and the App Store

1. **$99/yr Apple Developer Program** (currently free personal-team signing).
2. **Paid Apps Agreement** — banking + tax forms. Usually the slowest step.
3. Privacy policy URL (GitHub Pages off the now-public repo would do).
4. App Store Connect record: screenshots, description, keywords, age rating.
5. **iPad decision** — `TARGETED_DEVICE_FAMILY = "1,2"` claims iPad support, so
   Apple will review on iPad and want iPad screenshots. **Note:** dropping to
   iPhone-only would break Mac Catalyst, which is derived from the iPad idiom.
6. Decide what, if anything, the Supporter purchase unlocks beyond the title
   mark (a pure tip jar is allowed under 3.1.1, but should be framed as one).

---
