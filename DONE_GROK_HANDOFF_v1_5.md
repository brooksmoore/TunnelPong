# GROK HANDOFF — CyberPong v1.5 "Make It Actually Curve"

**To:** Grok
**From:** Claude (Opus)
**Date:** 2026-08-04
**Status:** v1 is shipped-quality and installed on device. This is a focused mechanics + cleanup pass. Audit will be by Claude after you report.

---

## Context

CyberPong is a SpriteKit 2.5D tunnel Pong game at `~/Desktop/TunnelPong`. It is an homage to the 2008 Flash game **Curveball**. It has no assets and no third-party dependencies — all visuals, type, and audio are procedural.

I obtained and decompiled the original Curveball `.swf` (Flash 5, 59 KB, ActionScript 1). The full decompiled source is placed at `~/Desktop/curveball-reference/` — deliberately OUTSIDE this repo, which is public. The comparison produced one dominant finding:

**Curveball's ball bends continuously in flight. Ours does not.** The original stores a per-ball `curve` vector that is added to velocity *every frame* and decays slowly, producing a visible banana arc down the tunnel. Ours applies a single deflection at contact and then travels in a straight line. That mechanic is the entire identity of the game we are paying homage to, and we do not have it.

Secondary finding: the original's scoring is far richer than ours (four stacking, self-degrading bonuses with on-screen popups), which matters because CyberPong is an endless high-score chase and currently gives the player almost no reason to play *stylishly* rather than just survive.

v1.5 = add the curve, deepen the scoring, delete accumulated dead code. Nothing else.

---

## Files to read first, in this order

1. `~/Desktop/curveball-reference/scripts/frame_44/DoAction.as` — the original's entire world init and its three ten-entry level tables. The whole game's tuning surface is ~15 numbers. Read this to calibrate how simple the original is.
2. `~/Desktop/curveball-reference/scripts/frame_92/PlaceObject2_80_20/onClipEvent(enterFrame).as` — the original ball loop. Lines 12–24 are the curve integration and decay. Lines 143–144 and 266–267 are where curve is *created* from paddle velocity. This is the mechanic you are porting.
3. `~/Desktop/curveball-reference/scripts/frame_45/PlaceObject2_59_43/onClipEvent(enterFrame).as` — the original player paddle. Note it deliberately *lags* toward the cursor; that lag is what generates the paddle-velocity signal the curve depends on.
4. `~/Desktop/curveball-reference/scripts/frame_91/PlaceObject2_75_13/onClipEvent(enterFrame).as` — the original AI, and its wall clamp.
5. `TunnelPong/Config.swift` — our single tuning surface. Every number lives here; adding tunables anywhere else is a contract violation.
6. `TunnelPong/GameScene.swift` — our game loop. Key line numbers as of this writing: ball integration ~1399, wall bounces ~1412, near/far plane crossings ~1427 and ~1448, contact response `applyEnglish` ~1476, velocity renormalization ~1493, AI ~1515.
7. `STATUS.md` and `LEDGER.md` — current project truth and append-only history.

---

## The task

### Part A — Persistent curve (the point of this release)

**A1.** Add to `Config.swift`, in a new `MARK: - Curve` section:
- `curveDecayPerSecond` — fraction of curve remaining after one second. Start at `0.80`.
- `curveFromPaddleVel` — scalar converting paddle world-velocity into curve acceleration. Start at `0.55`.
- `curveWallDamp` — fraction of curve retained after a wall bounce. Start at `0.85`.
- `curveMax` — hard ceiling on curve magnitude. Start at `900`.
- `curveBonusThreshold` / `curveSuperThreshold` — curve magnitudes that qualify for the scoring bonuses in Part C. Start at `120` and `260`.

**A2.** Add `curveX`, `curveY` state to `GameScene` alongside `vx/vy/vz`.

**A3.** In the physics step, *before* position integration:
```
vx += curveX * dt
vy += curveY * dt
```
then decay: `curveX *= pow(curveDecayPerSecond, dt)` (same for Y).

**CRITICAL — this is the part that will break if you rush it.** Our physics is delta-time based; the original's is per-frame at a fixed Flash frame rate. Its `curveDecay = 1.004` per frame is meaningless to us. You must express decay as an exponential in `dt` exactly as shown above, or the game will behave differently on 60 Hz vs 120 Hz displays. Do not port any per-frame constant literally.

**A4.** After adding curve, **renormalize total speed back to its pre-curve magnitude** and re-enforce `Config.minVzFraction`, reusing the existing `CourtMath.renormVelocity`. This makes curve *bend* the trajectory rather than accelerate the ball.

This is a deliberate divergence from the original, which lets curve add real speed. Reason: our speed is the difficulty curve and is bounded by `ballMaxSpeed` and the per-level ramp; letting curve inflate it would silently break the level tuning and could stall the ball's z-travel. Bend, don't accelerate.

