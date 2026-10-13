# Phase 1 — Core engine and saving

Date: 2026-10-12. Scope: Phase 1 only. No planet visuals, regions, eras, buildings or offline income were built.
Code commit: 551a6cc, plus the acceptance follow-up commit that adds this report.

## 1. What was built

- Server-authoritative resource engine: seven balances (Growth Points + Population, Food, Materials, Energy,
  Money, Research) live only in the server profile. The client sends exactly one argument, the intent
  `"Click"` or `"Ready"`; anything else is rejected.
- Click for Growth Points (+1 per accepted click) and +1 Growth Point per online second, integrated from server
  elapsed time. Two token buckets per player: clicks (burst 8, refill 8/s) and all requests (burst 16, refill 12/s).
  Rejections are counted per category; warnings are throttled to one per category every 5 s.
- Big numbers (`src/shared/BigNumber.luau`): a normalized `{m, e}` pair meaning `m × 10^e`, with `1 ≤ m < 10`
  (zero is `{0, 0}`), exponents from -300 to 3000. Add, subtract (rejects overdraft), scale, compare and validate.
  Chosen over a plain double because the economy must pass 1.8e308 without becoming `inf`. It is cheap and saves
  compactly in ProfileStore. Precision is about 15 significant digits: approximate arithmetic, not exact integers.
  Formatting: K, M, B, T, Qa, Qi … Dc with up to one decimal, rounding promoted across suffix boundaries
  (999 999 → 1M), then scientific notation (`2.5e400`).
- ProfileStore saving: schema v1 (`planets.home.resources`, so future planets are namespaced), Studio store
  `GrowAPlanet_Studio_v1` and live store `GrowAPlanet_Live_v1`, keys `Player_<UserId>`. Session locks via
  `StartSessionAsync` with cancel on leave, shutdown or a 30 s deadline. It never uses Steal or ProfileStore's mock fallback.
  Unknown schemas and malformed balances are rejected without reconciling defaults. Failed loads kick and write nothing.
  It saves on leave, and on `BindToClose` it ends sessions and waits for pending loads.
- Minimal HUD (`src/client/Main.client.luau`): seven balances in a scrolling list and a Grow button. The client
  never predicts rewards; it shows server snapshots (at most one every 0.25 s).
- Debug tools (`tests/Debug.luau` plus a bindable bridge in `tests/Pipeline.server.luau`): inspect, time-skip and pure
  simulation, plus a real-DataStore persistence acceptance test. Studio-only (`RunService:IsStudio()` asserts) and
  development mapping only. `scripts/check.ps1` asserts that none of it, nor TestEZ, appears in the release build.
- 26 TestEZ unit tests for formatting, big-number math, resource math, rate limiting and session-load failure handling.

Follow-up since 551a6cc (this commit): the resource list became a scroll frame with the Grow button anchored to the
panel bottom, which stops the button scrolling away on short screens. Also added: the `Inspect` debug command, the
bindable bridge (MCP `require` calls get an isolated module cache, so they cannot see the live Service), and a `-Port`
option on `serve.ps1`.

## 2. Verified behavior

Evidence lives in `docs/evidence/phase-1/`. Playtests ran in local Studio Play on place 94365962623582. Studio
scripts were checked byte-identical (after newline normalization) to the repo working tree: 19/19.

| Item | Method | Evidence | Result |
|---|---|---|---|
| Format, lint, strict types, both builds, release isolation, ProfileStore hash | `scripts/check.ps1` | `CHECKS_PASS` (run 2026-10-12 on the final tree) | PASS |
| Suffix formatting at 999, 1.5K, 2.3M, 4B, 7T, 9Qa, 2Qi (beyond Qa), 2.5e400 | TestEZ unit tests in Studio Play | `TESTS_PASS passed=26 failed=0` (both playtest sessions) | PASS |
| Resource math (add/subtract/scale, overdraft, nonfinite, time integration) | Unit tests | Same run | PASS |
| Earning by real UI clicks | `user_mouse_input` clicked the Grow button 5×; server state inspected | `accepted=5`; GP +19.8 over ~15 s | PASS |
| Join, earn, leave, rejoin with data intact | Stop Play → start Play; server inspect before and after | 466.3 GP before stop → saved 472.0 → loaded, continued to 486.3 | PASS (Studio namespace) |
| Client resource amounts rejected | 5 amount-bearing payloads fired from the client datamodel | `malformed_intent=5`, Money stays 0, `REJECT malformed_intent` log | PASS |
| Rapid remote spam rate limited | 200 `Click` intents in 0.0004 s | 184 `request_rate` + 8 `click_rate` rejects, only 8 accepted; both REJECT logs | PASS |
| Forced load failure does not overwrite data | Real ProfileStore save on a unique `Acceptance_` key, injected acquisition failure, reread, reopen | saved 42 → after failure 42 → reopened 42 | PASS (see the limitation in section 4) |
| Data services unavailable → no defaults | Earlier playtest with Studio API access disabled | `initial-playtest.txt`: `LOAD_FAILED … no default profile created` and kick | PASS |
| Debug time-skip and simulation | Bridge in Server datamodel | skip 600 s → +600 GP; negative skip refused; 1 h simulation result labeled `simulated=true` | PASS |
| HUD renders server balances | Studio screenshot during Play | `hud-playtest.png` | PASS (desktop viewport only) |

