# PHASE_PROMPTS.md: Paste these into Codex one at a time

**Change request (2026-10-12, owner):** Earth stage names (Barren Rock, Volcanic, Oceanic, Habitable, Mature World) are removed. Progression uses Human History ages, cities are developed per region with socioeconomic stages, and the planet's look changes at Kardashev milestones. GAME_SPEC.md section 5 is the source of truth. Phases 0-3 stay as built. Phase 4 implements the ages, city development and the Kardashev visuals. Do not start Phase 4 until the owner approves.

Before starting, put `AGENTS.md`, `GAME_SPEC.md`, and this file in the repo root.
After each phase, read the report, test the game yourself if you can, then paste the next prompt.

---

## KICKOFF (paste first, once)

```
Read AGENTS.md, GAME_SPEC.md, and PHASE_PROMPTS.md in full. Follow AGENTS.md at all times.
Do not start any phase yet. First, inspect every connected tool and the current Studio place.
Report each as Working / Not working / Missing:
1. Git installed, GitHub access working.
2. Rojo installed and able to serve a project to Studio.
3. Roblox Studio MCP: can it read the place, edit scripts, start a playtest, read output logs,
   and take screenshots? Can it move the camera to a given position and simulate a mouse click
   at a screen position? List what it can NOT do.
4. Blender MCP: create a cube, save it, export it in a format Studio can import.
5. Studio API access for saving/DataStore testing: enabled or not.
6. Device emulation (phone/tablet) available for UI and performance checks.
7. Free asset and UI sources reachable (GitHub and the web).
8. Lint/format/type-check tools available.
Also report what the existing workspace contains (a horns project exists; do not touch it), and
any questions that block Phase 0. For every missing or limited item, say which later phase checks
it would make unverifiable. Then stop and wait.
```

---

## PHASE 0: Foundation and isolated project

```
Execute Phase 0 only.

Goal: an isolated, version-controlled project that is ready to build in.

Do:
1. Create a NEW place/project for Grow a Planet, separate from the horns project and Roll & Grow.
2. Create the GitHub repo and a Rojo project (src/server, src/client, src/shared, assets/, docs/).
3. Install and pin the toolchain (Rokit/Aftman, Wally, StyLua, Selene, luau-lsp, a unit test
   framework). Add ProfileStore as a dependency and record its license.
4. Read the Check-UI-Clean-Roblox repo (SKILL.md, DESIGN_SYSTEM.md, source modules, examples).
   Then search GitHub and the web for free UI resources to fill any gaps: open-source Roblox UI
   libraries, UI kits, icon packs, and fonts with commercial-friendly licenses. Choose what you
   will use and write docs/UI_NOTES.md with your choices, licenses, and how you will adapt them
   into one cohesive style. Log each source in docs/ASSET_MANIFEST.md. No paid UI kits.
5. Create README.md, docs/SETUP.md, docs/ASSET_MANIFEST.md, docs/OWNER_SETUP.md.
6. Create empty central config modules (economy, planet, regions, terrain, eras, buildings)
   with typed schemas, no gameplay yet.
7. Prove the pipeline: Rojo syncs a test script into Studio and it runs via Studio MCP. Prove the
   Blender pipeline: build a test mesh with a standalone script, export it, reimport it.

Done when: repo builds, linters and type checks pass, Rojo sync works, Blender export/reimport
works, the horns project is untouched, and everything is committed.

Then write the phase report (AGENTS.md section 6) and STOP.
```

---

## PHASE 1: Core engine and saving

```
Execute Phase 1 only.

Goal: the server-authoritative economy core with safe saving. No planet visuals yet.

Build:
- Resource engine for the 6 resources plus Growth Points, on the server. Client sends intents only.
- Click/tap to generate Growth Points, with server-side rate limiting.
- Big-number method and suffix formatting (K, M, B, T, Qa...). Choose the method, explain it in
  the report.
- ProfileStore saving: versioned, namespaced profile, safe load-failure behavior, BindToClose.
- Minimal test UI: resources and a click button.
- Debug time-skip/simulation tool (disabled in release).
- Unit tests for number formatting and resource math.

Done when:
- Suffix formatting passes tests at 999, 1.5K, 2.3M, 4B, 7T, 9Qa and a value beyond Qa.
- I can join, earn resources, leave, and rejoin with my data intact (or Untested if Studio API
  access is missing).
- A client attempt to send a resource amount is rejected, with a log as evidence.
- Rapid remote spam is rate limited, with a log as evidence.
- A forced profile load failure does not overwrite my data.

Run a real playtest, fix issues, then write the phase report and STOP.
```

---

## PHASE 2: Planet growth