**A5.** Zero `curveX/curveY` wherever `vx/vy/vz` are already zeroed (point freeze, serve reset, game over). A stale curve surviving a reset will make the next serve mysteriously bend.

**A6.** On wall bounce, multiply `curveX/curveY` by `curveWallDamp`. Also negate the curve component on the axis that reflected — if the ball reverses X, its X-curve must reverse too, or the ball will bend back into the wall it just left.

**A7.** Clamp curve magnitude to `curveMax` after it is set.

### Part B — Curve comes from paddle velocity

**B1.** The player paddle already tracks a per-frame delta (`GameScene.swift` ~line 59). Convert it to a world-space velocity (units per second, not per frame — divide by `dt`) and smooth it over ~3 frames so a single jittery sample can't produce an absurd curve.

**B2.** In `applyEnglish` (near-plane hit), set curve from that paddle velocity scaled by `curveFromPaddleVel`, sign-matched so that swiping right bends the ball right.

**B3.** Do the same for the AI at the far plane, using the AI paddle's own movement delta. The original does this and it is the source of its best emergent behavior: a fast-tracking high-level AI naturally returns wickedly curved shots with no special-case code. **Do not hand-author AI curve.** Let it fall out of the AI's motion.

**B4.** Our player paddle currently tracks input with little or no lag. Verify it produces a usable velocity signal. If it snaps instantly, add a `paddleFollowLerp` config value (start `0.55`, meaning it closes 55% of the gap per frame-equivalent, dt-corrected) so there is a real velocity to read. Do not add lag beyond what is needed for the signal — responsiveness outranks fidelity to the original here.

**B5.** Keep the existing serve drag-spin. It should now write into `curveX/curveY` instead of directly into `vx/vy`, so a served ball curves for its whole flight.

### Part C — Scoring with teeth

Currently: 10 per hit, 100 per opponent life. That is too thin for an endless high-score game.

