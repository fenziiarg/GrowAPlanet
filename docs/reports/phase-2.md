# Phase 2 — Planet growth

Date: 2026-10-13 (UTC). Scope: Phase 2 only. No regions, strategic camera, eras, buildings or offline income.

## 1. What was built

- **Growth stats.** Earth Mass, Water Mass and Total Size are derived on the server from two saved growth levels
  (`src/shared/Planet.luau`). Players grow the planet by spending Growth Points on "Add Earth" or "Add Water".
  Every price, mass step, income bonus, size formula and threshold lives in `src/shared/config/planet.luau`.
- **Five stages.** Barren Rock → Volcanic → Oceanic → Habitable → Mature World, each with Earth and Water
  minimums in config. Water unlocks at Volcanic. Each growth level adds +1 Growth Point/s, so growth feeds the
  click → grow loop.
- **Server authority.** The client sends `("Grow", "Earth"|"Water")`. The server checks a dedicated rate limit
  (burst 10, 6/s), the unlock stage, the max level (1000) and the price, then commits balances and levels together.
  Rejections are logged per category (`locked`, `insufficient_funds`, `malformed_intent`, `growth_rate`, `max_level`).
- **One planet model, scaled by attributes.** The client copies the server's EarthMass, WaterMass, TotalSize and Stage
  onto a single `HomePlanet` model. `src/client/PlanetView.luau` rebuilds the stage look when Stage changes and
  calls `Model:ScaleTo` (0.5 s ease) when TotalSize changes. It is built from primitive parts and built-in materials,
  with no imported assets. Each player renders only their own planet.
- **Distinct looks:**
  - Barren Rock: grey cratered rock.
  - Volcanic: black basalt, glowing lava vents, orange haze.
  - Oceanic: ocean shell with rocky islands and a pale atmosphere.
  - Habitable: green continents, blue ocean and polar ice.
  - Mature World: larger continents, cloud sheets and atmosphere.
- **Stage-up notification.** The server fires a `Notify` remote; the client shows a 3 s top-centre toast.
- **Save data.** Profile schema v2 (`planets.home.growth`) with a v1→v2 upgrade done on a validated copy.
  Malformed or unknown records are still released untouched.
- **HUD.** A Planet panel (stage, stats, income, two growth buttons with price or lock reason) beside the
  existing Resources panel.
- **Debug and tests.** Bridge commands `Grow` and a stage-pacing bot (`Simulate`); 12 new unit tests (38 total).

## 2. Verified behavior

Evidence lives in `docs/evidence/phase-2/` (`acceptance-playtest.txt` plus screenshots). Testing was local Studio
Play. Studio scripts were verified identical to the repo (23/23) before each session.

| Item | Method | Evidence | Result |
|---|---|---|---|
| Format, lint, strict types, both builds, release isolation | `scripts/check.ps1` | `CHECKS_PASS` on the final tree | PASS |
| Unit tests (thresholds, monotonic stats, cost, locks, max level, income, schema migration) | TestEZ in Studio Play | `TESTS_PASS passed=38 failed=0` | PASS |
| Screenshots of all 5 stages, clearly different | `screen_capture` during live progression | `stage-1…5-*.png` | PASS (see section 4 for capture timing) |
| Planet scales with Total Size | Wide shots from one fixed camera; client model inspection | 1000 km → scale 0.40 (stage 1); 4140.8 km → 1.656 (stage 5) | PASS |
| Each stat increases, stages trigger at config values | Scripted live progression with assertions on every purchase | Transitions at exactly 800/0, 1600/600, 2600/1400, 4200/2800 | PASS |
| Growth bought from the real HUD | 3 mouse clicks on Add Earth | earthLevel 0 → 3, income 1 → 4/s, model rescaled | PASS |
| Invalid and locked growth rejected | 5 bad payloads from the client | `locked=1`, `malformed_intent=4`, levels unchanged | PASS |
| Growth spam limited | 15 Grow requests in one frame | 10 accepted, 5 `growth_rate`, logged | PASS |
| Stage-up notification | Live `STAGE_UP` logs; real `Notify` remote re-sent to show the toast | Console lines; `stage-up-toast.png` | PASS (see section 4) |
| Planet state restored after rejoin | Stop Play → start Play, server and client inspected | Levels 42/28, stage 5, 4140.8 km restored; model rebuilt at scale 1.656 | PASS (Studio namespace) |
| v1 save migrates without loss | Existing v1 Studio record loaded under v2 code | 2,355.6 GP saved → live 2,404.8 GP, schema 2 | PASS |