```
Execute Phase 2 only.

Goal: a planet that visibly grows and changes.

Build:
- Earth Mass, Water Mass, Total Size stats driven by growth.
- One planet model (Blender or built-in parts), scaled by attributes.
- The 5 stages with thresholds in config and a distinct look for each.
- Stage-up notification.
- Stats saved and restored.

Done when:
- Screenshots of all 5 stages exist and look clearly different from one another.
- A scripted test shows each stat increasing and stage thresholds triggering at the config values.
- Planet state is restored correctly after a rejoin.

Playtest, fix, write the phase report, and STOP.
```

---

## PHASE 3: Planet map and camera

```
Execute Phase 3 only.

Goal: the HOI4-style strategic view on the planet, with real clickable regions.

Build:
- Divide the sphere surface into regions covering the whole planet. Choose the approach, justify
  it, and propose the region count in config.
- Terrain types (at least land, ocean, desert; propose others) shown visually. Propose how terrain
  is generated and how Water Mass affects ocean coverage.
- Strategic camera: drag-rotate (including poles), smooth zoom, mouse/keyboard/touch support,
  framing that adapts as the planet grows.
- Hover highlight and click selection by raycast, with a placeholder region panel showing region
  ID and terrain.
- Region data model (terrain, population, building levels) saved and restored, with stable IDs.

Done when:
- A scripted test clicks known screen positions and the returned region IDs match, with logs.
- A test confirms every region is reachable by the camera (poles and back side included), and
  none overlap or leave gaps.
- Screenshots at three zoom levels, and at all 5 planet stages, show regions scaling with the planet.
- Measured frame rate in Studio at the chosen region count is reported. Phone performance is
  reported as Untested unless a physical device or emulation was used.
- Region data survives a rejoin.

This phase is the highest risk for faking. Do not substitute a plain orbit camera or 2D overlays.
Playtest, fix, write the phase report, and STOP.
```

---

## PHASE 4: Civilization and economy

```
Execute Phase 4 only.

Goal: the full era and regional economy system.

Build:
- Human History ages (Stone, Metal, Later Historical, Silicon and AI) with unlock conditions, income multipliers, and upgrade trees.
- Cities per region with socioeconomic stages (Hunter-Gatherer to Post-Industrial). At least 2 buildings per age, built in cities, using the 6 resources.
- Per-region population and production based on terrain (propose the terrain-to-production table
  in config).
- Planet totals from the sum of regions plus era multipliers.
- Era advancement.
- Offline income with a cap, calculated on rejoin.

Done when:
- A scripted simulation reaches each Human History age and each Kardashev milestone, with logs.
- Different terrains produce different outputs per the table, shown by a test.
- Offline income is tested with simulated timestamps: below the cap, at the cap, and past the cap.
- Every build and purchase is validated server-side, including invalid region IDs, with logs for
  rejections.
- Unit tests for production formulas, era thresholds, and offline income.

Playtest, fix, write the phase report, and STOP.
```

---

## PHASE 5: UI, tutorial, audio

```
Execute Phase 5 only.

Goal: the final UI for planet, regions, and civilization.

Build with the Check-UI foundation plus the free UI sources chosen in docs/UI_NOTES.md (no paid
UI kits; log any new source in docs/ASSET_MANIFEST.md):
- Top bar, planet stats panel, full region panel (terrain, population, buildings, build buttons),
  Planet and Civilization tabs.
- Tooltips on all items, unlock and stage-up notifications.
- Settings (reduced motion, sound, music, effects quality).
- Mobile-first scaling.
- Tutorial and audio only as the cut list allows. Audio must be free with verified licenses,
  logged in the manifest.

Done when:
- Screenshots at phone, tablet, and desktop sizes show nothing overlapping or cut off.
- Selecting a region, building in it, and seeing planet totals change works end to end in a playtest.
- No tabs or buttons exist for deferred features.
- Touch targets and safe areas checked on small screens.

Playtest, fix, write the phase report, and STOP.
```

---

## PHASE 6: Balance, optimize, test, release prep

```
Execute Phase 6 only.

- Tune config so the pacing targets in GAME_SPEC.md section 5 are met, using the debug tool.
  State clearly that bot-simulated results are simulated, not verified by a human.
- Optimize per GAME_SPEC.md section 7.
- Run the full test matrix in GAME_SPEC.md section 9, including long-session leak checks and
  data-load-failure / shutdown-save tests.
- Anti-exploit review of every remote.
- Final UI pass on mobile and PC.
- Finalize docs/ASSET_MANIFEST.md, in-game credits, docs/OWNER_SETUP.md (publishing checklist),
  and the list of external blockers.
- State exactly which physical devices were tested. If none, say so.

Write the final report with a verified vs untested table and STOP.
```

---

## LATER (only if I ask)

- **Phase 7:** Military branches, units, and defenses.
- **Phase 8:** PvP (async raids first, then live wars and ranked seasons).
- **Phase 9:** Space expansion: Moon, Mars, the rest of the solar system, and the planet-switch button.
- **Phase 10:** Prestige ("Big Bang").
- **Phase 11:** Monetization, retention, and analytics.