**C1.** Add to `Config.swift` (mirroring the original's degrade model — each bonus is worth less each time you use it, resetting when you lose a life):

| Value | Start | Degrade per use |
|---|---|---|
| `hitScore` | 100 | 10 |
| `curveBonus` | 50 | 5 |
| `superCurveBonus` | 150 | 15 |
| `accuracyBonus` | 100 | 10 |
| `levelClearBonus` | 3000 | ticks down over elapsed level time |

All floor at 0. All reset to their start values when the player loses a life.

**C2.** Award `curveBonus` when the resulting curve magnitude exceeds `curveBonusThreshold` on one axis; `superCurveBonus` when it exceeds `curveSuperThreshold` on **both** axes.

**C3.** Award `accuracyBonus` for striking within a small centered window of the paddle. Add `accuracyWindowFrac` to Config (start `0.15` of paddle half-extent).

**C4.** `levelClearBonus` decays while the ball is live during a level and is banked on level clear — this rewards fast, aggressive clears.

**C5.** Add a transient on-screen popup using the existing `PixelLabel`: "CURVE BONUS", "SUPER CURVE", "PERFECT HIT". These are not decoration — in the original they are the *only* thing that teaches the player the curve mechanic exists. Keep them short, snap them to the pixel grid, and route their timings through Config.

### Part D — Difficulty lane at the ceiling

**D1.** Clamp the AI paddle so its center cannot come within half a paddle-width of any wall (the original does exactly this). Combined with our existing `aiLateralFrac` cap, this makes wall-hugging shots the reliable scoring lane at high levels — a real skill expression instead of a pure reaction test.

**D2.** Re-verify the `aiLateralFrac` safety ceiling still never binds after the paddle-velocity and curve changes. Produce the numeric table across levels 1–10 in your results file. If it now binds, say so with numbers; do not silently retune it.

### Part E — Deletions

Each of these is verified present in the current build. Remove them.

**E1.** The perspective face-grid render path is dead. `Config.gridDepthLines` and `Config.gridLongLines` are both `0`, so the loops at `GameScene.swift` ~390–451 never execute and `gridLines` is always allocated empty. Delete the loops, the `gridLines` array, the sizing at ~533, and these five Config constants: `gridDepthLines`, `gridLongLines`, `gridAlphaNear`, `gridAlphaFar`, `gridLineWidthNear`. Also remove the now-orphaned use in `Nodes.swift` ~239–240.

**E2.** `Config.ballDrawScale` is `1.0` — a no-op multiply in two hot-loop sites (`GameScene.swift` ~1554, ~1589). Delete the constant and the multiplications.

**E3.** `Config.serveSwipeMinMac` and `Config.serveSwipeMin` are both `18`. Collapse to one.

**E4.** `Config.railLineWidth` exists as *both* a stored constant and a function `railLineWidth(index:)`, and both are live. Rename the stored one to `railLineWidthDefault` so the overload stops being a reading hazard.

**E5.** `Config.hudTopGap` is commented "Legacy alias — HUD now keys off heartsInsetFromNearRing" but is actually live at `GameScene.swift` ~467, and `heartsInsetFromNearRing` does not exist. Delete the false comment. Do not delete the constant.

**E6.** A crescent moon is still drawn at `Nodes.swift` ~91–99, but Brooks explicitly asked for no moon. **Do not delete it unilaterally** — flag it in your results file with a screenshot so he can decide. It may have been kept deliberately.

### Part F — What NOT to adopt from the original

Recorded so you don't "improve" toward it later:

- **Its level-10 AI.** At `skillFactor = 1` it lands exactly on the ball every frame — unbeatable by construction, escapable only through its wall clamp. We keep a bounded speed cap.
- **Its collision test.** It uses Flash's screen-space bounding-box `hitTest`. We use true z-crossing and must keep it — it is why we don't tunnel at high speed.
- **Its win state.** It ends at level 10. CyberPong is endless by design. Do not add an ending.
- **Its frame-locked physics.** See A3.
- **Its server-side PHP leaderboard.** If we want global scores it will be Game Center, and it is out of scope for v1.5.
- **Its 5-life model.** We use 3 spare lives (= 4 total misses), +1 per level cleared, capped at 3. Do not change this.

### Part G — Judgment call, already decided

**Keep contact-offset english, but demote it.** The original has no contact-offset mechanic at all — curve is purely paddle velocity. Deleting ours would be closer to the original, but it would make *where* on the paddle you hit the ball meaningless, reducing the near paddle to a binary "touched it / didn't." That is a real loss for a touchscreen game where precise placement is the main expressive act.

So: reduce `Config.englishStrength` from `0.88` to about `0.45`, keep `serveCornerBoost`, and let paddle-velocity curve become the dominant tool. Tune from there by feel. If after playing you believe offset english should go entirely, argue it in your results file with specifics — do not remove it in this pass.

---

## Constraints

- **`Config.swift` is the only tuning surface.** Every new number goes there with a doc comment. A magic number in `GameScene.swift` is a bug.
- **A dead Config knob is a bug.** If you add a value and don't wire it, delete it before reporting.
- **No new dependencies. No asset files.** Everything stays procedural.
- **Physics stays delta-time based.** Never port a per-frame constant literally.
- **Do not touch** `Store.swift`, `PrivacyInfo.xcprivacy`, `Products.storekit`, or the StoreKit scheme wiring. That is shipped App Store groundwork and is unrelated to this work.
- **Do not touch** the pbxproj beyond registering genuinely new source files. If you add a file, verify the UUID does not collide with an existing one — this has caused a real breakage in this repo before.
- **Do not add a win state, do not change the lives model, do not add ads.**
- **Do not run iOS Simulators.** Brooks's machine handles them badly. Build for device or Mac Catalyst and verify there.

## Testing — read this carefully

Brooks's standing rule across all his projects: **a test that cannot fail is a bug, not coverage.** Every test you add must be demonstrably red against pre-change code and green after. Show both states in your results file.

The existing test target is not currently runnable (no simulator by request, and its macOS deployment target exceeds the host's OS). So: write the curve and scoring logic as **pure functions with no SpriteKit dependency**, in a plain Swift file, and drive them from a small command-line harness you can actually execute. Prove these:

1. Curve decay is frame-rate independent — the same elapsed time produces the same deflection at simulated 60 Hz and 120 Hz, within tolerance.
2. Total speed is preserved across a curve step (Part A4).
3. `minVzFraction` is never violated after curve is applied.
4. Curve magnitude never exceeds `curveMax`.
5. A wall bounce inverts the curve on the reflected axis and damps magnitude.
6. Each score bonus degrades to exactly 0 and never goes negative.
7. Bonuses reset to their start values on life loss.

If you cannot run something, **say you could not run it.** Do not report a test as passing that you did not execute.

---

## Definition of done

- Ball visibly arcs down the tunnel; a hard lateral swipe produces an obviously bent shot.
- The AI returns curved balls, purely as a consequence of its own tracking motion.
- All four scoring bonuses fire, degrade, floor at 0, and reset on life loss.
- Popups appear for curve, super curve, and perfect hit.
- All seven logic assertions above shown red-before / green-after.
- Every item in Part E deleted, except E6 which is flagged for Brooks, not actioned.
- No new Config knob is unused; no new magic number outside Config.
- Builds clean for iOS device and Mac Catalyst.
- `STATUS.md` header updated (stage, tests, last-updated, one line under Recent movement) and a dated entry appended to `LEDGER.md`.

## Report back

Write your results to `~/Desktop/umbrella/inbox/GROK_TO_CLAUDE_cyberpong_v1_5_RESULTS.md` covering:

- What you changed, file by file.
- The red-before / green-after evidence for all seven assertions.
- The `aiLateralFrac` numeric table from D2.
- Your recommended final values for `curveDecayPerSecond`, `curveFromPaddleVel`, and `englishStrength` after playing it, and what each felt like.
- The E6 moon decision, with a screenshot.
- Anything you chose not to do, and why.

Then rename this file to `DONE_GROK_HANDOFF_v1_5.md`.