## 3. Untested assumptions

- **Published live servers.** Only Studio Play was tested, against the Studio namespace. The live namespace,
  real multi-server session locking and Roblox shutdown timing on live servers are untested.
- **Shutdown save under load.** The rejoin test exercised leave/stop with one player. `BindToClose` with
  many players, or with a load still in progress, was not separately observed.
- **Session loss mid-play** (another server taking the lock → kick) was not triggered.
- **The release build was not played.** Its contents are checked structurally by `check.ps1`; it was not run in Studio.
- **HUD on phone and tablet sizes and touch input** were not tested: no device emulation run, no physical device.
- **Long-session leaks** (connections and instances over hours) were not measured.

## 4. Known bugs and limitations

- **The forced load failure is injected at the session adapter** (`Session.load` receives a nil or throwing
  loader), not inside ProfileStore's own DataStore calls. The other real failure path covered is "API services
  unavailable" (initial playtest). A DataStore error in the middle of a ProfileStore load was not forced.
- **Big numbers are approximate.** A tiny reward next to a huge balance can fall below precision; this is
  documented in `docs/ENGINE.md`.
- **The debug bridge argument order** is `(command, player, seconds, clicks)`, so Simulate needs `nil` for player. It is a
  development-only API, not a bug in shipped code, but easy to misuse; I hit it once during testing.
- **Development test traffic changed this account's Studio-namespace profile.** Correction found in Phase 2:
  it ended at 2,355.6 GP, not about 1.1K. Two failed debug-script attempts each applied the 600 s skip before
  erroring, so three skips ran.
  It also left one `Acceptance_…` key in the Studio namespace. Live data is untouched.
- **The Studio MCP is registered for Codex, not Claude Code.** This session drove `StudioMCP.exe` through a
  stdio client. It is now also registered with Claude Code for this project (`claude mcp add … Roblox_Studio`).
- **Rojo was not running during acceptance.** Studio already held exactly the working-tree sources (verified by
  diffing). Reconnect Rojo (SETUP.md) before further edits.

## 5. Devices actually tested

Windows desktop, local Roblox Studio Play (one player). No physical phone or tablet, no device emulation, and no
published live server.

## 6. Economy snapshot

From `src/shared/config/economy.luau`:

| Key | Value |
|---|---|
| Starting balances | 0 for all seven |
| Click reward | +1 Growth Point |
| Online production | +1 Growth Point/s; 0 for the other six resources (no earning systems until Phase 4) |
| Click limit | burst 8, refill 8/s |
| Request limit | burst 16, refill 12/s |
| Snapshot interval / tick | 0.25 s / 0.1 s |
| Max debug skip or simulation | 3600 s |

Measured (playtest): about 1 GP/s passive, plus 1 per click. Simulated (bot, not human): 1 hour at 2 clicks/s ≈ 10.8K GP.
The pacing targets in GAME_SPEC §5 cannot be measured yet: nothing spends Growth Points until Phase 2 adds growth.

## 7. Proposals needing owner approval

- The `{m, e}` big-number method and the K…Dc suffix list, followed by scientific notation.
- Rates: +1 GP per click, +1 GP/s online; click limit 8/s (burst 8), request limit 12/s (burst 16).
- Profile layout: schema v1, `planets.home.resources`, separate Studio and live namespaces.
- No spec deviations or cuts. No deferred features were built.

## 8. Blockers needing the owner

- [ ] Review this report and explicitly approve before Phase 2 begins.
- [x] Studio API Services access: observed **enabled** on 2026-10-12 (ProfileStore reported API services available).
  This agent did not change the setting.
- [ ] Optional: physical phone testing when there is real gameplay UI (Phase 5).

## 9. Next phase proposal

After explicit approval only: Phase 2, planet growth. Earth Mass, Water Mass and Total Size driven by growth; one planet model scaled by attributes; the five stages with config thresholds and distinct looks;
a stage-up notification; stats saved in the existing `planets.home` namespace. Work is stopped at this gate.
