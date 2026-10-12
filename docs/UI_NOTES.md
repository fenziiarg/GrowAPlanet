# UI foundation decisions

Phase 0 prepares the design foundation; no gameplay screens or interactive UI have been built.

## Check-UI review

Reviewed TemporaryLooker22/Check-UI-Clean-Roblox at commit
52ac1edfe33b76d415c4f14dc5bd17307148f0a3: SKILL.md, DESIGN_SYSTEM.md, Theme,
Components, Controller, Icons, and all five supplied example modules. A local, Git-ignored reference copy is kept under
docs/references/check-ui and is excluded from every Rojo mapping. Icon ID tables were inspected as data;
their individual Roblox media licenses were not verified. None are selected for use.

The upstream README declares MIT and commercial use, but the inspected tree lacks a standalone LICENSE
and copyright notice. Preserve that declaration and attribution. Use the design guidance and original
implementations; do not ship copied upstream code until the full notice is clarified. This avoids blocking
the original UI foundation on uncertain media provenance.

Adopt its compact, beveled slate panels: slate #3B5866, dark borders #181E22, recessed surfaces #1A2C34,
cyan for planet information, gold for civilization information, lime for enabled actions, silver for disabled
actions and red for invalid actions. Use Roblox built-in GothamBlack for short labels with readable supporting
text. These are design proposals, not gameplay balance values.

Adapt layouts to screen width with reflow, 44-pixel minimum touch targets, safe-area handling and readable
labels. Keep motion brief; add reduced-motion support when motion is implemented. Connections and tweens
need cleanup and camera references must tolerate replacement. Upstream fixed minimum scaling can clip
small displays; do not copy it unchanged. The reviewed controller/component examples contain persistent
connections, cached camera assumptions and example callback behavior requiring replacement.

Examples are references only. Do not import their shop, rebirth, daily reward or deferred-feature menus.
No invented asset IDs, fake counters or inactive buttons may enter game UI.

## Free alternatives evaluated

| Source | License evidence | Decision |
|---|---|---|
| Check-UI | Upstream README MIT declaration, pinned reference | Design language first; original implementation, no copied runtime yet |
| Fusion (dphfox) | MIT LICENSE retained | Evaluated optional reactive library; no current need, not installed |
| Lucide | ISC with MIT Feather-derived subset; full notice retained | Evaluated, not selected: no icon assets imported |
| Kenney UI packs | https://kenney.nl/support says assets CC0 | Candidate only; no individual pack downloaded or selected |
| Roblox built-in fonts | Explicitly permitted by project AGENTS.md | Selected; no external font download or asset upload |
| Original shapes and line icons | Original work | Selected for first implementation; no Phase 0 UI art generated |

This keeps one cohesive visual style and avoids extra framework dependencies before any screen exists.
No paid resources, unknown-license images or upstream icon IDs are used. Any later external icon/font/kit
must receive an individual manifest entry and preserved notice before use.

Accessibility, responsive behavior and the resulting look remain untested until there is actual UI.

Owner accepted the original Check-UI-inspired direction before Phase 1.
