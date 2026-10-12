# Phase 0 — Foundation and isolated project

Date: 2026-10-12. Scope: Phase 0 only. Foundation checks passed; no gameplay or persistence system built.

## 1. What was built

- Reused the existing GrowAPlanet repository and the owner's explicitly confirmed isolated experience:
  place **94365962623582**, universe **10770529946**. No duplicate experience was created.
- Configured repository-local Git identity for fenziiarg. Added pinned tool versions, Wally/TestEZ,
  official pinned ProfileStore, release/development Rojo mappings and repeatable bootstrap/check/serve scripts.
- Added six empty frozen central config registries with typed schemas, separated server/client/shared paths.
- Built and imported an original Blender cube fixture, retaining editable source, export and audit scripts.
- Reviewed Check-UI and free alternatives; documented a cohesive original UI implementation approach,
  source licensing, setup, owner tasks and evidence. No UI screens were implemented in this phase.

## 2. Verified behavior

| Item | Method | Evidence | Result |
|---|---|---|---|
| Correct Studio target | Read place/universe IDs and received explicit owner confirmation before edits | IDs in studio-import.json; owner confirmation in chat | PASS |
| Dependency bootstrap | Ran scripts/bootstrap.ps1 with local Wally cache and type-definition hash check | Installed locked TestEZ; subsequent type/build checks | PASS |
| Formatting | StyLua --check src tests | ../evidence/phase-0/checks.txt | PASS |
| Lint | Selene src tests | Same log: zero errors/warnings/parse errors | PASS |
| Strict type analysis | luau-lsp analyze with Roblox definitions and development sourcemap | Same log; exit 0 | PASS |
| Both project builds | Rojo release rbxlx and development rbxl | Same log | PASS |
| Release isolation | XML assertions: no Script/LocalScript or TestEZ/pipeline runner in release | scripts/check.ps1 and checks.txt | PASS |
| ProfileStore pin | SHA-256 of vendored official source | scripts/check.ps1, manifest | PASS |
| Real Rojo synchronization | Served localhost:34872, connected plugin, revised repo script and played | ../evidence/phase-0/studio-console.txt, revision=2 | PASS |
| Config/runtime dependencies | Studio assertions required six empty frozen registries, checked server-only ProfileStore and loaded TestEZ bootstrap | PIPELINE_PASS console line | PASS |
| Blender source and export | Fresh process built .blend/FBX, separate process reopened blend and reimported FBX | ../evidence/phase-0/blender.json | PASS: one mesh, 8 vertices, 6 faces, no script/linked library content |
| Studio import | 3D Importer imported original FBX; MCP inspected and calibrated MeshPart | ../evidence/phase-0/studio-import.json and studio-import.png | PASS: one MeshPart, zero scripts |
| Camera/screenshot | Studio MCP capture from explicit camera position | studio-import.png shows cube over spawn | PASS |

The test script is an integration assertion, not gameplay unit-test coverage. TestEZ is loaded and ready;
there is no pure gameplay logic to unit-test in Phase 0. Third-party source was audited but not subjected
to authored-code formatting or strict-type gates. The only luau-lsp warning concerns unsupported CLI file-watcher registration.

## 3. Untested assumptions

- ProfileStore saving, rejoin persistence, session conflicts, load-failure handling and shutdown saves.
  Installing the dependency is not implementation of those systems. No DataStore write was intentionally run.
- Studio API Services setting, published-server behavior and end-to-end production asset availability.
- Responsive UI, accessibility, input simulation, device performance and touch interaction.
- The imported mesh's durable asset ownership/availability: upload was unchecked, but Studio returned
  mesh ID 128741790029501. This is an observed ID, not a production asset guarantee.
- Fresh-host tool installation: this host already had the pinned executable versions cached.

## 4. Known bugs and limitations

- FBX importer default scale converted two Blender units to 200 studs. Test instance calibrated to two studs;
  future imports need 0.01 scale plus dimension verification. No production mesh depends on this fixture.
- Check-UI declares MIT in its README but lacks a standalone license notice in the inspected tree.
  Reference copies remain outside the game; original UI implementation is selected. Embedded media IDs are unused.
- Studio's title has not been renamed. IDs and owner confirmation establish identity.
- Local Studio contains the development test fixture and runner. Do not publish this development session;
  use the release mapping/build. Release output contains no executable scripts at this phase.
- No unrelated project was opened for editing or written by these operations. No claim of a full forensic
  before/after comparison of unrelated directories is made.

## 5. Devices actually tested

Windows desktop running Roblox Studio. No physical mobile/tablet or console tested. No mobile-emulation
acceptance test was performed. Studio playtest is not a published live-server test.

## 6. Economy snapshot

All six central config tables are intentionally empty. Only typed schemas exist. No resource amounts,
production rates, stage thresholds, region counts, prices or pacing values were chosen or measured.

## 7. Proposals needing owner approval

- Accept the original Check-UI-inspired slate/cyan/gold design direction, built-in fonts and original icons.
- Use vendored official ProfileStore pinned by commit and Wally for TestEZ.
- Reuse the existing owner-confirmed experience/repository instead of creating duplicates (already authorized).
- No balance proposals, scope cuts, deferred features or monetization were added.

## 8. Blockers needing the owner

No remaining blocker for the Phase 0 foundation acceptance criteria.

- [ ] Review this report and explicitly approve before Phase 1 begins.
- [ ] Before Phase 1 persistence acceptance, verify Studio API Services access as described in OWNER_SETUP.md.
  This remains an owner action, not a Phase 0 saving claim.
- [ ] Optional experience rename; later physical-device testing and production asset ownership checks.

## 9. Next phase proposal

After explicit approval only: Phase 1 core server-authoritative resource engine and safe ProfileStore saving,
minimal test UI and pure-logic tests, exactly as PHASE_PROMPTS.md specifies. Work is stopped at this gate.

## Delivery

All source, original asset files, documentation and evidence are intended for the authorized GitHub origin.
Final commit and remote verification are reported in chat after push; generated builds, caches and installed
packages are intentionally ignored. No public game publication or purchases were performed.