## 3. Untested assumptions

- **Release build and live servers.** Only Studio Play was tested.
- **Performance.** The model has at most 49 parts, all non-colliding and non-queryable. FPS was not measured,
  and nothing was tested on a phone.
- **Phone and tablet layouts and touch input.** Not tested (see section 4).
- **Long sessions and leaks.** Not measured. The renderer rebuilds only on stage changes and cleans its tween,
  connections and model through its Janitor, but this was observed by reading the code, not measured.
- **Toast under a real transition.** The toast screenshot came from re-sending the real `Notify` message, not from
  a live stage-up. The live stage-ups printed `STAGE_UP` from the same code that fires that message.

## 4. Known bugs and limitations

- **On phones the HUD would cover the planet.** Each panel takes half the screen width, capped at 380 px. Fine on
  desktop; responsive layout is Phase 5.
- **Stage 1–4 screenshots predate the Mature World revision.** The revision touched only Mature-only rendering
  (cloud sheets) and Mature config (land height and colour). Stage 5 images are from the final code. There are no
  same-camera wide shots for stages 2–4; the close-ups show the stage size in their HUD.
- **The camera is the default character camera.** The planet floats at (0, 170, -300). The strategic camera
  belongs to Phase 3.
- **Water Mass changes stage and size, not ocean coverage within a stage.** Ocean coverage is a Phase 3 proposal
  per GAME_SPEC §4.
- **Once growth income dominates, clicking matters little.** The bot reaches Mature World at 19.2 min with
  3 clicks/s versus 20.7 min idle.
- **The Studio test profile is now Mature World** (42/28, about 30K GP). Live data was untouched.
- **Rojo was not connected for this phase's tests.** Sources were mirrored and diff-verified instead (see the
  evidence file). Reconnect Rojo before further edits.

## 5. Devices actually tested

Windows desktop, local Roblox Studio Play, one player. No physical phone or tablet, no device emulation, and no
published live server.

## 6. Economy snapshot

| Key | Value |
|---|---|
| Earth | base 10 GP, ×1.18 per level, +100 mass, +1 GP/s per level |
| Water | base 20 GP, ×1.18 per level, +100 mass, +1 GP/s per level, unlocks at Volcanic |
| Stage minimums (Earth / Water) | Volcanic 800/0, Oceanic 1600/600, Habitable 2600/1400, Mature World 4200/2800 |
| Total Size | 1000 km × (1 + total mass / 100)^(1/3); 1000 km at start, 4141 km at the Mature minimum |
| Visual size | 0.02 studs per km (model radius 20 → 83 studs) |
| Max level | 1000 per growth |
| Growth rate limit | burst 10, refill 6/s |

Measured pacing (bot simulation, **simulated**, not human-verified):

| Stage | 3 clicks/s | Idle |
|---|---|---|
| Volcanic | 21 s | 41 s |
| Oceanic | 1.0 min | 1.5 min |
| Habitable | 2.9 min | 3.5 min |
| Mature World | 19.2 min | 20.7 min |

Against GAME_SPEC §5, the planet visibly grows within the first minute. The first-era target is Phase 4 work;
I propose tying Stone Age to Habitable, which arrives at about 3 minutes.

## 7. Proposals needing owner approval

- The growth numbers and stage thresholds in section 6.
- The Earth/Water purchase model: Total Size derived from total mass, and Water unlocking at Volcanic.
- Growth levels adding passive Growth Point income.
- Built-in parts for the planet model instead of a Blender mesh. Phase 3 regions may need a dedicated sphere
  mesh; I'll propose that there.
- The five stage looks, as shown in the screenshots.
- No cuts and no deferred features.

## 8. Blockers needing the owner

- [ ] Review this report and explicitly approve before Phase 3 begins.
- [ ] Reconnect the Rojo plugin (`./scripts/serve.ps1 -Development -Port 34873`) before the next phase's edits,
  so syncing no longer relies on the mirror workaround.

## 9. Next phase proposal

After explicit approval only: Phase 3, the planet map and strategic camera. That means real raycast-picked
regions covering the sphere, terrain types, a drag/zoom camera that frames the growing planet, and region data
saved with stable IDs, per PHASE_PROMPTS.md. Work is stopped at this gate.
